import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  addDoc,
  arrayUnion,
  collection,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

import {
  booleanArg,
  clientConfig,
  emulatorSettings,
  integerArg,
  numberArg,
  parseArgs,
  shardRange,
  sleep,
  stringArg,
  testPassword,
  testUser,
} from './config.mjs';
import { Metrics } from './metrics.mjs';

const args = parseArgs();
const totalUsers = integerArg(args, 'users', 500, { min: 1, max: 5000 });
const shards = integerArg(args, 'shards', 5, { min: 1, max: 100 });
const shard = integerArg(args, 'shard', 0, { min: 0, max: shards - 1 });
const rampMinutes = numberArg(args, 'ramp', 15, { min: 0, max: 240 });
const durationMinutes = numberArg(args, 'duration', 45, { min: 0.1, max: 1440 });
const chatListeners = integerArg(args, 'chatListeners', 3, { min: 0, max: 100 });
const workflowWritesPerUserMinute = numberArg(args, 'workflowRate', 0.05, { min: 0, max: 10 });
const chatWritesPerUserMinute = numberArg(args, 'chatRate', 0.02, { min: 0, max: 10 });
const maxUsersPerProcess = integerArg(args, 'maxUsersPerProcess', 125, { min: 1, max: 1000 });
const runId = stringArg(args, 'runId', process.env.LOAD_TEST_RUN_ID || 'baseline-500');
const dryRun = booleanArg(args, 'dryRun', false);
const range = shardRange(totalUsers, shard, shards);
const firebaseConfig = clientConfig();
const password = testPassword();
const emulators = emulatorSettings();

if (range.count > maxUsersPerProcess) {
  throw new Error(
    `Shard ${shard} contains ${range.count} users, above the ${maxUsersPerProcess} process safety limit. ` +
    'Increase --shards or explicitly raise --max-users-per-process.',
  );
}

const settings = {
  projectId: firebaseConfig.projectId,
  runId,
  totalUsers,
  shards,
  shard,
  localUsers: range.count,
  userRange: [range.start, range.end - 1],
  rampMinutes,
  durationMinutes,
  chatListeners,
  workflowWritesPerUserMinute,
  chatWritesPerUserMinute,
  emulators: Boolean(emulators),
};

if (dryRun) {
  console.log(JSON.stringify(settings, null, 2));
  process.exit(0);
}

console.log(`Starting shard ${shard + 1}/${shards}: users ${range.start}-${range.end - 1}`);
const metrics = new Metrics(settings);
const clients = [];
const rampMilliseconds = rampMinutes * 60_000;
const launchPromises = Array.from({ length: range.count }, (_, localIndex) => (async () => {
  const delay = range.count <= 1 ? 0 : (rampMilliseconds * localIndex) / (range.count - 1);
  await sleep(delay);
  const userIndex = range.start + localIndex;
  try {
    const client = await startClient(userIndex);
    clients.push(client);
    metrics.increment('clientsReady');
    if (clients.length % 10 === 0 || clients.length === range.count) {
      console.log(`Shard ${shard}: ${clients.length}/${range.count} clients ready`);
    }
  } catch (error) {
    metrics.error('client_start', error, userIndex);
    console.error(`Client ${userIndex} failed: ${error.message}`);
  }
})());

await Promise.all(launchPromises);
console.log(`Shard ${shard}: ramp complete; holding for ${durationMinutes} minutes.`);
await sleep(durationMinutes * 60_000);
await Promise.allSettled(clients.map(stopClient));

const { filename, report } = await metrics.save();
console.log(JSON.stringify(report, null, 2));
console.log(`Report written to ${filename}`);
if ((report.counters.errors || 0) > 0) process.exitCode = 2;

