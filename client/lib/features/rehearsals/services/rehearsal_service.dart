import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/rehearsal_exceptions.dart';
import '../models/rehearsal_model.dart';

class RehearsalService {
  final FirebaseFirestore? _customFirestore;

  RehearsalService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Helper to test if two time intervals [startA, endA) and [startB, endB) overlap.
  /// Adjacent intervals (where endA == startB or endB == startA) do NOT overlap.
  static bool intervalsOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  /// Normalizes venue identifier for conflict comparisons.
  static String normalizeVenue(String venue) => venue.trim().toLowerCase();

  /// Validates standard fields of a [Rehearsal].
  /// Throws [RehearsalValidationException] if any validation fails.
  void validateRehearsal(Rehearsal rehearsal) {
    if (rehearsal.productionId.trim().isEmpty) {
      throw const RehearsalValidationException('Production ID is required.');
    }

    if (rehearsal.venueId.trim().isEmpty && rehearsal.venueName.trim().isEmpty) {
      throw const RehearsalValidationException('Venue is required.');
    }

    if (rehearsal.creatorUid.trim().isEmpty) {
      throw const RehearsalValidationException('Creator UID is required.');
    }

    if (rehearsal.startTime == rehearsal.endTime) {
      throw const RehearsalValidationException(
        'End time must be after start time (rehearsal duration cannot be zero).',
      );
    }

    if (!rehearsal.isValidTimeRange) {
      throw const RehearsalValidationException(
        'End time must be strictly after start time.',
      );
    }
  }

  /// Validates that the referenced production document exists in Firestore.
  /// Throws [RehearsalValidationException] if not found.
  Future<void> validateProductionReference(String productionId) async {
    final prodDoc = await firestore
        .collection('productions')
        .doc(productionId.trim())
        .get();

    if (!prodDoc.exists) {
      throw RehearsalValidationException(
        'Referenced production does not exist: $productionId',
      );
    }
  }

  /// Checks if two rehearsals reference the same venue, comparing IDs, names, and canonical labels.
  static bool isSameVenue(Rehearsal a, Rehearsal b) {
    final aId = normalizeVenue(a.venueId);
    final bId = normalizeVenue(b.venueId);
    if (aId.isNotEmpty && bId.isNotEmpty && aId == bId) {
      return true;
    }

    final aName = normalizeVenue(a.venueName);
    final bName = normalizeVenue(b.venueName);
    if (aName.isNotEmpty && bName.isNotEmpty && aName == bName) {
      return true;
    }

    final aCanonical = normalizeVenue(a.venue);
    final bCanonical = normalizeVenue(b.venue);
    if (aCanonical.isNotEmpty && bCanonical.isNotEmpty) {
      if (aCanonical == bCanonical ||
          (bId.isNotEmpty && aCanonical == bId) ||
          (aId.isNotEmpty && aId == bCanonical) ||
          (bName.isNotEmpty && aCanonical == bName) ||
          (aName.isNotEmpty && aName == bCanonical)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if the requested rehearsal conflicts with any existing booking at the same venue.
  /// Returns the conflicting [Rehearsal] if an overlap is found, or null otherwise.
  /// [excludeRehearsalId] ignores a specific document ID (critical when editing).
  Future<Rehearsal?> findConflictingRehearsal(
    Rehearsal rehearsal, {
    String? excludeRehearsalId,
  }) async {
    final excludeId = excludeRehearsalId?.trim() ??
        (rehearsal.id.trim().isNotEmpty ? rehearsal.id.trim() : null);

    final snapshot = await firestore.collection('rehearsals').get();

    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) {
        continue;
      }

      final existing = Rehearsal.fromFirestore(doc);

      if (!isSameVenue(rehearsal, existing)) {
        continue;
      }

      if (intervalsOverlap(
        rehearsal.startTime,
        rehearsal.endTime,
        existing.startTime,
        existing.endTime,
      )) {
        return existing;
      }
    }

    return null;
  }

  /// Returns true if a conflicting booking exists at the same venue.
  Future<bool> hasVenueConflict(
    Rehearsal rehearsal, {
    String? excludeRehearsalId,
  }) async {
    final conflict = await findConflictingRehearsal(
      rehearsal,
      excludeRehearsalId: excludeRehearsalId,
    );
    return conflict != null;
  }

  /// Creates a new rehearsal in Firestore after verifying validations,
  /// production reference, and venue conflict detection.
  Future<Rehearsal> createRehearsal(
    Rehearsal rehearsal, {
    bool checkProductionExists = true,
  }) async {
    validateRehearsal(rehearsal);

    if (checkProductionExists) {
      await validateProductionReference(rehearsal.productionId);
    }

    final conflict = await findConflictingRehearsal(rehearsal);
    if (conflict != null) {
      throw VenueConflictException(
        message: 'Venue "${rehearsal.venue}" is already booked for "${conflict.title}" '
            'from ${conflict.startTime} to ${conflict.endTime}.',
        conflictingRehearsal: conflict,
        requestedRehearsal: rehearsal,
      );
    }

    final docRef = await firestore
        .collection('rehearsals')
        .add(rehearsal.toMap());

    return rehearsal.copyWith(id: docRef.id);
  }

  /// Updates an existing rehearsal in Firestore.
  /// Validates time range, production reference, and conflicts (excluding the edited rehearsal itself).
  Future<void> updateRehearsal(
    Rehearsal rehearsal, {
    bool checkProductionExists = true,
  }) async {
    if (rehearsal.id.trim().isEmpty) {
      throw ArgumentError('Rehearsal ID cannot be empty for update.');
    }

    validateRehearsal(rehearsal);

    if (checkProductionExists) {
      await validateProductionReference(rehearsal.productionId);
    }

    final conflict = await findConflictingRehearsal(
      rehearsal,
      excludeRehearsalId: rehearsal.id,
    );
    if (conflict != null) {
      throw VenueConflictException(
        message: 'Venue "${rehearsal.venue}" is already booked for "${conflict.title}" '
            'from ${conflict.startTime} to ${conflict.endTime}.',
        conflictingRehearsal: conflict,
        requestedRehearsal: rehearsal,
      );
    }

    await firestore
        .collection('rehearsals')
        .doc(rehearsal.id.trim())
        .update(rehearsal.toMap());
  }

  /// Deletes a rehearsal by document ID.
  Future<void> deleteRehearsal(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('Rehearsal ID cannot be empty for deletion.');
    }
    await firestore.collection('rehearsals').doc(id.trim()).delete();
  }

