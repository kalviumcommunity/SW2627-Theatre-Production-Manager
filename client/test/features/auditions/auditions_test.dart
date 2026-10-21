import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:client/features/auditions/models/audition_model.dart';
import 'package:client/features/auditions/services/audition_service.dart';
import 'package:client/features/auditions/screens/auditions_screen.dart';
import 'package:client/features/auditions/screens/add_audition_screen.dart';
import 'package:client/features/auditions/screens/audition_details_screen.dart';
import 'package:client/features/auditions/widgets/audition_card.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/productions/screens/production_details_screen.dart';
import 'package:client/services/auth_service.dart';

class FakeAuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);
}

class FakeProductionService extends ProductionService {
  final List<Production> productions;
  FakeProductionService({List<Production>? initial})
    : productions =
          initial ??
          [
            Production(
              id: 'prod-1',
              title: 'Hamlet',
              status: ProductionStatus.planning,
              director: 'John Doe',
            ),
            Production(
              id: 'prod-2',
              title: 'Macbeth',
              status: ProductionStatus.inRehearsal,
              director: 'Jane Smith',
            ),
          ];

  @override
  Future<List<Production>> getProductions() async => productions;
}

class FakeAuditionService extends AuditionService {
  List<Audition> auditions;
  bool shouldThrowOnCreate = false;
  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnCancel = false;
  bool shouldThrowStreamError = false;

  int createCalls = 0;
  int updateCalls = 0;
  int cancelCalls = 0;

  final StreamController<List<Audition>> _controller =
      StreamController<List<Audition>>.broadcast();

  FakeAuditionService({List<Audition>? initialAuditions})
    : auditions = initialAuditions != null ? List.from(initialAuditions) : [],
      super();

  @override
  Stream<List<Audition>> streamAuditions({String? productionId}) async* {
    if (shouldThrowStreamError) {
      throw Exception('Firestore stream connection failure');
    }
    yield _filter(auditions, productionId);
    yield* _controller.stream.map((list) => _filter(list, productionId));
  }

  @override
  Future<List<Audition>> getAuditions({String? productionId}) async {
    return _filter(auditions, productionId);
  }

  List<Audition> _filter(List<Audition> list, String? productionId) {
    if (productionId != null && productionId.isNotEmpty) {
      return list.where((a) => a.productionId == productionId).toList();
    }
    return List.from(list);
  }

  void emit(List<Audition> list) {
    auditions = List.from(list);
    _controller.add(auditions);
  }

  @override
  Future<Audition> createAudition(
    Audition audition, {
    bool checkProductionExists = true,
  }) async {
    createCalls++;
    if (shouldThrowOnCreate) {
      throw Exception('Failed to create audition in test');
    }
    final toSave = audition.copyWith(
      id: audition.id.isNotEmpty ? audition.id : 'gen-aud-$createCalls',
    );
    auditions.add(toSave);
    emit(auditions);
    return toSave;
  }

  @override
  Future<void> updateAudition(
    Audition audition, {
    bool checkProductionExists = true,
  }) async {
    updateCalls++;
    if (shouldThrowOnUpdate) {
      throw Exception('Failed to update audition in test');
    }
    final idx = auditions.indexWhere((a) => a.id == audition.id);
    if (idx >= 0) {
      auditions[idx] = audition;
    } else {
      auditions.add(audition);
    }
    emit(auditions);
  }

  @override
  Future<void> cancelAudition(String auditionId, {String? reason}) async {
    cancelCalls++;
    if (shouldThrowOnCancel) {
      throw Exception('Failed to cancel audition in test');
    }
    final idx = auditions.indexWhere((a) => a.id == auditionId);
    if (idx >= 0) {
      auditions[idx] = auditions[idx].copyWith(
        status: AuditionStatus.cancelled,
        cancellationReason: reason,
      );
      emit(auditions);
    }
  }

  @override
  Future<Audition?> getAuditionById(String auditionId) async {
    final matches = auditions.where((a) => a.id == auditionId);
    return matches.isNotEmpty ? matches.first : null;
  }
}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B1E3F)),
      useMaterial3: true,
    ),
    home: child,
  );
}

