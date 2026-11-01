/*
 * Safe demo data for local Firebase emulators only.
 * This script intentionally refuses non-demo project IDs and non-loopback
 * emulator hosts. Bookings use the deployed-shape callable endpoint and
 * Firestore client REST writes carry emulator-issued user ID tokens/rules.
 */
const { initializeApp, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || process.env.GCLOUD_PROJECT_ID;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';

function assertLoopbackHost(host, label) {
  if (typeof host !== 'string' || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error(`${label} must point to a loopback emulator host; received ${host || '(unset)'}.`);
  }
}

if (typeof projectId !== 'string' || !projectId.startsWith('demo-')) {
  throw new Error('Refusing to seed: GCLOUD_PROJECT must use a demo-* project ID.');
}
assertLoopbackHost(firestoreHost, 'FIRESTORE_EMULATOR_HOST');
assertLoopbackHost(authHost, 'FIREBASE_AUTH_EMULATOR_HOST');
assertLoopbackHost(functionsHost, 'FUNCTIONS_EMULATOR_HOST');

const directorPassword = process.env.DEMO_DIRECTOR_PASSWORD;
const castPassword = process.env.DEMO_CAST_PASSWORD;
if (!directorPassword || !castPassword) {
  throw new Error('Set DEMO_DIRECTOR_PASSWORD and DEMO_CAST_PASSWORD for emulator accounts.');
}

if (getApps().length === 0) initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();
const apiKey = 'fake-api-key'; // Auth Emulator accepts this placeholder; it is not a credential.
const directorEmail = 'demo-director@example.invalid';
const castEmail = 'demo-cast@example.invalid';
const directorName = 'Demo Director';
const castName = 'Demo Cast Member';

async function ensureAuthUser(email, displayName, password) {
  try {
    return await auth.createUser({ email, displayName, password, emailVerified: true });
  } catch (error) {
    if (error.code !== 'auth/email-already-exists') throw error;
    return auth.getUserByEmail(email);
  }
}

async function signIn(email, password) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = await response.json();
  if (!response.ok) throw new Error(`Auth Emulator sign-in failed: ${JSON.stringify(body)}`);
  return body.idToken;
}

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(value).map(([key, child]) => [key, encodeValue(child)])),
      },
    };
  }
  throw new Error(`Unsupported Firestore seed value: ${typeof value}`);
}

function documentName(collection, id) {
  return `projects/${projectId}/databases/(default)/documents/${collection}/${id}`;
}

function firestoreUrl(collection, id) {
  return `http://${firestoreHost}/v1/${documentName(collection, id)}`;
}

async function getDocument(collection, id, token) {
  const response = await fetch(firestoreUrl(collection, id), {
    headers: { authorization: `Bearer ${token}` },
  });
  if (response.status === 404) return false;
  if (!response.ok) throw new Error(`Firestore read failed for ${collection}/${id}: ${await response.text()}`);
  return true;
}

async function createDocument(collection, id, fields, token, {
  readToken = token,
  checkExisting = true,
} = {}) {
  if (checkExisting && await getDocument(collection, id, readToken)) {
    console.log(`Preserved existing ${collection}/${id}`);
    return false;
  }
  const response = await fetch(
    `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        writes: [{
          update: {
            name: documentName(collection, id),
            fields: Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, encodeValue(value)])),
          },
          currentDocument: { exists: false },
        }],
      }),
    },
  );
  if (!response.ok) {
    const error = await response.text();
    if (/already exists|ALREADY_EXISTS/i.test(error)) {
      console.log(`Preserved existing ${collection}/${id}`);
      return false;
    }
    throw new Error(`Firestore create failed for ${collection}/${id}: ${error}`);
  }
  console.log(`Created ${collection}/${id}`);
  return true;
}

async function callFunction(name, token, data) {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/us-central1/${name}`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ data }),
    },
  );
  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`${name} failed: ${JSON.stringify(body.error || body)}`);
  }
  return body.result;
}

