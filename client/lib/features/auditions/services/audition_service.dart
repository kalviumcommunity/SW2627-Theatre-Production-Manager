import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../exceptions/audition_exceptions.dart';
import '../models/audition_model.dart';
import '../../venues/services/venue_availability_service.dart';
import '../../venues/services/venue_booking_gateway.dart';

class AuditionService {
  final FirebaseFirestore? _customFirestore;
  final VenueBookingGateway? bookingGateway;

  AuditionService({FirebaseFirestore? firestore, this.bookingGateway})
    : _customFirestore = firestore;

  VenueBookingGateway get _bookingGatewayOrDefault =>
      bookingGateway ?? VenueAvailabilityService();

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Explicit demo/test auditions for fallback or initial rendering.
  static final List<Audition> demoAuditions = List.unmodifiable([
    Audition(
      id: 'aud-demo-1',
      productionId: 'sample-1',
      title: 'Principal Roles (Christine, Raoul, Phantom)',
      venue: 'Main Rehearsal Hall',
      startTime: DateTime(2026, 11, 5, 10, 0),
      endTime: DateTime(2026, 11, 5, 14, 0),
      description: 'Open call for principal vocalists and actors.',
      requirements: 'Prepare 32 bars of classical or musical theatre; sheet music required.',
      status: AuditionStatus.scheduled,
      creatorUid: 'director-demo',
      createdAt: DateTime(2026, 10, 20),
    ),
    Audition(
      id: 'aud-demo-2',
      productionId: 'sample-2',
      title: 'Fairies & Mechanicals Ensemble',
      venue: 'Studio Theatre A',
      startTime: DateTime(2026, 11, 12, 13, 0),
      endTime: DateTime(2026, 11, 12, 17, 0),
      description: 'Movement and comedic reading auditions.',
      requirements: 'Wear comfortable movement attire. Sides will be provided.',
      status: AuditionStatus.scheduled,
      creatorUid: 'director-demo',
      createdAt: DateTime(2026, 10, 21),
    ),
  ]);

  /// Validates standard fields of an [Audition].
  /// Throws [AuditionValidationException] if validation fails.
  void validateAudition(Audition audition) {
    if (audition.productionId.trim().isEmpty) {
      throw const AuditionValidationException('Production ID is required.');
    }

    if (audition.title.trim().isEmpty) {
      throw const AuditionValidationException('Audition title is required.');
    }

    if (audition.venue.trim().isEmpty) {
      throw const AuditionValidationException('Venue is required.');
    }

    if (audition.creatorUid.trim().isEmpty) {
      throw const AuditionValidationException('Creator UID is required.');
    }

    if (audition.startTime == audition.endTime) {
      throw const AuditionValidationException(
        'End time must be after start time (audition duration cannot be zero).',
      );
    }

    if (!audition.isValidTimeRange) {
      throw const AuditionValidationException(
        'End time must be strictly after start time.',
      );
    }
  }

  /// Validates that the referenced production document exists in Firestore.
  /// Throws [AuditionValidationException] if not found.
  Future<void> validateProductionReference(String productionId) async {
    final prodDoc = await firestore
        .collection('productions')
        .doc(productionId.trim())
        .get();

    if (!prodDoc.exists) {
      throw AuditionValidationException(
        'Referenced production does not exist: $productionId',
      );
    }
  }

  /// Creates a new audition document in Firestore.
  Future<Audition> createAudition(
    Audition audition, {
    bool checkProductionExists = true,
  }) async {
    validateAudition(audition);

    if (checkProductionExists) {
      await validateProductionReference(audition.productionId);
    }

    final collection = firestore.collection('auditions');
    final docRef = audition.id.isNotEmpty
        ? collection.doc(audition.id)
        : collection.doc();

    final toSave = audition.copyWith(
      id: docRef.id,
      createdAt: audition.createdAt ?? DateTime.now(),
    );
    final savedId = await _bookingGatewayOrDefault.saveBooking(
      eventType: 'audition',
      action: 'create',
      booking: _bookingPayload(toSave),
    );
    return toSave.copyWith(id: savedId);
  }

  /// Updates an existing audition document in Firestore.
  Future<void> updateAudition(
    Audition audition, {
    bool checkProductionExists = true,
  }) async {
    validateAudition(audition);

    if (checkProductionExists) {
      await validateProductionReference(audition.productionId);
    }

    final docRef = firestore.collection('auditions').doc(audition.id);
    final existingDoc = await docRef.get();
    if (!existingDoc.exists) {
      throw AuditionNotFoundException(
        'Cannot update non-existent audition ${audition.id}',
      );
    }

    final toUpdate = audition.copyWith(updatedAt: DateTime.now());

    await _bookingGatewayOrDefault.saveBooking(
      eventType: 'audition',
      action: 'update',
      booking: _bookingPayload(toUpdate),
    );
  }

  /// Cancels an audition safely by changing its status to Cancelled.
  Future<void> cancelAudition(String auditionId, {String? reason}) async {
    if (auditionId.trim().isEmpty) {
      throw const AuditionValidationException(
        'Audition ID is required to cancel.',
      );
    }

    try {
      await _bookingGatewayOrDefault.cancelAudition(
        auditionId: auditionId.trim(),
        reason: reason,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw AuditionNotFoundException(
          'Cannot cancel non-existent audition ${auditionId.trim()}',
        );
      }
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw AuditionNotFoundException(
          'Cannot cancel non-existent audition ${auditionId.trim()}',
        );
      }
      rethrow;
    }
  }

  /// Deletes an audition document permanently (for administrative/testing cleanup).
  Future<void> deleteAudition(String auditionId) async {
    if (auditionId.trim().isEmpty) {
      throw const AuditionValidationException(
        'Audition ID is required to delete.',
      );
    }
    await _bookingGatewayOrDefault.deleteBooking(
      eventType: 'audition',
      id: auditionId.trim(),
    );
  }

  static Map<String, dynamic> _bookingPayload(Audition audition) => {
    'id': audition.id,
    'productionId': audition.productionId,
    'title': audition.title,
    'venue': audition.venue,
    if (audition.venueId != null) 'venueId': audition.venueId,
    'startTime': audition.startTime,
    'endTime': audition.endTime,
    'description': audition.description,
    'requirements': audition.requirements,
    'status': audition.status,
    'creatorUid': audition.creatorUid,
  };

  /// Fetches an audition by ID.
  Future<Audition?> getAuditionById(String auditionId) async {
    if (auditionId.trim().isEmpty) return null;
    final doc = await firestore
        .collection('auditions')
        .doc(auditionId.trim())
        .get();
    if (!doc.exists) return null;
    return Audition.fromFirestore(doc);
  }

  /// Streams auditions, optionally filtered by production ID.
  Stream<List<Audition>> streamAuditions({String? productionId}) {
    try {
      Query query = firestore.collection('auditions');

      if (productionId != null && productionId.trim().isNotEmpty) {
        query = query.where('productionId', isEqualTo: productionId.trim());
      }

      return query.snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Audition.fromFirestore(doc))
            .toList();
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        return list;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Fetches a list of auditions once, optionally filtered by production ID.
  Future<List<Audition>> getAuditions({String? productionId}) async {
    Query query = firestore.collection('auditions');

    if (productionId != null && productionId.trim().isNotEmpty) {
      query = query.where('productionId', isEqualTo: productionId.trim());
    }

    final snapshot = await query.get();
    final list = snapshot.docs
        .map((doc) => Audition.fromFirestore(doc))
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }
}
