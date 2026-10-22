import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/cast/models/cast_assignment_model.dart';
import 'package:client/features/cast/screens/assign_cast_screen.dart';
import 'package:client/features/cast/screens/cast_screen.dart';
import 'package:client/features/cast/services/cast_service.dart';
import 'package:client/features/cast/widgets/cast_member_card.dart';
import 'package:client/features/productions/models/production_model.dart';
import 'package:client/features/productions/services/production_service.dart';

class _FakeCastService extends CastService {
  final List<CastAssignment> assignments;
  final List<EligibleUser> eligibleUsers;
  CastAssignment? lastCreatedAssignment;
  CastAssignment? lastUpdatedAssignment;
  String? lastRemovedAssignmentId;

  _FakeCastService({
    List<CastAssignment>? initialAssignments,
    List<EligibleUser>? initialUsers,
  })  : assignments = initialAssignments ?? [],
        eligibleUsers = initialUsers ?? [];

  @override
  Stream<List<CastAssignment>> streamCastAssignments({String? productionId}) {
    if (productionId != null && productionId.trim().isNotEmpty) {
      return Stream.value(
          assignments.where((a) => a.productionId == productionId).toList());
    }
    return Stream.value(assignments);
  }

  @override
  Future<List<CastAssignment>> getCastAssignments({String? productionId}) async {
    if (productionId != null && productionId.trim().isNotEmpty) {
      return assignments.where((a) => a.productionId == productionId).toList();
    }
    return assignments;
  }

  @override
  Future<List<EligibleUser>> getEligibleUsers() async => eligibleUsers;

  @override
  Future<CastAssignment> assignCastMember(CastAssignment assignment) async {
    validateAssignment(assignment);
    final roleNorm = assignment.characterRole.trim().toLowerCase();
    final hasDup = assignments.any((a) =>
        a.productionId == assignment.productionId &&
        a.characterRole.trim().toLowerCase() == roleNorm);
    if (hasDup) {
      throw DuplicateRoleException(
          assignment.characterRole, assignment.productionId);
    }

    final created = assignment.copyWith(id: 'cast-${assignments.length + 1}');
    assignments.add(created);
    lastCreatedAssignment = created;
    return created;
  }

  @override
  Future<void> updateCastAssignment(CastAssignment assignment) async {
    validateAssignment(assignment);
    final roleNorm = assignment.characterRole.trim().toLowerCase();
    final hasDup = assignments.any((a) =>
        a.id != assignment.id &&
        a.productionId == assignment.productionId &&
        a.characterRole.trim().toLowerCase() == roleNorm);
    if (hasDup) {
      throw DuplicateRoleException(
          assignment.characterRole, assignment.productionId);
    }

    final index = assignments.indexWhere((a) => a.id == assignment.id);
    if (index != -1) {
      assignments[index] = assignment;
    }
    lastUpdatedAssignment = assignment;
  }

  @override
  Future<void> removeCastAssignment(String assignmentId) async {
    assignments.removeWhere((a) => a.id == assignmentId);
    lastRemovedAssignmentId = assignmentId;
  }
}

class _FakeProductionService extends ProductionService {
  final List<Production> productions;
  _FakeProductionService({this.productions = const []});

