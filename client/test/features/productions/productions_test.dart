import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/productions/screens/productions_screen.dart';
import 'package:client/features/productions/screens/add_production_screen.dart';
import 'package:client/features/productions/screens/production_details_screen.dart';
import 'package:client/features/productions/widgets/production_card.dart';

// Test mock service with configurable data and failure simulation
class FakeProductionService extends ProductionService {
  List<Production> customProductions;
  bool shouldThrowOnCreate = false;
  bool shouldThrowOnUpdate = false;
  bool shouldThrowOnDelete = false;

  FakeProductionService({List<Production>? initialProductions})
      : customProductions = initialProductions != null
            ? List.from(initialProductions)
            : [],
        super();

  @override
  Stream<List<Production>> streamProductions() {
    return Stream.value(List.unmodifiable(customProductions));
  }

  @override
  Future<List<Production>> getProductions() async {
    return List.unmodifiable(customProductions);
  }

  @override
  Future<Production> createProduction(Production production) async {
    if (shouldThrowOnCreate) {
      throw Exception('Firestore write permission denied');
    }
    final created = production.copyWith(
      id: 'test-id-${customProductions.length + 1}',
    );
    customProductions.insert(0, created);
    return created;
  }

  @override
  Future<void> updateProduction(Production production) async {
    if (shouldThrowOnUpdate) {
      throw Exception('Firestore update failed');
    }
    final index = customProductions.indexWhere((p) => p.id == production.id);
    if (index != -1) {
      customProductions[index] = production;
    }
  }

  @override
  Future<void> deleteProduction(String id) async {
    if (shouldThrowOnDelete) {
      throw Exception('Firestore delete failed');
    }
    customProductions.removeWhere((p) => p.id == id);
  }
}

