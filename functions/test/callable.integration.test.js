const { after, before, beforeEach, describe, it } = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const projectId = 'demo-venue-booking-tests';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
process.env.FIRESTORE_EMULATOR_HOST ||= firestoreHost;
process.env.FIREBASE_AUTH_EMULATOR_HOST ||= authHost;
const functionsHost = '127.0.0.1:5001';
const app = initializeApp({ projectId }, 'venue-callable-integration');
const db = getFirestore(app);
let directorToken;
let castToken;
let directorUid;
let castUid;
let emulatorsAvailable = false;

function requireEmulatorConnection(hostPort, label) {
  const separator = hostPort.lastIndexOf(':');
  const host = hostPort.slice(0, separator);
  const port = Number(hostPort.slice(separator + 1));
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error(`${label} emulator did not accept a connection at ${hostPort} within 3 seconds.`));
    }, 3000);
    socket.once('connect', () => {
      clearTimeout(timer);
      socket.destroy();
      resolve();
    });
    socket.once('error', (error) => {
      clearTimeout(timer);
      reject(new Error(`${label} emulator connection failed at ${hostPort}: ${error.code ?? error.message}`));
    });
  });
}

function booking({ id, venue = 'Main Stage', start = Date.UTC(2026, 10, 5, 10), end } = {}) {
  return {
    id,
    productionId: 'prod-integration',
    title: `Booking ${id}`,
    venue,
    venueId: venue,
    venueName: venue,
    startTimeMillis: start,
    endTimeMillis: end ?? start + 60 * 60 * 1000,
    status: 'Scheduled',
  };
}

async function signup(email) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-api-key`,
    {
      method: 'POST',
      signal: AbortSignal.timeout(5000),
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: 'test-password-123', returnSecureToken: true }),
    },
  );
  const body = await response.json();
  assert.ok(response.ok, `Auth Emulator sign-up failed: ${JSON.stringify(body)}`);
  return body;
}

async function invoke(data, token = directorToken) {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/us-central1/saveVenueBooking`,
    {
      method: 'POST',
      signal: AbortSignal.timeout(10000),
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  return { httpStatus: response.status, body: await response.json() };
}

