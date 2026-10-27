# Venue booking backend

`saveVenueBooking` is the only intended client mutation path for auditions and
rehearsals. Firestore client rules deny writes to those two collections. The
callable checks the caller's `users/{uid}.role` profile and requires `Director`.
Venue directory changes use the `manageVenue` callable, also Director-only.
Client rules deny venue writes so renames, alias history, and deletion checks
cannot be bypassed.

New bookings resolve registered venues to their stable document ID and store
that ID in `venueId`, including auditions. Venue renames append the previous
normalized name to the venue document's `aliases` array. All names and aliases
resolve to one canonical venue identity; if existing directory data makes an
alias ambiguous, the callable fails closed. A deleted venue is retained as a
tombstone with its aliases and ID, preventing later bookings by either identity.
Deletion is rejected while any non-cancelled audition or rehearsal is ongoing
or future. Past booking documents remain available as history.

Booking and venue-management transactions advance the same canonical venue
lock. A rename also locks its old, new, and historical name aliases, so an
in-flight booking either observes the new mapping on retry or serializes ahead
of the rename and is included under the preserved alias.

## Existing venue and date schema

Rehearsals store Firestore timestamps in `startTime`/`endTime` and venue text
in `venueId`, `venueName`, and legacy `venue` fields. The current rehearsal
form is free text and writes the same text into all three fields. Auditions
store Firestore timestamps and a free-text `venue` field. The server resolves
stored venue document IDs and venue names through `venues/{id}` when possible,
then also compares normalized aliases. Free-text venue labels remain valid to
preserve current form behavior; unknown labels are not referentially validated.
When a rehearsal supplies a distinct `venueId` and `venueName`, the pair must
resolve to the same venue document. The current free-text form supplies the
same value in both fields and remains supported.

Existing booking models also accept ISO-8601 timestamp strings. The transaction
accepts those strings for existing bookings. If an active legacy booking has
no usable venue identity, every new active booking fails with
`booking-data-review` until the record is corrected. If a matching venue has
missing, malformed, or reversed dates, that request fails with the same code.
This is intentionally fail-closed and can require manual cleanup of old data.

## Concurrency and scale

Each mutation reads both booking collections and the venue directory, then
reads and increments hashed `venue_booking_locks` documents for every resolved
venue alias within the same Firestore transaction as the booking write. A
conflicting transaction on the same alias retries and sees the committed event.
Lock documents are counters and are not deleted; they are lazily created and
one remains for each alias ever written. No lock backfill is necessary because
the transaction still scans existing bookings before mutation.

This design is linear in the number of auditions, rehearsals, and venue
documents read per mutation. A per-venue reservation index could reduce that
cost, but is unsafe until an admin migration backfills every active legacy
booking, normalizes venue aliases, rejects/repairs malformed records, and a
verified cutover prevents new writes from bypassing the index. No such index
or migration is included here. Free-text venue aliases also mean typos can
represent distinct venue identities; production forms should eventually use
the venue document ID plus displayed name.

## Emulator verification

Functions use the Node 22 runtime (`functions/package.json` and `firebase.json`).
Run the commands in a Node 22 shell; do not change the project runtime to match
a different local Node installation.

The configured emulator addresses are `127.0.0.1:8085` (Firestore),
`127.0.0.1:9099` (Auth), and `127.0.0.1:5001` (Functions). The Emulator Suite
must be able to bind these addresses, and test processes must be able to
connect to them.

From the repository root:

- `npm --prefix functions run test:unit` runs seventeen pure booking-validation,
  callable-handler, and venue-identity unit tests. It does not require Firebase
  Emulators.
- `npm --prefix functions run test:transaction` runs
  `functions/test/booking_logic.test.js` against Firestore Emulator. It requires
  `FIRESTORE_EMULATOR_HOST=127.0.0.1:8085` and a reachable emulator.
- `npm --prefix functions run test:integration` sends HTTP callable requests
  to Functions Emulator, gets test ID tokens from Auth Emulator, and inspects
  Firestore Emulator data. It requires all three emulators and checks their
  ports before making requests. Emulator HTTP calls have bounded timeouts.
- `npm --prefix functions test` runs unit, transaction, and callable
  integration suites in that order. The latter two require their emulators.
- `npm run test:rules` runs the Firestore security rules suite using the
  Firestore Emulator on port 8085.
- `npm run test:bookings` starts Auth, Firestore, and Functions Emulators, then
  runs all Functions suites under the isolated demo project
  `demo-venue-booking-tests`. Emulator startup uses Firebase CLI debug output;
  startup or test failures are returned as a nonzero command result.

For a manual transaction-suite run, use two PowerShell sessions:

```powershell
# Session 1
firebase --project demo-venue-booking-tests emulators:start --only firestore

# Session 2
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085'
npm --prefix functions run test:transaction
```

For a manual callable integration run, use two PowerShell sessions:

```powershell
# Session 1
firebase --project demo-venue-booking-tests emulators:start --only auth,firestore,functions

# Session 2
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8085'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
npm --prefix functions run test:integration
```

The transaction test clears its booking, lock, production, and venue test
collections before each case, deletes its fixture collections afterward, and
closes its Admin app. The callable integration suite resets booking data before
each test and removes its temporary Auth accounts, user profiles, and fixture
collections after the suite. Cleanup failures are reported as suite failures.
Both emulator-backed Node suites preflight their emulator ports and fail with
the connection error instead of waiting indefinitely for database requests.

Deploy the callable and `client/firestore.rules` together. Deploying only the
rules disables all client booking mutations; deploying only the callable does
not stop direct client writes. These sources and tests do not deploy anything.
