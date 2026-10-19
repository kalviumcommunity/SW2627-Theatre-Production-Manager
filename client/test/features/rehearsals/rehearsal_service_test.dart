// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/rehearsals/exceptions/rehearsal_exceptions.dart';
import 'package:client/features/rehearsals/models/rehearsal_model.dart';
import 'package:client/features/rehearsals/services/rehearsal_service.dart';

// --- Fakes for Firestore testing ---

class FakeFirestore extends Fake implements FirebaseFirestore {
  final Map<String, FakeCollectionReference> _collections = {};

  FakeCollectionReference getCollection(String path) {
    return _collections.putIfAbsent(path, () => FakeCollectionReference(path));
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return getCollection(collectionPath);
  }
}

class FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final String collectionPath;
  final Map<String, Map<String, dynamic>> docs = {};
  bool shouldThrowOnGet = false;
  bool shouldThrowOnAdd = false;
  Exception? errorToThrow;
  StreamController<QuerySnapshot<Map<String, dynamic>>>? streamController;

  FakeCollectionReference(this.collectionPath);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (shouldThrowOnGet) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to fetch collection');
    }
    return FakeQuerySnapshot(
      docs.entries
          .map((e) => FakeQueryDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
          .toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (streamController != null) {
      return streamController!.stream;
    }
    return Stream.value(
      FakeQuerySnapshot(
        docs.entries
            .map((e) => FakeQueryDocumentSnapshot(e.key, Map<String, dynamic>.from(e.value)))
            .toList(),
      ),
    );
  }

  final Map<String, FakeDocumentReference> _docRefs = {};

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docId = path ?? 'auto-id-${docs.length + 1}';
    return _docRefs.putIfAbsent(docId, () => FakeDocumentReference(this, docId));
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) async {
    if (shouldThrowOnAdd) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to add document');
    }
    final docId = 'rehearsal-doc-id-${docs.length + 1}';
    docs[docId] = Map<String, dynamic>.from(data);
    return FakeDocumentReference(this, docId);
  }
}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FakeCollectionReference parentCollection;
  @override
  final String id;
  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnDelete = false;
  bool shouldThrowOnGet = false;
  Exception? errorToThrow;

  FakeDocumentReference(this.parentCollection, this.id);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (shouldThrowOnGet) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to get document');
    }
    final data = parentCollection.docs[id];
    return FakeDocumentSnapshot(id, data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (shouldThrowOnUpdate) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to update document');
    }
    if (!parentCollection.docs.containsKey(id)) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'not-found',
        message: 'No document to update: $id',
      );
    }
    final stringKeyData = data.map((key, value) => MapEntry(key.toString(), value));
    parentCollection.docs[id]!.addAll(stringKeyData);
  }

  @override
  Future<void> delete() async {
    if (shouldThrowOnDelete) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to delete document');
    }
    parentCollection.docs.remove(id);
  }
}

class FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  FakeQuerySnapshot(this.docs);
}

class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  FakeQueryDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;
}

// --- Main test suite ---

