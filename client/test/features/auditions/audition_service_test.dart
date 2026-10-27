// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/auditions/exceptions/audition_exceptions.dart';
import 'package:client/features/auditions/models/audition_model.dart';
import 'package:client/features/auditions/services/audition_service.dart';

import '../../support/fake_venue_booking_gateway.dart';

// --- Lightweight Fakes for Firestore unit testing ---

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
  int _autoIdCounter = 0;

  FakeCollectionReference(this.collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'auto-id-${++_autoIdCounter}';
    return FakeDocumentReference(this, id);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeQuerySnapshot(
      docs.entries
          .map(
            (e) => FakeQueryDocumentSnapshot(
              e.key,
              Map<String, dynamic>.from(e.value),
            ),
          )
          .toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.value(
      FakeQuerySnapshot(
        docs.entries
            .map(
              (e) => FakeQueryDocumentSnapshot(
                e.key,
                Map<String, dynamic>.from(e.value),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return FakeQuery(this, field as String, isEqualTo);
  }
}

class FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  final FakeCollectionReference collection;
  final String field;
  final dynamic targetValue;

  FakeQuery(this.collection, this.field, this.targetValue);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final filtered = collection.docs.entries
        .where((e) {
          return e.value[field] == targetValue;
        })
        .map(
          (e) => FakeQueryDocumentSnapshot(
            e.key,
            Map<String, dynamic>.from(e.value),
          ),
        )
        .toList();

    return FakeQuerySnapshot(filtered);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final filtered = collection.docs.entries
        .where((e) {
          return e.value[field] == targetValue;
        })
        .map(
          (e) => FakeQueryDocumentSnapshot(
            e.key,
            Map<String, dynamic>.from(e.value),
          ),
        )
        .toList();

    return Stream.value(FakeQuerySnapshot(filtered));
  }
}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FakeCollectionReference parentCollection;
  final String docId;

  FakeDocumentReference(this.parentCollection, this.docId);

  @override
  String get id => docId;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final exists = parentCollection.docs.containsKey(docId);
    return FakeDocumentSnapshot(
      docId,
      exists ? Map<String, dynamic>.from(parentCollection.docs[docId]!) : null,
      exists,
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    parentCollection.docs[docId] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (!parentCollection.docs.containsKey(docId)) {
      throw FirebaseException(
        plugin: 'firestore',
        code: 'not-found',
        message: 'No document found to update',
      );
    }
    parentCollection.docs[docId]!.addAll(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> delete() async {
    parentCollection.docs.remove(docId);
  }
}

class FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic>? _data;
  final bool _exists;

  FakeDocumentSnapshot(this._id, this._data, this._exists);

  @override
  String get id => _id;

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;
}

class FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;

  FakeQueryDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic> data() => _data;
}

class FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  FakeQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  int get size => _docs.length;
}