async function startClient(userIndex) {
  const profile = testUser(userIndex);
  const app = initializeApp(firebaseConfig, `load-${runId}-${shard}-${userIndex}-${Date.now()}`);
  const auth = getAuth(app);
  const db = getFirestore(app);
  if (emulators) {
    connectAuthEmulator(auth, `http://${emulators.auth.host}:${emulators.auth.port}`, {
      disableWarnings: true,
    });
    connectFirestoreEmulator(db, emulators.firestore.host, emulators.firestore.port);
  }

  const client = {
    app,
    auth,
    db,
    profile,
    stopped: false,
    unsubs: [],
    timers: [],
    orderIds: [],
    orderStatuses: new Map(),
    seenMarkers: new Set(),
  };

  let started = performance.now();
  await signInWithEmailAndPassword(auth, profile.email, password);
  metrics.timing('auth', performance.now() - started);
  metrics.increment('authSuccess');

  started = performance.now();
  const profileSnapshot = await getDoc(doc(db, 'users', profile.uid));
  if (!profileSnapshot.exists()) throw new Error(`Profile ${profile.uid} does not exist.`);
  metrics.timing('profileRead', performance.now() - started);
  metrics.increment('profileDocsDelivered', 1);

  started = performance.now();
  const usersSnapshot = await getDocs(collection(db, 'users'));
  metrics.timing('userDirectoryRead', performance.now() - started);
  metrics.increment('userDirectoryDocsDelivered', usersSnapshot.size);

  const workOrdersQuery = profile.role === 'technician'
    ? query(
      collection(db, 'work_orders'),
      where('assignedTechnicianIds', 'array-contains', profile.uid),
      where('isOpen', '==', true),
      orderBy('createdAt', 'desc'),
    )
    : profile.role === 'admin'
      ? query(
        collection(db, 'work_orders'),
        where('createdAt', '>=', new Date(Date.now() - 45 * 24 * 60 * 60 * 1000)),
        orderBy('createdAt', 'desc'),
      )
    : query(
      collection(db, 'work_orders'),
      where('isOpen', '==', true),
      orderBy('createdAt', 'desc'),
    );
  started = performance.now();
  const mainInitial = deferred();
  const mainUnsub = onSnapshot(
    workOrdersQuery,
    { includeMetadataChanges: false },
    (snapshot) => {
      recordSnapshotDelivery('workOrders', snapshot, false);
      if (!mainInitial.settled) {
        for (const document of snapshot.docs) {
          const data = document.data();
          if (isVisibleTo(profile, data)) {
            client.orderIds.push(document.id);
            client.orderStatuses.set(document.id, data.status || 'Dispatched');
          }
        }
        mainInitial.resolve(snapshot.size);
      } else {
        recordPropagation(snapshot, client);
        for (const change of snapshot.docChanges()) {
          if (change.type !== 'removed') {
            client.orderStatuses.set(change.doc.id, change.doc.data().status || 'Dispatched');
          }
        }
      }
    },
    (error) => {
      metrics.error('work_orders_listener', error, userIndex);
      mainInitial.reject(error);
    },
  );
  client.unsubs.push(mainUnsub);
  await mainInitial.promise;
  metrics.timing('initialDashboard', performance.now() - started);

  for (const orderId of client.orderIds.slice(0, chatListeners)) {
    attachUnreadListener(client, orderId, userIndex);
  }
  client.unsubs.push(onSnapshot(
    query(
      collection(db, 'users', profile.uid, 'chat_unread'),
      where('count', '>', 0),
    ),
    (snapshot) => {
      metrics.increment('unreadTotalSnapshots');
      metrics.increment('unreadTotalDocsDelivered', snapshot.docChanges().length);
    },
    (error) => metrics.error('unread_total_listener', error, userIndex),
  ));

  scheduleRecurring(client, workflowWritesPerUserMinute, () => performWorkflowWrite(client));
  scheduleRecurring(client, chatWritesPerUserMinute, () => performChatWrite(client));
  return client;
}

function recordSnapshotDelivery(prefix, snapshot, includeMetadataChanges) {
  const changes = snapshot.docChanges({ includeMetadataChanges });
  const initial = changes.length === snapshot.size;
  const delivered = initial ? snapshot.size : changes.length;
  metrics.increment(`${prefix}Snapshots`);
  metrics.increment(`${prefix}DocsDelivered`, delivered);
}

function recordPropagation(snapshot, client) {
  for (const change of snapshot.docChanges()) {
    const marker = change.doc.data().loadTestMarker;
    if (!marker?.id || !Number.isFinite(marker.sentAtMs) || client.seenMarkers.has(marker.id)) continue;
    client.seenMarkers.add(marker.id);
    metrics.timing('realtimePropagation', Date.now() - marker.sentAtMs);
    metrics.increment('markersObserved');
  }
}

