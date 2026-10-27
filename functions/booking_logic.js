const crypto = require('node:crypto');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

const COLLECTIONS = ['rehearsals', 'auditions'];
const AUDITION_STATUSES = ['Scheduled', 'Completed', 'Cancelled'];

function normalizeAlias(value) {
  return typeof value === 'string'
    ? value.trim().toLocaleLowerCase('en-US').replace(/\s+/g, ' ')
    : '';
}

function bookingAliases(data, eventType) {
  const values = eventType === 'rehearsal'
    ? [data.venueId, data.venueName, data.venue]
    : [data.venue, data.venueId];
  return [...new Set(values.map(normalizeAlias).filter(Boolean))];
}

function venueAliasKeys(data, eventType, venueKeys) {
  const stableId = typeof data.venueId === 'string' ? data.venueId.trim() : '';
  const stableKey = stableId ? venueKeys.ids.get(stableId) : null;
  if (stableKey) return [stableKey];

  const aliases = bookingAliases(data, eventType);
  const resolved = new Set();
  for (const alias of aliases) {
    const matches = venueKeys.aliases.get(alias) ?? new Set();
    if (matches.size > 1) {
      throw new HttpsError(
        'failed-precondition',
        `Venue alias "${alias}" identifies more than one venue. Correct the venue directory or booking data.`,
        { reason: 'venue-alias-ambiguous', alias },
      );
    }
    for (const canonicalKey of matches) resolved.add(canonicalKey);
  }
  if (resolved.size > 1) {
    throw new HttpsError(
      'failed-precondition',
      'Booking venue fields identify different registered venues.',
      { reason: 'venue-alias-ambiguous' },
    );
  }
  return resolved.size === 1 ? [...resolved] : aliases.map((alias) => `alias:${alias}`);
}

function createVenueAliasIndex(venueDocs) {
  const aliases = new Map();
  const ids = new Map();
  const idsByKey = new Map();
  const deleted = new Set();
  const add = (alias, key) => {
    const normalized = normalizeAlias(alias);
    if (!normalized) return;
    const matches = aliases.get(normalized) ?? new Set();
    matches.add(key);
    aliases.set(normalized, matches);
  };
  for (const venue of venueDocs) {
    const key = `venue:${normalizeAlias(venue.id)}`;
    ids.set(venue.id, key);
    idsByKey.set(key, venue.id);
    if (venue.data.deleted === true) deleted.add(key);
    add(venue.id, key);
    add(venue.data.name, key);
    const historical = venue.data.aliases ?? [];
    if (!Array.isArray(historical) || historical.some((alias) => typeof alias !== 'string')) {
      throw new HttpsError(
        'failed-precondition',
        `Venue ${venue.id} has malformed alias history. Correct the venue directory before booking.`,
        { reason: 'venue-data-review', venueId: venue.id },
      );
    }
    historical.forEach((alias) => add(alias, key));
  }
  return { aliases, ids, idsByKey, deleted };
}

function canonicalizeBookingVenue(input, eventType, venueKeys) {
  const id = typeof input.venueId === 'string' ? input.venueId.trim() : '';
  const idKey = id ? venueKeys.ids.get(id) : null;
  let resolvedKey = idKey;
  const aliases = bookingAliases(input, eventType);
  if (idKey) {
    for (const alias of aliases) {
      const matches = venueKeys.aliases.get(alias) ?? new Set();
      if (matches.size > 1 || (matches.size === 1 && !matches.has(idKey))) {
        throw new HttpsError(
          'invalid-argument',
          'The venue ID and venue name do not identify the same venue.',
          { reason: 'invalid-venue-reference' },
        );
      }
    }
  }
  if (!resolvedKey) {
    const resolved = new Set(aliases.flatMap((alias) => [...(venueKeys.aliases.get(alias) ?? [])]));
    if (resolved.size > 1) {
      throw new HttpsError(
        'failed-precondition',
        'The selected venue name is ambiguous. Select a venue with a unique name or correct the venue directory.',
        { reason: 'venue-alias-ambiguous' },
      );
    }
    resolvedKey = [...resolved][0];
  }
  if (!resolvedKey) return { ...input };
  if (venueKeys.deleted.has(resolvedKey)) {
    throw new HttpsError(
      'failed-precondition',
      'This venue has been deleted and can no longer be booked.',
      { reason: 'venue-deleted' },
    );
  }
  const venueId = venueKeys.idsByKey.get(resolvedKey) ?? resolvedKey.slice('venue:'.length);
  if (eventType === 'audition') return { ...input, venueId };
  const displayName = [input.venueName, input.venue, input.venueId]
    .find((value) => typeof value === 'string' && value.trim())?.trim() ?? '';
  return { ...input, venueId, venueName: displayName, venue: displayName };
}

