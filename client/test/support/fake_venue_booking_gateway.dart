import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:client/features/venues/services/venue_booking_gateway.dart';

/// In-memory mutation adapter for unit tests. Production services default to
/// the callable gateway; this adapter must be injected explicitly by a test.
class FakeVenueBookingGateway implements VenueBookingGateway {
  FakeVenueBookingGateway(this.firestore);

  final FirebaseFirestore firestore;

  Map<String, dynamic> _firestoreData(Map<String, dynamic> booking) {
    final data = Map<String, dynamic>.from(booking);
    for (final field in ['startTime', 'endTime']) {
      final value = data[field];
      if (value is DateTime) data[field] = Timestamp.fromDate(value);
    }
    data.remove('id');
    return data;
  }

  @override
  Future<String> saveBooking({
    required String eventType,
    required String action,
    required Map<String, dynamic> booking,
  }) async {
    final collection = firestore.collection(
      eventType == 'audition' ? 'auditions' : 'rehearsals',
    );
    final id = booking['id'] as String;
    final reference = collection.doc(id);
    final data = _firestoreData(booking);
    if (action == 'create') {
      await reference.set(data);
    } else {
      await reference.update(data);
    }
    return id;
  }

  @override
  Future<void> cancelAudition({
    required String auditionId,
    String? reason,
  }) async {
    await firestore.collection('auditions').doc(auditionId).update({
      'status': 'Cancelled',
      if (reason != null && reason.trim().isNotEmpty)
        'cancellationReason': reason.trim(),
    });
  }

  @override
  Future<void> deleteBooking({
    required String eventType,
    required String id,
  }) async {
    await firestore
        .collection(eventType == 'audition' ? 'auditions' : 'rehearsals')
        .doc(id)
        .delete();
  }
}
