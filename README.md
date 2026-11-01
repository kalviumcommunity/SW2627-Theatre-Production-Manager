# Theatre Production Manager

Repository: `SW2627-Theatre-Production-Manager`
Simulated Work Sprint 2 | Semester 3 | JECRC | Team 02, Squad 124

## Description

Theatre Production Manager is a centralized Flutter and Firebase application for a regional theatre group managing multiple simultaneous productions. It replaces fragmented group-chat coordination for auditions, rehearsals, venue bookings, cast assignments, schedules, and alerts with a unified, role-based system.

> Status note: The repository contains the application and its Firebase backend. Verification status depends on the checks listed below; emulator-backed and Flutter checks must be run in an environment where those tools and services start successfully.

## Problem Summary

A regional theatre group manages auditions, rehearsal schedules, and cast assignments across several simultaneous productions. Coordination through group chats becomes unmanageable once multiple productions run in parallel. The full problem statement is in [docs/problem-statement.md](docs/problem-statement.md).

## Project Objective

Provide a centralized, production-ready application that lets the theatre group:

- Keep rehearsal and audition schedule information in one place so cast members and directors never miss updates,
- Prevent venue double-bookings with automated conflict detection across all production commitments, and
- Provide directors and cast members with clear, role-specific views across all productions.

## Core Problems Being Addressed

| # | Problem | Solution in App |
|---|---|---|
| 1 | Cast members miss schedule changes. | Centralized real-time schedule feed & automated schedule-change notifications. |
| 2 | Venues get double-booked. | Venue booking engine with automatic overlap & conflict detection across rehearsals and auditions. |
| 3 | Directors have no consolidated view of commitments. | Master Schedule aggregating all auditions and rehearsals with production and date filtering. |

## Implemented Modules

| Module | Status | Description |
|---|---|---|
| Production Management | Implemented | Create, edit, and track productions, timelines, and active/completed states. |
| Audition Management | Implemented | Schedule audition calls, track casting notices, manage slots, and record requirements. |
| Cast Management | Implemented | Manage cast rosters, assign character roles, assign understudies, and prevent duplicate role assignments. |
| Rehearsal Scheduling | Implemented | Schedule rehearsal sessions, assign venues, track run notes, and browse chronological timelines. |
| Venue Management | Implemented | Manage performance and rehearsal venues, validate seat capacities, and detect scheduling conflicts. |
| Master Schedule | Implemented | Consolidated calendar view aggregating rehearsals and auditions with role-based filtering (Director/Cast). |
| Notifications | Implemented | Real-time alerts for schedule changes, call times, and role assignments with read tracking. |

## Technology Stack

| Layer | Technology |
|---|---|
| Application | Flutter (Cross-platform) |
| Language | Dart |
| Authentication | Firebase Authentication (Director and Cast roles) |
| Database | Cloud Firestore (Real-time synchronization & security rules) |
| Notifications | Firebase Cloud Messaging (FCM) & in-app notification streams |
| Testing | Flutter Test, Node test runner, Mocha, Firebase Emulator Suite |

## High-Level Architecture

```text
User (Director / Cast Member)
  |
  v
Flutter Application (Responsive Mobile & Desktop Web)
  |
  +--> Firebase Authentication (Role-based access)
  +--> Cloud Firestore (Data streams & security rules)
  +--> Firebase Cloud Messaging (Push notifications & in-app alerts)
```

The repository structure follows modular feature packaging under `client/lib/features/`, detailed in [docs/project-structure.md](docs/project-structure.md).

## Team

| Member | Role in this stage |
|---|---|
| Vidit | Repository foundation, README, project structure, Backend Production Services |
| Himesh | Problem analysis, Initial Documentation |
| Ayushman | Managed Audition, Integrated Rehearsal and its backend, Improve Firestore-Security |

Team 02, Squad 124, JECRC campus.

## Current Project Status

| Area | Status |
|---|---|
| Problem definition | Documented ([docs/problem-statement.md](docs/problem-statement.md)) |
| Problem analysis | Documented ([docs/problem-analysis.md](docs/problem-analysis.md)) |
| Repository structure | Implemented (`client/`, `docs/`, `test/`) |
| Flutter project setup | Implemented (`client/`) |
| Firebase project setup | Implemented (Auth, Firestore, Messaging, Security Rules) |
| Automated Test Suite | See the commands and current verification results below |

## Development Status

All core modules specified in the requirements are implemented in Flutter and backed by Cloud Firestore and Firebase Authentication. The system features responsive mobile/desktop layouts, role-based dashboards and views (Director vs. Cast Member), real-time Firestore synchronization, conflict detection across rehearsals and auditions, and comprehensive automated test suites.

## Documentation

| Document | Description |
|---|---|
| [docs/problem-statement.md](docs/problem-statement.md) | Original problem statement, context, impact, stakeholders, and boundaries |
| [docs/problem-analysis.md](docs/problem-analysis.md) | Workflow analysis, requirements, constraints, MVP scope, and implementation mapping |
| [docs/project-structure.md](docs/project-structure.md) | Implemented Flutter and Firebase repository structure |
| [docs/app-requirements.md](docs/app-requirements.md) | Detailed functional and non-functional requirements |

