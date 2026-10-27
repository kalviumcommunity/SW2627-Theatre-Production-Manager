import '../models/rehearsal_model.dart';
import '../../venues/exceptions/venue_booking_exception.dart';

/// Exception thrown when a rehearsal fails input validation (e.g. empty fields, invalid times).
class RehearsalValidationException implements Exception {
  final String message;
  const RehearsalValidationException(this.message);

  @override
  String toString() => 'RehearsalValidationException: $message';
}

/// Exception thrown when a rehearsal conflicts with an existing booking at the same venue.
class VenueConflictException extends VenueBookingConflictException {
  final Rehearsal conflictingRehearsal;
  final Rehearsal requestedRehearsal;

  const VenueConflictException({
    required String message,
    required this.conflictingRehearsal,
    required this.requestedRehearsal,
  }) : super(message);
}
