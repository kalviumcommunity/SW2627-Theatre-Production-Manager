import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_model.dart';

class ProductionService {
  final FirebaseFirestore? _firestore;

  // Broadcast controller to emit in-memory updates when offline / using sample data
  final StreamController<List<Production>> _mockStreamController =
      StreamController<List<Production>>.broadcast();

  // In-memory sample data
  late List<Production> _sampleProductions;

  ProductionService({FirebaseFirestore? firestore}) : _firestore = firestore {
    _initSampleData();
  }

  void _initSampleData() {
    _sampleProductions = [
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
  }

  FirebaseFirestore? get firestore {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Returns unmodifiable list of current in-memory sample productions
  List<Production> get sampleProductions => List.unmodifiable(_sampleProductions);

  /// Streams productions from Cloud Firestore, falling back to mock stream if unavailable.
  Stream<List<Production>> streamProductions() async* {
    yield List.unmodifiable(_sampleProductions);

    final fs = firestore;
    if (fs != null) {
      try {
        yield* fs
            .collection('productions')
            .snapshots()
            .map((snapshot) {
              if (snapshot.docs.isEmpty) {
                return _sampleProductions;
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
            })
            .handleError((_) {
              return _sampleProductions;
            });
      } catch (_) {
        yield* _mockStreamController.stream;
      }
    } else {
      yield* _mockStreamController.stream;
    }
  }

  /// Fetches production list from Firestore or fallback.
  Future<List<Production>> getProductions() async {
    final fs = firestore;
    if (fs == null) {
      return _sampleProductions;
    }

    try {
      final snapshot = await fs.collection('productions').get();
      if (snapshot.docs.isEmpty) {
        return _sampleProductions;
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
    } catch (_) {
      return _sampleProductions;
    }
  }

  /// Adds a new production to Firestore (or in-memory mock store if offline).
  Future<Production> createProduction(Production production) async {
    final fs = firestore;
    Production created = production;

    if (fs != null) {
      try {
        final docRef = await fs.collection('productions').add(production.toMap());
        created = production.copyWith(id: docRef.id);
      } catch (_) {
        // Fall back to in-memory generation if Firestore write fails
        final fallbackId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
        created = production.copyWith(id: fallbackId);
      }
    } else {
      final fallbackId = 'prod-${DateTime.now().millisecondsSinceEpoch}';
      created = production.copyWith(id: fallbackId);
    }

    // Always update in-memory list and notify mock stream listeners
    _sampleProductions.insert(0, created);
    _mockStreamController.add(List.unmodifiable(_sampleProductions));

    return created;
  }

  /// Updates an existing production.
  Future<void> updateProduction(Production production) async {
    final fs = firestore;
    if (fs != null) {
      try {
        await fs.collection('productions').doc(production.id).update(production.toMap());
      } catch (_) {
        // Fallback update in-memory
      }
    }

    final index = _sampleProductions.indexWhere((p) => p.id == production.id);
    if (index != -1) {
      _sampleProductions[index] = production;
      _mockStreamController.add(List.unmodifiable(_sampleProductions));
    }
  }

  /// Deletes a production by ID.
  Future<void> deleteProduction(String id) async {
    final fs = firestore;
    if (fs != null) {
      try {
        await fs.collection('productions').doc(id).delete();
      } catch (_) {
        // Ignore
      }
    }

    _sampleProductions.removeWhere((p) => p.id == id);
    _mockStreamController.add(List.unmodifiable(_sampleProductions));
  }

  void dispose() {
    _mockStreamController.close();
  }
}
