// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';

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
          FirebaseException(plugin: 'firestore', message: 'Failed to fetch productions');
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
          FirebaseException(plugin: 'firestore', message: 'Failed to add production');
    }
    final docId = 'real-doc-id-${docs.length + 1}';
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
  Exception? errorToThrow;

  FakeDocumentReference(this.parentCollection, this.id);

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (shouldThrowOnUpdate) {
      throw errorToThrow ??
          FirebaseException(plugin: 'firestore', message: 'Failed to update production');
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
          FirebaseException(plugin: 'firestore', message: 'Failed to delete production');
    }
    parentCollection.docs.remove(id);
  }
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
  late FakeCollectionReference productionsCollection;
  late ProductionService service;

  setUp(() {
    fakeFirestore = FakeFirestore();
    productionsCollection = fakeFirestore.getCollection('productions');
    service = ProductionService(firestore: fakeFirestore);
  });

  group('ProductionService - getProductions()', () {
    test('returns empty list when Firestore returns zero documents', () async {
      final result = await service.getProductions();
      expect(result, isEmpty);
    });

    test('returns parsed documents when Firestore has data', () async {
      productionsCollection.docs['doc-1'] = {
        'title': 'Hamlet',
        'description': 'Prince of Denmark',
        'status': ProductionStatus.planning,
        'director': 'Kenneth Branagh',
        'startDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'endDate': Timestamp.fromDate(DateTime(2026, 12, 1)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      };

      final result = await service.getProductions();
      expect(result.length, 1);
      final prod = result.first;
      expect(prod.id, 'doc-1');
      expect(prod.title, 'Hamlet');
      expect(prod.description, 'Prince of Denmark');
      expect(prod.status, ProductionStatus.planning);
      expect(prod.director, 'Kenneth Branagh');
      expect(prod.startDate, DateTime(2026, 11, 1));
      expect(prod.endDate, DateTime(2026, 12, 1));
      expect(prod.createdAt, DateTime(2026, 10, 1));
    });

    test('preserves descending date ordering by start date', () async {
      productionsCollection.docs['doc-early'] = {
        'title': 'Early Production',
        'startDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
      };
      productionsCollection.docs['doc-late'] = {
        'title': 'Late Production',
        'startDate': Timestamp.fromDate(DateTime(2026, 12, 1)),
      };
      productionsCollection.docs['doc-mid'] = {
        'title': 'Mid Production',
        'startDate': Timestamp.fromDate(DateTime(2026, 8, 1)),
      };

      final result = await service.getProductions();
      expect(result.length, 3);
      expect(result[0].title, 'Late Production');
      expect(result[1].title, 'Mid Production');
      expect(result[2].title, 'Early Production');
    });

    test('falls back to createdAt ordering when startDate is null', () async {
      productionsCollection.docs['doc-older'] = {
        'title': 'Older Created',
        'startDate': null,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      };
      productionsCollection.docs['doc-newer'] = {
        'title': 'Newer Created',
        'startDate': null,
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
      };

      final result = await service.getProductions();
      expect(result.length, 2);
      expect(result[0].title, 'Newer Created');
      expect(result[1].title, 'Older Created');
    });

    test('falls back to title ordering when both startDate and createdAt are null', () async {
      productionsCollection.docs['doc-z'] = {
        'title': 'Zeta Show',
        'startDate': null,
        'createdAt': null,
      };
      productionsCollection.docs['doc-a'] = {
        'title': 'Alpha Show',
        'startDate': null,
        'createdAt': null,
      };
      productionsCollection.docs['doc-dated'] = {
        'title': 'Dated Show',
        'startDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
      };

      final result = await service.getProductions();
      expect(result.length, 3);
      // Scheduled production comes first
      expect(result[0].title, 'Dated Show');
      // Undated productions sort alphabetically by title as sensible fallback
      expect(result[1].title, 'Alpha Show');
      expect(result[2].title, 'Zeta Show');
    });

    test('propagates Firestore error when fetch fails', () async {
      productionsCollection.shouldThrowOnGet = true;
      productionsCollection.errorToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Permission denied for productions collection',
      );

      expect(
        () => service.getProductions(),
        throwsA(isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );
    });
  });

  group('ProductionService - streamProductions()', () {
    test('emits empty list when collection is empty', () async {
      final streamResult = await service.streamProductions().first;
      expect(streamResult, isEmpty);
    });

    test('emits parsed documents in correct date order', () async {
      productionsCollection.docs['stream-1'] = {
        'title': 'Show A',
        'startDate': Timestamp.fromDate(DateTime(2026, 4, 1)),
      };
      productionsCollection.docs['stream-2'] = {
        'title': 'Show B',
        'startDate': Timestamp.fromDate(DateTime(2026, 10, 1)),
      };

      final streamResult = await service.streamProductions().first;
      expect(streamResult.length, 2);
      expect(streamResult[0].title, 'Show B');
      expect(streamResult[1].title, 'Show A');
    });

    test('emits updated productions when Firestore documents change', () async {
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      productionsCollection.streamController = controller;

      final emissions = <List<Production>>[];
      final subscription = service.streamProductions().listen(emissions.add);

      // 1. Initial empty state
      controller.add(FakeQuerySnapshot([]));
      await Future<void>.delayed(Duration.zero);

      // 2. Collection receives first document
      controller.add(FakeQuerySnapshot([
        FakeQueryDocumentSnapshot('stream-1', {
          'title': 'Show 1',
          'startDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
        }),
      ]));
      await Future<void>.delayed(Duration.zero);

      // 3. Collection receives updated/second document
      controller.add(FakeQuerySnapshot([
        FakeQueryDocumentSnapshot('stream-1', {
          'title': 'Show 1',
          'startDate': Timestamp.fromDate(DateTime(2026, 5, 1)),
        }),
        FakeQueryDocumentSnapshot('stream-2', {
          'title': 'Show 2',
          'startDate': Timestamp.fromDate(DateTime(2026, 8, 1)),
        }),
      ]));
      await Future<void>.delayed(Duration.zero);

      expect(emissions.length, 3);
      expect(emissions[0], isEmpty);
      expect(emissions[1].length, 1);
      expect(emissions[1][0].title, 'Show 1');
      expect(emissions[2].length, 2);
      expect(emissions[2][0].title, 'Show 2'); // Later start date first
      expect(emissions[2][1].title, 'Show 1');

      await subscription.cancel();
      await controller.close();
    });

    test('propagates stream errors instead of swallowing or substituting sample data', () async {
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      productionsCollection.streamController = controller;

      final stream = service.streamProductions();
      final streamExpectation = expectLater(
        stream,
        emitsError(isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable')),
      );

      controller.addError(
        FirebaseException(plugin: 'firestore', code: 'unavailable', message: 'Service down'),
      );
      await streamExpectation;
      await controller.close();
    });
  });

  group('ProductionService - createProduction()', () {
    test('saves production and returns actual Firestore document ID', () async {
      final input = Production(
        id: '',
        title: 'Othello',
        description: 'Tragedy of Venice',
        status: ProductionStatus.inRehearsal,
        director: 'Laurence Olivier',
        startDate: DateTime(2026, 11, 15),
      );

      final created = await service.createProduction(input);
      expect(created.id, 'real-doc-id-1');
      expect(created.title, 'Othello');
      expect(created.status, ProductionStatus.inRehearsal);

      // Verify document was written to fake Firestore
      expect(productionsCollection.docs.containsKey('real-doc-id-1'), isTrue);
      final storedData = productionsCollection.docs['real-doc-id-1']!;
      expect(storedData['title'], 'Othello');
      expect(storedData['director'], 'Laurence Olivier');
    });

    test('propagates write errors without returning a fake ID', () async {
      productionsCollection.shouldThrowOnAdd = true;
      productionsCollection.errorToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'unauthenticated',
        message: 'User is not logged in',
      );

      final input = const Production(id: '', title: 'Failed Show');

      expect(
        () => service.createProduction(input),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unauthenticated')),
      );
    });
  });

  group('ProductionService - updateProduction()', () {
    test('updates existing document in Firestore', () async {
      productionsCollection.docs['prod-123'] = {
        'title': 'Original Title',
        'status': ProductionStatus.planning,
      };

      final updated = Production(
        id: 'prod-123',
        title: 'Updated Title',
        status: ProductionStatus.inRehearsal,
      );

      await service.updateProduction(updated);
      expect(productionsCollection.docs['prod-123']!['title'], 'Updated Title');
      expect(productionsCollection.docs['prod-123']!['status'], ProductionStatus.inRehearsal);
    });

    test('throws ArgumentError when ID is empty or whitespace', () async {
      final emptyId = const Production(id: '', title: 'Empty ID');
      final whitespaceId = const Production(id: '   ', title: 'Whitespace ID');
      expect(
        () => service.updateProduction(emptyId),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.updateProduction(whitespaceId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('propagates update errors without swallowing', () async {
      productionsCollection.docs['prod-456'] = {'title': 'Show'};
      final docRef = productionsCollection.doc('prod-456') as FakeDocumentReference;
      docRef.shouldThrowOnUpdate = true;
      docRef.errorToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'aborted',
        message: 'Transaction aborted',
      );

      final prod = const Production(id: 'prod-456', title: 'Show Update');
      expect(
        () => service.updateProduction(prod),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'aborted')),
      );
    });
  });

  group('ProductionService - deleteProduction()', () {
    test('deletes document from Firestore', () async {
      productionsCollection.docs['prod-del'] = {'title': 'To Delete'};
      expect(productionsCollection.docs.containsKey('prod-del'), isTrue);

      await service.deleteProduction('prod-del');
      expect(productionsCollection.docs.containsKey('prod-del'), isFalse);
    });

    test('throws ArgumentError when ID is empty or whitespace', () async {
      expect(
        () => service.deleteProduction(''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => service.deleteProduction('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('propagates deletion failures without silently ignoring', () async {
      final docRef = productionsCollection.doc('prod-fail') as FakeDocumentReference;
      docRef.shouldThrowOnDelete = true;
      docRef.errorToThrow = FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Cannot delete',
      );

      expect(
        () => service.deleteProduction('prod-fail'),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });
  });

  group('ProductionService - Sample / Demo Data Separation', () {
    test('demoProductions provides unmodifiable sample data with clean accents', () {
      final demoList = ProductionService.demoProductions;
      expect(demoList, isNotEmpty);
      expect(demoList.length, 4);

      // Verify unmodifiable
      expect(() => demoList.add(const Production(id: 'extra', title: 'Extra')), throwsUnsupportedError);

      // Verify clean accents
      final phantom = demoList.firstWhere((p) => p.id == 'sample-1');
      expect(phantom.description.contains('Christine Daaé'), isTrue);

      final lesMis = demoList.firstWhere((p) => p.id == 'sample-3');
      expect(lesMis.title, 'Les Misérables');
    });

    test('sampleProductions returns unmodifiable demo data for compatibility', () {
      expect(service.sampleProductions.length, 4);
    });
  });
}