  /// Retrieves a rehearsal by document ID.
  Future<Rehearsal?> getRehearsalById(String id) async {
    if (id.trim().isEmpty) return null;
    final doc = await firestore.collection('rehearsals').doc(id.trim()).get();
    if (!doc.exists) return null;
    return Rehearsal.fromFirestore(doc);
  }

  /// Fetches rehearsals chronologically sorted by start time.
  /// Optional filters by [productionId] and [venueId].
  Future<List<Rehearsal>> getRehearsals({
    String? productionId,
    String? venueId,
  }) async {
    final snapshot = await firestore.collection('rehearsals').get();
    final list = snapshot.docs
        .map((doc) => Rehearsal.fromFirestore(doc))
        .where((r) {
          if (productionId != null && r.productionId != productionId) {
            return false;
          }
          if (venueId != null) {
            final target = normalizeVenue(venueId);
            final matches = normalizeVenue(r.venueId) == target ||
                normalizeVenue(r.venueName) == target ||
                normalizeVenue(r.venue) == target;
            if (!matches) return false;
          }
          return true;
        })
        .toList();

    _sortRehearsalsChronologically(list);
    return list;
  }

  /// Streams rehearsals chronologically sorted by start time.
  Stream<List<Rehearsal>> streamRehearsals({
    String? productionId,
    String? venueId,
  }) {
    try {
      return firestore.collection('rehearsals').snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Rehearsal.fromFirestore(doc))
            .where((r) {
              if (productionId != null && r.productionId != productionId) {
                return false;
              }
              if (venueId != null) {
                final target = normalizeVenue(venueId);
                final matches = normalizeVenue(r.venueId) == target ||
                    normalizeVenue(r.venueName) == target ||
                    normalizeVenue(r.venue) == target;
                if (!matches) return false;
              }
              return true;
            })
            .toList();

        _sortRehearsalsChronologically(list);
        return list;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Fetches rehearsals for a specific production.
  Future<List<Rehearsal>> getRehearsalsByProduction(String productionId) {
    return getRehearsals(productionId: productionId);
  }

  /// Fetches rehearsals for a specific venue.
  Future<List<Rehearsal>> getRehearsalsByVenue(String venueId) {
    return getRehearsals(venueId: venueId);
  }

  static void _sortRehearsalsChronologically(List<Rehearsal> list) {
    list.sort((a, b) {
      final cmp = a.startTime.compareTo(b.startTime);
      if (cmp != 0) return cmp;
      return a.endTime.compareTo(b.endTime);
    });
  }

  void dispose() {}
}
