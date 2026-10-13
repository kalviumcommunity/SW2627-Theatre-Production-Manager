import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/production_model.dart';

class ProductionService {
  final FirebaseFirestore? _customFirestore;

  ProductionService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Explicit demo/test data for development or testing purposes.
  static final List<Production> demoProductions = List.unmodifiable([
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
  ]);

  /// Preserved for backwards compatibility with existing UI callers.
  /// Exposes unmodifiable demo productions. Callers should avoid using this as
  /// initialData to prevent showing demo data before Firestore loads.
  List<Production> get sampleProductions => demoProductions;

  /// Streams productions from Cloud Firestore.
  /// Empty collections emit an empty list. Stream errors are propagated to the caller.
  Stream<List<Production>> streamProductions() {
    return firestore.collection('productions').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return <Production>[];
      }
      final list = snapshot.docs
          .map((doc) => Production.fromFirestore(doc))
          .toList();
      _sortProductions(list);
      return list;
    });
  }

  /// Fetches production list from Firestore.
  /// Returns empty list if collection is empty. Propagates errors to the caller.
  Future<List<Production>> getProductions() async {
    final snapshot = await firestore.collection('productions').get();
    if (snapshot.docs.isEmpty) {
      return <Production>[];
    }
    final list = snapshot.docs
        .map((doc) => Production.fromFirestore(doc))
        .toList();
    _sortProductions(list);
    return list;
  }

  /// Adds a new production to Firestore and returns the production with its
  /// real Firestore-generated document ID. Propagates failures to the caller.
  Future<Production> createProduction(Production production) async {
    final docRef = await firestore.collection('productions').add(production.toMap());
    return production.copyWith(id: docRef.id);
  }

  /// Updates an existing production in Firestore.
  /// Propagates failures to the caller.
  Future<void> updateProduction(Production production) async {
    if (production.id.trim().isEmpty) {
      throw ArgumentError('Production ID cannot be empty for update.');
    }
    await firestore
        .collection('productions')
        .doc(production.id.trim())
        .update(production.toMap());
  }

  /// Deletes a production by document ID in Firestore.
  /// Propagates failures to the caller.
  Future<void> deleteProduction(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('Production ID cannot be empty for deletion.');
    }
    await firestore.collection('productions').doc(id.trim()).delete();
  }

  static void _sortProductions(List<Production> list) {
    list.sort((a, b) {
      final aDate = a.startDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.startDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = bDate.compareTo(aDate);
      if (cmp != 0) return cmp;
      if (a.createdAt != null && b.createdAt != null) {
        final createdCmp = b.createdAt!.compareTo(a.createdAt!);
        if (createdCmp != 0) return createdCmp;
      }
      return a.title.compareTo(b.title);
    });
  }

  void dispose() {}
}