void main() {
  late FakeFirestore fakeFirestore;
  late FakeCollectionReference rehearsalsCollection;
  late FakeCollectionReference productionsCollection;
  late RehearsalService service;

  setUp(() {
    fakeFirestore = FakeFirestore();
    rehearsalsCollection = fakeFirestore.getCollection('rehearsals');
    productionsCollection = fakeFirestore.getCollection('productions');
    service = RehearsalService(firestore: fakeFirestore);

    // Seed a valid existing production
    productionsCollection.docs['prod-valid'] = {
      'title': 'The Phantom of the Opera',
      'status': 'In Rehearsal',
    };
  });

  group('Rehearsal Model', () {
    test('instantiates with all fields and computes duration / isValidTimeRange', () {
      final start = DateTime(2026, 11, 1, 14, 0);
      final end = DateTime(2026, 11, 1, 17, 0);
      final created = DateTime(2026, 10, 20);

      final rehearsal = Rehearsal(
        id: 'reh-1',
        productionId: 'prod-valid',
        title: 'Act 1 Scene 2 Run-Through',
        venueId: 'main-stage',
        venueName: 'Main Stage Auditorium',
        startTime: start,
        endTime: end,
        creatorUid: 'director-uid',
        notes: 'Bring full costumes',
        createdAt: created,
      );

      expect(rehearsal.id, 'reh-1');
      expect(rehearsal.productionId, 'prod-valid');
      expect(rehearsal.title, 'Act 1 Scene 2 Run-Through');
      expect(rehearsal.venueId, 'main-stage');
      expect(rehearsal.venueName, 'Main Stage Auditorium');
      expect(rehearsal.venue, 'Main Stage Auditorium');
      expect(rehearsal.startTime, start);
      expect(rehearsal.endTime, end);
      expect(rehearsal.creatorUid, 'director-uid');
      expect(rehearsal.notes, 'Bring full costumes');
      expect(rehearsal.createdAt, created);
      expect(rehearsal.isValidTimeRange, isTrue);
      expect(rehearsal.duration, const Duration(hours: 3));
    });

    test('prefers venueName if present, falls back to venueId for venue getter', () {
      final r1 = Rehearsal(
        id: 'r1',
        productionId: 'p1',
        venueId: 'room-101',
        venueName: 'Studio 101',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'uid-1',
      );
      expect(r1.venue, 'Studio 101');

      final r2 = Rehearsal(
        id: 'r2',
        productionId: 'p1',
        venueId: 'room-102',
        venueName: '',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'uid-1',
      );
      expect(r2.venue, 'room-102');
    });

    test('serializes toMap and deserializes fromMap with Timestamp and String', () {
      final start = DateTime(2026, 11, 10, 9, 30);
      final end = DateTime(2026, 11, 10, 12, 0);

      final original = Rehearsal(
        id: 'reh-serialize',
        productionId: 'prod-valid',
        title: 'Vocal Warmups',
        venueId: 'rehearsal-hall-a',
        venueName: 'Hall A',
        startTime: start,
        endTime: end,
        creatorUid: 'director-1',
        notes: 'Bring scores',
        createdAt: DateTime(2026, 11, 1),
      );

      final map = original.toMap();
      expect(map['productionId'], 'prod-valid');
      expect(map['title'], 'Vocal Warmups');
      expect(map['venueId'], 'rehearsal-hall-a');
      expect(map['venueName'], 'Hall A');
      expect(map['venue'], 'Hall A');
      expect(map['creatorUid'], 'director-1');
      expect(map['notes'], 'Bring scores');
      expect(map['startTime'], isA<Timestamp>());
      expect(map['endTime'], isA<Timestamp>());
      expect(map['scheduledAt'], isA<Timestamp>());

      // Deserialization from map
      final restored = Rehearsal.fromMap(map, 'reh-serialize');
      expect(restored.id, 'reh-serialize');
      expect(restored.productionId, 'prod-valid');
      expect(restored.title, 'Vocal Warmups');
      expect(restored.venueId, 'rehearsal-hall-a');
      expect(restored.venueName, 'Hall A');
      expect(restored.startTime, start);
      expect(restored.endTime, end);
      expect(restored.creatorUid, 'director-1');

      // Deserialization with ISO string dates
      final mapWithStrings = {
        'productionId': 'prod-valid',
        'title': 'Choreography',
        'venue': 'Dance Studio',
        'startTime': '2026-11-15T14:00:00.000Z',
        'endTime': '2026-11-15T16:00:00.000Z',
        'createdBy': 'choreographer-1',
      };
      final stringParsed = Rehearsal.fromMap(mapWithStrings, 'str-id');
      expect(stringParsed.title, 'Choreography');
      expect(stringParsed.venue, 'Dance Studio');
      expect(stringParsed.startTime, DateTime.parse('2026-11-15T14:00:00.000Z'));
      expect(stringParsed.endTime, DateTime.parse('2026-11-15T16:00:00.000Z'));
      expect(stringParsed.creatorUid, 'choreographer-1');
    });

    test('copyWith updates specified fields only', () {
      final original = Rehearsal(
        id: 'orig-id',
        productionId: 'prod-1',
        title: 'Original Title',
        venueId: 'v1',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'dir-1',
      );

      final updated = original.copyWith(
        title: 'New Title',
        notes: 'Updated notes',
      );

      expect(updated.id, 'orig-id');
      expect(updated.productionId, 'prod-1');
      expect(updated.title, 'New Title');
      expect(updated.notes, 'Updated notes');
      expect(updated.startTime, original.startTime);
      expect(updated.endTime, original.endTime);
    });
  });

  group('RehearsalService - Field and Reference Validation', () {
    test('rejects empty or whitespace productionId', () {
      final r1 = Rehearsal(
        id: '',
        productionId: '',
        venueId: 'main-stage',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'dir-1',
      );
      final r2 = r1.copyWith(productionId: '   ');

      expect(
        () => service.validateRehearsal(r1),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('Production ID is required'),
        )),
      );
      expect(
        () => service.validateRehearsal(r2),
        throwsA(isA<RehearsalValidationException>()),
      );
    });

    test('rejects empty or whitespace venue', () {
      final r1 = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        venueId: '',
        venueName: '',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'dir-1',
      );
      final r2 = r1.copyWith(venueId: '   ', venueName: '   ');

      expect(
        () => service.validateRehearsal(r1),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('Venue is required'),
        )),
      );
      expect(
        () => service.validateRehearsal(r2),
        throwsA(isA<RehearsalValidationException>()),
      );
    });

    test('rejects empty or whitespace creatorUid', () {
      final r = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        venueId: 'stage-1',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: '',
      );

      expect(
        () => service.validateRehearsal(r),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('Creator UID is required'),
        )),
      );
    });

    test('rejects zero duration (startTime == endTime)', () {
      final time = DateTime(2026, 11, 1, 14, 0);
      final r = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        venueId: 'stage-1',
        startTime: time,
        endTime: time,
        creatorUid: 'dir-1',
      );

      expect(
        () => service.validateRehearsal(r),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('duration cannot be zero'),
        )),
      );
    });

    test('rejects invalid time range (endTime before startTime)', () {
      final r = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        venueId: 'stage-1',
        startTime: DateTime(2026, 11, 1, 16, 0),
        endTime: DateTime(2026, 11, 1, 14, 0),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.validateRehearsal(r),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('strictly after start time'),
        )),
      );
    });

    test('rejects booking when referenced production does not exist', () async {
      final r = Rehearsal(
        id: '',
        productionId: 'non-existent-production-999',
        venueId: 'stage-1',
        startTime: DateTime(2026, 11, 1, 10),
        endTime: DateTime(2026, 11, 1, 12),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(r, checkProductionExists: true),
        throwsA(isA<RehearsalValidationException>().having(
          (e) => e.message,
          'message',
          contains('Referenced production does not exist'),
        )),
      );
    });
  });

  group('RehearsalService - Venue Conflict Detection & Time Overlaps', () {
    final existingStart = DateTime(2026, 11, 15, 14, 0);
    final existingEnd = DateTime(2026, 11, 15, 17, 0);

    setUp(() {
      // Seed an existing rehearsal at 'Main Auditorium' from 14:00 to 17:00
      rehearsalsCollection.docs['existing-booking-1'] = {
        'productionId': 'prod-valid',
        'title': 'Existing Scene Run',
        'venueId': 'main-auditorium',
        'venueName': 'Main Auditorium',
        'startTime': Timestamp.fromDate(existingStart),
        'endTime': Timestamp.fromDate(existingEnd),
        'creatorUid': 'dir-existing',
      };
    });

    test('intervalsOverlap correctly classifies overlap vs non-overlap', () {
      final t1 = DateTime(2026, 11, 15, 10, 0);
      final t2 = DateTime(2026, 11, 15, 12, 0);
      final t3 = DateTime(2026, 11, 15, 14, 0);
      final t4 = DateTime(2026, 11, 15, 16, 0);

      // Adjacent (t2 == t2): [10, 12) and [12, 14) -> false
      expect(RehearsalService.intervalsOverlap(t1, t2, t2, t3), isFalse);

      // Completely disjoint: [10, 12) and [14, 16) -> false
      expect(RehearsalService.intervalsOverlap(t1, t2, t3, t4), isFalse);

      // Overlapping: [10, 14) and [12, 16) -> true
      expect(RehearsalService.intervalsOverlap(t1, t3, t2, t4), isTrue);

      // Enclosed: [10, 16) and [12, 14) -> true
      expect(RehearsalService.intervalsOverlap(t1, t4, t2, t3), isTrue);
    });

    test('allows adjacent booking that ends exactly as existing booking begins', () async {
      // 11:00 to 14:00 (ends exactly at 14:00, when existing begins)
      final adjacentBefore = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Morning Block',
        venueId: 'main-auditorium',
        venueName: 'Main Auditorium',
        startTime: DateTime(2026, 11, 15, 11, 0),
        endTime: existingStart, // 14:00
        creatorUid: 'dir-1',
      );

      final created = await service.createRehearsal(adjacentBefore);
      expect(created.id, isNotEmpty);
      expect(rehearsalsCollection.docs.containsKey(created.id), isTrue);
    });

    test('allows adjacent booking that starts exactly as existing booking ends', () async {
      // 17:00 to 20:00 (starts exactly at 17:00, when existing ends)
      final adjacentAfter = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Evening Block',
        venueId: 'main-auditorium',
        venueName: 'Main Auditorium',
        startTime: existingEnd, // 17:00
        endTime: DateTime(2026, 11, 15, 20, 0),
        creatorUid: 'dir-1',
      );

      final created = await service.createRehearsal(adjacentAfter);
      expect(created.id, isNotEmpty);
      expect(rehearsalsCollection.docs.containsKey(created.id), isTrue);
    });

    test('allows concurrent booking at a DIFFERENT venue during exact same time', () async {
      final differentVenue = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Dance Studio Rehearsal',
        venueId: 'studio-b',
        venueName: 'Studio B',
        startTime: existingStart, // 14:00
        endTime: existingEnd, // 17:00
        creatorUid: 'dir-1',
      );

      final created = await service.createRehearsal(differentVenue);
      expect(created.id, isNotEmpty);
      expect(created.venue, 'Studio B');
    });

    test('rejects booking that partially overlaps start of existing booking', () async {
      // 13:00 to 15:00 overlaps 14:00 to 17:00
      final partialStartOverlap = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Overlapping Start',
        venueId: 'main-auditorium',
        startTime: DateTime(2026, 11, 15, 13, 0),
        endTime: DateTime(2026, 11, 15, 15, 0),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(partialStartOverlap),
        throwsA(isA<VenueConflictException>().having(
          (e) => e.conflictingRehearsal.id,
          'conflictingRehearsal.id',
          'existing-booking-1',
        )),
      );
    });

    test('rejects booking that partially overlaps end of existing booking', () async {
      // 16:00 to 18:00 overlaps 14:00 to 17:00
      final partialEndOverlap = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Overlapping End',
        venueId: 'main-auditorium',
        startTime: DateTime(2026, 11, 15, 16, 0),
        endTime: DateTime(2026, 11, 15, 18, 0),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(partialEndOverlap),
        throwsA(isA<VenueConflictException>()),
      );
    });

    test('rejects booking completely inside existing booking', () async {
      // 14:30 to 16:30 is inside 14:00 to 17:00
      final insideOverlap = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Inside Booking',
        venueId: 'main-auditorium',
        startTime: DateTime(2026, 11, 15, 14, 30),
        endTime: DateTime(2026, 11, 15, 16, 30),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(insideOverlap),
        throwsA(isA<VenueConflictException>()),
      );
    });

    test('rejects booking that completely encloses existing booking', () async {
      // 12:00 to 19:00 encloses 14:00 to 17:00
      final enclosingOverlap = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Enclosing Booking',
        venueId: 'main-auditorium',
        startTime: DateTime(2026, 11, 15, 12, 0),
        endTime: DateTime(2026, 11, 15, 19, 0),
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(enclosingOverlap),
        throwsA(isA<VenueConflictException>()),
      );
    });

    test('rejects exact duplicate time booking at same venue', () async {
      final duplicateBooking = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Duplicate Time Booking',
        venueId: 'main-auditorium',
        startTime: existingStart,
        endTime: existingEnd,
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(duplicateBooking),
        throwsA(isA<VenueConflictException>()),
      );
    });

    test('recognizes venue conflict case-insensitively with leading/trailing spaces', () async {
      final weirdCasedVenue = Rehearsal(
        id: '',
        productionId: 'prod-valid',
        title: 'Messy Venue Name',
        venueId: '  mAiN-AuDiToRiUm  ',
        startTime: existingStart,
        endTime: existingEnd,
        creatorUid: 'dir-1',
      );

      expect(
        () => service.createRehearsal(weirdCasedVenue),
        throwsA(isA<VenueConflictException>()),
      );
    });
  });

  group('RehearsalService - Editing Existing Booking', () {
    final startA = DateTime(2026, 11, 20, 10, 0);
    final endA = DateTime(2026, 11, 20, 12, 0);
    final startB = DateTime(2026, 11, 20, 14, 0);
    final endB = DateTime(2026, 11, 20, 16, 0);

    setUp(() {
      rehearsalsCollection.docs['reh-a'] = {
        'productionId': 'prod-valid',
        'title': 'Rehearsal A',
        'venueId': 'stage-one',
        'venueName': 'Stage One',
        'startTime': Timestamp.fromDate(startA),
        'endTime': Timestamp.fromDate(endA),
        'creatorUid': 'dir-1',
      };
      rehearsalsCollection.docs['reh-b'] = {
        'productionId': 'prod-valid',
        'title': 'Rehearsal B',
        'venueId': 'stage-one',
        'venueName': 'Stage One',
        'startTime': Timestamp.fromDate(startB),
        'endTime': Timestamp.fromDate(endB),
        'creatorUid': 'dir-1',
      };
    });

    test('allows updating an existing rehearsal without conflicting with itself', () async {
      final rehA = Rehearsal(
        id: 'reh-a',
        productionId: 'prod-valid',
        title: 'Rehearsal A (Updated Title)',
        venueId: 'stage-one',
        venueName: 'Stage One',
        startTime: startA,
        endTime: endA,
        creatorUid: 'dir-1',
        notes: 'Updated notes',
      );

      await service.updateRehearsal(rehA);
      expect(rehearsalsCollection.docs['reh-a']!['title'], 'Rehearsal A (Updated Title)');
      expect(rehearsalsCollection.docs['reh-a']!['notes'], 'Updated notes');
    });

    test('allows updating existing rehearsal time to a non-conflicting time', () async {
      final rehA = Rehearsal(
        id: 'reh-a',
        productionId: 'prod-valid',
        title: 'Rehearsal A (Shifted)',
        venueId: 'stage-one',
        venueName: 'Stage One',
        startTime: DateTime(2026, 11, 20, 8, 0),
        endTime: DateTime(2026, 11, 20, 10, 0),
        creatorUid: 'dir-1',
      );

      await service.updateRehearsal(rehA);
      expect(
        rehearsalsCollection.docs['reh-a']!['startTime'],
        Timestamp.fromDate(DateTime(2026, 11, 20, 8, 0)),
      );
    });

    test('rejects updating existing rehearsal if modified time conflicts with another rehearsal', () async {
      // Shifting reh-a into reh-b (14:00 to 16:00)
      final rehAConflicting = Rehearsal(
        id: 'reh-a',
        productionId: 'prod-valid',
        title: 'Rehearsal A (Overlaps B)',
        venueId: 'stage-one',
        venueName: 'Stage One',
        startTime: DateTime(2026, 11, 20, 13, 0),
        endTime: DateTime(2026, 11, 20, 15, 0), // overlaps reh-b at 14:00
        creatorUid: 'dir-1',
      );

      expect(
        () => service.updateRehearsal(rehAConflicting),
        throwsA(isA<VenueConflictException>().having(
          (e) => e.conflictingRehearsal.id,
          'conflictingRehearsal.id',
          'reh-b',
        )),
      );
    });
  });

  group('RehearsalService - CRUD Operations & Retrieval', () {
    test('getRehearsals returns empty list when no rehearsals exist', () async {
      final list = await service.getRehearsals();
      expect(list, isEmpty);
    });

    test('getRehearsals returns items sorted chronologically by start time', () async {
      rehearsalsCollection.docs['reh-late'] = {
        'productionId': 'prod-valid',
        'title': 'Late Show',
        'venueId': 'stage-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 12, 1, 18, 0)),
        'endTime': Timestamp.fromDate(DateTime(2026, 12, 1, 20, 0)),
        'creatorUid': 'dir-1',
      };
      rehearsalsCollection.docs['reh-early'] = {
        'productionId': 'prod-valid',
        'title': 'Early Show',
        'venueId': 'stage-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 12, 1, 9, 0)),
        'endTime': Timestamp.fromDate(DateTime(2026, 12, 1, 11, 0)),
        'creatorUid': 'dir-1',
      };
      rehearsalsCollection.docs['reh-mid'] = {
        'productionId': 'prod-valid',
        'title': 'Mid Show',
        'venueId': 'stage-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 12, 1, 13, 0)),
        'endTime': Timestamp.fromDate(DateTime(2026, 12, 1, 15, 0)),
        'creatorUid': 'dir-1',
      };

      final list = await service.getRehearsals();
      expect(list.length, 3);
      expect(list[0].title, 'Early Show');
      expect(list[1].title, 'Mid Show');
      expect(list[2].title, 'Late Show');
    });

    test('getRehearsals filters by productionId and venueId', () async {
      rehearsalsCollection.docs['r-p1-v1'] = {
        'productionId': 'prod-1',
        'title': 'P1 V1',
        'venueId': 'venue-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
        'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 12)),
        'creatorUid': 'dir-1',
      };
      rehearsalsCollection.docs['r-p1-v2'] = {
        'productionId': 'prod-1',
        'title': 'P1 V2',
        'venueId': 'venue-2',
        'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 13)),
        'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 15)),
        'creatorUid': 'dir-1',
      };
      rehearsalsCollection.docs['r-p2-v1'] = {
        'productionId': 'prod-2',
        'title': 'P2 V1',
        'venueId': 'venue-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 16)),
        'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 18)),
        'creatorUid': 'dir-1',
      };

      final prod1List = await service.getRehearsalsByProduction('prod-1');
      expect(prod1List.length, 2);

      final venue1List = await service.getRehearsalsByVenue('venue-1');
      expect(venue1List.length, 2);

      final filtered = await service.getRehearsals(productionId: 'prod-1', venueId: 'venue-1');
      expect(filtered.length, 1);
      expect(filtered.first.title, 'P1 V1');
    });

    test('getRehearsalById returns single item or null if not found', () async {
      rehearsalsCollection.docs['r-find'] = {
        'productionId': 'prod-valid',
        'title': 'Find Me',
        'venueId': 'stage-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
        'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 12)),
        'creatorUid': 'dir-1',
      };

      final found = await service.getRehearsalById('r-find');
      expect(found, isNotNull);
      expect(found!.title, 'Find Me');

      final notFound = await service.getRehearsalById('unknown-id');
      expect(notFound, isNull);

      final emptyId = await service.getRehearsalById('');
      expect(emptyId, isNull);
    });

    test('deleteRehearsal deletes doc and throws on empty ID', () async {
      rehearsalsCollection.docs['r-delete'] = {
        'productionId': 'prod-valid',
        'title': 'To Delete',
        'venueId': 'stage-1',
        'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
        'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 12)),
        'creatorUid': 'dir-1',
      };

      await service.deleteRehearsal('r-delete');
      expect(rehearsalsCollection.docs.containsKey('r-delete'), isFalse);

      expect(() => service.deleteRehearsal(''), throwsA(isA<ArgumentError>()));
      expect(() => service.deleteRehearsal('   '), throwsA(isA<ArgumentError>()));
    });

    test('streamRehearsals emits live updates in chronological order', () async {
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      rehearsalsCollection.streamController = controller;

      final emissions = <List<Rehearsal>>[];
      final sub = service.streamRehearsals().listen(emissions.add);

      controller.add(FakeQuerySnapshot([]));
      await Future<void>.delayed(Duration.zero);

      controller.add(FakeQuerySnapshot([
        FakeQueryDocumentSnapshot('r2', {
          'productionId': 'p1',
          'title': 'Later Session',
          'venueId': 'v1',
          'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 14)),
          'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 16)),
          'creatorUid': 'd1',
        }),
        FakeQueryDocumentSnapshot('r1', {
          'productionId': 'p1',
          'title': 'Earlier Session',
          'venueId': 'v1',
          'startTime': Timestamp.fromDate(DateTime(2026, 11, 1, 10)),
          'endTime': Timestamp.fromDate(DateTime(2026, 11, 1, 12)),
          'creatorUid': 'd1',
        }),
      ]));
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, 2);
      expect(emissions[0], isEmpty);
      expect(emissions[1].length, 2);
      expect(emissions[1][0].title, 'Earlier Session'); // Sorted chronologically
      expect(emissions[1][1].title, 'Later Session');

      await sub.cancel();
      await controller.close();
    });

    test('propagates Firestore error when fetch fails', () async {
      rehearsalsCollection.shouldThrowOnGet = true;
      rehearsalsCollection.errorToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Permission denied',
      );

      expect(
        () => service.getRehearsals(),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });
  });
}
