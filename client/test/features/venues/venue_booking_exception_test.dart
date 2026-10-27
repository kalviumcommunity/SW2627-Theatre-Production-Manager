import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/venues/exceptions/venue_booking_exception.dart';

void main() {
  group('venue booking callable error mapping', () {
    test(
      'maps a venue conflict into the shared booking conflict exception',
      () {
        final mapped = mapVenueBookingFunctionsException(
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Venue is occupied.',
            details: {'reason': 'venue-conflict'},
          ),
        );
        expect(mapped, isA<VenueBookingConflictException>());
        expect(
          (mapped as VenueBookingConflictException).message,
          'Venue is occupied.',
        );
      },
    );

    test('maps legacy booking data problems into a review exception', () {
      final mapped = mapVenueBookingFunctionsException(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Existing data needs correction.',
          details: {'reason': 'booking-data-review'},
        ),
      );
      expect(mapped, isA<VenueBookingDataReviewException>());
    });

    test('preserves unrelated callable errors', () {
      final original = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Only directors may manage bookings.',
      );
      expect(mapVenueBookingFunctionsException(original), same(original));
    });
  });
}
