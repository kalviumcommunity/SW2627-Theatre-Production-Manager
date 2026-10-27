const { onCall } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { createSaveVenueBookingHandler } = require('./callable_handler');
const { createManageVenueHandler } = require('./venue_management');

if (getApps().length === 0) initializeApp();
const db = getFirestore();

exports.saveVenueBooking = onCall(
  { region: 'us-central1' },
  createSaveVenueBookingHandler({ db }),
);

exports.manageVenue = onCall(
  { region: 'us-central1' },
  createManageVenueHandler({ db }),
);
