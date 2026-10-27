const { after, before, beforeEach, describe, it } = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { transactBooking } = require('../booking_logic');

const projectId = 'demo-venue-booking-tests';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
process.env.FIRESTORE_EMULATOR_HOST ||= firestoreHost;
const app = initializeApp({ projectId }, 'venue-booking-tests');
const db = getFirestore(app);
let firestoreAvailable = false;

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

const start = Date.UTC(2026, 10, 5, 10, 0);
const booking = ({
  id,
  eventType = 'rehearsal',
  venue = 'Main Stage',
  startTimeMillis = start,
  endTimeMillis,
}) => ({
  id,
  productionId: 'prod-test',
  title: `${eventType} ${id}`,
  venue,
  venueId: venue,
  venueName: venue,
  startTimeMillis,
  endTimeMillis: endTimeMillis ?? startTimeMillis + 60 * 60 * 1000,
  creatorUid: 'director-test',
  status: 'Scheduled',
});

async function clearData() {
  for (const collection of ['auditions', 'rehearsals', 'venue_booking_locks', 'productions', 'venues']) {
    const snapshot = await db.collection(collection).get();
    if (!snapshot.empty) {
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
  await db.collection('productions').doc('prod-test').set({ title: 'Test show' });
}

async function cleanupTestData() {
  for (const collection of ['auditions', 'rehearsals', 'venue_booking_locks', 'productions', 'venues']) {
    const snapshot = await db.collection(collection).get();
    if (snapshot.empty) continue;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function create(type, input) {
  return transactBooking({ db, eventType: type, action: 'create', input, uid: 'director-test' });
}

before(async () => {
  await requireEmulatorConnection(firestoreHost, 'Firestore');
  firestoreAvailable = true;
});
beforeEach(clearData);
after(async () => {
  if (!firestoreAvailable) {
    await deleteApp(app);
    return;
  }
  try {
    await cleanupTestData();
  } finally {
    await deleteApp(app);
  }
});

describe('transactional venue bookings', () => {
  it('rejects overlapping bookings at the same venue across event types', async () => {
    await create('rehearsal', booking({ id: 'r1' }));
    await assert.rejects(
      create('audition', booking({ id: 'a1', eventType: 'audition', startTimeMillis: start + 30 * 60 * 1000 })),
      (error) => error.code === 'failed-precondition' && error.details.reason === 'venue-conflict',
    );
    assert.equal((await db.collection('auditions').get()).size, 0);
  });

  it('allows simultaneous bookings at different venues', async () => {
    await Promise.all([
      create('rehearsal', booking({ id: 'r-main', venue: 'Main Stage' })),
      create('audition', booking({ id: 'a-studio', eventType: 'audition', venue: 'Studio A' })),
    ]);
  });

  it('allows adjacent half-open intervals', async () => {
    await create('rehearsal', booking({ id: 'r1' }));
    await create('audition', booking({
      id: 'a1', eventType: 'audition',
      startTimeMillis: start + 60 * 60 * 1000,
      endTimeMillis: start + 2 * 60 * 60 * 1000,
    }));
  });

  it('excludes an event from its own edit and rejects an edit into another booking', async () => {
    await create('rehearsal', booking({ id: 'r1' }));
    await create('audition', booking({
      id: 'a1', eventType: 'audition', venue: 'Studio A',
    }));

    await transactBooking({
      db, eventType: 'rehearsal', action: 'update',
      input: booking({ id: 'r1', startTimeMillis: start + 15 * 60 * 1000 }),
      uid: 'director-test',
    });

    await assert.rejects(
      transactBooking({
        db, eventType: 'rehearsal', action: 'update',
        input: booking({ id: 'r1', venue: 'Studio A' }),
        uid: 'director-test',
      }),
      (error) => error.code === 'failed-precondition',
    );
    const unchanged = await db.collection('rehearsals').doc('r1').get();
    assert.equal(unchanged.get('venueName'), 'Main Stage');
  });

  it('rejects empty, zero-length, and reversed intervals', async () => {
    for (const eventType of ['rehearsal', 'audition']) {
      for (const [startTimeMillis, endTimeMillis] of [
        [start, start],
        [start + 1, start],
      ]) {
        await assert.rejects(
          create(eventType, booking({
            id: `invalid-${eventType}-${startTimeMillis}-${endTimeMillis}`,
            eventType,
            startTimeMillis,
            endTimeMillis,
          })),
          (error) => error.code === 'invalid-argument',
        );
      }
    }
  });

  it('matches legacy rehearsal IDs to audition venue names through the venue directory', async () => {
    await db.collection('venues').doc('venue-main-id').set({ name: 'Main Stage', capacity: 100 });
    await create('rehearsal', {
      ...booking({ id: 'legacy-id-booking', venue: 'Main Stage' }),
      venueId: 'venue-main-id',
      venueName: 'Main Stage',
    });
    await assert.rejects(
      create('audition', booking({ id: 'name-booking', eventType: 'audition', venue: ' main   stage ' })),
      (error) => error.details?.reason === 'venue-conflict',
    );
  });

  it('accepts legacy ISO timestamps and reports malformed matching records for review', async () => {
    await db.collection('auditions').doc('legacy-iso').set({
      venue: 'Main Stage', title: 'Imported audition', status: 'Scheduled',
      startTime: new Date(start).toISOString(),
      endTime: new Date(start + 60 * 60 * 1000).toISOString(),
    });
    await assert.rejects(
      create('rehearsal', booking({ id: 'iso-collision' })),
      (error) => error.details?.reason === 'venue-conflict',
    );

    await db.collection('auditions').doc('legacy-bad-time').set({
      venue: 'Main Stage', title: 'Malformed imported audition', status: 'Scheduled',
      startTime: 'not-a-date', endTime: new Date(start + 60 * 60 * 1000).toISOString(),
    });
    await assert.rejects(
      create('rehearsal', booking({ id: 'malformed-collision', startTimeMillis: start + 3 * 60 * 60 * 1000 })),
      (error) => error.details?.reason === 'booking-data-review',
    );
  });

  it('fails closed when an active legacy booking has no usable venue identity', async () => {
    await db.collection('rehearsals').doc('legacy-no-venue').set({
      title: 'Unclassifiable imported rehearsal',
      startTime: new Date(start).toISOString(),
      endTime: new Date(start + 60 * 60 * 1000).toISOString(),
    });
    await assert.rejects(
      create('audition', booking({ id: 'blocked-until-cleanup', eventType: 'audition', venue: 'Studio A' })),
      (error) => error.details?.reason === 'booking-data-review',
    );
  });

  it('does not allow two concurrent overlapping calls to both book one venue', async () => {
    const results = await Promise.allSettled([
      create('rehearsal', booking({ id: 'concurrent-r' })),
      create('audition', booking({ id: 'concurrent-a', eventType: 'audition' })),
    ]);
    assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
    const [rehearsals, auditions] = await Promise.all([
      db.collection('rehearsals').get(),
      db.collection('auditions').get(),
    ]);
    assert.equal(rehearsals.size + auditions.size, 1);
  });
});
