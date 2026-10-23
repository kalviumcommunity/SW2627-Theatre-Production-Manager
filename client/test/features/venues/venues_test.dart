import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/venues/models/venue_model.dart';
import 'package:client/features/venues/screens/add_edit_venue_screen.dart';
import 'package:client/features/venues/screens/venue_details_screen.dart';
import 'package:client/features/venues/screens/venues_screen.dart';
import 'package:client/features/venues/services/venue_service.dart';
import 'package:client/features/venues/widgets/venue_card.dart';

class _FakeVenueService extends VenueService {
  final List<Venue> venues;
  Venue? lastCreatedVenue;
  Venue? lastUpdatedVenue;
  String? lastDeletedVenueId;

  _FakeVenueService({List<Venue>? initialVenues})
      : venues = initialVenues ?? [];

  @override
  Stream<List<Venue>> streamVenues() => Stream.value(venues);

  @override
  Future<List<Venue>> getVenues() async => venues;

  @override
  Future<Venue?> getVenue(String id) async {
    try {
      return venues.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Venue> createVenue(Venue venue) async {
    validateVenue(venue);
    final created = venue.copyWith(id: 'venue-${venues.length + 1}');
    venues.add(created);
    lastCreatedVenue = created;
    return created;
  }

  @override
  Future<void> updateVenue(Venue venue) async {
    validateVenue(venue);
    final index = venues.indexWhere((v) => v.id == venue.id);
    if (index != -1) {
      venues[index] = venue;
    }
    lastUpdatedVenue = venue;
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    venues.removeWhere((v) => v.id == venueId);
    lastDeletedVenueId = venueId;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  group('Venue Model & Validation Tests', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime(2026, 11, 1, 10, 0);
      final venue = Venue(
        id: 'venue-1',
        name: 'Main Auditorium',
        address: '100 Broadway Ave',
        capacity: 350,
        description: 'Primary proscenium stage',
        facilities: const ['Sound System', 'Fly Tower', 'Dressing Rooms'],
        createdAt: now,
      );

      final map = venue.toMap();
      expect(map['name'], 'Main Auditorium');
      expect(map['address'], '100 Broadway Ave');
      expect(map['capacity'], 350);
      expect(map['description'], 'Primary proscenium stage');
      expect(map['facilities'], ['Sound System', 'Fly Tower', 'Dressing Rooms']);

      final reconstructed = Venue.fromMap({
        'name': 'Main Auditorium',
        'address': '100 Broadway Ave',
        'capacity': 350,
        'description': 'Primary proscenium stage',
        'facilities': ['Sound System', 'Fly Tower', 'Dressing Rooms'],
        'createdAt': now,
      }, 'venue-1');

      expect(reconstructed.id, 'venue-1');
      expect(reconstructed.name, 'Main Auditorium');
      expect(reconstructed.capacity, 350);
      expect(reconstructed.facilities.length, 3);
    });

    test('validates positive capacity and required name', () {
      final service = VenueService(firestore: null);

      expect(
        () => service.validateVenue(const Venue(id: '', name: '', capacity: 100)),
        throwsA(isA<VenueValidationException>()),
      );

      expect(
        () => service.validateVenue(const Venue(id: '', name: 'Hall', capacity: 0)),
        throwsA(isA<VenueValidationException>()),
      );

      expect(
        () => service.validateVenue(const Venue(id: '', name: 'Hall', capacity: -5)),
        throwsA(isA<VenueValidationException>()),
      );

      expect(
        () => service.validateVenue(const Venue(id: '', name: 'Hall', capacity: 50)),
        returnsNormally,
      );
    });
  });