void main() {
  late FakeFirestore fakeFirestore;
  late AuditionService service;

  final start = DateTime(2026, 11, 10, 10, 0);
  final end = DateTime(2026, 11, 10, 14, 0);

  Audition createSample({
    String id = 'aud-1',
    String productionId = 'prod-1',
    String title = 'Principal Auditions',
    String venue = 'Main Stage',
    DateTime? startTime,
    DateTime? endTime,
    String creatorUid = 'director-1',
    String status = AuditionStatus.scheduled,
  }) {
    return Audition(
      id: id,
      productionId: productionId,
      title: title,
      venue: venue,
      startTime: startTime ?? start,
      endTime: endTime ?? end,
      creatorUid: creatorUid,
      status: status,
    );
  }

  setUp(() {
    fakeFirestore = FakeFirestore();
    service = AuditionService(
      firestore: fakeFirestore,
      bookingGateway: FakeVenueBookingGateway(fakeFirestore),
    );

    // Seed sample production
    fakeFirestore.getCollection('productions').docs['prod-1'] = {
      'title': 'Hamlet',
      'status': 'Planning',
    };
  });

  group('AuditionService - Validation Tests', () {
    test('passes on valid audition', () {
      expect(() => service.validateAudition(createSample()), returnsNormally);
    });

    test('throws AuditionValidationException on missing productionId', () {
      expect(
        () => service.validateAudition(createSample(productionId: '  ')),
        throwsA(
          isA<AuditionValidationException>().having(
            (e) => e.message,
            'message',
            contains('Production ID is required'),
          ),
        ),
      );
    });

    test('throws AuditionValidationException on missing title', () {
      expect(
        () => service.validateAudition(createSample(title: '')),
        throwsA(
          isA<AuditionValidationException>().having(
            (e) => e.message,
            'message',
            contains('Audition title is required'),
          ),
        ),
      );
    });

    test('throws AuditionValidationException on missing venue', () {
      expect(
        () => service.validateAudition(createSample(venue: '  ')),
        throwsA(
          isA<AuditionValidationException>().having(
            (e) => e.message,
            'message',
            contains('Venue is required'),
          ),
        ),
      );
    });

    test('throws AuditionValidationException on missing creatorUid', () {
      expect(
        () => service.validateAudition(createSample(creatorUid: '')),
        throwsA(
          isA<AuditionValidationException>().having(
            (e) => e.message,
            'message',
            contains('Creator UID is required'),
          ),
        ),
      );
    });

    test('throws AuditionValidationException when start equals end time', () {
      expect(
        () => service.validateAudition(createSample(endTime: start)),
        throwsA(
          isA<AuditionValidationException>().having(
            (e) => e.message,
            'message',
            contains('duration cannot be zero'),
          ),
        ),
      );
    });

    test(
      'throws AuditionValidationException when end time is before start',
      () {
        expect(
          () => service.validateAudition(
            createSample(endTime: start.subtract(const Duration(hours: 1))),
          ),
          throwsA(
            isA<AuditionValidationException>().having(
              (e) => e.message,
              'message',
              contains('strictly after start time'),
            ),
          ),
        );
      },
    );

    test(
      'validateProductionReference passes for existing production',
      () async {
        await expectLater(
          service.validateProductionReference('prod-1'),
          completes,
        );
      },
    );

    test(
      'validateProductionReference throws for non-existent production',
      () async {
        await expectLater(
          service.validateProductionReference('non-existent-prod'),
          throwsA(
            isA<AuditionValidationException>().having(
              (e) => e.message,
              'message',
              contains('Referenced production does not exist'),
            ),
          ),
        );
      },
    );
  });

  group('AuditionService - CRUD Operations', () {
    test('creates audition successfully with generated ID', () async {
      final toCreate = createSample(id: '');
      final created = await service.createAudition(toCreate);

      expect(created.id, isNotEmpty);
      expect(created.title, 'Principal Auditions');
      expect(
        fakeFirestore.getCollection('auditions').docs.containsKey(created.id),
        isTrue,
      );
    });

    test('creates audition with specified ID', () async {
      final toCreate = createSample(id: 'custom-aud-id');
      final created = await service.createAudition(toCreate);

      expect(created.id, 'custom-aud-id');
      expect(
        fakeFirestore
            .getCollection('auditions')
            .docs
            .containsKey('custom-aud-id'),
        isTrue,
      );
    });

    test(
      'createAudition throws when referenced production does not exist',
      () async {
        final toCreate = createSample(productionId: 'ghost-prod');
        expect(
          () => service.createAudition(toCreate, checkProductionExists: true),
          throwsA(isA<AuditionValidationException>()),
        );
      },
    );

    test('createAudition skips production check when checkProductionExists = false', () async {
      final toCreate = createSample(productionId: 'ghost-prod');
      final created = await service.createAudition(
        toCreate,
        checkProductionExists: false,
      );
      expect(created.id, isNotEmpty);
    });

    test('updates existing audition', () async {
      final created = await service.createAudition(createSample());

      final updatedModel = created.copyWith(
        title: 'Updated Audition Title',
        venue: 'Studio B',
      );

      await service.updateAudition(updatedModel);

      final fetched = await service.getAuditionById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Updated Audition Title');
      expect(fetched.venue, 'Studio B');
    });

    test('updateAudition throws AuditionNotFoundException when updating missing document', () async {
      final nonExistent = createSample(id: 'missing-doc-id');
      expect(
        () => service.updateAudition(nonExistent),
        throwsA(isA<AuditionNotFoundException>()),
      );
    });

    test('cancels audition safely and records cancellation reason', () async {
      final created = await service.createAudition(createSample());

      await service.cancelAudition(created.id, reason: 'Director unavailable');

      final fetched = await service.getAuditionById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.status, AuditionStatus.cancelled);
      expect(fetched.isCancelled, isTrue);
      expect(fetched.cancellationReason, 'Director unavailable');
    });

    test('cancelAudition throws on non-existent document', () async {
      expect(
        () => service.cancelAudition('missing-id'),
        throwsA(isA<AuditionNotFoundException>()),
      );
    });

    test('cancelAudition throws on empty id', () async {
      expect(
        () => service.cancelAudition(''),
        throwsA(isA<AuditionValidationException>()),
      );
    });

    test('deletes audition document', () async {
      final created = await service.createAudition(createSample());
      expect(
        fakeFirestore.getCollection('auditions').docs.containsKey(created.id),
        isTrue,
      );

      await service.deleteAudition(created.id);
      expect(
        fakeFirestore.getCollection('auditions').docs.containsKey(created.id),
        isFalse,
      );
    });

    test(
      'getAuditions filters by production ID and sorts by startTime',
      () async {
        // Seed second production
        fakeFirestore.getCollection('productions').docs['prod-2'] = {
          'title': 'Macbeth',
          'status': 'Planning',
        };

        await service.createAudition(
          createSample(
            id: 'aud-a',
            productionId: 'prod-1',
            startTime: DateTime(2026, 11, 20, 10, 0),
            endTime: DateTime(2026, 11, 20, 12, 0),
          ),
        );
        await service.createAudition(
          createSample(
            id: 'aud-b',
            productionId: 'prod-1',
            startTime: DateTime(2026, 11, 10, 10, 0),
            endTime: DateTime(2026, 11, 10, 12, 0),
          ),
        );
        await service.createAudition(
          createSample(
            id: 'aud-c',
            productionId: 'prod-2',
            startTime: DateTime(2026, 11, 15, 10, 0),
            endTime: DateTime(2026, 11, 15, 12, 0),
          ),
        );

        final prod1Auditions = await service.getAuditions(
          productionId: 'prod-1',
        );
        expect(prod1Auditions.length, 2);
        expect(prod1Auditions.first.id, 'aud-b'); // Earlier date first
        expect(prod1Auditions.last.id, 'aud-a');

        final allAuditions = await service.getAuditions();
        expect(allAuditions.length, 3);
      },
    );

    test('streamAuditions emits filtered stream', () async {
      await service.createAudition(
        createSample(id: 'aud-stream-1', productionId: 'prod-1'),
      );

      final list = await service.streamAuditions(productionId: 'prod-1').first;
      expect(list.length, 1);
      expect(list.first.id, 'aud-stream-1');
    });
  });
}
