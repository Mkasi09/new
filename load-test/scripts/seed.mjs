import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

import {
  assertSafeProject,
  integerArg,
  parseArgs,
  projectId,
  stringArg,
  testPassword,
  testUser,
} from './config.mjs';

const args = parseArgs();
const users = integerArg(args, 'users', 500, { min: 25, max: 5000 });
const orders = integerArg(args, 'orders', 1000, { min: 1, max: 100000 });
const messagesPerOrder = integerArg(args, 'messagesPerOrder', 2, { min: 0, max: 100 });
const runId = stringArg(args, 'runId', process.env.LOAD_TEST_RUN_ID || 'baseline-500');
const id = assertSafeProject(projectId());
const password = testPassword();

if (args.dryRun) {
  console.log(JSON.stringify({ projectId: id, users, orders, messagesPerOrder, runId }, null, 2));
  process.exit(0);
}

const adminOptions = process.env.USE_FIREBASE_EMULATORS === 'true'
  ? { projectId: id }
  : { credential: applicationDefault(), projectId: id };
const app = getApps()[0] || initializeApp(adminOptions);
const auth = getAuth(app);
const db = getFirestore(app);
const profiles = Array.from({ length: users }, (_, index) => testUser(index));

console.log(`Seeding ${users} users into ${id}...`);
await runPool(profiles, 10, async (profile) => {
  try {
    await auth.createUser({
      uid: profile.uid,
      email: profile.email,
      password,
      displayName: profile.name,
      emailVerified: true,
    });
  } catch (error) {
    if (error?.code !== 'auth/uid-already-exists' && error?.code !== 'auth/email-already-exists') {
      throw error;
    }
    await auth.updateUser(profile.uid, {
      email: profile.email,
      password,
      displayName: profile.name,
      emailVerified: true,
      disabled: false,
    });
  }
  await auth.setCustomUserClaims(profile.uid, { role: profile.role, loadTest: true });
});

let writer = db.bulkWriter();
for (const profile of profiles) {
  writer.set(db.collection('users').doc(profile.uid), {
    name: profile.name,
    email: profile.email,
    role: profile.role,
    team: profile.team,
    mustChangePassword: false,
    loadTestRunId: runId,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}
await writer.close();

const admins = profiles.filter((profile) => profile.role === 'admin');
const supervisors = profiles.filter((profile) => profile.role === 'supervisor');
const technicians = profiles.filter((profile) => profile.role === 'technician');
const statuses = ['Assigned to Supervisor', 'Dispatched', 'On Site', 'Submitted', 'Approved'];
const now = Date.now();

console.log(`Seeding ${orders} work orders and ${orders * messagesPerOrder} messages...`);
writer = db.bulkWriter();
writer.onWriteError((error) => error.failedAttempts < 5);
for (let index = 0; index < orders; index += 1) {
  const suffix = String(index).padStart(7, '0');
  const orderId = `loadtest-order-${suffix}`;
  const supervisor = supervisors[index % supervisors.length];
  const technician = technicians[index % technicians.length];
  const admin = admins[index % admins.length];
  const status = statuses[index % statuses.length];
  const createdAt = Timestamp.fromMillis(now - (orders - index) * 60_000);
  const orderRef = db.collection('work_orders').doc(orderId);
  writer.set(orderRef, {
    site: `Load Test Site ${suffix}`,
    address: `${(index % 500) + 1} Test Avenue, Johannesburg`,
    scope: `Synthetic load-test work order ${suffix}`,
    sla: index % 10 === 0 ? 'Due in 4 hours' : 'Due in 24 hours',
    siteCode: `LT-${suffix}`,
    status,
    priority: index % 20 === 0 ? 'critical' : index % 3 === 0 ? 'low' : 'high',
    dueAt: Timestamp.fromMillis(now + ((index % 24) + 1) * 3_600_000),
    arrivalVerified: status === 'On Site' || status === 'Submitted' || status === 'Approved',
    evidenceUploaded: status === 'Submitted' || status === 'Approved',
    evidenceSlots: status === 'Submitted' || status === 'Approved' ? ['before', 'after'] : [],
    evidencePhotos: {},
    reviewed: status === 'Approved',
    supervisor: supervisor.uid,
    supervisorId: supervisor.uid,
    assignedTo: technician.uid,
    assignedTechnicians: [technician.uid],
    assignedTechnicianIds: [technician.uid],
    isOpen: status !== 'Approved',
    createdBy: admin.uid,
    chatMessageCount: messagesPerOrder,
    createdAt,
    updatedAt: createdAt,
    loadTestRunId: runId,
    history: [{ action: 'seeded for load test', userId: admin.uid, at: createdAt }],
  });

  for (let messageIndex = 0; messageIndex < messagesPerOrder; messageIndex += 1) {
    const sender = messageIndex % 2 === 0 ? technician : supervisor;
    const messageAt = Timestamp.fromMillis(createdAt.toMillis() + (messageIndex + 1) * 10_000);
    writer.set(orderRef.collection('messages').doc(`loadtest-message-${messageIndex}`), {
      workOrderId: orderId,
      senderId: sender.uid,
      senderName: sender.name,
      senderRole: sender.role,
      message: `Synthetic message ${messageIndex + 1} for ${orderId}`,
      createdAt: messageAt,
      loadTestRunId: runId,
    });
  }
}
await writer.close();

console.log(JSON.stringify({
  seeded: true,
  projectId: id,
  runId,
  users,
  roles: { admins: admins.length, supervisors: supervisors.length, technicians: technicians.length },
  orders,
  messages: orders * messagesPerOrder,
}, null, 2));

async function runPool(items, concurrency, operation) {
  let next = 0;
  const workers = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next];
      next += 1;
      await operation(item);
    }
  });
  await Promise.all(workers);
}
