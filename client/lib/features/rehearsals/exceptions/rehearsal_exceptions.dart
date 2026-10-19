import '../models/rehearsal_model.dart';

/// Exception thrown when a rehearsal fails input validation (e.g. empty fields, invalid times).
class RehearsalValidationException implements Exception {
  final String message;
  const RehearsalValidationException(this.message);

  @override
  String toString() => 'RehearsalValidationException: $message';
}

/// Exception thrown when a rehearsal conflicts with an existing booking at the same venue.
class VenueConflictException implements Exception {
  final String message;
  final Rehearsal conflictingRehearsal;
  final Rehearsal requestedRehearsal;

  const VenueConflictException({
    required this.message,
    required this.conflictingRehearsal,
    required this.requestedRehearsal,
  });

  @override
  String toString() => 'VenueConflictException: $message';
}
