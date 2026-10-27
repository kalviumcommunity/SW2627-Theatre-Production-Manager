const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createVenueAliasIndex, legacyDate, validateBooking, venueAliasKeys } = require('../booking_logic');

function input(overrides = {}) {
  return {
    id: 'event-1',
    productionId: 'production-1',
    title: 'Production call',
    venue: 'Main Stage',
    startTimeMillis: Date.UTC(2026, 10, 5, 10),
    endTimeMillis: Date.UTC(2026, 10, 5, 11),
    status: 'Scheduled',
    ...overrides,
  };
}

describe('booking validation and legacy data unit tests', () => {
  it('rejects invalid event type, action, IDs, and unsupported cancellation type', () => {
    assert.throws(() => validateBooking('other', 'create', input()), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('audition', 'nope', input()), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('audition', 'create', input({ id: 'a/b' })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'cancel', { id: 'r1' }), { code: 'invalid-argument' });
  });

  it('rejects missing, malformed, zero-length, reversed, and out-of-range time fields', () => {
    assert.throws(() => validateBooking('rehearsal', 'create', input({ startTimeMillis: undefined })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'create', input({ startTimeMillis: 'tomorrow' })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'create', input({ startTimeMillis: 100, endTimeMillis: 100 })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'create', input({ startTimeMillis: 200, endTimeMillis: 100 })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'create', input({ endTimeMillis: Number.MAX_SAFE_INTEGER })), { code: 'invalid-argument' });
  });

  it('rejects missing/invalid venue values and invalid audition status', () => {
    assert.throws(() => validateBooking('rehearsal', 'create', input({ venue: '  ', venueName: '', venueId: '' })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('rehearsal', 'create', input({ venueId: 77 })), { code: 'invalid-argument' });
    assert.throws(() => validateBooking('audition', 'create', input({ status: 'Draft' })), { code: 'invalid-argument' });
  });

  it('recognizes the same registered venue by ID or normalized display name', () => {
    const venueKeys = createVenueAliasIndex([
      { id: 'venue-main-id', data: { name: 'Main Stage', aliases: [] } },
    ]);
    const rehearsalKeys = venueAliasKeys(
      { venueId: 'venue-main-id', venueName: 'Main Stage', venue: 'Main Stage' },
      'rehearsal',
      venueKeys,
    );
    const auditionKeys = venueAliasKeys({ venue: ' main   stage ' }, 'audition', venueKeys);
    assert.ok(rehearsalKeys.includes('venue:venue-main-id'));
    assert.ok(auditionKeys.includes('venue:venue-main-id'));
  });

  it('parses supported legacy ISO timestamps and rejects malformed values', () => {
    assert.equal(legacyDate('2026-11-05T10:00:00.000Z').getTime(), Date.UTC(2026, 10, 5, 10));
    assert.equal(legacyDate('not-a-date'), null);
    assert.equal(legacyDate(undefined), null);
  });
});
