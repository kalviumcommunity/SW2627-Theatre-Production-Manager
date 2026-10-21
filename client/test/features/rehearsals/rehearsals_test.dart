import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:client/features/dashboard/screens/dashboard_screen.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/screens/production_details_screen.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/rehearsals/exceptions/rehearsal_exceptions.dart';
import 'package:client/features/rehearsals/models/rehearsal_model.dart';
import 'package:client/features/rehearsals/services/rehearsal_service.dart';
import 'package:client/features/rehearsals/screens/rehearsals_screen.dart';
import 'package:client/features/rehearsals/screens/add_rehearsal_screen.dart';
import 'package:client/features/rehearsals/screens/rehearsal_details_screen.dart';
import 'package:client/features/rehearsals/widgets/rehearsal_card.dart';
import 'package:client/services/auth_service.dart';

// Test mock auth service
class FakeAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);
}

// Test mock service with configurable data, streams, and conflict simulation
class FakeRehearsalService extends RehearsalService {
  List<Rehearsal> customRehearsals;
  bool shouldThrowOnCreate = false;
  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnDelete = false;
  bool shouldThrowStreamError = false;

  bool simulateVenueConflictOnCreate = false;
  bool simulateVenueConflictOnUpdate = false;
  Rehearsal? conflictFixture;

  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  final StreamController<List<Rehearsal>> _controller =
      StreamController<List<Rehearsal>>.broadcast();

  FakeRehearsalService({List<Rehearsal>? initialRehearsals})
    : customRehearsals = initialRehearsals != null
          ? List.from(initialRehearsals)
          : [],
      super();

  @override
  Stream<List<Rehearsal>> streamRehearsals({
    String? productionId,
    String? venueId,
  }) async* {
    if (shouldThrowStreamError) {
      throw Exception('Firestore stream connection failure');
    }
    yield List.unmodifiable(
      _filter(customRehearsals, productionId: productionId, venueId: venueId),
    );
    yield* _controller.stream.map(
      (list) => List.unmodifiable(
        _filter(list, productionId: productionId, venueId: venueId),
      ),
    );
  }

  @override
  Future<List<Rehearsal>> getRehearsals({
    String? productionId,
    String? venueId,
  }) async {
    return _filter(
      customRehearsals,
      productionId: productionId,
      venueId: venueId,
    );
  }

  @override
  Future<Rehearsal?> getRehearsalById(String id) async {
    final index = customRehearsals.indexWhere((r) => r.id == id);
    if (index == -1) return null;
    return customRehearsals[index];
  }

  @override
  Future<Rehearsal> createRehearsal(
    Rehearsal rehearsal, {
    bool checkProductionExists = true,
  }) async {
    createCalls++;
    if (shouldThrowOnCreate) {
      throw Exception('Firestore write permission denied');
    }

    if (simulateVenueConflictOnCreate) {
      final conflict =
          conflictFixture ??
          Rehearsal(
            id: 'conflict-1',
            productionId: 'prod-conflict',
            title: 'Existing Tech Run',
            venueId: rehearsal.venueId,
            venueName: rehearsal.venue,
            startTime: rehearsal.startTime,
            endTime: rehearsal.endTime,
            creatorUid: 'other-user',
          );
      throw VenueConflictException(
        message:
            'Venue "${rehearsal.venue}" is already booked for "${conflict.title}" '
            'from ${conflict.startTime} to ${conflict.endTime}.',
        conflictingRehearsal: conflict,
        requestedRehearsal: rehearsal,
      );
    }

    final created = rehearsal.copyWith(
      id: rehearsal.id.isNotEmpty
          ? rehearsal.id
          : 'test-reh-${customRehearsals.length + 1}',
    );
    customRehearsals.add(created);
    _controller.add(List.unmodifiable(customRehearsals));
    return created;
  }

  @override
  Future<void> updateRehearsal(
    Rehearsal rehearsal, {
    bool checkProductionExists = true,
  }) async {
    updateCalls++;
    if (shouldThrowOnUpdate) {
      throw Exception('Firestore update failed');
    }

    if (simulateVenueConflictOnUpdate) {
      final conflict =
          conflictFixture ??
          Rehearsal(
            id: 'conflict-2',
            productionId: 'prod-conflict',
            title: 'Conflicting Staging',
            venueId: rehearsal.venueId,
            venueName: rehearsal.venue,
            startTime: rehearsal.startTime,
            endTime: rehearsal.endTime,
            creatorUid: 'other-user',
          );
      throw VenueConflictException(
        message:
            'Venue "${rehearsal.venue}" is already booked for "${conflict.title}".',
        conflictingRehearsal: conflict,
        requestedRehearsal: rehearsal,
      );
    }

    final index = customRehearsals.indexWhere((r) => r.id == rehearsal.id);
    if (index != -1) {
      customRehearsals[index] = rehearsal;
      _controller.add(List.unmodifiable(customRehearsals));
    }
  }

