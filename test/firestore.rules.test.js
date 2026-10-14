const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'theatre-production-manager';
const RULES_PATH = path.resolve(__dirname, '../client/firestore.rules');

describe('Firestore Security Rules', function () {
  this.timeout(15000);

  let testEnv;

  const DIRECTOR_UID = 'director-user-1';
  const CAST_UID = 'cast-user-1';
  const NO_PROFILE_UID = 'user-without-profile';
  const OTHER_UID = 'other-user-2';

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: '127.0.0.1',
        port: 8080,
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
});