function validateRehearsalVenueReference(input, venueKeys) {
  const idAlias = normalizeAlias(input.venueId);
  const nameAlias = normalizeAlias(input.venueName);
  if (!idAlias || !nameAlias || idAlias === nameAlias) return;

  const idKeys = venueKeys.aliases.get(idAlias) ?? new Set();
  const nameKeys = venueKeys.aliases.get(nameAlias) ?? new Set();
  const stableKey = venueKeys.ids.get(input.venueId.trim());
  const matchesSameVenue = stableKey
    ? nameKeys.size === 1 && nameKeys.has(stableKey)
    : idKeys.size === 1 && nameKeys.size === 1
      && [...idKeys].some((key) => nameKeys.has(key));
  if (!matchesSameVenue) {
    throw new HttpsError(
      'invalid-argument',
      'The venue ID and venue name must identify the same registered venue.',
      { reason: 'invalid-venue-reference' },
    );
  }
}

function legacyDate(value) {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  // Both client models accept ISO-8601 strings from older/imported records.
  if (typeof value === 'string' && value.trim()) {
    const parsed = new Date(value);
    if (Number.isFinite(parsed.getTime())) return parsed;
  }
  return null;
}

function invalidLegacyBooking(candidate, reason) {
  throw new HttpsError(
    'failed-precondition',
    `Booking ${candidate.id} needs data correction before venue availability can be verified: ${reason}`,
    { reason: 'booking-data-review', eventType: candidate.collection, eventId: candidate.id },
  );
}

function lockId(alias) {
  return crypto.createHash('sha256').update(alias).digest('hex');
}

function overlaps(startA, endA, startB, endB) {
  return startA.toMillis() < endB.toMillis()
    && startB.toMillis() < endA.toMillis();
}

function isActive(data, collection) {
  return collection !== 'auditions' || data.status !== 'Cancelled';
}

