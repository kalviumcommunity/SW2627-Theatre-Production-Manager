import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:client/features/auditions/services/audition_service.dart';
import 'package:client/features/cast/services/cast_service.dart';
import 'package:client/features/productions/services/production_service.dart';
import 'package:client/features/rehearsals/services/rehearsal_service.dart';
import '../models/schedule_event_model.dart';

class ScheduleService {
  final FirebaseFirestore? _customFirestore;
  final RehearsalService? _customRehearsalService;
  final AuditionService? _customAuditionService;
  final ProductionService? _customProductionService;
  final CastService? _customCastService;

  ScheduleService({
    FirebaseFirestore? firestore,
    RehearsalService? rehearsalService,
    AuditionService? auditionService,
    ProductionService? productionService,
    CastService? castService,
  })  : _customFirestore = firestore,
        _customRehearsalService = rehearsalService,
        _customAuditionService = auditionService,
        _customProductionService = productionService,
        _customCastService = castService;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  RehearsalService get rehearsalService =>
      _customRehearsalService ?? RehearsalService(firestore: _customFirestore);

  AuditionService get auditionService =>
      _customAuditionService ?? AuditionService(firestore: _customFirestore);

  ProductionService get productionService =>
      _customProductionService ?? ProductionService(firestore: _customFirestore);

  CastService get castService =>
      _customCastService ?? CastService(firestore: _customFirestore);

  /// Fetches consolidated events across rehearsals and auditions, with role-based filtering.
  Future<List<ScheduleEvent>> getScheduleEvents({
    String? userId,
    bool isDirector = true,
    DateTime? dateFilter,
  }) async {
    try {
      // 1. Get productions map for titles
      final productions = await productionService.getProductions();
      final prodMap = {for (var p in productions) p.id: p.title};

      // 2. If cast member, get productions user is assigned to
      Set<String>? allowedProductionIds;
      if (!isDirector && userId != null && userId.isNotEmpty) {
        final userAssignments = await castService.getCastAssignments();
        allowedProductionIds = userAssignments
            .where((a) => a.userId == userId)
            .map((a) => a.productionId)
            .toSet();
      }

      final events = <ScheduleEvent>[];

      // 3. Collect rehearsals
      final rehearsals = await rehearsalService.getRehearsals();
      for (final reh in rehearsals) {
        if (allowedProductionIds != null &&
            !allowedProductionIds.contains(reh.productionId)) {
          continue;
        }
        events.add(ScheduleEvent(
          id: reh.id,
          title: reh.title.isNotEmpty ? reh.title : 'Rehearsal',
          productionId: reh.productionId,
          productionTitle: prodMap[reh.productionId] ?? 'Production',
          venue: reh.venue,
          startTime: reh.startTime,
          endTime: reh.endTime,
          status: reh.endTime.isBefore(DateTime.now())
              ? 'Completed'
              : 'Scheduled',
          type: ScheduleEventType.rehearsal,
          notes: reh.notes,
          originalObject: reh,
        ));
      }

      // 4. Collect auditions
      final auditions = await auditionService.getAuditions();
      for (final aud in auditions) {
        if (allowedProductionIds != null &&
            !allowedProductionIds.contains(aud.productionId)) {
          continue;
        }
        events.add(ScheduleEvent(
          id: aud.id,
          title: aud.title,
          productionId: aud.productionId,
          productionTitle: prodMap[aud.productionId] ?? 'Production',
          venue: aud.venue,
          startTime: aud.startTime,
          endTime: aud.endTime,
          status: aud.status,
          type: ScheduleEventType.audition,
          notes: aud.requirements.isNotEmpty
              ? aud.requirements
              : aud.description,
          originalObject: aud,
        ));
      }

      // 5. Apply dateFilter if provided
      var filtered = events;
      if (dateFilter != null) {
        filtered = filtered.where((e) {
          return e.startTime.year == dateFilter.year &&
              e.startTime.month == dateFilter.month &&
              e.startTime.day == dateFilter.day;
        }).toList();
      }

      // 6. Sort chronologically
      filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
      return filtered;
    } catch (_) {
      return [];
    }
  }
}
