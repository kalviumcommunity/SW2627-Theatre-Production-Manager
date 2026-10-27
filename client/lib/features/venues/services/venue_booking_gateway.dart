abstract interface class VenueBookingGateway {
  Future<String> saveBooking({
    required String eventType,
    required String action,
    required Map<String, dynamic> booking,
  });

  Future<void> cancelAudition({required String auditionId, String? reason});

  Future<void> deleteBooking({required String eventType, required String id});
}
