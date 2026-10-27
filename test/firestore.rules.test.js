const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'demo-venue-rules-tests';
const RULES_PATH = path.resolve(__dirname, '../client/firestore.rules');

describe('Firestore Security Rules', function () {
  this.timeout(15000);

  let testEnv;

  const DIRECTOR_UID = 'director-user-1';
  const CAST_UID = 'cast-user-1';
  const NO_PROFILE_UID = 'user-without-profile';
  const OTHER_UID = 'other-user-2';

  before(async () => {
    const hostPort = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8085';
    const [host, portStr] = hostPort.split(':');
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: host || '127.0.0.1',
        port: portStr ? parseInt(portStr, 10) : 8085,
        rules: fs.readFileSync(RULES_PATH, 'utf8'),
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // Seed existing fixtures bypassing rules
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(DIRECTOR_UID).set({
        name: 'Alice Director',
        email: 'alice@theatre.org',
        role: 'Director',
      });
      await db.collection('users').doc(CAST_UID).set({
        name: 'Bob Actor',
        email: 'bob@theatre.org',
        role: 'Cast Member',
      });
      await db.collection('productions').doc('prod-existing').set({
        title: 'Romeo and Juliet',
        status: 'Planning',
      });
      await db.collection('rehearsals').doc('reh-existing').set({
        productionId: 'prod-existing',
        venueId: 'main-stage',
        venue: 'Main Stage',
        startTime: new Date('2026-11-01T10:00:00Z'),
        endTime: new Date('2026-11-01T12:00:00Z'),
        creatorUid: DIRECTOR_UID,
      });
      await db.collection('auditions').doc('aud-existing').set({
        productionId: 'prod-existing',
        title: 'Lead Roles Audition',
        venue: 'Studio A',
        startTime: new Date('2026-11-02T10:00:00Z'),
        endTime: new Date('2026-11-02T14:00:00Z'),
        status: 'Scheduled',
        creatorUid: DIRECTOR_UID,
      });
      await db.collection('venues').doc('venue-existing').set({
        name: 'Main Auditorium',
        address: '100 Theatre Row',
        capacity: 250,
      });
      await db.collection('cast_assignments').doc('cast-existing').set({
        productionId: 'prod-existing',
        userId: CAST_UID,
        characterRole: 'Romeo',
        actorName: 'Bob Actor',
        status: 'Assigned',
      });
      await db.collection('notifications').doc('notif-existing').set({
        recipientUid: CAST_UID,
        title: 'Rehearsal Updated',
        message: 'Rehearsal moved to 11am',
        read: false,
      });
      await db.collection('notifications').doc('notif-private-other').set({
        recipientUid: OTHER_UID,
        title: 'Private rehearsal note',
        message: 'Only the assigned recipient should see this',
        read: false,
      });
    });
  });

  describe('1. Unauthenticated users access control', () => {
    it('denies unauthenticated read access to productions', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('productions').doc('prod-existing').get());
      await assertFails(db.collection('productions').get());
    });

    it('denies unauthenticated write access to productions', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        db.collection('productions').doc('prod-new').set({
          title: 'Macbeth',
          status: 'Planning',
        })
      );
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          status: 'Completed',
        })
      );
      await assertFails(db.collection('productions').doc('prod-existing').delete());
    });

    it('denies unauthenticated read access to user profiles', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('users').doc(DIRECTOR_UID).get());
      await assertFails(db.collection('users').doc(CAST_UID).get());
    });

    it('denies unauthenticated write access to user profiles', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        db.collection('users').doc('anon-user').set({
          name: 'Anon',
          email: 'anon@theatre.org',
          role: 'Cast Member',
        })
      );
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          name: 'Hacked Name',
        })
      );
      await assertFails(db.collection('users').doc(CAST_UID).delete());
    });
  });

  describe('2. Authenticated users read access to productions', () => {
    it('allows authenticated Director to read productions', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(db.collection('productions').doc('prod-existing').get());
      await assertSucceeds(db.collection('productions').get());
    });

    it('allows authenticated Cast Member to read productions', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(db.collection('productions').doc('prod-existing').get());
      await assertSucceeds(db.collection('productions').get());
    });

    it('allows authenticated user without a profile to read productions', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertSucceeds(db.collection('productions').doc('prod-existing').get());
      await assertSucceeds(db.collection('productions').get());
    });
  });

  describe('3. Cast Members production management restrictions', () => {
    it('denies Cast Member from creating productions', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-by-cast').set({
          title: 'A Midsummer Night\'s Dream',
          status: 'Planning',
        })
      );
    });

    it('denies Cast Member from updating productions', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          status: 'In Rehearsal',
        })
      );
    });

    it('denies Cast Member from deleting productions', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(db.collection('productions').doc('prod-existing').delete());
    });
  });

  describe('4. Director production management capabilities', () => {
    it('allows Director to create a production with valid data', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(
        db.collection('productions').doc('prod-valid-1').set({
          title: 'Hamlet',
          status: 'Planning',
        })
      );
      await assertSucceeds(
        db.collection('productions').doc('prod-valid-2').set({
          title: 'Othello',
          status: 'In Rehearsal',
        })
      );
      await assertSucceeds(
        db.collection('productions').doc('prod-valid-3').set({
          title: 'King Lear',
          status: 'Completed',
        })
      );
    });

    it('allows Director to update a production with valid data', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(
        db.collection('productions').doc('prod-existing').update({
          title: 'Romeo and Juliet (Extended Cut)',
          status: 'In Rehearsal',
        })
      );
    });

    it('allows Director to update only the status with valid data', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(
        db.collection('productions').doc('prod-existing').update({
          status: 'Completed',
        })
      );
    });

    it('allows Director to delete a production', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(db.collection('productions').doc('prod-existing').delete());
    });
  });

  describe('5. Users without profile cannot act as Directors', () => {
    it('denies user without a profile from creating productions', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-no-profile').set({
          title: 'The Tempest',
          status: 'Planning',
        })
      );
    });

    it('denies user without a profile from updating productions', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          title: 'Modified Title',
        })
      );
    });

    it('denies user without a profile from deleting productions', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertFails(db.collection('productions').doc('prod-existing').delete());
    });
  });

  describe('6. Public registration rules and role elevation prevention', () => {
    it('allows public registration with role "Cast Member" for own UID', async () => {
      const newUid = 'new-user-1';
      const db = testEnv.authenticatedContext(newUid).firestore();
      await assertSucceeds(
        db.collection('users').doc(newUid).set({
          name: 'Charlie Chaplin',
          email: 'charlie@theatre.org',
          role: 'Cast Member',
        })
      );
    });

    it('denies public registration attempting to claim role "Director"', async () => {
      const attackerUid = 'attacker-director';
      const db = testEnv.authenticatedContext(attackerUid).firestore();
      await assertFails(
        db.collection('users').doc(attackerUid).set({
          name: 'Mallory Malicious',
          email: 'mallory@theatre.org',
          role: 'Director',
        })
      );
    });

    it('denies public registration with any unauthorized role', async () => {
      const attackerUid = 'attacker-admin';
      const db = testEnv.authenticatedContext(attackerUid).firestore();
      await assertFails(
        db.collection('users').doc(attackerUid).set({
          name: 'Mallory Malicious',
          email: 'mallory@theatre.org',
          role: 'Admin',
        })
      );
    });

    it('denies user from creating a profile for another UID', async () => {
      const callerUid = 'caller-user-id';
      const victimUid = 'victim-user-id';
      const db = testEnv.authenticatedContext(callerUid).firestore();
      await assertFails(
        db.collection('users').doc(victimUid).set({
          name: 'Fake Profile',
          email: 'fake@theatre.org',
          role: 'Cast Member',
        })
      );
    });

    it('denies public registration with missing or non-string name or email', async () => {
      const newUid1 = 'new-user-missing-fields';
      const db1 = testEnv.authenticatedContext(newUid1).firestore();
      await assertFails(
        db1.collection('users').doc(newUid1).set({
          role: 'Cast Member',
          email: 'test@theatre.org',
        })
      );
      const newUid2 = 'new-user-bad-types';
      const db2 = testEnv.authenticatedContext(newUid2).firestore();
      await assertFails(
        db2.collection('users').doc(newUid2).set({
          name: 12345,
          role: 'Cast Member',
          email: 'test@theatre.org',
        })
      );
    });
  });

  describe('6b. Authenticated users profile read access (own profile only)', () => {
    it('allows authenticated user to read their own profile', async () => {
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(castDb.collection('users').doc(CAST_UID).get());

      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(directorDb.collection('users').doc(DIRECTOR_UID).get());
    });

    it('denies authenticated user from reading another user\'s profile', async () => {
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(castDb.collection('users').doc(DIRECTOR_UID).get());

      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(directorDb.collection('users').doc(CAST_UID).get());
    });

    it('denies authenticated user from listing all user profiles', async () => {
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(castDb.collection('users').get());

      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(directorDb.collection('users').get());
    });
  });

  describe('7. User profile protection: role immutability and deletion prevention', () => {
    it('denies user from changing their own role from Cast Member to Director', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          role: 'Director',
        })
      );
    });

    it('denies Director from changing their own role', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('users').doc(DIRECTOR_UID).update({
          role: 'Cast Member',
        })
      );
    });

    it('denies Cast Member from deleting their profile', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(db.collection('users').doc(CAST_UID).delete());
    });

    it('denies Director from deleting their own or others profiles', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(db.collection('users').doc(DIRECTOR_UID).delete());
      await assertFails(db.collection('users').doc(CAST_UID).delete());
    });
  });

  describe('8. User profile field restrictions', () => {
    it('allows user to update their own permitted name and email fields', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(
        db.collection('users').doc(CAST_UID).update({
          name: 'Robert Actor',
          email: 'robert@theatre.org',
        })
      );
    });

    it('allows user to update only their name', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(
        db.collection('users').doc(CAST_UID).update({
          name: 'Bobby Actor',
        })
      );
    });

    it('allows user to update only their email', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(
        db.collection('users').doc(CAST_UID).update({
          email: 'bobby.actor@theatre.org',
        })
      );
    });

    it('denies updating protected fields outside name and email', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          isAdmin: true,
        })
      );
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          permissions: ['all'],
        })
      );
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          uid: 'hacked-uid',
        })
      );
    });

    it('denies user from updating another user\'s profile', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('users').doc(DIRECTOR_UID).update({
          name: 'Tampered Director',
        })
      );
    });

    it('denies profile update with non-string name or email', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          name: 12345,
        })
      );
      await assertFails(
        db.collection('users').doc(CAST_UID).update({
          email: ['not', 'a', 'string'],
        })
      );
    });
  });

  describe('9. Production schema validation: title and status', () => {
    it('denies creating production with empty title', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-empty-title').set({
          title: '',
          status: 'Planning',
        })
      );
    });

    it('denies creating production with non-string title', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-number-title').set({
          title: 404,
          status: 'Planning',
        })
      );
      await assertFails(
        db.collection('productions').doc('prod-null-title').set({
          title: null,
          status: 'Planning',
        })
      );
    });

    it('denies creating production with invalid status', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      const invalidStatuses = ['Draft', 'Cancelled', 'Archived', 'Pending', 'Active', ''];
      for (const invalidStatus of invalidStatuses) {
        await assertFails(
          db.collection('productions').doc(`prod-invalid-${invalidStatus || 'empty'}`).set({
            title: 'Valid Title',
            status: invalidStatus,
          })
        );
      }
    });

    it('denies creating production missing title or status', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-no-title').set({
          status: 'Planning',
        })
      );
      await assertFails(
        db.collection('productions').doc('prod-no-status').set({
          title: 'Title Without Status',
        })
      );
    });

    it('denies updating production to empty title', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          title: '',
        })
      );
    });

    it('denies updating production to invalid status', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          status: 'Cancelled',
        })
      );
      await assertFails(
        db.collection('productions').doc('prod-existing').update({
          status: 'Unknown',
        })
      );
    });
  });

  describe('10. Rehearsal reads and trusted booking writes', () => {
    it('denies unauthenticated read and write access to rehearsals', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('rehearsals').doc('reh-existing').get());
      await assertFails(db.collection('rehearsals').get());
      await assertFails(
        db.collection('rehearsals').doc('reh-anon').set({
          productionId: 'prod-existing',
          venueId: 'main-stage',
          startTime: new Date('2026-11-02T10:00:00Z'),
          endTime: new Date('2026-11-02T12:00:00Z'),
        })
      );
    });

    it('allows authenticated users to read rehearsals', async () => {
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(castDb.collection('rehearsals').doc('reh-existing').get());
      await assertSucceeds(castDb.collection('rehearsals').get());

      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(directorDb.collection('rehearsals').doc('reh-existing').get());
      await assertSucceeds(directorDb.collection('rehearsals').get());
    });

    it('denies Cast Member from creating, updating, or deleting rehearsals', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('rehearsals').doc('reh-cast').set({
          productionId: 'prod-existing',
          venueId: 'main-stage',
          startTime: new Date('2026-11-02T10:00:00Z'),
          endTime: new Date('2026-11-02T12:00:00Z'),
        })
      );
      await assertFails(
        db.collection('rehearsals').doc('reh-existing').update({
          venueId: 'stage-2',
        })
      );
      await assertFails(db.collection('rehearsals').doc('reh-existing').delete());
    });

    it('denies direct booking writes even for Directors; callable backend owns writes', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('rehearsals').doc('reh-valid').set({
          productionId: 'prod-existing',
          venueId: 'stage-main',
          startTime: new Date('2026-11-05T14:00:00Z'),
          endTime: new Date('2026-11-05T17:00:00Z'),
        })
      );
      await assertFails(
        db.collection('rehearsals').doc('reh-existing').update({
          endTime: new Date('2026-11-01T13:00:00Z'),
        })
      );
      await assertFails(db.collection('rehearsals').doc('reh-existing').delete());
    });

    it('denies rehearsal creation with invalid time range (endTime <= startTime)', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      // endTime before startTime
      await assertFails(
        db.collection('rehearsals').doc('reh-inv-time').set({
          productionId: 'prod-existing',
          venueId: 'stage-main',
          startTime: new Date('2026-11-05T17:00:00Z'),
          endTime: new Date('2026-11-05T14:00:00Z'),
        })
      );
      // endTime equal to startTime
      await assertFails(
        db.collection('rehearsals').doc('reh-zero-dur').set({
          productionId: 'prod-existing',
          venueId: 'stage-main',
          startTime: new Date('2026-11-05T14:00:00Z'),
          endTime: new Date('2026-11-05T14:00:00Z'),
        })
      );
    });

    it('denies rehearsal creation with missing or empty productionId or venue', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      // empty productionId
      await assertFails(
        db.collection('rehearsals').doc('reh-no-prod').set({
          productionId: '',
          venueId: 'stage-main',
          startTime: new Date('2026-11-05T14:00:00Z'),
          endTime: new Date('2026-11-05T17:00:00Z'),
        })
      );
      // missing venue
      await assertFails(
        db.collection('rehearsals').doc('reh-no-venue').set({
          productionId: 'prod-existing',
          startTime: new Date('2026-11-05T14:00:00Z'),
          endTime: new Date('2026-11-05T17:00:00Z'),
        })
      );
    });

    it('denies user without profile from managing rehearsals', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertFails(
        db.collection('rehearsals').doc('reh-no-prof').set({
          productionId: 'prod-existing',
          venueId: 'stage-main',
          startTime: new Date('2026-11-05T14:00:00Z'),
          endTime: new Date('2026-11-05T17:00:00Z'),
        })
      );
      await assertFails(db.collection('rehearsals').doc('reh-existing').delete());
    });
  });
  describe('11. Audition reads and trusted booking writes', () => {
    it('denies unauthenticated read and write access to auditions', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('auditions').doc('aud-existing').get());
      await assertFails(db.collection('auditions').get());
      await assertFails(
        db.collection('auditions').doc('aud-unauth').set({
          productionId: 'prod-existing',
          title: 'Unauth Call',
          venue: 'Main Stage',
          startTime: new Date('2026-11-05T10:00:00Z'),
          endTime: new Date('2026-11-05T14:00:00Z'),
          status: 'Scheduled',
          creatorUid: 'unauth-uid',
        })
      );
    });

    it('allows authenticated users to read auditions', async () => {
      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      const noProfileDb = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();

      await assertSucceeds(directorDb.collection('auditions').doc('aud-existing').get());
      await assertSucceeds(castDb.collection('auditions').doc('aud-existing').get());
      await assertSucceeds(noProfileDb.collection('auditions').doc('aud-existing').get());
    });

    it('denies Cast Member from creating, updating, or deleting auditions', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-cast-new').set({
          productionId: 'prod-existing',
          title: 'Cast Audition',
          venue: 'Studio B',
          startTime: new Date('2026-11-05T10:00:00Z'),
          endTime: new Date('2026-11-05T14:00:00Z'),
          status: 'Scheduled',
          creatorUid: CAST_UID,
        })
      );
      await assertFails(
        db.collection('auditions').doc('aud-existing').update({
          title: 'Tampered Title',
        })
      );
      await assertFails(db.collection('auditions').doc('aud-existing').delete());
    });

    it('denies direct booking writes even for Directors; callable backend owns writes', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-dir-new').set({
          productionId: 'prod-existing',
          title: 'Director Audition Call',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'Scheduled',
          creatorUid: DIRECTOR_UID,
        })
      );
      await assertFails(
        db.collection('auditions').doc('aud-existing').update({
          status: 'Cancelled',
        })
      );
      await assertFails(db.collection('auditions').doc('aud-existing').delete());
    });

    it('denies audition creation with invalid time range (endTime <= startTime)', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-inv-time').set({
          productionId: 'prod-existing',
          title: 'Invalid Time Audition',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T14:00:00Z'),
          endTime: new Date('2026-11-10T10:00:00Z'),
          status: 'Scheduled',
          creatorUid: DIRECTOR_UID,
        })
      );
      await assertFails(
        db.collection('auditions').doc('aud-zero-dur').set({
          productionId: 'prod-existing',
          title: 'Zero Duration Audition',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T10:00:00Z'),
          status: 'Scheduled',
          creatorUid: DIRECTOR_UID,
        })
      );
    });

    it('denies audition creation with missing or empty productionId, title, or venue', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-no-title').set({
          productionId: 'prod-existing',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'Scheduled',
        })
      );
      await assertFails(
        db.collection('auditions').doc('aud-empty-venue').set({
          productionId: 'prod-existing',
          title: 'Audition',
          venue: '',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'Scheduled',
        })
      );
      await assertFails(
        db.collection('auditions').doc('aud-empty-prod').set({
          productionId: '',
          title: 'Audition',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'Scheduled',
        })
      );
    });

    it('denies audition with invalid status', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-inv-status').set({
          productionId: 'prod-existing',
          title: 'Audition',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'PendingReview',
          creatorUid: DIRECTOR_UID,
        })
      );
    });

    it('denies user without profile from managing auditions', async () => {
      const db = testEnv.authenticatedContext(NO_PROFILE_UID).firestore();
      await assertFails(
        db.collection('auditions').doc('aud-no-prof').set({
          productionId: 'prod-existing',
          title: 'Audition',
          venue: 'Studio A',
          startTime: new Date('2026-11-10T10:00:00Z'),
          endTime: new Date('2026-11-10T14:00:00Z'),
          status: 'Scheduled',
          creatorUid: NO_PROFILE_UID,
        })
      );
      await assertFails(db.collection('auditions').doc('aud-existing').delete());
    });
  });

  describe('12. Venues access control and validation', () => {
    it('denies unauthenticated read and write access to venues', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('venues').doc('venue-existing').get());
      await assertFails(db.collection('venues').get());
      await assertFails(
        db.collection('venues').doc('venue-new').set({
          name: 'Black Box Theatre',
          capacity: 80,
        })
      );
    });

    it('allows authenticated users to read venues', async () => {
      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(directorDb.collection('venues').doc('venue-existing').get());
      await assertSucceeds(directorDb.collection('venues').get());
      await assertSucceeds(castDb.collection('venues').doc('venue-existing').get());
      await assertSucceeds(castDb.collection('venues').get());
    });

    it('denies Cast Member from creating, updating, or deleting venues', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('venues').doc('venue-new').set({
          name: 'Cast Created Venue',
          capacity: 50,
        })
      );
      await assertFails(
        db.collection('venues').doc('venue-existing').update({
          capacity: 300,
        })
      );
      await assertFails(db.collection('venues').doc('venue-existing').delete());
    });

    it('denies Director from directly creating, updating, or deleting venues', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('venues').doc('venue-director').set({
          name: 'Rehearsal Hall C',
          capacity: 60,
          address: '42 Main Street',
        })
      );
      await assertFails(
        db.collection('venues').doc('venue-director').update({
          capacity: 75,
        })
      );
      await assertFails(db.collection('venues').doc('venue-director').delete());
    });

    it('denies direct venue writes regardless of payload validity', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(db.collection('venues').doc('venue-zero-cap').set({ name: 'Valid Name', capacity: 0 }));
      await assertFails(db.collection('venues').doc('venue-neg-cap').set({ name: 'Valid Name', capacity: -10 }));
      await assertFails(db.collection('venues').doc('venue-empty-name').set({ name: '', capacity: 100 }));
    });
  });

  describe('13. Cast assignments access control and validation', () => {
    it('denies unauthenticated read and write access to cast assignments', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('cast_assignments').doc('cast-existing').get());
      await assertFails(db.collection('cast_assignments').get());
      await assertFails(
        db.collection('cast_assignments').doc('cast-new').set({
          productionId: 'prod-existing',
          userId: CAST_UID,
          characterRole: 'Juliet',
          actorName: 'Jane Actress',
          status: 'Assigned',
        })
      );
    });

    it('allows authenticated users to read cast assignments', async () => {
      const directorDb = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(directorDb.collection('cast_assignments').doc('cast-existing').get());
      await assertSucceeds(directorDb.collection('cast_assignments').get());
      await assertSucceeds(castDb.collection('cast_assignments').doc('cast-existing').get());
      await assertSucceeds(castDb.collection('cast_assignments').get());
    });

    it('denies Cast Member from creating, updating, or deleting cast assignments', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('cast_assignments').doc('cast-member-hack').set({
          productionId: 'prod-existing',
          userId: CAST_UID,
          characterRole: 'Hamlet',
          actorName: 'Bob Actor',
          status: 'Assigned',
        })
      );
      await assertFails(
        db.collection('cast_assignments').doc('cast-existing').update({
          characterRole: 'Mercutio',
        })
      );
      await assertFails(db.collection('cast_assignments').doc('cast-existing').delete());
    });

    it('allows Director to create, update, and delete cast assignments with valid data', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(
        db.collection('cast_assignments').doc('cast-dir-create').set({
          productionId: 'prod-existing',
          userId: CAST_UID,
          characterRole: 'Tybalt',
          actorName: 'Charlie Actor',
          status: 'Confirmed',
        })
      );
      await assertSucceeds(
        db.collection('cast_assignments').doc('cast-dir-create').update({
          status: 'Understudy',
        })
      );
      await assertSucceeds(db.collection('cast_assignments').doc('cast-dir-create').delete());
    });

    it('denies cast assignment with empty role, production, or actor name', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(
        db.collection('cast_assignments').doc('cast-empty-role').set({
          productionId: 'prod-existing',
          userId: CAST_UID,
          characterRole: '',
          actorName: 'Valid Actor',
          status: 'Assigned',
        })
      );
      await assertFails(
        db.collection('cast_assignments').doc('cast-empty-prod').set({
          productionId: '',
          userId: CAST_UID,
          characterRole: 'Valid Role',
          actorName: 'Valid Actor',
          status: 'Assigned',
        })
      );
      await assertFails(
        db.collection('cast_assignments').doc('cast-invalid-status').set({
          productionId: 'prod-existing',
          userId: CAST_UID,
          characterRole: 'Valid Role',
          actorName: 'Valid Actor',
          status: 'UnknownStatus',
        })
      );
    });
  });

  describe('14. Notifications access control and update', () => {
    it('denies unauthenticated read and write access to notifications', async () => {
      const db = testEnv.unauthenticatedContext().firestore();
      await assertFails(db.collection('notifications').doc('notif-existing').get());
      await assertFails(db.collection('notifications').get());
      await assertFails(
        db.collection('notifications').doc('notif-new').set({
          title: 'Alert',
          message: 'Message',
          read: false,
        })
      );
    });

    it('allows users to read their own and global notifications, but not another user\'s', async () => {
      const castDb = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(castDb.collection('notifications').doc('notif-existing').get());
      await assertFails(
        castDb.collection('notifications').doc('notif-private-other').get()
      );
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('notifications').doc('notif-global').set({
          recipientUid: 'all',
          title: 'Announcement',
          message: 'Everyone can see this',
          read: false,
          readBy: [],
        });
      });
      await assertSucceeds(castDb.collection('notifications').doc('notif-global').get());
      await assertSucceeds(
        castDb.collection('notifications')
          .where('recipientUid', 'in', [CAST_UID, 'all']).get()
      );
      await assertSucceeds(
        castDb.collection('notifications').doc('notif-global').update({
          readBy: [CAST_UID],
        })
      );
      await assertFails(
        castDb.collection('notifications').doc('notif-global').update({
          readBy: [CAST_UID, OTHER_UID],
        })
      );
    });

    it('allows Director to create and delete notifications', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(
        db.collection('notifications').doc('notif-dir').set({
          recipientUid: 'all',
          title: 'All-Hands Call',
          message: 'Meeting at 6pm',
          read: false,
        })
      );
      await assertSucceeds(db.collection('notifications').doc('notif-dir').delete());
    });

    it('allows user to update read status on notifications', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(
        db.collection('notifications').doc('notif-existing').update({
          read: true,
        })
      );
    });

    it('denies a user from changing another recipient\'s notification read state', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('notifications').doc('notif-private-other').update({read: true})
      );
    });

    it('denies user from altering notification title or message', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertFails(
        db.collection('notifications').doc('notif-existing').update({
          title: 'Tampered Title',
        })
      );
      await assertFails(
        db.collection('notifications').doc('notif-existing').update({
          message: 'Tampered Message',
        })
      );
    });
  });

  describe('15. Cast member directory privacy', () => {
    it('allows a cast member to read only their own directory record', async () => {
      const db = testEnv.authenticatedContext(CAST_UID).firestore();
      await assertSucceeds(db.collection('cast_members').doc(CAST_UID).get());
      await assertFails(db.collection('cast_members').doc(OTHER_UID).get());
      await assertFails(db.collection('cast_members').get());
    });

    it('allows directors to read the cast member directory', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertSucceeds(db.collection('cast_members').get());
    });
  });

  describe('16. Venue mutations use the trusted management callable', () => {
    it('denies direct venue create, update, and delete even for Directors', async () => {
      const db = testEnv.authenticatedContext(DIRECTOR_UID).firestore();
      await assertFails(db.collection('venues').doc('venue-direct-create').set({
        name: 'New Hall', capacity: 100,
      }));
      await assertFails(db.collection('venues').doc('venue-existing').update({
        name: 'Renamed Hall',
      }));
      await assertFails(db.collection('venues').doc('venue-existing').delete());
    });
  });
});
