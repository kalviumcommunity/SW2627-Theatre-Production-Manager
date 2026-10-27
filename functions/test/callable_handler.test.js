const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createSaveVenueBookingHandler } = require('../callable_handler');

function makeDb(role = 'Director') {
  return {
    collection(name) {
      assert.equal(name, 'users');
      return {
        doc(uid) {
          return {
            async get() {
              return role === null
                ? { exists: false, get: () => undefined }
                : { exists: true, get: (field) => field === 'role' ? role : undefined };
            },
          };
        },
      };
    },
  };
}

describe('saveVenueBooking callable handler unit tests', () => {
  it('rejects missing authentication before reading the profile', async () => {
    const handler = createSaveVenueBookingHandler({ db: makeDb(), transact: async () => assert.fail() });
    await assert.rejects(handler({ auth: null, data: {} }), { code: 'unauthenticated' });
  });

  it('rejects authenticated non-Directors', async () => {
    const handler = createSaveVenueBookingHandler({ db: makeDb('Cast Member'), transact: async () => assert.fail() });
    await assert.rejects(
      handler({ auth: { uid: 'cast-1' }, data: {} }),
      { code: 'permission-denied' },
    );
  });

  it('rejects authenticated users without a profile', async () => {
    const handler = createSaveVenueBookingHandler({ db: makeDb(null), transact: async () => assert.fail() });
    await assert.rejects(
      handler({ auth: { uid: 'missing-profile' }, data: {} }),
      { code: 'permission-denied' },
    );
  });

  it('passes an authorized Director identity and payload to booking transaction logic', async () => {
    let received;
    const handler = createSaveVenueBookingHandler({
      db: makeDb(),
      transact: async (args) => { received = args; return { id: 'booking-1' }; },
    });
    const result = await handler({
      auth: { uid: 'director-1' },
      data: { eventType: 'audition', action: 'create', booking: { id: 'booking-1' } },
    });
    assert.deepEqual(result, { id: 'booking-1' });
    assert.equal(received.uid, 'director-1');
    assert.equal(received.eventType, 'audition');
    assert.equal(received.input.id, 'booking-1');
  });
});