  group('VenueCard Tests', () {
    testWidgets('renders name, address, capacity, and facilities', (tester) async {
      bool tapped = false;
      const venue = Venue(
        id: 'v1',
        name: 'Black Box Theatre',
        address: 'West Wing Studio 3',
        capacity: 75,
        description: 'Flexible staging environment',
        facilities: ['Flexible Seating', 'Dimmers'],
      );

      await tester.pumpWidget(_wrap(
        VenueCard(
          venue: venue,
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('Black Box Theatre'), findsOneWidget);
      expect(find.text('West Wing Studio 3'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('Flexible staging environment'), findsOneWidget);
      expect(find.text('Flexible Seating'), findsOneWidget);

      await tester.tap(find.byType(VenueCard));
      expect(tapped, isTrue);
    });
  });

  group('VenuesScreen Tests', () {
    testWidgets('renders empty state when no venues exist', (tester) async {
      final fakeService = _FakeVenueService(initialVenues: []);

      await tester.pumpWidget(_wrap(
        VenuesScreen(
          venueService: fakeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No venues configured yet.'), findsOneWidget);
      expect(find.byKey(const Key('venue_search_input')), findsOneWidget);
    });

    testWidgets('renders venue list and filters by search query', (tester) async {
      final fakeService = _FakeVenueService(initialVenues: [
        const Venue(id: 'v1', name: 'Main Hall', capacity: 300, address: 'Building A'),
        const Venue(id: 'v2', name: 'Studio B', capacity: 40, address: 'Building B'),
      ]);

      await tester.pumpWidget(_wrap(
        VenuesScreen(
          venueService: fakeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Main Hall'), findsOneWidget);
      expect(find.text('Studio B'), findsOneWidget);

      // Search Studio
      await tester.enterText(find.byKey(const Key('venue_search_input')), 'Studio');
      await tester.pumpAndSettle();

      expect(find.text('Studio B'), findsOneWidget);
      expect(find.text('Main Hall'), findsNothing);
    });
  });

  group('AddEditVenueScreen Tests', () {
    testWidgets('validates required name and positive capacity', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FakeVenueService();

      await tester.pumpWidget(_wrap(
        AddEditVenueScreen(venueService: fakeService),
      ));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.ensureVisible(find.byKey(const Key('save_venue_button')));
      await tester.tap(find.byKey(const Key('save_venue_button')));
      await tester.pumpAndSettle();

      expect(find.text('Venue name is required.'), findsOneWidget);
      expect(find.text('Capacity is required.'), findsOneWidget);
    });

    testWidgets('creates venue with valid input and facilities', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FakeVenueService();

      await tester.pumpWidget(_wrap(
        AddEditVenueScreen(venueService: fakeService),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('venue_name_input')), 'Opera Hall');
      await tester.enterText(find.byKey(const Key('venue_address_input')), '12 Opera Way');
      await tester.enterText(find.byKey(const Key('venue_capacity_input')), '450');
      await tester.enterText(find.byKey(const Key('venue_facility_input')), 'Grand Piano');

      await tester.ensureVisible(find.byKey(const Key('add_facility_button')));
      await tester.tap(find.byKey(const Key('add_facility_button')));
      await tester.pumpAndSettle();

      expect(find.text('Grand Piano'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('save_venue_button')));
      await tester.tap(find.byKey(const Key('save_venue_button')));
      await tester.pumpAndSettle();

      expect(fakeService.lastCreatedVenue, isNotNull);
      expect(fakeService.lastCreatedVenue!.name, 'Opera Hall');
      expect(fakeService.lastCreatedVenue!.capacity, 450);
      expect(fakeService.lastCreatedVenue!.facilities, contains('Grand Piano'));
    });
  });

  group('VenueDetailsScreen Tests', () {
    testWidgets('renders venue details and triggers delete with confirmation', (tester) async {
      final fakeService = _FakeVenueService();
      const venue = Venue(
        id: 'v-del',
        name: 'Old Studio',
        capacity: 20,
        address: 'Basement',
        description: 'Dusty storage space',
      );

      await tester.pumpWidget(_wrap(
        VenueDetailsScreen(
          venue: venue,
          venueService: fakeService,
          isDirector: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Old Studio'), findsWidgets);
      expect(find.text('Basement'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      // Tap delete
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Venue'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fakeService.lastDeletedVenueId, 'v-del');
    });
  });
}