  @override
  Future<List<Production>> getProductions() async => productions;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  group('Cast Model & Validation Tests', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime(2026, 11, 2, 14, 0);
      final assignment = CastAssignment(
        id: 'c1',
        productionId: 'prod-1',
        userId: 'u1',
        characterRole: 'Romeo',
        actorName: 'Bob Actor',
        actorEmail: 'bob@theatre.org',
        status: CastAssignmentStatus.assigned,
        notes: 'First choice',
        assignedAt: now,
      );

      final map = assignment.toMap();
      expect(map['productionId'], 'prod-1');
      expect(map['userId'], 'u1');
      expect(map['characterRole'], 'Romeo');
      expect(map['actorName'], 'Bob Actor');
      expect(map['actorEmail'], 'bob@theatre.org');
      expect(map['status'], 'Assigned');

      final reconstructed = CastAssignment.fromMap({
        'productionId': 'prod-1',
        'userId': 'u1',
        'characterRole': 'Romeo',
        'actorName': 'Bob Actor',
        'actorEmail': 'bob@theatre.org',
        'status': 'Assigned',
        'notes': 'First choice',
        'assignedAt': now,
      }, 'c1');

      expect(reconstructed.id, 'c1');
      expect(reconstructed.characterRole, 'Romeo');
      expect(reconstructed.actorName, 'Bob Actor');
    });

    test('validates required fields', () {
      final service = CastService(firestore: null);

      expect(
        () => service.validateAssignment(const CastAssignment(
          id: '',
          productionId: '',
          userId: 'u1',
          characterRole: 'Role',
          actorName: 'Actor',
        )),
        throwsA(isA<CastValidationException>()),
      );

      expect(
        () => service.validateAssignment(const CastAssignment(
          id: '',
          productionId: 'p1',
          userId: '',
          characterRole: 'Role',
          actorName: 'Actor',
        )),
        throwsA(isA<CastValidationException>()),
      );

      expect(
        () => service.validateAssignment(const CastAssignment(
          id: '',
          productionId: 'p1',
          userId: 'u1',
          characterRole: '',
          actorName: 'Actor',
        )),
        throwsA(isA<CastValidationException>()),
      );

      expect(
        () => service.validateAssignment(const CastAssignment(
          id: '',
          productionId: 'p1',
          userId: 'u1',
          characterRole: 'Role',
          actorName: '',
        )),
        throwsA(isA<CastValidationException>()),
      );

      expect(
        () => service.validateAssignment(const CastAssignment(
          id: '',
          productionId: 'p1',
          userId: 'u1',
          characterRole: 'Role',
          actorName: 'Actor',
        )),
        returnsNormally,
      );
    });
  });

  group('CastMemberCard Tests', () {
    testWidgets('renders character role, actor name, status and notes', (tester) async {
      const assignment = CastAssignment(
        id: 'c1',
        productionId: 'p1',
        userId: 'u1',
        characterRole: 'Juliet Capulet',
        actorName: 'Alice Actress',
        status: CastAssignmentStatus.confirmed,
        notes: 'Understudy: Carol',
      );

      await tester.pumpWidget(_wrap(
        const CastMemberCard(
          assignment: assignment,
          productionTitle: 'Romeo & Juliet',
        ),
      ));

      expect(find.text('Juliet Capulet'), findsOneWidget);
      expect(find.text('Alice Actress'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Romeo & Juliet'), findsOneWidget);
      expect(find.text('Understudy: Carol'), findsOneWidget);
    });
  });

  group('CastScreen Tests', () {
    testWidgets('renders empty state when no assignments exist', (tester) async {
      final fakeService = _FakeCastService(initialAssignments: []);

      await tester.pumpWidget(_wrap(
        CastScreen(
          castService: fakeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No cast members assigned yet.'), findsOneWidget);
    });

    testWidgets('renders roster and filters by production', (tester) async {
      final fakeService = _FakeCastService(initialAssignments: [
        const CastAssignment(
          id: 'c1',
          productionId: 'p1',
          userId: 'u1',
          characterRole: 'Romeo',
          actorName: 'Bob Actor',
        ),
        const CastAssignment(
          id: 'c2',
          productionId: 'p2',
          userId: 'u2',
          characterRole: 'Prince of Denmark',
          actorName: 'Dan Actor',
        ),
      ]);
      final fakeProdService = _FakeProductionService(productions: [
        Production(id: 'p1', title: 'Romeo & Juliet', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10))),
        Production(id: 'p2', title: 'Hamlet Play', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10))),
      ]);

      await tester.pumpWidget(_wrap(
        CastScreen(
          castService: fakeService,
          productionService: fakeProdService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Romeo'), findsOneWidget);
      expect(find.text('Prince of Denmark'), findsOneWidget);

      // Filter by Hamlet Play
      await tester.tap(find.widgetWithText(FilterChip, 'Hamlet Play'));
      await tester.pumpAndSettle();

      expect(find.text('Prince of Denmark'), findsOneWidget);
      expect(find.text('Romeo'), findsNothing);
    });
  });

  group('AssignCastScreen Tests', () {
    testWidgets('shows error when role is already assigned in same production', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FakeCastService(initialAssignments: [
        const CastAssignment(
          id: 'c1',
          productionId: 'p1',
          userId: 'u1',
          characterRole: 'Romeo',
          actorName: 'Bob Actor',
        ),
      ]);
      final fakeProdService = _FakeProductionService(productions: [
        Production(id: 'p1', title: 'Romeo & Juliet', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10))),
      ]);

      await tester.pumpWidget(_wrap(
        AssignCastScreen(
          initialProductionId: 'p1',
          castService: fakeService,
          productionService: fakeProdService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('character_role_input')), 'Romeo');
      await tester.enterText(find.byKey(const Key('actor_name_input')), 'Another Actor');

      await tester.ensureVisible(find.byKey(const Key('save_cast_assignment_button')));
      await tester.tap(find.byKey(const Key('save_cast_assignment_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assignment_error_banner')), findsOneWidget);
      expect(find.textContaining('already assigned'), findsOneWidget);
    });

    testWidgets('assigns new role successfully when not duplicate', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FakeCastService();
      final fakeProdService = _FakeProductionService(productions: [
        Production(id: 'p1', title: 'Romeo & Juliet', startDate: DateTime.now(), endDate: DateTime.now().add(const Duration(days: 10))),
      ]);

      await tester.pumpWidget(_wrap(
        AssignCastScreen(
          initialProductionId: 'p1',
          castService: fakeService,
          productionService: fakeProdService,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('character_role_input')), 'Mercutio');
      await tester.enterText(find.byKey(const Key('actor_name_input')), 'Charlie Actor');

      await tester.ensureVisible(find.byKey(const Key('save_cast_assignment_button')));
      await tester.tap(find.byKey(const Key('save_cast_assignment_button')));
      await tester.pumpAndSettle();

      expect(fakeService.lastCreatedAssignment, isNotNull);
      expect(fakeService.lastCreatedAssignment!.characterRole, 'Mercutio');
      expect(fakeService.lastCreatedAssignment!.actorName, 'Charlie Actor');
    });
  });
}
