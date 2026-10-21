class AuditionException implements Exception {
  final String message;
  const AuditionException(this.message);

  @override
  String toString() => message;
}

class AuditionValidationException extends AuditionException {
  const AuditionValidationException(super.message);
}

class AuditionNotFoundException extends AuditionException {
  const AuditionNotFoundException([super.message = 'Audition not found.']);
}