## Setup and verification

Prerequisites: Node.js 22 for Cloud Functions, Flutter/Dart for the client,
Firebase CLI, and Java supported by the installed Firebase Emulator Suite.
The Functions runtime is configured for Node.js 22; do not change it to match a
different local Node version.

From the repository root, install dependencies and prepare the Flutter client:

```sh
npm ci
npm --prefix functions ci
cd client
flutter pub get
```

Run backend checks from the repository root:

```sh
npm run test:functions:unit
npm run test:rules
npm run test:bookings
npm test
```

`test:functions:transaction` and `test:functions:integration` are also available
for running those Functions suites against already-running emulators. The
transaction suite requires `FIRESTORE_EMULATOR_HOST=127.0.0.1:8085`; callable
integration requires Firestore, Auth, and Functions emulators on ports 8085,
9099, and 5001. `npm run test:rules` starts its own Firestore emulator.
`npm run test:bookings` starts Auth, Firestore, and Functions emulators, then
runs all Functions test suites. The emulated project IDs are demo IDs and do
not target a production Firebase project.

Run client checks from `client/`:

```sh
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

The repository-wide Dart formatting check currently reports pre-existing
formatting differences in files outside this change. To avoid reformatting
unrelated work, format the Dart files touched by a change with
`dart format <changed .dart files>` and run the same `--set-exit-if-changed`
check against those paths.

The venue booking backend uses `saveVenueBooking` for audition and rehearsal
mutations and `manageVenue` for venue create, update, and deletion. Deploy the
Functions and Firestore rules together to a selected Firebase project after
review. Deploying only the rules blocks client writes without enabling the
callables; deploying only the Functions leaves direct writes allowed by old
rules. No deployment is performed by these test commands.

The current venue deletion behavior is a soft deletion: it marks the venue as
deleted and retains its document ID and aliases so historical bookings remain
resolvable. Directors cannot edit a deleted venue or create another venue using
one of its historical names.


### User Roles and Permissions

| Feature / Action | Director | Cast Member | Enforcement Mechanism |
|---|---|---|---|
| **View Dashboard** | Full stats & all upcoming commitments | Relevant productions & assigned rehearsals | UI role gating & Firestore queries |
| **Productions** | Create, edit, delete, view all | Read-only access to assigned productions | Firestore Rules (`isDirector()`) & UI gating |
| **Auditions** | Schedule, edit, cancel, assign venues | Read-only view of audition notices & call times | Firestore Rules (writes blocked) + `saveVenueBooking` callable |
| **Rehearsals** | Schedule, edit, cancel, assign venues | Read-only view of rehearsals for their productions | Firestore Rules (writes blocked) + `saveVenueBooking` callable |
| **Venues** | Create, rename, edit capacity, soft-delete | View venues & check availability | Firestore Rules (writes blocked) + `manageVenue` callable |
| **Cast Management** | View roster, assign roles & understudies | View cast assignments | Firestore Rules (`isDirector()`) & UI gating |
| **Master Schedule** | Full schedule across all productions & venues | Filtered schedule of assigned rehearsals/auditions | UI role filtering & client queries |
| **Notifications** | View/manage notifications | View personal notifications, mark as read | Firestore Rules (`isOwner(resource.data.userId)`) |

### Database Collection Structure

| Collection | Document ID Pattern | Key Fields | Read Access | Write Access |
|---|---|---|---|---|
| `users` | `users/{uid}` | `email`, `displayName`, `role` (`'Director'` or `'Cast Member'`), `createdAt` | Authenticated users | Owner (self) |
| `productions` | `productions/{productionId}` | `title`, `description`, `directorId`, `startDate`, `endDate`, `status` | Authenticated users | Director only |
| `auditions` | `auditions/{auditionId}` | `productionId`, `venueId`, `venueName`, `startDateTime`, `endDateTime`, `roles`, `status` | Authenticated users | Callable (`saveVenueBooking`) |
| `rehearsals` | `rehearsals/{rehearsalId}` | `productionId`, `venueId`, `venueName`, `startDateTime`, `endDateTime`, `requiredRoles`, `notes` | Authenticated users | Callable (`saveVenueBooking`) |
| `venues` | `venues/{venueId}` | `name`, `capacity`, `location`, `aliases`, `isDeleted`, `updatedAt` | Authenticated users | Callable (`manageVenue`) |
| `cast_members` | `cast_members/{uid}` | `name`, `email`, `phoneNumber`, `bio`, `active` | Authenticated users | Director or self |
| `cast_assignments` | `cast_assignments/{assignmentId}` | `productionId`, `actorId`, `actorName`, `characterRole`, `isUnderstudy` | Authenticated users | Director only |
| `notifications` | `notifications/{notificationId}` | `userId`, `title`, `message`, `type`, `isRead`, `timestamp` | Document owner | Backend / Director / Owner read flag |

### Firebase data paths

| App area | Firestore source and write path |
|---|---|
| Productions | `productions/{productionId}`; Director-only client writes under `client/firestore.rules`. |
| Auditions | `auditions/{auditionId}`; reads from Firestore and mutations through `saveVenueBooking`. New bookings persist `venueId` when the selected venue resolves in the directory. |
| Rehearsals | `rehearsals/{rehearsalId}`; reads from Firestore and mutations through `saveVenueBooking`; new bookings persist the stable venue ID and display name. |
| Venues | `venues/{venueId}`; reads from Firestore and create/rename/soft-delete through Director-authorized `manageVenue`. `aliases` retains prior names. |
| Cast and roles | `cast_assignments/{assignmentId}` and `cast_members/{uid}`; Director writes are protected by rules. Profiles live in `users/{uid}`. |
| Master schedule | Derived from audition, rehearsal, production, and cast-assignment data; there is no separate schedule collection. |
| In-app notifications | `notifications/{notificationId}`; booking and assignment changes create notifications, and clients read/update read state under notification rules. |
| Dashboard | Counts are loaded from productions, rehearsals, auditions, and venues; upcoming rehearsals come from `rehearsals`. |

Firebase connectivity and collection contents have not been verified against the
configured live project in this environment. The Firebase CLI session used for
the read-only project check had expired credentials. Reauthenticate with
`firebase login --reauth`, select the intended project explicitly, and verify
the project ID and user access before checking live data. This repository does
not auto-seed any Firebase project. For safe demos, run the Firebase emulators
with a `demo-*` project ID and invoke the explicit repeatable seed command
below; never point a demo seed at a production project. Seeded bookings use the
booking callable, and ordinary Firestore seed writes use emulator-issued
authenticated tokens and the configured security rules.

To seed local demo records, use throwaway passwords and start all three
emulators. In PowerShell, from the repository root:

```powershell
$env:DEMO_DIRECTOR_PASSWORD = 'local-only-demo-password-1'
$env:DEMO_CAST_PASSWORD = 'local-only-demo-password-2'
firebase emulators:exec --project demo-theatre-data --only auth,firestore,functions "npm --prefix functions run seed:demo"
```

The script refuses a non-`demo-*` project or any non-loopback emulator host.
It uses stable `[DEMO]` record IDs and create-only writes, so reruns preserve
existing data. It creates the Director profile with the Admin SDK only inside
the emulators because Director roles are provisioned administratively; no
service-account key is embedded or needed. Audition/rehearsal bookings go
through `saveVenueBooking`, and venue creation goes through `manageVenue`.
These demo accounts and passwords exist only in the emulator; do not reuse
them for a Firebase project or real account.

The booking transaction, callable integration, and rules tests require local
Firebase emulators. A passing Functions unit suite alone does not verify
transaction behavior, concurrent booking safety, callable authorization, or
Firestore rules. Flutter widget tests use fakes for service behavior and do not
verify live Firebase connectivity.

### Running the Flutter Client with Local Emulators

To run the Flutter app connected to local Firebase emulators (Auth on port 9099, Firestore on port 8085, and Cloud Functions on port 5001):

1. Start Firebase Emulators:
   ```sh
   firebase emulators:start --only auth,firestore,functions
   ```

2. Run the Flutter web or desktop/mobile application with the emulator flag enabled:
   ```sh
   cd client
   flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
   ```
   *(For Android emulators, set `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`)*

### Deployment Prerequisites & Known Limitations

> [!WARNING]
> **Cloud Functions API Requirement (Known Issue Resolution)**:
> In the live Google Cloud / Firebase project `theatre-production-manager`, the Cloud Functions API previously returned `403 SERVICE_DISABLED`. Callable functions (`manageVenue` and `saveVenueBooking`) will fail with `internal [0]` in production if invoked while this API remains disabled.
>
> Before live deployment, the project administrator must:
> 1. Upgrade the Firebase project to the **Blaze (pay-as-you-go)** plan.
> 2. Enable the **Cloud Functions v2 API** (`cloudfunctions.googleapis.com`), **Cloud Build API** (`cloudbuild.googleapis.com`), and **Artifact Registry API** (`artifactregistry.googleapis.com`) in the Google Cloud Console.
> 3. Verify that the App Engine / Cloud Functions service account has `roles/datastore.user` and `roles/cloudfunctions.invoker`.
> 4. Deploy rules and callables atomically:
>    ```sh
>    firebase deploy --only firestore:rules,functions
>    ```

## Development Workflow

The project follows a branch-based Git workflow:

1. Create a personal branch from `main` (e.g. `feature/<topic>` or `docs/<topic>`).
2. Make and verify changes (running `flutter test` and security rule checks).
3. Push the branch to the remote repository.
4. Open a Pull Request targeting `main`.
5. A teammate reviews the Pull Request.
6. After review and approval, changes are merged into `main`.