async function ensureDirectorProfile(uid) {
  const ref = db.collection('users').doc(uid);
  const profile = await ref.get();
  if (profile.exists) {
    if (profile.get('role') !== 'Director') {
      throw new Error(`Existing emulator profile ${uid} is not a Director; refusing to change it.`);
    }
    return;
  }
  // Director profiles are provisioned administratively by the app's role model.
  // This Admin SDK write is safe only because the strict emulator guards above ran.
  await ref.create({ name: directorName, email: directorEmail, role: 'Director' });
}

async function createBookingIfMissing(collection, eventType, token, booking) {
  if (await getDocument(collection, booking.id, token)) {
    console.log(`Preserved existing ${collection}/${booking.id}`);
    return;
  }
  await callFunction('saveVenueBooking', token, { eventType, action: 'create', booking });
  console.log(`Created ${collection}/${booking.id} through saveVenueBooking`);
}

async function main() {
  const director = await ensureAuthUser(directorEmail, directorName, directorPassword);
  const castMember = await ensureAuthUser(castEmail, castName, castPassword);
  await ensureDirectorProfile(director.uid);
  const directorToken = await signIn(directorEmail, directorPassword);
  const castToken = await signIn(castEmail, castPassword);

  await createDocument('users', castMember.uid, {
    name: castName, email: castEmail, role: 'Cast Member',
  }, castToken);
  await createDocument('cast_members', castMember.uid, {
    uid: castMember.uid, name: castName, email: castEmail,
  }, castToken);

  const productionId = 'demo-hamlet-production';
  await createDocument('productions', productionId, {
    title: '[DEMO] Hamlet',
    description: 'Local emulator demonstration production.',
    status: 'In Rehearsal',
    director: directorName,
    startDate: null,
    endDate: null,
  }, directorToken);

  const venueId = 'demo-main-stage';
  if (!(await getDocument('venues', venueId, directorToken))) {
    await callFunction('manageVenue', directorToken, {
      action: 'create',
      venue: {
        id: venueId,
        name: '[DEMO] Main Stage',
        address: 'Emulator only',
        capacity: 120,
        description: 'Local emulator demonstration venue.',
        facilities: ['Lighting', 'Sound'],
      },
    });
    console.log(`Created venues/${venueId} through manageVenue`);
  } else {
    console.log(`Preserved existing venues/${venueId}`);
  }

  const assignmentId = 'demo-hamlet-lead-assignment';
  await createDocument('cast_assignments', assignmentId, {
    productionId,
    userId: castMember.uid,
    characterRole: 'Hamlet',
    actorName: castName,
    actorEmail: castEmail,
    status: 'Confirmed',
    notes: '[DEMO] Emulator seed assignment.',
    assignedBy: director.uid,
  }, directorToken);
  await createDocument('notifications', 'demo-role-assignment-notification', {
    recipientUid: castMember.uid,
    title: 'New role assignment: Hamlet',
    message: 'You have been assigned the demo role Hamlet.',
    type: 'role_assignment',
    relatedId: assignmentId,
    read: false,
  }, directorToken, { checkExisting: false });

  const start = new Date();
  start.setUTCDate(start.getUTCDate() + 30);
  start.setUTCHours(10, 0, 0, 0);
  const startMillis = start.getTime();
  await createBookingIfMissing('auditions', 'audition', directorToken, {
    id: 'demo-hamlet-audition',
    productionId,
    title: '[DEMO] Hamlet callbacks',
    venue: '[DEMO] Main Stage',
    venueId,
    startTimeMillis: startMillis,
    endTimeMillis: startMillis + 60 * 60 * 1000,
    status: 'Scheduled',
    description: 'Local emulator demonstration audition.',
    requirements: 'Demo only',
  });
  await createBookingIfMissing('rehearsals', 'rehearsal', directorToken, {
    id: 'demo-hamlet-rehearsal',
    productionId,
    title: '[DEMO] Hamlet table read',
    venueId,
    venueName: '[DEMO] Main Stage',
    venue: '[DEMO] Main Stage',
    startTimeMillis: startMillis + 2 * 60 * 60 * 1000,
    endTimeMillis: startMillis + 4 * 60 * 60 * 1000,
    notes: 'Local emulator demonstration rehearsal.',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
