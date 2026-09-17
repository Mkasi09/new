import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

import {
  assertSafeProject,
  chunks,
  integerArg,
  parseArgs,
  projectId,
  stringArg,
  testUser,
} from './config.mjs';

const args = parseArgs();
const users = integerArg(args, 'users', 500, { min: 1, max: 5000 });
const runId = stringArg(args, 'runId', process.env.LOAD_TEST_RUN_ID || 'baseline-500');
const id = assertSafeProject(projectId());

if (!args.confirm) {
  throw new Error(
    `Cleanup requires --confirm. It will remove load-test users and work orders for run ${runId} from ${id}.`,
  );
}

const adminOptions = process.env.USE_FIREBASE_EMULATORS === 'true'
  ? { projectId: id }
  : { credential: applicationDefault(), projectId: id };
const app = getApps()[0] || initializeApp(adminOptions);
const auth = getAuth(app);
const db = getFirestore(app);

let deletedOrders = 0;
while (true) {
  const snapshot = await db.collection('work_orders')
    .where('loadTestRunId', '==', runId)
    .limit(100)
    .get();
  if (snapshot.empty) break;
  await Promise.all(snapshot.docs.map((document) => db.recursiveDelete(document.ref)));
  deletedOrders += snapshot.size;
  console.log(`Deleted ${deletedOrders} work orders...`);
}

const userIds = Array.from({ length: users }, (_, index) => testUser(index).uid);
for (const batch of chunks(userIds, 1000)) {
  await auth.deleteUsers(batch);
}
const writer = db.bulkWriter();
for (const uid of userIds) writer.delete(db.collection('users').doc(uid));
await writer.close();

console.log(JSON.stringify({ cleaned: true, projectId: id, runId, deletedOrders, deletedUsers: users }, null, 2));
