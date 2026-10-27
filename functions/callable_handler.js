const { HttpsError } = require('firebase-functions/v2/https');
const { transactBooking } = require('./booking_logic');

function createSaveVenueBookingHandler({ db, transact = transactBooking }) {
  return async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in before changing a booking.');
    }
    const profile = await db.collection('users').doc(request.auth.uid).get();
    if (!profile.exists || profile.get('role') !== 'Director') {
      throw new HttpsError('permission-denied', 'Only directors may manage bookings.');
    }

    const { eventType, action } = request.data ?? {};
    const booking = request.data?.booking ?? request.data ?? {};
    return transact({
      db,
      eventType,
      action,
      input: booking,
      uid: request.auth.uid,
    });
  };
}

module.exports = { createSaveVenueBookingHandler };