void main() {
  Widget buildApp(Widget home) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B1E3F),
        ),
      ),
      home: home,
    );
  }

  group('Production Model Tests', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime(2026, 10, 9);
      final prod = Production(
        id: 'test-1',
        title: 'Macbeth',
        description: 'Tragedy of Scottish general',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 12, 1),
        status: ProductionStatus.inRehearsal,
        director: 'William Shakespeare',
        createdAt: now,
      );

      final map = prod.toMap();
      expect(map['title'], 'Macbeth');
      expect(map['description'], 'Tragedy of Scottish general');
      expect(map['status'], ProductionStatus.inRehearsal);
      expect(map['director'], 'William Shakespeare');

      final fromMap = Production.fromMap(map, 'test-1');
      expect(fromMap.id, 'test-1');
      expect(fromMap.title, 'Macbeth');
      expect(fromMap.status, ProductionStatus.inRehearsal);
      expect(fromMap.startDate, DateTime(2026, 11, 1));
      expect(fromMap.endDate, DateTime(2026, 12, 1));
    });

    test('formats date ranges correctly', () {
      final bothDates = Production(
        id: '1',
        title: 'P1',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 11, 15),
      );
      expect(bothDates.dateRangeFormatted, 'Oct 1, 2026 – Nov 15, 2026');

      final startOnly = Production(
        id: '2',
        title: 'P2',
        startDate: DateTime(2026, 10, 1),
      );
      expect(startOnly.dateRangeFormatted, 'Starts Oct 1, 2026');

      final endOnly = Production(
        id: '3',
        title: 'P3',
        endDate: DateTime(2026, 11, 15),
      );
      expect(endOnly.dateRangeFormatted, 'Ends Nov 15, 2026');

      const noDates = Production(id: '4', title: 'P4');
      expect(noDates.dateRangeFormatted, 'Dates to be announced');
    });

    test('copyWith works as expected', () {
      const prod = Production(id: '1', title: 'Original');
      final updated = prod.copyWith(title: 'Updated', status: ProductionStatus.completed);
      expect(updated.id, '1');
      expect(updated.title, 'Updated');
      expect(updated.status, ProductionStatus.completed);
    });
  });

  group('ProductionService Data Separation Tests', () {
    test('sampleProductions remains separate from default service instances', () async {
      // By default without sample data flag, mock store starts empty
      final service = ProductionService();
      final productions = await service.getProductions();
      expect(productions.isEmpty, isTrue);

      // Curated sample productions exist separately as a static template
      expect(ProductionService.sampleProductions.length, 4);
    });

    test('mock service can opt into sample data explicitly when desired', () async {
      final service = ProductionService(loadSampleDataInMockMode: true);
      final productions = await service.getProductions();
      expect(productions.length, 4);
    });
  });

  group('ProductionCard Tests', () {
    testWidgets('renders title, status, and dates', (WidgetTester tester) async {
      final prod = Production(
        id: 'card-1',
        title: 'The Tempest',
        description: 'Enchanted island play',
        status: ProductionStatus.planning,
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2027, 1, 10),
        director: 'Prospero',
      );

      await tester.pumpWidget(
        buildApp(ProductionCard(production: prod)),
      );

      expect(find.text('The Tempest'), findsOneWidget);
      expect(find.text('Enchanted island play'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Dir: Prospero'), findsOneWidget);
      expect(find.text('Dec 1, 2026 – Jan 10, 2027'), findsOneWidget);
    });
  });

  group('ProductionsScreen Tests', () {
    testWidgets('shows title and production cards', (WidgetTester tester) async {
      final fakeService = FakeProductionService(
        initialProductions: [
          Production(
            id: '1',
            title: 'The Phantom of the Opera',
            description: 'Classic musical',
            status: ProductionStatus.inRehearsal,
          ),
          Production(
            id: '2',
            title: 'Les Misérables',
            description: 'French revolution musical',
            status: ProductionStatus.completed,
          ),
        ],
      );

      await tester.pumpWidget(
        buildApp(ProductionsScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Productions'), findsOneWidget);
      expect(find.text('The Phantom of the Opera'), findsOneWidget);
      expect(find.text('Les Misérables'), findsOneWidget);
      expect(find.byType(ProductionCard), findsNWidgets(2));
      expect(find.text('Add Production'), findsWidgets);
    });

    testWidgets('shows empty state when no productions exist', (WidgetTester tester) async {
      final fakeService = FakeProductionService(initialProductions: []);

      await tester.pumpWidget(
        buildApp(ProductionsScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Productions Yet'), findsOneWidget);
      expect(find.text('Create your first theatre production to begin organizing rehearsals and stage runs.'), findsOneWidget);
      expect(find.byType(ProductionCard), findsNothing);
    });

    testWidgets('filters productions by status chip', (WidgetTester tester) async {
      final fakeService = FakeProductionService(
        initialProductions: [
          Production(
            id: '1',
            title: 'The Phantom of the Opera',
            status: ProductionStatus.inRehearsal,
          ),
          Production(
            id: '2',
            title: 'Les Misérables',
            status: ProductionStatus.completed,
          ),
        ],
      );

      await tester.pumpWidget(
        buildApp(ProductionsScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      // Tap 'Completed' filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Les Misérables'), findsOneWidget);
      expect(find.text('The Phantom of the Opera'), findsNothing);
    });

    testWidgets('surfaces error SnackBar when delete fails from card popup menu', (WidgetTester tester) async {
      final fakeService = FakeProductionService(
        initialProductions: [
          Production(
            id: '1',
            title: 'The Phantom of the Opera',
            status: ProductionStatus.inRehearsal,
          ),
        ],
      )..shouldThrowOnDelete = true;

      await tester.pumpWidget(
        buildApp(ProductionsScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      // Open card popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap delete in popup menu
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to delete "The Phantom of the Opera"'), findsOneWidget);
      expect(fakeService.customProductions.length, 1);
    });

    testWidgets('navigates to AddProductionScreen when Add Production is tapped', (WidgetTester tester) async {
      final fakeService = FakeProductionService(initialProductions: []);

      await tester.pumpWidget(
        buildApp(ProductionsScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      final addFab = find.widgetWithText(FloatingActionButton, 'Add Production');
      await tester.tap(addFab);
      await tester.pumpAndSettle();

      expect(find.byType(AddProductionScreen), findsOneWidget);
    });
  });

  group('AddProductionScreen Tests', () {
    testWidgets('shows validation error when submitting with empty title', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = FakeProductionService();

      await tester.pumpWidget(
        buildApp(AddProductionScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_production_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('Production title is required and cannot be empty.'), findsOneWidget);
    });

    testWidgets('validates end date cannot be earlier than start date', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = FakeProductionService();

      await tester.pumpWidget(
        buildApp(
          AddProductionScreen(
            productionService: fakeService,
            initialProduction: Production(
              id: 'init-1',
              title: 'Macbeth',
              startDate: DateTime(2026, 12, 1),
              endDate: DateTime(2026, 10, 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('save_production_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.text('End date cannot be earlier than start date.'), findsOneWidget);
      expect(fakeService.customProductions.isEmpty, isTrue);
    });

    testWidgets('surfaces error SnackBar when creation fails', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = FakeProductionService()..shouldThrowOnCreate = true;

      await tester.pumpWidget(
        buildApp(AddProductionScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('production_title_input'));
      await tester.enterText(titleField, 'Hamlet');

      final saveButton = find.byKey(const Key('save_production_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(find.textContaining('Failed to save production:'), findsOneWidget);
    });

    testWidgets('successfully creates production with valid data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = FakeProductionService();

      await tester.pumpWidget(
        buildApp(AddProductionScreen(productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('production_title_input'));
      await tester.enterText(titleField, 'Hamlet');

      final descField = find.byKey(const Key('production_description_input'));
      await tester.enterText(descField, 'Prince of Denmark tragedy');

      final directorField = find.byKey(const Key('production_director_input'));
      await tester.enterText(directorField, 'Kenneth Branagh');

      final saveButton = find.byKey(const Key('save_production_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeService.customProductions.length, 1);
      expect(fakeService.customProductions.first.title, 'Hamlet');
      expect(fakeService.customProductions.first.description, 'Prince of Denmark tragedy');
      expect(fakeService.customProductions.first.director, 'Kenneth Branagh');
    });

    testWidgets('successfully updates existing production in edit mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existing = Production(
        id: 'prod-edit-1',
        title: 'Original Title',
        description: 'Original Desc',
      );
      final fakeService = FakeProductionService(initialProductions: [existing]);

      await tester.pumpWidget(
        buildApp(
          AddProductionScreen(
            initialProduction: existing,
            productionService: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Production'), findsOneWidget);

      final titleField = find.byKey(const Key('production_title_input'));
      await tester.enterText(titleField, 'Updated Title');

      final saveButton = find.byKey(const Key('save_production_button'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeService.customProductions.first.title, 'Updated Title');
    });
  });

  group('ProductionDetailsScreen Tests', () {
    testWidgets('renders all production details and timeline', (WidgetTester tester) async {
      final prod = Production(
        id: 'det-1',
        title: 'Othello',
        description: 'Tragedy of jealousy and deception',
        status: ProductionStatus.inRehearsal,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 11, 1),
        director: 'Laurence Olivier',
      );

      await tester.pumpWidget(
        buildApp(ProductionDetailsScreen(production: prod)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Production Details'), findsOneWidget);
      expect(find.text('Othello'), findsOneWidget);
      expect(find.text('Directed by Laurence Olivier'), findsOneWidget);
      expect(find.text('Tragedy of jealousy and deception'), findsOneWidget);
      expect(find.text('In Rehearsal'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('Oct 1, 2026'), findsOneWidget);
      expect(find.text('Nov 1, 2026'), findsOneWidget);
      expect(find.text('Back to Productions List'), findsOneWidget);
    });

    testWidgets('surfaces error SnackBar when delete fails from details screen', (WidgetTester tester) async {
      final prod = const Production(
        id: 'det-err',
        title: 'Othello',
      );
      final fakeService = FakeProductionService()..shouldThrowOnDelete = true;

      await tester.pumpWidget(
        buildApp(ProductionDetailsScreen(production: prod, productionService: fakeService)),
      );
      await tester.pumpAndSettle();

      // Tap delete in AppBar
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to delete:'), findsOneWidget);
    });

    testWidgets('pops back to productions list when back button is tapped', (WidgetTester tester) async {
      final prod = const Production(
        id: 'det-2',
        title: 'Twelfth Night',
      );

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductionDetailsScreen(production: prod),
                ),
              ),
              child: const Text('Open Details'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Twelfth Night'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to Productions'));
      await tester.pumpAndSettle();

      expect(find.text('Twelfth Night'), findsNothing);
    });
  });
}