function validateBooking(eventType, action, input) {
  if (eventType !== 'audition' && eventType !== 'rehearsal') {
    throw new HttpsError('invalid-argument', 'Unknown booking type.');
  }
  if (!['create', 'update', 'cancel', 'delete'].includes(action)) {
    throw new HttpsError('invalid-argument', 'Unknown booking action.');
  }
  if (action === 'cancel' && eventType !== 'audition') {
    throw new HttpsError('invalid-argument', 'Only auditions can be cancelled.');
  }
  if (!input || typeof input !== 'object') {
    throw new HttpsError('invalid-argument', 'Booking data is required.');
  }
  if (action !== 'create' && (typeof input.id !== 'string' || !input.id.trim() || input.id.includes('/'))) {
    throw new HttpsError('invalid-argument', 'A valid booking ID is required.');
  }
  if (action === 'create' && (typeof input.id !== 'string' || !input.id.trim() || input.id.includes('/'))) {
    throw new HttpsError('invalid-argument', 'A valid booking ID is required.');
  }
  if (action === 'delete' || action === 'cancel') return;

  for (const field of ['venueId', 'venueName', 'venue']) {
    if (input[field] !== undefined && input[field] !== null && typeof input[field] !== 'string') {
      throw new HttpsError('invalid-argument', `${field} must be text.`);
    }
  }

  for (const field of ['productionId', 'title']) {
    if (typeof input[field] !== 'string' || !input[field].trim()) {
      throw new HttpsError('invalid-argument', `${field} is required.`);
    }
  }
  const venueAliases = bookingAliases(input, eventType);
  if (venueAliases.length === 0) {
    throw new HttpsError('invalid-argument', 'A venue is required.');
  }
  if (eventType === 'audition'
      && (typeof input.venue !== 'string' || !input.venue.trim())) {
    throw new HttpsError('invalid-argument', 'A venue is required.');
  }
  if (!Number.isSafeInteger(input.startTimeMillis) || !Number.isSafeInteger(input.endTimeMillis)) {
    throw new HttpsError('invalid-argument', 'Valid start and end times are required.');
  }
  if (Math.abs(input.startTimeMillis) > 8.64e15 || Math.abs(input.endTimeMillis) > 8.64e15) {
    throw new HttpsError('invalid-argument', 'Booking dates are outside the supported range.');
  }
  if (input.endTimeMillis <= input.startTimeMillis) {
    throw new HttpsError('invalid-argument', 'End time must be after start time.');
  }
  if (eventType === 'audition' && !AUDITION_STATUSES.includes(input.status)) {
    throw new HttpsError('invalid-argument', 'Invalid audition status.');
  }
}

