import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/venue_model.dart';

class VenueValidationException implements Exception {
  final String message;
  const VenueValidationException(this.message);

  @override
  String toString() => message;
}

class VenueConflictInfo {
  final String title;
  final String type; // 'Rehearsal' or 'Audition'
  final DateTime startTime;
  final DateTime endTime;

  VenueConflictInfo({
    required this.title,
    required this.type,
    required this.startTime,
    required this.endTime,
  });

  String get formattedRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}

class VenueService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;

  VenueService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _customFirestore = firestore,
      _customFunctions = functions;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseFunctions get functions =>
      _customFunctions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  void validateVenue(Venue venue) {
    if (venue.name.trim().isEmpty) {
      throw const VenueValidationException('Venue name is required.');
    }
    if (venue.capacity <= 0) {
      throw const VenueValidationException(
        'Venue capacity must be greater than zero.',
      );
    }
  }

  Future<Venue> createVenue(Venue venue) async {
    validateVenue(venue);
    final id = venue.id.trim().isNotEmpty
        ? venue.id.trim()
        : firestore.collection('venues').doc().id;
    await _mutateVenue('create', venue.copyWith(id: id));
    return venue.copyWith(id: id);
  }

  Future<void> updateVenue(Venue venue) async {
    if (venue.id.trim().isEmpty) {
      throw ArgumentError('Venue ID cannot be empty for update.');
    }
    validateVenue(venue);
    await _mutateVenue('update', venue);
  }

  Future<void> deleteVenue(String venueId) async {
    if (venueId.trim().isEmpty) {
      throw ArgumentError('Venue ID cannot be empty for deletion.');
    }
    await functions.httpsCallable('manageVenue').call({
      'action': 'delete',
      'venue': {'id': venueId.trim()},
    });
  }

  Future<void> _mutateVenue(String action, Venue venue) async {
    try {
      await functions.httpsCallable('manageVenue').call({
        'action': action,
        'venue': {
          'id': venue.id.trim(),
          'name': venue.name.trim(),
          'address': venue.address.trim(),
          'capacity': venue.capacity,
          'description': venue.description.trim(),
          'facilities': venue.facilities,
        },
      });
    } on FirebaseFunctionsException catch (error) {
      throw VenueValidationException(error.message ?? 'Venue update failed.');
    }
  }

  Future<Venue?> getVenue(String venueId) async {
    if (venueId.trim().isEmpty) return null;
    final doc = await firestore.collection('venues').doc(venueId.trim()).get();
    if (!doc.exists || doc.data() == null || doc.data()!['deleted'] == true) {
      return null;
    }
    return Venue.fromMap(doc.data()!, doc.id);
  }

  Stream<List<Venue>> streamVenues() {
    try {
      return firestore
          .collection('venues')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .where((doc) => doc.data()['deleted'] != true)
                .map((doc) => Venue.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (_) {
      return Stream.value([]);
    }
  }

  Future<List<Venue>> getVenues() async {
    try {
      final snapshot = await firestore.collection('venues').get();
      return snapshot.docs
          .where((doc) => doc.data()['deleted'] != true)
          .map((doc) => Venue.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Checks for overlapping commitments (Rehearsals or Auditions) at the given venue.
  Future<List<VenueConflictInfo>> checkConflicts({
    required String venueNameOrId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeRehearsalId,
    String? excludeAuditionId,
  }) async {
    final normalized = venueNameOrId.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final conflicts = <VenueConflictInfo>[];

    // Check rehearsals
    final rehSnapshot = await firestore.collection('rehearsals').get();
    for (final doc in rehSnapshot.docs) {
      if (excludeRehearsalId != null && doc.id == excludeRehearsalId) continue;
      final data = doc.data();
      final vName = (data['venueName'] as String? ?? '').trim().toLowerCase();
      final vId = (data['venueId'] as String? ?? '').trim().toLowerCase();
      final vLegacy = (data['venue'] as String? ?? '').trim().toLowerCase();

      final matchesVenue =
          vName == normalized || vId == normalized || vLegacy == normalized;
      if (!matchesVenue) continue;

      DateTime? docStart = (data['startTime'] as Timestamp?)?.toDate();
      DateTime? docEnd = (data['endTime'] as Timestamp?)?.toDate();
      if (docStart == null || docEnd == null) continue;

      // Overlap condition: docStart < endTime && docEnd > startTime
      if (docStart.isBefore(endTime) && docEnd.isAfter(startTime)) {
        conflicts.add(
          VenueConflictInfo(
            title: (data['title'] as String? ?? 'Rehearsal').trim(),
            type: 'Rehearsal',
            startTime: docStart,
            endTime: docEnd,
          ),
        );
      }
    }

    // Check auditions
    final audSnapshot = await firestore.collection('auditions').get();
    for (final doc in audSnapshot.docs) {
      if (excludeAuditionId != null && doc.id == excludeAuditionId) continue;
      final data = doc.data();
      final v = (data['venue'] as String? ?? '').trim().toLowerCase();
      if (v != normalized) continue;

      // Ignore cancelled auditions
      final status = (data['status'] as String? ?? '').trim();
      if (status == 'Cancelled') continue;

      DateTime? docStart = (data['startTime'] as Timestamp?)?.toDate();
      DateTime? docEnd = (data['endTime'] as Timestamp?)?.toDate();
      if (docStart == null || docEnd == null) continue;

      if (docStart.isBefore(endTime) && docEnd.isAfter(startTime)) {
        conflicts.add(
          VenueConflictInfo(
            title: (data['title'] as String? ?? 'Audition').trim(),
            type: 'Audition',
            startTime: docStart,
            endTime: docEnd,
          ),
        );
      }
    }

    return conflicts;
  }
}
