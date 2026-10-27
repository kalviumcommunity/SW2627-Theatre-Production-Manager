import 'package:cloud_functions/cloud_functions.dart';

import '../exceptions/venue_booking_exception.dart';
import 'venue_booking_gateway.dart';

/// Sends every live booking mutation through the trusted transactional backend.
class VenueAvailabilityService implements VenueBookingGateway {
  final FirebaseFunctions? functionsOverride;

  const VenueAvailabilityService({this.functionsOverride});

  FirebaseFunctions get functions =>
      functionsOverride ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<String> saveBooking({
    required String eventType,
    required String action,
    required Map<String, dynamic> booking,
  }) async {
    try {
      final result = await functions.httpsCallable('saveVenueBooking').call({
        'eventType': eventType,
        'action': action,
        'booking':
            {
                ...booking,
                if (booking['startTime'] is DateTime)
                  'startTimeMillis':
                      (booking['startTime'] as DateTime).millisecondsSinceEpoch,
                if (booking['endTime'] is DateTime)
                  'endTimeMillis':
                      (booking['endTime'] as DateTime).millisecondsSinceEpoch,
              }
              ..remove('startTime')
              ..remove('endTime'),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['id'] as String;
    } on FirebaseFunctionsException catch (error) {
      throw mapVenueBookingFunctionsException(error);
    }
  }

  @override
  Future<void> cancelAudition({
    required String auditionId,
    String? reason,
  }) async {
    await functions.httpsCallable('saveVenueBooking').call({
      'eventType': 'audition',
      'action': 'cancel',
      'id': auditionId,
      'reason': reason,
    });
  }

  @override
  Future<void> deleteBooking({
    required String eventType,
    required String id,
  }) async {
    await functions.httpsCallable('saveVenueBooking').call({
      'eventType': eventType,
      'action': 'delete',
      'id': id,
    });
  }
}
