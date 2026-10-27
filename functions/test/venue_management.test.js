const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { HttpsError } = require('firebase-functions/v2/https');
const {
  canonicalizeBookingVenue,
  createVenueAliasIndex,
  validateRehearsalVenueReference,
} = require('../booking_logic');
const {
  assertNoOverlappingBookingsForVenue,
  createManageVenueHandler,
  validateVenueInput,
} = require('../venue_management');

describe('stable venue identity and historical aliases', () => {
  it('resolves old aliases to the stable venue ID and persists that ID', () => {
    const index = createVenueAliasIndex([{
      id: 'venue-main-id',
      data: { name: 'Black Box', aliases: ['Main Stage', 'Grand Stage'] },
    }]);
    const audition = canonicalizeBookingVenue({ venue: ' main   stage ' }, 'audition', index);
    const rehearsal = canonicalizeBookingVenue({
      venueId: 'Main Stage', venueName: 'Main Stage', venue: 'Main Stage',
    }, 'rehearsal', index);
    assert.equal(audition.venueId, 'venue-main-id');
    assert.equal(rehearsal.venueId, 'venue-main-id');
    assert.equal(rehearsal.venueName, 'Main Stage');
  });

  it('uses a supplied stable ID first but rejects a contradictory registered name', () => {
    const index = createVenueAliasIndex([
      { id: 'venue-a', data: { name: 'Hall A', aliases: [] } },
      { id: 'venue-b', data: { name: 'Hall B', aliases: [] } },
    ]);
    assert.equal(canonicalizeBookingVenue({ venueId: 'venue-a', venue: 'Hall A' }, 'audition', index).venueId, 'venue-a');
    assert.throws(
      () => canonicalizeBookingVenue({ venueId: 'venue-a', venue: 'Hall B' }, 'audition', index),
      (error) => error.code === 'invalid-argument' && error.details.reason === 'invalid-venue-reference',
    );
  });

  it('rejects ambiguous aliases instead of selecting a venue arbitrarily', () => {
    const index = createVenueAliasIndex([
      { id: 'venue-a', data: { name: 'Hall A', aliases: ['Old Hall'] } },
      { id: 'venue-b', data: { name: 'Hall B', aliases: [' old   hall '] } },
    ]);
    assert.throws(
      () => canonicalizeBookingVenue({ venue: 'Old Hall' }, 'audition', index),
      (error) => error.code === 'failed-precondition' && error.details.reason === 'venue-alias-ambiguous',
    );
  });

  it('rejects a rehearsal ID/name pair when either different value is unresolved', () => {
    const index = createVenueAliasIndex([
      { id: 'venue-a', data: { name: 'Hall A', aliases: [] } },
    ]);
    for (const input of [
      { venueId: 'missing-id', venueName: 'Hall A' },
      { venueId: 'venue-a', venueName: 'Unregistered Hall' },
    ]) {
      assert.throws(
        () => validateRehearsalVenueReference(input, index),
        (error) => error.code === 'invalid-argument' && error.details.reason === 'invalid-venue-reference',
      );
    }
    assert.doesNotThrow(() => validateRehearsalVenueReference({
      venueId: 'venue-a', venueName: 'Hall A',
    }, index));
  });

  it('rejects bookings by tombstoned venue ID or historical name', () => {
    const index = createVenueAliasIndex([{
      id: 'venue-deleted', data: { name: 'Current Hall', aliases: ['Old Hall'], deleted: true },
    }]);
    for (const input of [{ venueId: 'venue-deleted', venue: 'Current Hall' }, { venue: 'Old Hall' }]) {
      assert.throws(
        () => canonicalizeBookingVenue(input, 'audition', index),
        (error) => error.code === 'failed-precondition' && error.details.reason === 'venue-deleted',
      );
    }
  });

  it('validates create, update, and delete payload identities', () => {
    assert.doesNotThrow(() => validateVenueInput({ id: 'venue-1', name: 'Hall', capacity: 40 }, 'create'));
    assert.doesNotThrow(() => validateVenueInput({ id: 'venue-1' }, 'delete'));
    assert.throws(() => validateVenueInput({ id: '', name: 'Hall', capacity: 40 }, 'create'), HttpsError);
    assert.throws(() => validateVenueInput({ id: 'venue-1', name: 'Hall', capacity: 0 }, 'update'), HttpsError);
  });

  it('authorizes only Directors before invoking venue mutations', async () => {
    const makeDb = (role) => ({
      collection(name) {
        assert.equal(name, 'users');
        return { doc: () => ({ get: async () => ({
          exists: role !== null,
          get: () => role,
        }) }) };
      },
    });
    const noAuth = createManageVenueHandler({ db: makeDb('Director'), transact: async () => assert.fail() });
    await assert.rejects(noAuth({ auth: null, data: {} }), { code: 'unauthenticated' });
    const cast = createManageVenueHandler({ db: makeDb('Cast Member'), transact: async () => assert.fail() });
    await assert.rejects(cast({ auth: { uid: 'cast-1' }, data: {} }), { code: 'permission-denied' });

    let received;
    const director = createManageVenueHandler({
      db: makeDb('Director'),
      transact: async (args) => { received = args; return { id: 'venue-1' }; },
    });
    assert.deepEqual(await director({
      auth: { uid: 'director-1' },
      data: { action: 'create', venue: { id: 'venue-1' } },
    }), { id: 'venue-1' });
    assert.equal(received.action, 'create');
    assert.equal(received.input.id, 'venue-1');
  });

  it('rejects a rename projection that merges overlapping old and new name bookings', () => {
    const projected = createVenueAliasIndex([{
      id: 'venue-main-id', data: { name: 'Grand Stage', aliases: ['Main Stage'] },
    }]);
    const bookings = [
      {
        id: 'old-name', collection: 'auditions',
        data: { venue: 'Main Stage', status: 'Scheduled', startTime: new Date(1000), endTime: new Date(5000) },
      },
      {
        id: 'new-name', collection: 'rehearsals',
        data: { venueId: 'Grand Stage', venueName: 'Grand Stage', startTime: new Date(4000), endTime: new Date(8000) },
      },
    ];
    assert.throws(
      () => assertNoOverlappingBookingsForVenue(bookings, projected, projected.ids.get('venue-main-id'), () => 0),
      (error) => error.code === 'failed-precondition' && error.details.reason === 'venue-alias-conflict',
    );
  });
});