function buildBooking(eventType, input, existing, creatorUid) {
  const startTime = Timestamp.fromMillis(input.startTimeMillis);
  const endTime = Timestamp.fromMillis(input.endTimeMillis);
  if (eventType === 'audition') {
    return {
      ...(existing ?? {}),
      productionId: input.productionId.trim(),
      title: input.title.trim(),
      venue: input.venue.trim(),
      ...(typeof input.venueId === 'string' && input.venueId.trim()
        ? { venueId: input.venueId.trim() }
        : {}),
      startTime,
      endTime,
      description: typeof input.description === 'string' ? input.description.trim() : '',
      requirements: typeof input.requirements === 'string' ? input.requirements.trim() : '',
      status: input.status,
      creatorUid: existing?.creatorUid ?? creatorUid,
      createdAt: existing?.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
  }
  const venueId = [input.venueId, input.venueName, input.venue]
    .find((value) => typeof value === 'string' && value.trim())?.trim() ?? '';
  const venueName = [input.venueName, input.venue, input.venueId]
    .find((value) => typeof value === 'string' && value.trim())?.trim() ?? '';
  return {
    ...(existing ?? {}),
    productionId: input.productionId.trim(),
    title: input.title.trim(),
    venueId,
    venueName,
    venue: venueName || venueId,
    startTime,
    endTime,
    scheduledAt: startTime,
    creatorUid: existing?.creatorUid ?? creatorUid,
    notes: typeof input.notes === 'string' ? input.notes.trim() : '',
    createdAt: existing?.createdAt ?? FieldValue.serverTimestamp(),
  };
}

async function transactBooking({ db, eventType, action, input, uid }) {
  if (typeof uid !== 'string' || !uid.trim()) {
    throw new HttpsError('unauthenticated', 'Sign in before changing a booking.');
  }
  validateBooking(eventType, action, input);
  const collectionName = eventType === 'audition' ? 'auditions' : 'rehearsals';
  const eventId = input.id.trim();
  const eventRef = db.collection(collectionName).doc(eventId);

  return db.runTransaction(async (transaction) => {
    const existingSnapshot = action === 'create' ? null : await transaction.get(eventRef);
    if (action === 'create' && existingSnapshot === null) {
      // A client-selected ID must never overwrite an existing booking.
      const collision = await transaction.get(eventRef);
      if (collision.exists) throw new HttpsError('already-exists', 'Booking ID already exists.');
    } else if (!existingSnapshot?.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const existing = existingSnapshot?.data();

    const snapshots = await Promise.all(
      COLLECTIONS.map((name) => transaction.get(db.collection(name)))
    );
    const otherBookings = snapshots.flatMap((snapshot, index) =>
      snapshot.docs.map((doc) => ({
        id: doc.id,
        collection: COLLECTIONS[index],
        data: doc.data(),
      }))
    );
    const venuesSnapshot = await transaction.get(db.collection('venues'));
    const venueKeys = createVenueAliasIndex(venuesSnapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() })));

    const newData = action === 'create' || action === 'update'
      ? buildBooking(eventType, canonicalizeBookingVenue(input, eventType, venueKeys), existing, uid.trim())
      : null;
    const productionSnapshot = newData
      ? await transaction.get(db.collection('productions').doc(newData.productionId))
      : null;
    if (newData && !productionSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'The selected production no longer exists.');
    }

    if (newData && eventType === 'rehearsal') {
      validateRehearsalVenueReference(input, venueKeys);
    }

    const oldAliases = existing ? venueAliasKeys(existing, eventType, venueKeys) : [];
    const newAliases = newData ? venueAliasKeys(newData, eventType, venueKeys) : [];
    const aliases = [...new Set([...oldAliases, ...newAliases])];
    const lockRefs = aliases
      .map((alias) => db.collection('venue_booking_locks').doc(lockId(alias)))
      .sort((a, b) => a.path.localeCompare(b.path));
    const lockSnapshots = await Promise.all(lockRefs.map((ref) => transaction.get(ref)));

    if (newData && isActive(newData, collectionName)) {
      const requestedAliases = new Set(newAliases);
      for (const candidate of otherBookings) {
        if (candidate.collection === collectionName && candidate.id === eventId) continue;
        if (!isActive(candidate.data, candidate.collection)) continue;
        const candidateAliases = venueAliasKeys(
          candidate.data,
          candidate.collection === 'auditions' ? 'audition' : 'rehearsal',
          venueKeys,
        );
        if (candidateAliases.length === 0) {
          invalidLegacyBooking(candidate, 'venue is missing or malformed');
        }
        if (!candidateAliases.some((alias) => requestedAliases.has(alias))) continue;
        const start = legacyDate(candidate.data.startTime);
        const end = legacyDate(candidate.data.endTime);
        if (!start || !end || end.getTime() <= start.getTime()) {
          invalidLegacyBooking(candidate, 'startTime/endTime are missing, malformed, or reversed');
        }
        const requestedStart = newData.startTime.toDate();
        const requestedEnd = newData.endTime.toDate();
        if (start.getTime() < requestedEnd.getTime() && requestedStart.getTime() < end.getTime()) {
          throw new HttpsError(
            'failed-precondition',
            `Venue is already booked by ${candidate.data.title || 'another event'} `
              + `from ${start.toISOString()} to ${end.toISOString()}.`,
            { reason: 'venue-conflict', eventType: candidate.collection, eventId: candidate.id },
          );
        }
      }
    }

    // Every booking writer reads and advances the same lock for each venue
    // alias. Concurrent transactions therefore retry against committed events.
    lockRefs.forEach((ref, index) => {
      const version = lockSnapshots[index].exists
        ? lockSnapshots[index].get('version')
        : 0;
      transaction.set(ref, {
        version: (Number.isInteger(version) ? version : 0) + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    if (action === 'delete') {
      transaction.delete(eventRef);
      return { id: eventId };
    }
    if (action === 'cancel') {
      transaction.update(eventRef, {
        status: 'Cancelled',
        ...(typeof input.reason === 'string' && input.reason.trim()
          ? { cancellationReason: input.reason.trim() }
          : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { id: eventId };
    }

    transaction.set(eventRef, newData);
    return { id: eventId };
  });
}

module.exports = {
  bookingAliases,
  canonicalizeBookingVenue,
  createVenueAliasIndex,
  legacyDate,
  normalizeAlias,
  overlaps,
  transactBooking,
  validateBooking,
  venueAliasKeys,
  validateRehearsalVenueReference,
};
