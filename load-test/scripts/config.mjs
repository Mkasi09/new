import 'dotenv/config';

const FORBIDDEN_PROJECTS = new Set(['magzmotron-5ae93']);

export function parseArgs(argv = process.argv.slice(2)) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const equalsAt = token.indexOf('=');
    if (equalsAt >= 0) {
      result[toCamel(token.slice(2, equalsAt))] = token.slice(equalsAt + 1);
      continue;
    }
    const key = toCamel(token.slice(2));
    const next = argv[index + 1];
    if (next && !next.startsWith('--')) {
      result[key] = next;
      index += 1;
    } else {
      result[key] = true;
    }
  }
  return result;
}

export function integerArg(args, name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  const raw = args[name] ?? fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(`--${toKebab(name)} must be an integer between ${min} and ${max}.`);
  }
  return value;
}

export function numberArg(args, name, fallback, { min = 0, max = Number.MAX_VALUE } = {}) {
  const raw = args[name] ?? fallback;
  const value = Number(raw);
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new Error(`--${toKebab(name)} must be a number between ${min} and ${max}.`);
  }
  return value;
}

export function stringArg(args, name, fallback) {
  const value = String(args[name] ?? fallback ?? '').trim();
  if (!value) throw new Error(`--${toKebab(name)} is required.`);
  return value;
}

export function booleanArg(args, name, fallback = false) {
  const raw = args[name];
  if (raw === undefined) return fallback;
  if (raw === true || raw === 'true' || raw === '1') return true;
  if (raw === false || raw === 'false' || raw === '0') return false;
  throw new Error(`--${toKebab(name)} must be true or false.`);
}

export function projectId() {
  return String(process.env.FIREBASE_PROJECT_ID || '').trim();
}

export function assertSafeProject(id = projectId()) {
  if (!id) throw new Error('FIREBASE_PROJECT_ID is required. Copy .env.example to .env.');
  if (FORBIDDEN_PROJECTS.has(id)) {
    throw new Error(`Refusing to load-test production project ${id}. Use a dedicated staging project.`);
  }
  const emulator = process.env.USE_FIREBASE_EMULATORS === 'true' || id.startsWith('demo-');
  const looksNonProduction = /(test|staging|stage|load|demo|emulator)/i.test(id);
  const explicitlyAllowed = process.env.LOAD_TEST_ALLOW_PROJECT === id;
  if (!emulator && !looksNonProduction && !explicitlyAllowed) {
    throw new Error(
      `Project ${id} does not look like staging. Set LOAD_TEST_ALLOW_PROJECT=${id} to confirm it explicitly.`,
    );
  }
  return id;
}

export function clientConfig() {
  const id = assertSafeProject();
  const apiKey = requiredEnv('FIREBASE_API_KEY');
  return {
    apiKey,
    appId: requiredEnv('FIREBASE_APP_ID'),
    projectId: id,
    authDomain: process.env.FIREBASE_AUTH_DOMAIN || `${id}.firebaseapp.com`,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET || `${id}.firebasestorage.app`,
    messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID || undefined,
  };
}

export function testPassword() {
  const password = String(process.env.LOAD_TEST_PASSWORD || '').trim();
  if (password.length < 12) {
    throw new Error('LOAD_TEST_PASSWORD must contain at least 12 characters.');
  }
  return password;
}

export function testUser(index) {
  const suffix = String(index).padStart(6, '0');
  const percentile = index % 100;
  const role = percentile < 5 ? 'admin' : percentile < 20 ? 'supervisor' : 'technician';
  return {
    index,
    uid: `loadtest-${suffix}`,
    email: `loadtest+${suffix}@example.test`,
    name: `Load Test ${role[0].toUpperCase()}${role.slice(1)} ${suffix}`,
    role,
    team: role === 'admin' ? 'Operations' : `Field Team ${(index % 10) + 1}`,
  };
}

export function shardRange(totalUsers, shard, shards) {
  if (shard >= shards) throw new Error('--shard must be lower than --shards.');
  const start = Math.floor((totalUsers * shard) / shards);
  const end = Math.floor((totalUsers * (shard + 1)) / shards);
  return { start, end, count: end - start };
}

export function emulatorSettings() {
  if (process.env.USE_FIREBASE_EMULATORS !== 'true') return null;
  const auth = splitHost(process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099');
  const firestore = splitHost(process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080');
  return { auth, firestore };
}

export function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function chunks(items, size) {
  const output = [];
  for (let index = 0; index < items.length; index += size) {
    output.push(items.slice(index, index + size));
  }
  return output;
}

function requiredEnv(name) {
  const value = String(process.env[name] || '').trim();
  if (!value) throw new Error(`${name} is required. Copy .env.example to .env.`);
  return value;
}

function splitHost(value) {
  const normalized = value.replace(/^https?:\/\//, '');
  const [host, portText] = normalized.split(':');
  const port = Number(portText);
  if (!host || !Number.isInteger(port)) throw new Error(`Invalid emulator host: ${value}`);
  return { host, port };
}

function toCamel(value) {
  return value.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
}

function toKebab(value) {
  return value.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}