function attachUnreadListener(client, orderId, userIndex) {
  client.unsubs.push(onSnapshot(
    doc(client.db, 'users', client.profile.uid, 'chat_unread', orderId),
    (snapshot) => {
      metrics.increment('unreadJobSnapshots');
      if (snapshot.exists()) metrics.increment('unreadJobDocsDelivered');
    },
    (error) => metrics.error('unread_job_listener', error, userIndex),
  ));
}

function scheduleRecurring(client, ratePerMinute, operation) {
  if (ratePerMinute <= 0) return;
  const averageInterval = 60_000 / ratePerMinute;
  const run = async () => {
    if (client.stopped) return;
    try {
      await operation();
    } catch (error) {
      metrics.error('scheduled_operation', error, client.profile.index);
    }
    if (!client.stopped) {
      const jitter = 0.5 + Math.random();
      const timer = setTimeout(run, averageInterval * jitter);
      client.timers.push(timer);
    }
  };
  const timer = setTimeout(run, Math.random() * averageInterval);
  client.timers.push(timer);
}

async function performWorkflowWrite(client) {
  const orderId = randomItem(client.orderIds);
  if (!orderId) return;
  const current = client.orderStatuses.get(orderId) || 'Dispatched';
  const status = nextStatus(client.profile.role, current);
  const sentAtMs = Date.now();
  const markerId = `${runId}-${shard}-${client.profile.index}-${sentAtMs}-${Math.random()}`;
  const started = performance.now();
  await updateDoc(doc(client.db, 'work_orders', orderId), {
    status,
    updatedAt: serverTimestamp(),
    loadTestMarker: { id: markerId, sentAtMs, writer: client.profile.uid },
    history: arrayUnion({
      action: `load test ${status.toLowerCase()}`,
      userId: client.profile.uid,
      atMs: sentAtMs,
    }),
  });
  metrics.timing('workflowWrite', performance.now() - started);
  metrics.increment('workflowWrites');
}

async function performChatWrite(client) {
  const orderId = randomItem(client.orderIds);
  if (!orderId) return;
  const message = `Load test message from ${client.profile.uid} at ${new Date().toISOString()}`;
  const messages = collection(client.db, 'work_orders', orderId, 'messages');
  const started = performance.now();
  await addDoc(messages, {
    workOrderId: orderId,
    senderId: client.profile.uid,
    senderName: client.profile.name,
    senderRole: client.profile.role,
    message,
    createdAt: serverTimestamp(),
    loadTestRunId: runId,
  });
  await updateDoc(doc(client.db, 'work_orders', orderId), {
    lastMessage: message,
    lastMessageAt: serverTimestamp(),
    lastMessageBy: client.profile.name,
    updatedAt: serverTimestamp(),
  });
  metrics.timing('chatWrite', performance.now() - started);
  metrics.increment('chatWrites');
}

async function stopClient(client) {
  client.stopped = true;
  for (const timer of client.timers) clearTimeout(timer);
  for (const unsubscribe of client.unsubs) unsubscribe();
  await signOut(client.auth).catch(() => undefined);
  await deleteApp(client.app);
}

function isVisibleTo(profile, order) {
  if (profile.role === 'admin') return true;
  if (profile.role === 'supervisor') {
    return order.status !== 'Approved' && (!order.supervisor || order.supervisor === profile.uid);
  }
  const assigned = [order.assignedTo, ...(Array.isArray(order.assignedTechnicians) ? order.assignedTechnicians : [])];
  return assigned.includes(profile.uid) && ['Dispatched', 'On Site', 'Submitted', 'Approved'].includes(order.status);
}

function nextStatus(role, current) {
  if (role === 'admin') return current === 'Approved' ? 'Submitted' : 'Approved';
  if (role === 'supervisor') return current === 'Dispatched' ? 'Assigned to Supervisor' : 'Dispatched';
  return current === 'On Site' ? 'Submitted' : 'On Site';
}

function randomItem(items) {
  return items.length === 0 ? null : items[Math.floor(Math.random() * items.length)];
}

function deferred() {
  let resolvePromise;
  let rejectPromise;
  const value = {
    settled: false,
    promise: new Promise((resolve, reject) => {
      resolvePromise = resolve;
      rejectPromise = reject;
    }),
    resolve(result) {
      if (value.settled) return;
      value.settled = true;
      resolvePromise(result);
    },
    reject(error) {
      if (value.settled) return;
      value.settled = true;
      rejectPromise(error);
    },
  };
  return value;
}