void main() {
  final testStart = DateTime(2026, 11, 15, 10, 0);
  final testEnd = DateTime(2026, 11, 15, 13, 0);

  Audition sampleAudition({
    String id = 'aud-test-1',
    String prodId = 'prod-1',
    String title = 'Hamlet & Ophelia Call',
    String venue = 'Main Hall',
    DateTime? startTime,
    DateTime? endTime,
    String status = AuditionStatus.scheduled,
    String requirements = 'Prepare classical monologue',
    String description = 'Bring resume and headshot',
  }) {
    return Audition(
      id: id,
      productionId: prodId,
      title: title,
      venue: venue,
      startTime: startTime ?? testStart,
      endTime: endTime ?? testEnd,
      creatorUid: 'dir-uid',
      status: status,
      requirements: requirements,
      description: description,
    );
  }

  group('AuditionCard Tests', () {
    testWidgets('renders title, status, venue, date, and time window', (
      tester,
    ) async {
      final audition = sampleAudition();
      await tester.pumpWidget(
        createTestApp(Scaffold(body: AuditionCard(audition: audition))),
      );

      expect(find.text('Hamlet & Ophelia Call'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Main Hall'), findsOneWidget);
      expect(find.text('Prod: prod-1'), findsOneWidget);
      expect(find.text('15 Nov 2026'), findsOneWidget);
      expect(find.text('10:00 - 13:00'), findsOneWidget);
      expect(find.text('3h'), findsOneWidget);
    });

    testWidgets('triggers onCancel from popup menu', (tester) async {
      bool cancelCalled = false;
      final audition = sampleAudition();

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: AuditionCard(
              audition: audition,
              onCancel: () => cancelCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Audition'), findsOneWidget);
      await tester.tap(find.text('Cancel Audition'));
      await tester.pumpAndSettle();

      expect(cancelCalled, isTrue);
    });
  });

  group('AuditionsScreen Tests', () {
    testWidgets('renders empty state when no auditions exist', (tester) async {
      final fakeService = FakeAuditionService();

      await tester.pumpWidget(
        createTestApp(AuditionsScreen(auditionService: fakeService)),
      );
      await tester.pump();

      expect(find.text('No Auditions Scheduled Yet'), findsOneWidget);
      expect(find.text('Schedule Audition'), findsWidgets);
    });

    testWidgets('renders list of auditions', (tester) async {
      final fakeService = FakeAuditionService(
        initialAuditions: [
          sampleAudition(id: '1', title: 'Hamlet Call'),
          sampleAudition(id: '2', title: 'Macbeth Call'),
        ],
      );

      await tester.pumpWidget(
        createTestApp(AuditionsScreen(auditionService: fakeService)),
      );
      await tester.pump();

      expect(find.text('Hamlet Call'), findsOneWidget);
      expect(find.text('Macbeth Call'), findsOneWidget);
    });

    testWidgets('filters auditions by search query', (tester) async {
      final fakeService = FakeAuditionService(
        initialAuditions: [
          sampleAudition(id: '1', title: 'Romeo Lead Call', venue: 'Studio A'),
          sampleAudition(id: '2', title: 'Juliet Callback', venue: 'Studio B'),
        ],
      );

      await tester.pumpWidget(
        createTestApp(AuditionsScreen(auditionService: fakeService)),
      );
      await tester.pump();

      expect(find.text('Romeo Lead Call'), findsOneWidget);
      expect(find.text('Juliet Callback'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Romeo');
      await tester.pump();

      expect(find.text('Romeo Lead Call'), findsOneWidget);
      expect(find.text('Juliet Callback'), findsNothing);
    });

    testWidgets(
      'filters auditions by initialProductionFilter and allows clearing',
      (tester) async {
        final fakeService = FakeAuditionService(
          initialAuditions: [
            sampleAudition(id: '1', prodId: 'prod-1', title: 'Hamlet Audition'),
            sampleAudition(
              id: '2',
              prodId: 'prod-2',
              title: 'Macbeth Audition',
            ),
          ],
        );

        await tester.pumpWidget(
          createTestApp(
            AuditionsScreen(
              auditionService: fakeService,
              initialProductionFilter: 'prod-1',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Hamlet Audition'), findsOneWidget);
        expect(find.text('Macbeth Audition'), findsNothing);
        expect(find.text('Production: prod-1'), findsOneWidget);

        // Tap clear filters
        await tester.tap(find.text('Clear Filters'));
        await tester.pump();

        expect(find.text('Hamlet Audition'), findsOneWidget);
        expect(find.text('Macbeth Audition'), findsOneWidget);
      },
    );
  });

  group('AddAuditionScreen Tests', () {
    testWidgets('shows validation errors for empty required fields', (
      tester,
    ) async {
      final fakeService = FakeAuditionService();

      await tester.pumpWidget(
        createTestApp(AddAuditionScreen(auditionService: fakeService)),
      );
      await tester.pumpAndSettle();

      // Clear the default title and submit
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Audition Call'),
        '',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Audition title is required'), findsOneWidget);
      expect(find.text('Venue is required'), findsOneWidget);
      expect(fakeService.createCalls, 0);
    });

    testWidgets('creates audition with valid form data', (tester) async {
      final fakeService = FakeAuditionService();
      final fakeProdService = FakeProductionService();

      await tester.pumpWidget(
        createTestApp(
          AddAuditionScreen(
            auditionService: fakeService,
            productionService: fakeProdService,
            initialProductionId: 'prod-1',
            checkProductionExists: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Studio Rehearsal Stage',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeService.createCalls, 1);
      expect(fakeService.auditions.length, 1);
      expect(fakeService.auditions.first.venue, 'Studio Rehearsal Stage');
    });

    testWidgets('allows editing historical date without date picker crash', (
      tester,
    ) async {
      final fakeService = FakeAuditionService();
      final pastDate = DateTime(2023, 5, 10, 10, 0);
      final pastAudition = sampleAudition(
        startTime: pastDate,
        endTime: pastDate.add(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        createTestApp(
          AddAuditionScreen(
            auditionService: fakeService,
            initialAudition: pastAudition,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to change date
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Audition'), findsOneWidget);
    });
  });

  group('AuditionDetailsScreen Tests', () {
    testWidgets('renders all audition details and requirements', (
      tester,
    ) async {
      final fakeService = FakeAuditionService();
      final fakeProdService = FakeProductionService();
      final audition = sampleAudition();

      await tester.pumpWidget(
        createTestApp(
          AuditionDetailsScreen(
            audition: audition,
            auditionService: fakeService,
            productionService: fakeProdService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hamlet & Ophelia Call'), findsOneWidget);
      expect(find.text('Main Hall'), findsOneWidget);
      expect(find.text('Hamlet (Planning)'), findsOneWidget);
      expect(find.text('Prepare classical monologue'), findsOneWidget);
      expect(find.text('Bring resume and headshot'), findsOneWidget);
      expect(find.text('Back to Auditions List'), findsOneWidget);
    });

    testWidgets('cancels audition with confirmation dialog', (tester) async {
      final audition = sampleAudition();
      final fakeService = FakeAuditionService(initialAuditions: [audition]);

      await tester.pumpWidget(
        createTestApp(
          AuditionDetailsScreen(
            audition: audition,
            auditionService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Audition'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel Audition'));
      await tester.pumpAndSettle();

      expect(fakeService.cancelCalls, 1);
      expect(find.text('Audition Cancelled'), findsOneWidget);
    });
  });

  group('ProductionDetailsScreen Auditions Integration Tests', () {
    testWidgets(
      'navigates to AuditionsScreen when Auditions activity row is tapped',
      (tester) async {
        final prod = Production(
          id: 'prod-1',
          title: 'Hamlet',
          status: 'Planning',
        );
        final fakeAuditionService = FakeAuditionService(
          initialAuditions: [
            sampleAudition(prodId: 'prod-1', title: 'Hamlet Call'),
            sampleAudition(prodId: 'prod-2', title: 'Macbeth Call'),
          ],
        );

        await tester.pumpWidget(
          createTestApp(
            ProductionDetailsScreen(
              production: prod,
              auditionService: fakeAuditionService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Auditions'), findsOneWidget);
        expect(
          find.text('View and schedule audition calls for this production'),
          findsOneWidget,
        );

        await tester.ensureVisible(find.text('Auditions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Auditions'));
        await tester.pumpAndSettle();

        expect(find.text('Hamlet Call'), findsOneWidget);
        expect(find.text('Macbeth Call'), findsNothing);
        expect(find.text('Production: prod-1'), findsOneWidget);
      },
    );
  });

  group('Narrow Viewport Responsiveness Tests', () {
    testWidgets(
      'renders AuditionsScreen without overflow on 360x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final fakeService = FakeAuditionService(
          initialAuditions: [
            sampleAudition(
              title: 'Very Long Audition Title That Should Not Cause Any Overflow Issue',
            ),
          ],
        );

        await tester.pumpWidget(
          createTestApp(AuditionsScreen(auditionService: fakeService)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders AddAuditionScreen without overflow on 360x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestApp(const AddAuditionScreen()));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders AuditionDetailsScreen without overflow on 360x640 mobile screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestApp(AuditionDetailsScreen(audition: sampleAudition())),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
