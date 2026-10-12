// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_model.dart';

class ProductionService {
  final FirebaseFirestore? _firestore;

  // Broadcast controller to emit in-memory updates when explicitly using mock/local mode
  final StreamController<List<Production>> _mockStreamController =
      StreamController<List<Production>>.broadcast();

  // In-memory mock productions (only used when firestore is null or in explicit mock mode)
  final List<Production> _mockProductions = [];

  ProductionService({
    FirebaseFirestore? firestore,
    bool loadSampleDataInMockMode = false,
  }) : _firestore = firestore {
    if (loadSampleDataInMockMode && _firestore == null) {
      _mockProductions.addAll(sampleProductions);
    }
  }

  /// Curated sample productions for testing or manual preview.
  /// Kept strictly separate from real Firestore production data.
  static List<Production> get sampleProductions => [
    Production(
      id: 'sample-1',
      title: 'The Phantom of the Opera',
      description:
          'A musical masterpiece following the masked musical genius living beneath the Paris Opera House and his obsession with soprano Christine Daaé.',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 11, 25),
      status: ProductionStatus.inRehearsal,
      director: 'Sarah Jenkins',
      createdAt: DateTime(2026, 9, 15),
    ),
    Production(
      id: 'sample-2',
      title: 'A Midsummer Night\'s Dream',
      description:
          'Shakespeare\'s whimsical comedy of enchanted forests, mischievous fairies, and tangled Athenian lovers under the spell of Puck.',
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2027, 1, 15),
      status: ProductionStatus.planning,
      director: 'David Miller',
      createdAt: DateTime(2026, 9, 28),
    ),
    Production(
      id: 'sample-3',
      title: 'Les Misérables',
      description:
          'An epic tale of passion, sacrifice, and redemption set against the backdrop of 19th-century revolutionary France.',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 9, 30),
      status: ProductionStatus.completed,
      director: 'Arthur Pendelton',
      createdAt: DateTime(2026, 6, 10),
    ),
    Production(
      id: 'sample-4',
      title: 'The Crucible',
      description:
          'Arthur Miller\'s chilling allegory of mass hysteria and moral compromise in Salem, Massachusetts.',
      startDate: DateTime(2026, 12, 10),
      endDate: DateTime(2027, 2, 28),
      status: ProductionStatus.planning,
      director: 'Elena Rostova',
      createdAt: DateTime(2026, 10, 5),
    ),
  ];

  FirebaseFirestore? get firestore {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Streams productions.
  /// If Firestore is available:
  /// - Streams from the `productions` collection.
  /// - Returns an empty list `[]` when the collection has no documents.
  /// - Propagates stream errors so the UI can display error states.
  /// If Firestore is not available:
  /// - Emits from the in-memory mock repository.
  Stream<List<Production>> streamProductions() {
    final fs = firestore;
    if (fs != null) {
      return fs
          .collection('productions')
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return const <Production>[];
            }
            final list = snapshot.docs
                .map((doc) => Production.fromFirestore(doc))
                .toList();
            list.sort((a, b) {
              final aDate = a.startDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.startDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });
            return list;
          });
    }

    // In-memory mock stream for testing or offline environments
    return Stream<List<Production>>.multi((controller) {
      controller.add(List.unmodifiable(_mockProductions));
      final sub = _mockStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  /// Fetches production list.
  /// If Firestore is available:
  /// - Fetches from `productions` collection.
  /// - Returns `[]` if collection has no documents.
  /// - Surfaces errors to caller.
  /// If Firestore is not available:
  /// - Returns in-memory mock productions.
  Future<List<Production>> getProductions() async {
    final fs = firestore;
    if (fs != null) {
      final snapshot = await fs.collection('productions').get();
      if (snapshot.docs.isEmpty) {
        return const <Production>[];
      }
      final list = snapshot.docs
          .map((doc) => Production.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        final aDate = a.startDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.startDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return list;
    }

    return List.unmodifiable(_mockProductions);
  }

  /// Adds a new production.
  /// If Firestore is available:
  /// - Persists to Firestore. Any write error is thrown to caller so UI surfaces the failure.
  /// - Never silently falls back to in-memory on Firestore write failure.
  Future<Production> createProduction(Production production) async {
    final fs = firestore;
    if (fs != null) {
      final docRef = await fs.collection('productions').add(production.toMap());
      return production.copyWith(id: docRef.id);
    }

    // Mock store write
    final fallbackId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
    final created = production.copyWith(id: fallbackId);
    _mockProductions.insert(0, created);
    _mockStreamController.add(List.unmodifiable(_mockProductions));
    return created;
  }

  /// Updates an existing production.
  /// If Firestore is available:
  /// - Updates Firestore document. Failures are thrown so UI can display them.
  Future<void> updateProduction(Production production) async {
    final fs = firestore;
    if (fs != null) {
      await fs.collection('productions').doc(production.id).update(production.toMap());
      return;
    }

    final index = _mockProductions.indexWhere((p) => p.id == production.id);
    if (index != -1) {
      _mockProductions[index] = production;
      _mockStreamController.add(List.unmodifiable(_mockProductions));
    }
  }

  /// Deletes a production by ID.
  /// If Firestore is available:
  /// - Deletes from Firestore. Failures are thrown so UI can display them.
  Future<void> deleteProduction(String id) async {
    final fs = firestore;
    if (fs != null) {
      await fs.collection('productions').doc(id).delete();
      return;
    }

    _mockProductions.removeWhere((p) => p.id == id);
    _mockStreamController.add(List.unmodifiable(_mockProductions));
  }

  void dispose() {
    _mockStreamController.close();
  }
}