async function invokeVenue(data, token = directorToken) {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/us-central1/manageVenue`,
    {
      method: 'POST',
      signal: AbortSignal.timeout(10000),
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ data }),
    },
  );
  return { httpStatus: response.status, body: await response.json() };
}

function expectCallableError(result, statuses) {
  const status = result.body?.error?.status;
  assert.ok(statuses.includes(status), `Expected ${statuses.join('/')} but received ${JSON.stringify(result)}`);
  return result.body.error;
}

async function clearData() {
  for (const collection of ['auditions', 'rehearsals', 'venue_booking_locks', 'venues']) {
    const snapshot = await db.collection(collection).get();
    if (!snapshot.empty) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
  await db.collection('productions').doc('prod-integration').set({ title: 'Integration Show' });
  await db.collection('venues').doc('venue-main-id').set({ name: 'Main Stage', capacity: 100 });
}

async function cleanupFixtures() {
  for (const collection of ['auditions', 'rehearsals', 'venue_booking_locks', 'productions', 'venues']) {
    const snapshot = await db.collection(collection).get();
    if (snapshot.empty) continue;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

before(async () => {
  await requireEmulatorConnection(firestoreHost, 'Firestore');
  await requireEmulatorConnection(authHost, 'Auth');
  await requireEmulatorConnection(functionsHost, 'Functions');
  emulatorsAvailable = true;
  const director = await signup(`director-${Date.now()}@example.test`);
  directorUid = director.localId;
  directorToken = director.idToken;
  const castMember = await signup(`cast-${Date.now()}@example.test`);
  castUid = castMember.localId;
  castToken = castMember.idToken;
  await db.collection('users').doc(directorUid).set({ role: 'Director' });
  await db.collection('users').doc(castUid).set({ role: 'Cast Member' });
});
beforeEach(clearData);
after(async () => {
  if (!emulatorsAvailable) {
    await deleteApp(app);
    return;
  }
  const authEndpoint = `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:delete?key=emulator-api-key`;
  const cleanups = [];
  if (directorUid) {
    cleanups.push(db.collection('users').doc(directorUid).delete());
    if (directorToken) cleanups.push(fetch(authEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: directorToken }),
      signal: AbortSignal.timeout(5000),
    }).then(async (response) => {
      assert.ok(response.ok, `Auth Emulator cleanup failed: ${await response.text()}`);
    }));
  }
  if (castUid) {
    cleanups.push(db.collection('users').doc(castUid).delete());
    if (castToken) cleanups.push(fetch(authEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: castToken }),
      signal: AbortSignal.timeout(5000),
    }).then(async (response) => {
      assert.ok(response.ok, `Auth Emulator cleanup failed: ${await response.text()}`);
    }));
  }
  cleanups.push(cleanupFixtures());
  try {
    const results = await Promise.allSettled(cleanups);
    const failures = results.filter((result) => result.status === 'rejected');
    if (failures.length > 0) {
      throw new AggregateError(
        failures.map((result) => result.reason),
        'Callable integration emulator cleanup failed.',
      );
    }
  } finally {
    await deleteApp(app);
  }
});

describe('saveVenueBooking callable HTTP integration (Auth + Functions + Firestore Emulators)', () => {
  it('rejects missing authentication and authenticated non-Directors', async () => {
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'unauth' }) }, null), ['UNAUTHENTICATED']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'cast' }) }, castToken), ['PERMISSION_DENIED']);
    expectCallableError(await invokeVenue({ action: 'delete', venue: { id: 'venue-main-id' } }, null), ['UNAUTHENTICATED']);
    expectCallableError(await invokeVenue({ action: 'delete', venue: { id: 'venue-main-id' } }, castToken), ['PERMISSION_DENIED']);
  });

  it('creates, renames, and tombstones an unused venue through the authorized callable', async () => {
    const created = await invokeVenue({
      action: 'create',
      venue: { id: 'venue-created', name: 'Black Box', address: 'Level 2', capacity: 80 },
    });
    assert.equal(created.body.result.id, 'venue-created');
    assert.equal((await db.collection('venues').doc('venue-created').get()).get('name'), 'Black Box');

    const renamed = await invokeVenue({
      action: 'update',
      venue: { id: 'venue-created', name: 'Studio Black', address: 'Level 2', capacity: 80 },
    });
    assert.equal(renamed.body.result.id, 'venue-created');
    assert.deepEqual((await db.collection('venues').doc('venue-created').get()).get('aliases'), ['Black Box']);

    const deleted = await invokeVenue({ action: 'delete', venue: { id: 'venue-created' } });
    assert.equal(deleted.body.result.deleted, true);
    assert.equal((await db.collection('venues').doc('venue-created').get()).get('deleted'), true);

    const duplicate = await invokeVenue({
      action: 'create', venue: { id: 'venue-reuse-name', name: 'Black Box', capacity: 40 },
    });
    assert.equal(duplicate.body.error.details.reason, 'venue-alias-ambiguous');
  });

  it('creates, updates, cancels, and deletes an audition for a Director', async () => {
    const input = booking({ id: 'aud-http' });
    const created = await invoke({ eventType: 'audition', action: 'create', booking: input });
    assert.equal(created.body.result.id, 'aud-http');
    assert.equal((await db.collection('auditions').doc('aud-http').get()).get('status'), 'Scheduled');

    const updated = await invoke({
      eventType: 'audition', action: 'update',
      booking: { ...input, title: 'Updated', startTimeMillis: input.startTimeMillis + 3_600_000, endTimeMillis: input.endTimeMillis + 3_600_000 },
    });
    assert.equal(updated.body.result.id, 'aud-http');
    assert.equal((await db.collection('auditions').doc('aud-http').get()).get('title'), 'Updated');

    const cancelled = await invoke({ eventType: 'audition', action: 'cancel', id: 'aud-http', reason: 'Schedule changed' });
    assert.equal(cancelled.body.result.id, 'aud-http');
    assert.equal((await db.collection('auditions').doc('aud-http').get()).get('status'), 'Cancelled');

    const deleted = await invoke({ eventType: 'audition', action: 'delete', id: 'aud-http' });
    assert.equal(deleted.body.result.id, 'aud-http');
    assert.equal((await db.collection('auditions').doc('aud-http').get()).exists, false);
  });

  it('creates, updates, and deletes a rehearsal through the callable', async () => {
    const input = {
      ...booking({ id: 'reh-http' }),
      venueId: 'venue-main-id',
      venueName: 'Main Stage',
      venue: 'Main Stage',
    };
    const created = await invoke({ eventType: 'rehearsal', action: 'create', booking: input });
    assert.equal(created.body.result.id, 'reh-http');
    assert.equal((await db.collection('rehearsals').doc('reh-http').get()).get('venueId'), 'venue-main-id');

    const updated = await invoke({
      eventType: 'rehearsal', action: 'update',
      booking: { ...input, title: 'Updated rehearsal', startTimeMillis: input.startTimeMillis + 3_600_000, endTimeMillis: input.endTimeMillis + 3_600_000 },
    });
    assert.equal(updated.body.result.id, 'reh-http');
    assert.equal((await db.collection('rehearsals').doc('reh-http').get()).get('title'), 'Updated rehearsal');

    const deleted = await invoke({ eventType: 'rehearsal', action: 'delete', id: 'reh-http' });
    assert.equal(deleted.body.result.id, 'reh-http');
    assert.equal((await db.collection('rehearsals').doc('reh-http').get()).exists, false);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'cancel', id: 'reh-http' }), ['INVALID_ARGUMENT']);
  });

  it('rejects invalid actions, IDs, times, empty venues, and missing productions', async () => {
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'update', booking: { ...booking({ id: '' }) } }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'bogus', booking: booking({ id: 'bad-action' }) }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'bad-id/segment' }) }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'bad-range', start: 20, end: 10 }) }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'zero-range', start: 20, end: 20 }) }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: { ...booking({ id: 'bad-date' }), startTimeMillis: 'tomorrow' } }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: { ...booking({ id: 'wrong-venue-type' }), venueId: 42 } }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'cancel', id: 'not-supported' }), ['INVALID_ARGUMENT']);
    const invalidVenue = { ...booking({ id: 'invalid-venue-ref' }), venueId: 'missing-venue-id', venueName: 'Studio A', venue: 'Studio A' };
    const invalidVenueResponse = await invoke({ eventType: 'rehearsal', action: 'create', booking: invalidVenue });
    expectCallableError(invalidVenueResponse, ['INVALID_ARGUMENT']);
    assert.equal(invalidVenueResponse.body.error.details.reason, 'invalid-venue-reference');
    expectCallableError(await invoke({ eventType: 'audition', action: 'create', booking: { ...booking({ id: 'empty-venue' }), venue: '  ' } }), ['INVALID_ARGUMENT']);
    expectCallableError(await invoke({ eventType: 'rehearsal', action: 'create', booking: { ...booking({ id: 'missing-prod' }), productionId: 'not-found' } }), ['FAILED_PRECONDITION']);
  });

  it('resolves a venue document ID and its name as the same venue', async () => {
    await invoke({
      eventType: 'rehearsal', action: 'create',
      booking: { ...booking({ id: 'reh-alias' }), venueId: 'venue-main-id', venueName: 'Main Stage', venue: 'Main Stage' },
    });
    const response = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'aud-alias', venue: 'main stage', start: Date.UTC(2026, 10, 5, 10, 30) }),
    });
    assert.equal(response.body.error.details.reason, 'venue-conflict');
  });

  it('persists stable venue IDs on new auditions and rehearsals', async () => {
    const rehearsal = await invoke({
      eventType: 'rehearsal', action: 'create',
      booking: { ...booking({ id: 'stable-rehearsal' }), venueId: 'venue-main-id', venueName: 'Main Stage', venue: 'Main Stage' },
    });
    const audition = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'stable-audition', venue: 'Main Stage', start: Date.UTC(2026, 10, 6, 10) }),
    });
    assert.equal(rehearsal.body.result.id, 'stable-rehearsal');
    assert.equal(audition.body.result.id, 'stable-audition');
    assert.equal((await db.collection('rehearsals').doc('stable-rehearsal').get()).get('venueId'), 'venue-main-id');
    assert.equal((await db.collection('auditions').doc('stable-audition').get()).get('venueId'), 'venue-main-id');
  });

  it('keeps legacy old-name bookings locked to the venue after rename', async () => {
    await db.collection('auditions').doc('legacy-old-name').set({
      title: 'Legacy audition', productionId: 'prod-integration', venue: 'Main Stage',
      status: 'Scheduled', startTime: new Date(Date.UTC(2026, 10, 5, 10)),
      endTime: new Date(Date.UTC(2026, 10, 5, 11)),
    });
    const rename = await invokeVenue({
      action: 'update', venue: { id: 'venue-main-id', name: 'Grand Stage', capacity: 100 },
    });
    assert.equal(rename.body.result.id, 'venue-main-id');
    const conflict = await invoke({
      eventType: 'rehearsal', action: 'create',
      booking: { ...booking({ id: 'renamed-conflict', venue: 'Grand Stage', start: Date.UTC(2026, 10, 5, 10, 30) }), venueId: 'venue-main-id', venueName: 'Grand Stage' },
    });
    assert.equal(conflict.body.error?.details?.reason, 'venue-conflict', JSON.stringify(conflict.body));
    const normalized = await db.collection('venues').doc('venue-main-id').get();
    assert.deepEqual(normalized.get('aliases'), ['Main Stage']);
  });

  it('preserves aliases through multiple sequential renames', async () => {
    const start = Date.UTC(2026, 10, 5, 10);
    await db.collection('auditions').doc('legacy-before-sequential-renames').set({
      title: 'Legacy audition', productionId: 'prod-integration', venue: 'Main Stage',
      status: 'Scheduled', startTime: new Date(start), endTime: new Date(start + 60 * 60 * 1000),
    });
    await invokeVenue({ action: 'update', venue: { id: 'venue-main-id', name: 'Grand Stage', capacity: 100 } });
    await invokeVenue({ action: 'update', venue: { id: 'venue-main-id', name: 'Black Box', capacity: 100 } });
    const conflict = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'multiple-rename-conflict', venue: 'main stage', start: start + 30 * 60 * 1000 }),
    });
    assert.equal(conflict.body.error?.details?.reason, 'venue-conflict', JSON.stringify(conflict.body));
    assert.deepEqual((await db.collection('venues').doc('venue-main-id').get()).get('aliases'), ['Main Stage', 'Grand Stage']);
  });

  it('fails closed for duplicate or ambiguous aliases', async () => {
    await db.collection('venues').doc('venue-second-id').set({ name: 'Studio B', aliases: ['Main Stage'], capacity: 20 });
    const ambiguous = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'ambiguous-alias', venue: 'Main Stage' }),
    });
    assert.equal(ambiguous.body.error.details.reason, 'venue-alias-ambiguous');
    const rename = await invokeVenue({ action: 'update', venue: { id: 'venue-main-id', name: 'Studio B', capacity: 100 } });
    assert.equal(rename.body.error.details.reason, 'venue-alias-ambiguous');
  });

  it('blocks deleting venues with active bookings and tombstones unused venues', async () => {
    const now = Date.now();
    await invoke({
      eventType: 'rehearsal', action: 'create',
      booking: {
        ...booking({ id: 'delete-active', start: now - 30 * 60 * 1000, end: now + 30 * 60 * 1000 }),
        venueId: 'venue-main-id', venueName: 'Main Stage',
      },
    });
    const blocked = await invokeVenue({ action: 'delete', venue: { id: 'venue-main-id' } });
    assert.equal(blocked.body.error.details.reason, 'venue-in-use');
    await db.collection('rehearsals').doc('delete-active').delete();
    await invoke({
      eventType: 'audition', action: 'create',
      booking: {
        ...booking({ id: 'delete-future', eventType: 'audition', start: now + 24 * 60 * 60 * 1000, end: now + 25 * 60 * 60 * 1000 }),
        venueId: 'venue-main-id',
      },
    });
    const futureBlocked = await invokeVenue({ action: 'delete', venue: { id: 'venue-main-id' } });
    assert.equal(futureBlocked.body.error.details.reason, 'venue-in-use');
    await db.collection('auditions').doc('delete-future').delete();
    await db.collection('auditions').doc('delete-past').set({
      title: 'Past audition', productionId: 'prod-integration', venue: 'Main Stage', venueId: 'venue-main-id',
      status: 'Scheduled', startTime: new Date(now - 2 * 60 * 60 * 1000), endTime: new Date(now - 60 * 60 * 1000),
    });
    const deleted = await invokeVenue({ action: 'delete', venue: { id: 'venue-main-id' } });
    assert.equal(deleted.body.result.deleted, true);
    assert.equal((await db.collection('venues').doc('venue-main-id').get()).get('deleted'), true);
    assert.equal((await db.collection('auditions').doc('delete-past').get()).exists, true);
    const afterDelete = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'deleted-venue-booking', venue: 'Main Stage' }),
    });
    assert.equal(afterDelete.body.error.details.reason, 'venue-deleted');
  });

  it('serializes concurrent rename and booking through shared venue locks', async () => {
    const [bookingResult, renameResult] = await Promise.all([
      invoke({
        eventType: 'rehearsal', action: 'create',
        // Clients have the stable venue ID from the directory even if a rename
        // races their request; the existing display name remains a valid alias.
        booking: { ...booking({ id: 'concurrent-rename-booking', venue: 'Main Stage' }), venueId: 'venue-main-id', venueName: 'Main Stage' },
      }),
      invokeVenue({ action: 'update', venue: { id: 'venue-main-id', name: 'Grand Stage', capacity: 100 } }),
    ]);
    assert.equal(bookingResult.body.error, undefined, JSON.stringify(bookingResult.body));
    assert.equal(renameResult.body.error, undefined, JSON.stringify(renameResult.body));
    const laterConflict = await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'after-concurrent-rename', venue: 'Main Stage', start: Date.UTC(2026, 10, 5, 10, 30) }),
    });
    if (bookingResult.body.result && renameResult.body.result) {
      assert.equal(laterConflict.body.error.details.reason, 'venue-conflict');
      assert.equal((await db.collection('rehearsals').doc('concurrent-rename-booking').get()).get('venueId'), 'venue-main-id');
    }
  });

  it('does not merge a concurrent new-name booking with an old-name booking on rename', async () => {
    const start = Date.UTC(2026, 10, 5, 10);
    await db.collection('auditions').doc('before-rename').set({
      title: 'Before rename', productionId: 'prod-integration', venue: 'Main Stage',
      status: 'Scheduled', startTime: new Date(start), endTime: new Date(start + 60 * 60 * 1000),
    });
    const [newNameBooking, rename] = await Promise.all([
      invoke({
        eventType: 'rehearsal', action: 'create',
        booking: {
          ...booking({ id: 'during-rename', venue: 'Grand Stage', start: start + 15 * 60 * 1000 }),
          venueId: 'Grand Stage', venueName: 'Grand Stage',
        },
      }),
      invokeVenue({ action: 'update', venue: { id: 'venue-main-id', name: 'Grand Stage', capacity: 100 } }),
    ]);
    const succeeded = [newNameBooking, rename].filter((result) => result.body.result).length;
    assert.equal(succeeded, 1, JSON.stringify({ newNameBooking, rename }));
    assert.ok(newNameBooking.body.result || ['FAILED_PRECONDITION', 'INVALID_ARGUMENT'].includes(newNameBooking.body.error?.status));
    assert.ok(rename.body.result || ['FAILED_PRECONDITION', 'ALREADY_EXISTS'].includes(rename.body.error?.status));
  });

  it('rejects an update into another booking and leaves the rehearsal unchanged', async () => {
    const rehearsal = {
      ...booking({ id: 'reh-update-conflict' }),
      venueId: 'venue-main-id', venueName: 'Main Stage', venue: 'Main Stage',
    };
    await invoke({ eventType: 'rehearsal', action: 'create', booking: rehearsal });
    await invoke({
      eventType: 'audition', action: 'create',
      booking: booking({ id: 'aud-update-conflict', venue: 'Studio A' }),
    });
    const response = await invoke({
      eventType: 'rehearsal', action: 'update',
      booking: { ...rehearsal, venueId: 'Studio A', venueName: 'Studio A', venue: 'Studio A' },
    });
    assert.equal(response.body.error.details.reason, 'venue-conflict');
    const unchanged = await db.collection('rehearsals').doc('reh-update-conflict').get();
    assert.equal(unchanged.get('venueId'), 'venue-main-id');
  });

  it('does not let concurrent conflicting callable requests both succeed', async () => {
    const [one, two] = await Promise.all([
      invoke({ eventType: 'rehearsal', action: 'create', booking: booking({ id: 'concurrent-r' }) }),
      invoke({ eventType: 'audition', action: 'create', booking: booking({ id: 'concurrent-a' }) }),
    ]);
    assert.equal([one, two].filter((result) => result.body.result).length, 1);
    assert.equal([one, two].filter((result) => result.body.error).length, 1);
  });
});