  @override
  Future<void> deleteRehearsal(String id) async {
    deleteCalls++;
    if (shouldThrowOnDelete) {
      throw Exception('Firestore delete failed');
    }
    customRehearsals.removeWhere((r) => r.id == id);
    _controller.add(List.unmodifiable(customRehearsals));
  }

  List<Rehearsal> _filter(
    List<Rehearsal> source, {
    String? productionId,
    String? venueId,
  }) {
    return source.where((r) {
      if (productionId != null && r.productionId != productionId) return false;
      if (venueId != null && r.venue != venueId) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class FakeProductionServiceForRehearsals extends ProductionService {
  final List<Production> productions;

  FakeProductionServiceForRehearsals({List<Production>? initialProductions})
    : productions =
          initialProductions ??
          [
            Production(id: 'prod-1', title: 'Hamlet', status: 'In Rehearsal'),
            Production(id: 'prod-2', title: 'The Crucible', status: 'Planning'),
          ],
      super();

  @override
  Future<List<Production>> getProductions() async =>
      List.unmodifiable(productions);

  @override
  Stream<List<Production>> streamProductions() async* {
    yield List.unmodifiable(productions);
  }
}

void main() {
  Widget buildApp(Widget home) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B1E3F)),
      ),
      home: home,
    );
  }

  group('RehearsalCard Tests', () {
    testWidgets('renders title, venue badge, date, time window, and duration', (
      WidgetTester tester,
    ) async {
      final rehearsal = Rehearsal(
        id: 'reh-1',
        productionId: 'prod-hamlet',
        title: 'Full Cast Run-Through',
        venueId: 'main-stage',
        venueName: 'Main Auditorium',
        startTime: DateTime(2026, 10, 20, 14, 0),
        endTime: DateTime(2026, 10, 20, 16, 30),
        creatorUid: 'director-1',
        notes: 'Act I and Act II run with stage props',
      );

      bool tapped = false;
      bool edited = false;
      bool deleted = false;

      await tester.pumpWidget(
        buildApp(
          Scaffold(
            body: RehearsalCard(
              rehearsal: rehearsal,
              onTap: () => tapped = true,
              onEdit: () => edited = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Cast Run-Through'), findsOneWidget);
      expect(find.text('Main Auditorium'), findsOneWidget);
      expect(find.textContaining('20 Oct 2026'), findsOneWidget);
      expect(find.textContaining('14:00 – 16:30'), findsOneWidget);
      expect(find.text('2h 30m'), findsOneWidget);
      expect(find.text('Production: prod-hamlet'), findsOneWidget);
      expect(
        find.text('Act I and Act II run with stage props'),
        findsOneWidget,
      );

      // Tap card
      await tester.tap(find.text('Full Cast Run-Through'));
      expect(tapped, isTrue);

      // Tap popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(edited, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });

  group('RehearsalsScreen Tests', () {
    testWidgets('renders empty state when no rehearsals exist', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeRehearsalService(initialRehearsals: []);

      await tester.pumpWidget(
        buildApp(RehearsalsScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Rehearsals Scheduled'), findsOneWidget);
      expect(
        find.text(
          'Schedule your first rehearsal run-through to coordinate call times and stage spaces.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('empty_schedule_rehearsal_button')),
        findsOneWidget,
      );
    });

    testWidgets('renders list of rehearsal cards', (WidgetTester tester) async {
      final rehearsals = [
        Rehearsal(
          id: '1',
          productionId: 'prod-1',
          title: 'Opening Scene Blocking',
          venueId: 'studio-a',
          venueName: 'Studio A',
          startTime: DateTime(2026, 10, 15, 10, 0),
          endTime: DateTime(2026, 10, 15, 12, 0),
          creatorUid: 'user-1',
        ),
        Rehearsal(
          id: '2',
          productionId: 'prod-2',
          title: 'Orchestra & Cast Polish',
          venueId: 'main-stage',
          venueName: 'Main Auditorium',
          startTime: DateTime(2026, 10, 16, 15, 0),
          endTime: DateTime(2026, 10, 16, 18, 0),
          creatorUid: 'user-2',
        ),
      ];
      final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

      await tester.pumpWidget(
        buildApp(RehearsalsScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opening Scene Blocking'), findsOneWidget);
      expect(find.text('Orchestra & Cast Polish'), findsOneWidget);
      expect(find.text('Total scheduled: 2'), findsOneWidget);
    });

    testWidgets('filters rehearsals by search query', (
      WidgetTester tester,
    ) async {
      final rehearsals = [
        Rehearsal(
          id: '1',
          productionId: 'prod-1',
          title: 'Balcony Scene',
          venueId: 'studio-a',
          venueName: 'Studio A',
          startTime: DateTime(2026, 10, 15, 10, 0),
          endTime: DateTime(2026, 10, 15, 12, 0),
          creatorUid: 'user-1',
        ),
        Rehearsal(
          id: '2',
          productionId: 'prod-2',
          title: 'Fight Choreography',
          venueId: 'black-box',
          venueName: 'Black Box',
          startTime: DateTime(2026, 10, 16, 15, 0),
          endTime: DateTime(2026, 10, 16, 18, 0),
          creatorUid: 'user-2',
        ),
      ];
      final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

      await tester.pumpWidget(
        buildApp(RehearsalsScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Fight');
      await tester.pumpAndSettle();

      expect(find.text('Fight Choreography'), findsOneWidget);
      expect(find.text('Balcony Scene'), findsNothing);

      // Search non-existent
      await tester.enterText(searchField, 'NonExistentXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No Matching Rehearsals'), findsOneWidget);
    });

    testWidgets(
      'navigates to AddRehearsalScreen when Schedule Rehearsal is tapped',
      (WidgetTester tester) async {
        final fakeService = FakeRehearsalService(initialRehearsals: []);

        await tester.pumpWidget(
          buildApp(RehearsalsScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        final fab = find.byKey(const Key('add_rehearsal_fab'));
        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(find.byType(AddRehearsalScreen), findsOneWidget);
      },
    );

    testWidgets(
      'surfaces error SnackBar when delete fails from card popup menu',
      (WidgetTester tester) async {
        final fakeService = FakeRehearsalService(
          initialRehearsals: [
            Rehearsal(
              id: '1',
              productionId: 'prod-1',
              title: 'Dress Rehearsal',
              venueId: 'stage-1',
              venueName: 'Main Stage',
              startTime: DateTime(2026, 10, 25, 18, 0),
              endTime: DateTime(2026, 10, 25, 21, 0),
              creatorUid: 'director',
            ),
          ],
        )..shouldThrowOnDelete = true;

        await tester.pumpWidget(
          buildApp(RehearsalsScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        // Open card popup menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap delete in popup menu
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Confirm in dialog
        expect(find.text('Delete Rehearsal'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Failed to delete "Dress Rehearsal"'),
          findsOneWidget,
        );
        expect(fakeService.customRehearsals.length, 1);
      },
    );
  });

  group('AddRehearsalScreen Tests', () {
    testWidgets('shows validation error when submitting with empty title', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeRehearsalService();

      await tester.pumpWidget(
        buildApp(AddRehearsalScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      // Clear title
      final titleField = find.widgetWithText(
        TextFormField,
        'Rehearsal Title *',
      );
      await tester.enterText(titleField, '');

      // Fill production and venue
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Production ID *'),
        'prod-101',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Venue *'),
        'Main Stage',
      );

      final saveButton = find.byKey(const Key('save_rehearsal_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(
        find.text('Rehearsal title is required and cannot be empty.'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error when production ID or venue is empty', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeRehearsalService();

      await tester.pumpWidget(
        buildApp(AddRehearsalScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_rehearsal_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Production ID is required.'), findsOneWidget);
      expect(find.text('Venue is required.'), findsOneWidget);
    });

    testWidgets('validates end time cannot be earlier than start time', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeRehearsalService();

      await tester.pumpWidget(
        buildApp(
          AddRehearsalScreen(
            rehearsalService: fakeService,
            initialRehearsal: Rehearsal(
              id: 'init-1',
              productionId: 'prod-1',
              title: 'Invalid Times Run',
              venueId: 'studio-b',
              venueName: 'Studio B',
              startTime: DateTime(2026, 10, 20, 18, 0),
              endTime: DateTime(2026, 10, 20, 15, 0), // End before start
              creatorUid: 'user-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_rehearsal_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(
        find.text(
          'End time must be after start time (rehearsal duration cannot be zero or negative).',
        ),
        findsOneWidget,
      );
      expect(fakeService.customRehearsals.isEmpty, isTrue);
    });

    testWidgets(
      'surfaces VenueConflictException with prominent alert banner and SnackBar',
      (WidgetTester tester) async {
        final fakeService = FakeRehearsalService()
          ..simulateVenueConflictOnCreate = true;

        await tester.pumpWidget(
          buildApp(AddRehearsalScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Rehearsal Title *'),
          'Afternoon Run',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Production ID *'),
          'prod-conflict',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Venue *'),
          'Auditorium',
        );

        final saveButton = find.byKey(const Key('save_rehearsal_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Expect prominent conflict alert banner
        expect(find.byKey(const Key('venue_conflict_alert')), findsOneWidget);
        expect(find.text('Venue Conflict Detected'), findsOneWidget);
        expect(find.textContaining('already booked'), findsWidgets);
        expect(fakeService.customRehearsals.isEmpty, isTrue);
      },
    );

    testWidgets('successfully creates rehearsal with valid data', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeRehearsalService();

      await tester.pumpWidget(
        buildApp(AddRehearsalScreen(rehearsalService: fakeService)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rehearsal Title *'),
        'Act II Blocking',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Production ID *'),
        'prod-hamlet',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Venue *'),
        'Stage Left Hall',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Rehearsal Notes & Scene Run'),
        'Full cast call for scene 3',
      );

      final saveButton = find.byKey(const Key('save_rehearsal_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeService.customRehearsals.length, 1);
      final created = fakeService.customRehearsals.first;
      expect(created.title, 'Act II Blocking');
      expect(created.productionId, 'prod-hamlet');
      expect(created.venue, 'Stage Left Hall');
      expect(created.notes, 'Full cast call for scene 3');
      expect(fakeService.createCalls, 1);
      expect(fakeService.updateCalls, 0);
    });

    testWidgets('successfully updates existing rehearsal in edit mode', (
      WidgetTester tester,
    ) async {
      final existing = Rehearsal(
        id: 'reh-edit-1',
        productionId: 'prod-1',
        title: 'Original Title',
        venueId: 'venue-1',
        venueName: 'Studio 1',
        startTime: DateTime(2026, 10, 20, 10, 0),
        endTime: DateTime(2026, 10, 20, 12, 0),
        creatorUid: 'user-1',
      );
      final fakeService = FakeRehearsalService(initialRehearsals: [existing]);

      await tester.pumpWidget(
        buildApp(
          AddRehearsalScreen(
            initialRehearsal: existing,
            rehearsalService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Rehearsal'), findsOneWidget);

      final titleField = find.widgetWithText(
        TextFormField,
        'Rehearsal Title *',
      );
      await tester.enterText(titleField, 'Updated Rehearsal Title');

      final saveButton = find.byKey(const Key('save_rehearsal_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        fakeService.customRehearsals.first.title,
        'Updated Rehearsal Title',
      );
      expect(fakeService.updateCalls, 1);
      expect(fakeService.createCalls, 0);
    });

    testWidgets(
      'allows editing historical rehearsal date without date picker assertion crash',
      (WidgetTester tester) async {
        final historicalRehearsal = Rehearsal(
          id: 'reh-hist-1',
          productionId: 'prod-hist',
          title: 'Past Production Archival Run',
          venueId: 'venue-hist',
          venueName: 'Historic Theatre',
          startTime: DateTime(2021, 4, 15, 14, 0),
          endTime: DateTime(2021, 4, 15, 17, 0),
          creatorUid: 'user-hist',
        );
        final fakeService = FakeRehearsalService(
          initialRehearsals: [historicalRehearsal],
        );

        await tester.pumpWidget(
          buildApp(
            AddRehearsalScreen(
              initialRehearsal: historicalRehearsal,
              rehearsalService: fakeService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Rehearsal'), findsOneWidget);
        expect(find.text('15 Apr 2021'), findsOneWidget);

        // Tap on Rehearsal Date tile to open showDatePicker
        await tester.tap(find.text('15 Apr 2021'));
        await tester.pumpAndSettle();

        // Date picker dialog is displayed without assertion crash
        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);

        // Cancel date picker dialog
        await tester.tap(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('15 Apr 2021'), findsOneWidget);
      },
    );
  });

  group('RehearsalDetailsScreen Tests', () {
    testWidgets('renders all rehearsal details and timeline', (
      WidgetTester tester,
    ) async {
      final rehearsal = Rehearsal(
        id: 'det-1',
        productionId: 'prod-macbeth',
        title: 'Macbeth Banquet Scene',
        venueId: 'main-stage',
        venueName: 'Main Theatre Hall',
        startTime: DateTime(2026, 10, 22, 16, 0),
        endTime: DateTime(2026, 10, 22, 19, 0),
        creatorUid: 'dir-1',
        notes: 'Ghost appearance lighting cue review',
      );

      await tester.pumpWidget(
        buildApp(RehearsalDetailsScreen(rehearsal: rehearsal)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rehearsal Details'), findsOneWidget);
      expect(find.text('Macbeth Banquet Scene'), findsOneWidget);
      expect(find.text('Main Theatre Hall'), findsOneWidget);
      expect(find.text('prod-macbeth'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
      expect(find.text('Ghost appearance lighting cue review'), findsOneWidget);
      expect(find.text('Back to Rehearsals List'), findsOneWidget);
    });

    testWidgets('pops back to rehearsals list when back button is tapped', (
      WidgetTester tester,
    ) async {
      final rehearsal = Rehearsal(
        id: 'det-2',
        productionId: 'prod-1',
        title: 'Blocking Run',
        venueId: 'stage-1',
        startTime: DateTime(2026, 10, 22, 10, 0),
        endTime: DateTime(2026, 10, 22, 12, 0),
        creatorUid: 'u-1',
      );

      await tester.pumpWidget(
        buildApp(
          Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (context) =>
                  RehearsalDetailsScreen(rehearsal: rehearsal),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.widgetWithText(
        OutlinedButton,
        'Back to Rehearsals List',
      );
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(RehearsalDetailsScreen), findsNothing);
    });

    testWidgets('deletes rehearsal after confirmation dialog', (
      WidgetTester tester,
    ) async {
      final rehearsal = Rehearsal(
        id: 'det-del-1',
        productionId: 'prod-1',
        title: 'Delete Me Session',
        venueId: 'stage-1',
        startTime: DateTime(2026, 10, 22, 10, 0),
        endTime: DateTime(2026, 10, 22, 12, 0),
        creatorUid: 'u-1',
      );
      final fakeService = FakeRehearsalService(initialRehearsals: [rehearsal]);

      await tester.pumpWidget(
        buildApp(
          RehearsalDetailsScreen(
            rehearsal: rehearsal,
            rehearsalService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap delete icon in AppBar
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Rehearsal'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeService.deleteCalls, 1);
      expect(fakeService.customRehearsals.isEmpty, isTrue);
    });
  });

  group('Rehearsal End-to-End Flow Tests', () {
    testWidgets(
      'full lifecycle: schedule -> list -> details -> edit -> delete',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeService = FakeRehearsalService(initialRehearsals: []);

        await tester.pumpWidget(
          buildApp(RehearsalsScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        // 1. Initial Empty State
        expect(find.text('No Rehearsals Scheduled'), findsOneWidget);

        // 2. Schedule New Rehearsal
        await tester.tap(find.byKey(const Key('add_rehearsal_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(AddRehearsalScreen), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Rehearsal Title *'),
          'Hamlet Final Staging',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Production ID *'),
          'prod-hamlet',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Venue *'),
          'Royal Grand Stage',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Rehearsal Notes & Scene Run'),
          'Final dress run with full cast and orchestra',
        );

        final saveButton = find.byKey(const Key('save_rehearsal_button'));
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // 3. Confirm in List
        expect(find.byType(RehearsalsScreen), findsOneWidget);
        expect(find.text('Hamlet Final Staging'), findsOneWidget);
        expect(find.text('Royal Grand Stage'), findsOneWidget);

        // 4. Open Details
        await tester.tap(find.text('Hamlet Final Staging'));
        await tester.pumpAndSettle();

        expect(find.byType(RehearsalDetailsScreen), findsOneWidget);
        expect(find.text('Rehearsal Details'), findsOneWidget);
        expect(find.text('Royal Grand Stage'), findsOneWidget);

        // 5. Edit Rehearsal from Details
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.byType(AddRehearsalScreen), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Rehearsal Title *'),
          'Hamlet Final Staging (Updated)',
        );

        final editSaveButton = find.byKey(const Key('save_rehearsal_button'));
        await tester.ensureVisible(editSaveButton);
        await tester.tap(editSaveButton);
        await tester.pumpAndSettle();

        // Details updated
        expect(find.text('Hamlet Final Staging (Updated)'), findsOneWidget);

        // 6. Delete from Details
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        // 7. Returned to RehearsalsScreen and empty state restored
        expect(find.byType(RehearsalsScreen), findsOneWidget);
        expect(find.text('No Rehearsals Scheduled'), findsOneWidget);
        expect(fakeService.customRehearsals.isEmpty, isTrue);
      },
    );
  });

  group('Dashboard Rehearsals Tab Integration Tests', () {
    testWidgets(
      'navigates to Rehearsals module when Upcoming Rehearsals card is tapped',
      (WidgetTester tester) async {
        final fakeAuth = FakeAuthService();
        final fakeRehearsalService = FakeRehearsalService(
          initialRehearsals: [
            Rehearsal(
              id: 'dash-reh-1',
              productionId: 'prod-1',
              title: 'Integrated Dashboard Rehearsal',
              venueId: 'stage-main',
              venueName: 'Main Stage',
              startTime: DateTime(2026, 10, 25, 14, 0),
              endTime: DateTime(2026, 10, 25, 16, 0),
              creatorUid: 'user-dash',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(
            DashboardScreen(
              authService: fakeAuth,
              rehearsalService: fakeRehearsalService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on Upcoming Rehearsals metric card
        await tester.tap(find.text('Upcoming Rehearsals').first);
        await tester.pumpAndSettle();

        // RehearsalsScreen is rendered
        expect(find.byType(RehearsalsScreen), findsOneWidget);
        expect(find.text('Integrated Dashboard Rehearsal'), findsOneWidget);
      },
    );
  });

  group('Production Filtering & Deep Integration Tests', () {
    testWidgets(
      'initialProductionFilter displays filter chip and filters rehearsals',
      (WidgetTester tester) async {
        final rehearsals = [
          Rehearsal(
            id: 'reh-p1',
            productionId: 'prod-1',
            title: 'Hamlet Act 1',
            venueId: 'stage-1',
            startTime: DateTime(2026, 11, 1, 10, 0),
            endTime: DateTime(2026, 11, 1, 12, 0),
            creatorUid: 'dir',
          ),
          Rehearsal(
            id: 'reh-p2',
            productionId: 'prod-2',
            title: 'Crucible Scene 2',
            venueId: 'stage-2',
            startTime: DateTime(2026, 11, 2, 14, 0),
            endTime: DateTime(2026, 11, 2, 16, 0),
            creatorUid: 'dir',
          ),
        ];
        final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

        await tester.pumpWidget(
          buildApp(
            RehearsalsScreen(
              rehearsalService: fakeService,
              initialProductionFilter: 'prod-1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only prod-1 item is visible
        expect(find.text('Hamlet Act 1'), findsOneWidget);
        expect(find.text('Crucible Scene 2'), findsNothing);

        // Filter chip for prod-1 exists and is highlighted
        expect(find.widgetWithText(FilterChip, 'prod-1'), findsOneWidget);
      },
    );

    testWidgets(
      'shows active filter chip even when rehearsals list has no entries for that production',
      (WidgetTester tester) async {
        final rehearsals = [
          Rehearsal(
            id: 'reh-p2',
            productionId: 'prod-2',
            title: 'Crucible Scene 2',
            venueId: 'stage-2',
            startTime: DateTime(2026, 11, 2, 14, 0),
            endTime: DateTime(2026, 11, 2, 16, 0),
            creatorUid: 'dir',
          ),
        ];
        final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

        await tester.pumpWidget(
          buildApp(
            RehearsalsScreen(
              rehearsalService: fakeService,
              initialProductionFilter: 'prod-empty',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Empty state shown
        expect(find.text('No Matching Rehearsals'), findsOneWidget);
        // Filter chip for prod-empty exists
        expect(find.widgetWithText(FilterChip, 'prod-empty'), findsOneWidget);
        // Clear Filters button is present
        expect(find.byKey(const Key('clear_filters_button')), findsOneWidget);

        // Tapping Clear Filters restores prod-2 rehearsal
        await tester.tap(find.byKey(const Key('clear_filters_button')));
        await tester.pumpAndSettle();

        expect(find.text('Crucible Scene 2'), findsOneWidget);
        expect(find.text('No Matching Rehearsals'), findsNothing);
      },
    );

    testWidgets(
      'filtered empty state schedule button pre-selects the filtered production ID',
      (WidgetTester tester) async {
        final rehearsals = [
          Rehearsal(
            id: 'reh-p2',
            productionId: 'prod-2',
            title: 'Crucible Scene 2',
            venueId: 'stage-2',
            startTime: DateTime(2026, 11, 2, 14, 0),
            endTime: DateTime(2026, 11, 2, 16, 0),
            creatorUid: 'dir',
          ),
        ];
        final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

        await tester.pumpWidget(
          buildApp(
            RehearsalsScreen(
              rehearsalService: fakeService,
              initialProductionFilter: 'prod-new-target',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scheduleBtn = find.byKey(
          const Key('filtered_schedule_rehearsal_button'),
        );
        expect(scheduleBtn, findsOneWidget);
        await tester.tap(scheduleBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AddRehearsalScreen), findsOneWidget);
        final prodField = find.widgetWithText(TextFormField, 'Production ID *');
        expect(
          find.descendant(
            of: prodField,
            matching: find.text('prod-new-target'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('search query and production filter work together', (
      WidgetTester tester,
    ) async {
      final rehearsals = [
        Rehearsal(
          id: 'reh-1',
          productionId: 'prod-1',
          title: 'Hamlet Act 1 Blocking',
          venueId: 'stage-1',
          startTime: DateTime(2026, 11, 1, 10, 0),
          endTime: DateTime(2026, 11, 1, 12, 0),
          creatorUid: 'dir',
        ),
        Rehearsal(
          id: 'reh-2',
          productionId: 'prod-1',
          title: 'Hamlet Act 2 Music',
          venueId: 'studio-a',
          startTime: DateTime(2026, 11, 1, 14, 0),
          endTime: DateTime(2026, 11, 1, 16, 0),
          creatorUid: 'dir',
        ),
        Rehearsal(
          id: 'reh-3',
          productionId: 'prod-2',
          title: 'Crucible Act 1 Blocking',
          venueId: 'stage-1',
          startTime: DateTime(2026, 11, 2, 10, 0),
          endTime: DateTime(2026, 11, 2, 12, 0),
          creatorUid: 'dir',
        ),
      ];
      final fakeService = FakeRehearsalService(initialRehearsals: rehearsals);

      await tester.pumpWidget(
        buildApp(
          RehearsalsScreen(
            rehearsalService: fakeService,
            initialProductionFilter: 'prod-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both Hamlet rehearsals match prod-1
      expect(find.text('Hamlet Act 1 Blocking'), findsOneWidget);
      expect(find.text('Hamlet Act 2 Music'), findsOneWidget);
      expect(find.text('Crucible Act 1 Blocking'), findsNothing);

      // Now add search query 'Music'
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Music');
      await tester.pumpAndSettle();

      expect(find.text('Hamlet Act 2 Music'), findsOneWidget);
      expect(find.text('Hamlet Act 1 Blocking'), findsNothing);
    });

    testWidgets(
      'navigates from ProductionDetailsScreen into RehearsalsScreen with production filter',
      (WidgetTester tester) async {
        final production = Production(
          id: 'prod-hamlet-detail',
          title: 'Hamlet Showcase',
          status: 'In Rehearsal',
        );
        final fakeRehearsalService = FakeRehearsalService(
          initialRehearsals: [
            Rehearsal(
              id: 'reh-target',
              productionId: 'prod-hamlet-detail',
              title: 'Showcase Run-Through',
              venueId: 'main-stage',
              startTime: DateTime(2026, 11, 10, 10, 0),
              endTime: DateTime(2026, 11, 10, 13, 0),
              creatorUid: 'dir',
            ),
            Rehearsal(
              id: 'reh-other',
              productionId: 'prod-other',
              title: 'Other Play Run',
              venueId: 'stage-2',
              startTime: DateTime(2026, 11, 10, 14, 0),
              endTime: DateTime(2026, 11, 10, 16, 0),
              creatorUid: 'dir',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(
            ProductionDetailsScreen(
              production: production,
              rehearsalService: fakeRehearsalService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll until visible and tap on Rehearsals row
        await tester.scrollUntilVisible(find.text('Rehearsals'), 100);
        await tester.tap(find.text('Rehearsals'));
        await tester.pumpAndSettle();

        expect(find.byType(RehearsalsScreen), findsOneWidget);
        expect(find.text('Showcase Run-Through'), findsOneWidget);
        expect(find.text('Other Play Run'), findsNothing);
      },
    );
  });

  group('RehearsalDetailsScreen Status & Production Resolution Tests', () {
    testWidgets(
      'displays schedule status badge and resolves linked production title & status',
      (WidgetTester tester) async {
        final rehearsal = Rehearsal(
          id: 'reh-resolved',
          productionId: 'prod-1',
          title: 'Scene Polish',
          venueId: 'stage-a',
          venueName: 'Stage A',
          startTime: DateTime(2026, 12, 1, 10, 0),
          endTime: DateTime(2026, 12, 1, 12, 0),
          creatorUid: 'dir',
        );
        final fakeProdService = FakeProductionServiceForRehearsals(
          initialProductions: [
            Production(
              id: 'prod-1',
              title: 'Hamlet Production',
              status: 'In Rehearsal',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(
            RehearsalDetailsScreen(
              rehearsal: rehearsal,
              productionService: fakeProdService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Schedule status: Upcoming (December 2026)
        expect(find.text('Upcoming'), findsOneWidget);
        expect(find.text('prod-1'), findsOneWidget);
        expect(find.textContaining('Hamlet Production'), findsOneWidget);
        expect(find.textContaining('In Rehearsal'), findsOneWidget);
      },
    );

    testWidgets(
      'handles missing or deleted production document safely in details',
      (WidgetTester tester) async {
        final rehearsal = Rehearsal(
          id: 'reh-missing-prod',
          productionId: 'prod-deleted-999',
          title: 'Orphaned Rehearsal',
          venueId: 'stage-x',
          startTime: DateTime(2026, 12, 1, 10, 0),
          endTime: DateTime(2026, 12, 1, 12, 0),
          creatorUid: 'dir',
        );
        final fakeProdService = FakeProductionServiceForRehearsals(
          initialProductions: [], // empty productions
        );

        await tester.pumpWidget(
          buildApp(
            RehearsalDetailsScreen(
              rehearsal: rehearsal,
              productionService: fakeProdService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('prod-deleted-999'), findsOneWidget);
        expect(
          find.text('Production record not found or deleted'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows completed status for past rehearsal', (
      WidgetTester tester,
    ) async {
      final rehearsal = Rehearsal(
        id: 'reh-past',
        productionId: 'prod-1',
        title: 'Archived Run',
        venueId: 'stage-1',
        startTime: DateTime(2020, 1, 1, 10, 0),
        endTime: DateTime(2020, 1, 1, 12, 0),
        creatorUid: 'dir',
      );

      await tester.pumpWidget(
        buildApp(RehearsalDetailsScreen(rehearsal: rehearsal)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
    });
  });

  group('Narrow Viewport Responsiveness & Layout Overflow Tests', () {
    testWidgets(
      'renders RehearsalsScreen without overflow on 360x640 mobile screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeService = FakeRehearsalService(
          initialRehearsals: [
            Rehearsal(
              id: 'reh-narrow',
              productionId: 'prod-narrow-view',
              title: 'Long Title Rehearsal For Narrow Viewport Check',
              venueId: 'long-venue-name',
              venueName: 'The Grand Royal Theatre Main Stage Hall A',
              startTime: DateTime(2026, 11, 15, 14, 30),
              endTime: DateTime(2026, 11, 15, 18, 45),
              creatorUid: 'dir',
              notes: 'Detailed scenes to cover: Act I Scene 1 through Act II Scene 4 with full cast.',
            ),
          ],
        );

        await tester.pumpWidget(
          buildApp(RehearsalsScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RehearsalsScreen), findsOneWidget);
        expect(
          find.text('Long Title Rehearsal For Narrow Viewport Check'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders RehearsalDetailsScreen without overflow on 360x640 mobile screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final rehearsal = Rehearsal(
          id: 'reh-narrow-detail',
          productionId: 'prod-hamlet-very-long-id',
          title: 'Act II Dress Run With Full Costumes And Orchestra',
          venueId: 'auditorium-hall',
          venueName: 'Royal Shakespeare Grand Amphitheatre',
          startTime: DateTime(2026, 11, 20, 13, 15),
          endTime: DateTime(2026, 11, 20, 17, 45),
          creatorUid: 'dir',
          notes: 'Extended rehearsal notes covering lighting cues, props handoff, sound checks, and stage reset.',
        );

        await tester.pumpWidget(
          buildApp(RehearsalDetailsScreen(rehearsal: rehearsal)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RehearsalDetailsScreen), findsOneWidget);
        expect(
          find.text('Act II Dress Run With Full Costumes And Orchestra'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders AddRehearsalScreen without overflow on 360x640 mobile screen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeService = FakeRehearsalService();

        await tester.pumpWidget(
          buildApp(AddRehearsalScreen(rehearsalService: fakeService)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AddRehearsalScreen), findsOneWidget);
        expect(find.text('Schedule Rehearsal'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
