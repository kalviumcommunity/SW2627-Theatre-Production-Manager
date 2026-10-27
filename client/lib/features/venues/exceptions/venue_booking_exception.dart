import 'package:cloud_functions/cloud_functions.dart';

class VenueBookingConflictException implements Exception {
  final String message;
  const VenueBookingConflictException(this.message);

  @override
  String toString() => message;
}

class VenueBookingDataReviewException implements Exception {
  final String message;
  const VenueBookingDataReviewException(this.message);

  @override
  String toString() => message;
}

Exception mapVenueBookingFunctionsException(FirebaseFunctionsException error) {
  if (error.code == 'failed-precondition' && error.details is Map) {
    final details = Map<String, dynamic>.from(error.details as Map);
    final message = error.message ?? 'Booking could not be saved.';
    if (details['reason'] == 'venue-conflict') {
      return VenueBookingConflictException(message);
    }
    if (details['reason'] == 'booking-data-review') {
      return VenueBookingDataReviewException(message);
    }
  }
  return error;
}
