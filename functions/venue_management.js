const crypto = require('node:crypto');
const { FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { createVenueAliasIndex, legacyDate, normalizeAlias, venueAliasKeys } = require('./booking_logic');

function venueLockId(alias) {
  return crypto.createHash('sha256').update(alias).digest('hex');
}

function isActiveBooking(data, collection) {
  return collection !== 'auditions' || data.status !== 'Cancelled';
}

function venueData(venue) {
  return typeof venue.data === 'function' ? venue.data() : (venue.data ?? venue);
}

function venueAliases(venue) {
  const data = venueData(venue);
  return [data.name, ...(Array.isArray(data.aliases) ? data.aliases : [])]
    .map(normalizeAlias)
    .filter(Boolean);
}

function validateVenueInput(input, action) {
  if (!input || typeof input !== 'object') {
    throw new HttpsError('invalid-argument', 'Venue data is required.');
  }
  if (action === 'delete') {
    if (typeof input.id !== 'string' || !input.id.trim() || input.id.includes('/')) {
      throw new HttpsError('invalid-argument', 'A valid venue ID is required.');
    }
    return;
  }
  if (!['create', 'update'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Unknown venue action.');
  }
  if (typeof input.id !== 'string' || !input.id.trim() || input.id.includes('/')) {
    throw new HttpsError('invalid-argument', 'A valid venue ID is required.');
  }
  if (typeof input.name !== 'string' || !input.name.trim()) {
    throw new HttpsError('invalid-argument', 'Venue name is required.');
  }
  if (!Number.isSafeInteger(input.capacity) || input.capacity <= 0) {
    throw new HttpsError('invalid-argument', 'Venue capacity must be a positive integer.');
  }
  for (const field of ['address', 'description']) {
    if (input[field] !== undefined && typeof input[field] !== 'string') {
      throw new HttpsError('invalid-argument', `${field} must be text.`);
    }
  }
  if (input.facilities !== undefined
      && (!Array.isArray(input.facilities) || input.facilities.some((item) => typeof item !== 'string'))) {
    throw new HttpsError('invalid-argument', 'facilities must be a list of text values.');
  }
}

function assertAliasAvailable(name, venueDocs, targetId) {
  const normalized = normalizeAlias(name);
  for (const doc of venueDocs) {
    if (doc.id === targetId) continue;
    if (venueAliases(doc).includes(normalized)) {
      throw new HttpsError(
        'already-exists',
        `Venue name or historical alias "${name.trim()}" is already assigned to another venue.`,
        { reason: 'venue-alias-ambiguous' },
      );
    }
  }
}

function assertNoOverlappingBookingsForVenue(bookings, venueKeys, targetKey, now) {
  const relevant = [];
  for (const booking of bookings) {
    if (!isActiveBooking(booking.data, booking.collection)) continue;
    const keys = venueAliasKeys(
      booking.data,
      booking.collection === 'auditions' ? 'audition' : 'rehearsal',
      venueKeys,
    );
    if (!keys.includes(targetKey)) continue;
    const start = legacyDate(booking.data.startTime);
    const end = legacyDate(booking.data.endTime);
    if (!start || !end || end <= start) {
      throw new HttpsError(
        'failed-precondition',
        `Booking ${booking.id} has invalid dates; correct it before changing this venue's aliases.`,
        { reason: 'booking-data-review', eventId: booking.id },
      );
    }
    if (end.getTime() > now()) relevant.push({ ...booking, start, end });
  }
  for (let i = 0; i < relevant.length; i += 1) {
    for (let j = i + 1; j < relevant.length; j += 1) {
      const first = relevant[i];
      const second = relevant[j];
      if (first.start < second.end && second.start < first.end) {
        throw new HttpsError(
          'failed-precondition',
          `Venue alias change would combine overlapping bookings "${first.data.title || first.id}" and "${second.data.title || second.id}".`,
          { reason: 'venue-alias-conflict', eventIds: [first.id, second.id] },
        );
      }
    }
  }
}

async function transactVenue({ db, action, input, now = () => Date.now() }) {
  validateVenueInput(input, action);
  const id = input.id.trim();
  const venueRef = db.collection('venues').doc(id);

  return db.runTransaction(async (transaction) => {
    const currentSnapshot = action === 'create' ? null : await transaction.get(venueRef);
    if (action === 'create' && currentSnapshot === null) {
      const collision = await transaction.get(venueRef);
      if (collision.exists) throw new HttpsError('already-exists', 'Venue ID already exists.');
    } else if (!currentSnapshot?.exists) {
      throw new HttpsError('not-found', 'Venue not found.');
    }

    const [venueSnapshot, rehearsalSnapshot, auditionSnapshot] = await Promise.all([
      transaction.get(db.collection('venues')),
      transaction.get(db.collection('rehearsals')),
      transaction.get(db.collection('auditions')),
    ]);
    const venues = venueSnapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
    const venueKeys = createVenueAliasIndex(venues);
    const current = currentSnapshot?.data();
    const newName = action === 'delete' ? current?.name : input.name.trim();
    assertAliasAvailable(newName, venues, id);

    const lockKeys = new Set([`venue:${normalizeAlias(id)}`]);
    for (const alias of [
      ...(current ? venueAliases(current) : []),
      ...(action !== 'delete' ? [input.name] : []),
    ]) {
      const normalized = normalizeAlias(alias);
      if (normalized) lockKeys.add(`alias:${normalized}`);
    }
    const lockRefs = [...lockKeys]
      .map((key) => db.collection('venue_booking_locks').doc(venueLockId(key)))
      .sort((a, b) => a.path.localeCompare(b.path));
    const lockSnapshots = await Promise.all(lockRefs.map((ref) => transaction.get(ref)));

    if (action === 'update' && normalizeAlias(current.name) !== normalizeAlias(input.name)) {
      const historicalAliases = [...new Set([
        ...(Array.isArray(current.aliases) ? current.aliases : []), current.name,
      ])].filter((alias) => normalizeAlias(alias) !== normalizeAlias(input.name));
      const projectedVenues = venues.map((venue) => venue.id === id
        ? { id, data: { ...current, name: input.name.trim(), aliases: historicalAliases } }
        : venue);
      const projectedKeys = createVenueAliasIndex(projectedVenues);
      const targetKey = projectedKeys.ids.get(id);
      const allBookings = [
        ...rehearsalSnapshot.docs.map((doc) => ({ id: doc.id, collection: 'rehearsals', data: doc.data() })),
        ...auditionSnapshot.docs.map((doc) => ({ id: doc.id, collection: 'auditions', data: doc.data() })),
      ];
      assertNoOverlappingBookingsForVenue(allBookings, projectedKeys, targetKey, now);
    }

    if (action === 'delete') {
      const targetKey = venueKeys.ids.get(id);
      const allBookings = [
        ...rehearsalSnapshot.docs.map((doc) => ({ id: doc.id, collection: 'rehearsals', data: doc.data() })),
        ...auditionSnapshot.docs.map((doc) => ({ id: doc.id, collection: 'auditions', data: doc.data() })),
      ];
      for (const booking of allBookings) {
        if (!isActiveBooking(booking.data, booking.collection)) continue;
        const keys = venueAliasKeys(
          booking.data,
          booking.collection === 'auditions' ? 'audition' : 'rehearsal',
          venueKeys,
        );
        if (!keys.includes(targetKey)) continue;
        const end = legacyDate(booking.data.endTime);
        if (!end) {
          throw new HttpsError(
            'failed-precondition',
            `Booking ${booking.id} has an invalid end time; correct it before deleting this venue.`,
            { reason: 'booking-data-review', eventId: booking.id },
          );
        }
        if (end.getTime() > now()) {
          throw new HttpsError(
            'failed-precondition',
            `Venue is still referenced by active or future booking "${booking.data.title || booking.id}".`,
            { reason: 'venue-in-use', eventId: booking.id, eventType: booking.collection },
          );
        }
      }
    }

    if (current?.deleted === true) {
      throw new HttpsError('failed-precondition', 'Deleted venues cannot be edited.');
    }

    lockRefs.forEach((ref, index) => {
      const version = lockSnapshots[index].exists ? lockSnapshots[index].get('version') : 0;
      transaction.set(ref, {
        version: (Number.isInteger(version) ? version : 0) + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    if (action === 'delete') {
      // A tombstone retains stable identity and aliases for historical events.
      transaction.update(venueRef, { deleted: true, updatedAt: FieldValue.serverTimestamp() });
      return { id, deleted: true };
    }

    const aliases = [...new Set([
      ...(Array.isArray(current?.aliases) ? current.aliases.map((alias) => alias.trim()).filter(Boolean) : []),
      ...(current && normalizeAlias(current.name) !== normalizeAlias(input.name) ? [current.name.trim()] : []),
    ])].filter((alias) => normalizeAlias(alias) !== normalizeAlias(input.name));
    const venueData = {
      name: input.name.trim(),
      address: (input.address ?? '').trim(),
      capacity: input.capacity,
      description: (input.description ?? '').trim(),
      facilities: (input.facilities ?? []).map((value) => value.trim()).filter(Boolean),
      aliases,
      deleted: false,
      ...(current?.createdAt ? { createdAt: current.createdAt } : { createdAt: FieldValue.serverTimestamp() }),
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.set(venueRef, venueData);
    return { id };
  });
}

function createManageVenueHandler({ db, transact = transactVenue }) {
  return async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in before changing a venue.');
    const profile = await db.collection('users').doc(request.auth.uid).get();
    if (!profile.exists || profile.get('role') !== 'Director') {
      throw new HttpsError('permission-denied', 'Only directors may manage venues.');
    }
    return transact({ db, action: request.data?.action, input: request.data?.venue ?? request.data });
  };
}

module.exports = {
  assertNoOverlappingBookingsForVenue,
  createManageVenueHandler,
  transactVenue,
  validateVenueInput,
};
