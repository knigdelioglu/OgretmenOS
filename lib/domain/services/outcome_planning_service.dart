import '../models/course_models.dart';
import '../models/outcome_tracking_models.dart';
import '../models/weekly_plan_models.dart';
import '../repositories/course_knowledge_repository.dart';
import '../repositories/outcome_tracking_repository.dart';

typedef OutcomeInteractionObserver =
    Future<void> Function(
      TrackedOutcome item,
      OutcomeTrackingStatus resultingStatus,
      int displayWeekNumber,
    );

class OutcomePlanningService {
  const OutcomePlanningService({
    required this.repository,
    required this.weeklyPlanning,
    required this.trackingRepository,
    this.onInteraction,
  });

  final CourseKnowledgeRepository repository;
  final WeeklyPlanningService weeklyPlanning;
  final OutcomeTrackingRepository trackingRepository;
  final OutcomeInteractionObserver? onInteraction;

  Future<AnnualOutcomePlan> buildPlan({DateTime? today}) async {
    final weeklyPlan = await weeklyPlanning.buildPlan(today: today);
    final records = await trackingRepository.getForAcademicYear(
      weeklyPlan.academicYear,
    );
    final recordsByKey = <String, LearningOutcomeTrackingRecord>{
      for (final record in records) record.trackingKey: record,
    };

    final detailCache = <String, BlockDetail>{};
    final weekItems = <int, List<TrackedOutcome>>{};
    final baseByKey = <String, TrackedOutcome>{};

    for (final week in weeklyPlan.weeks) {
      final blockDetails = <BlockDetail>[];
      for (final segment in week.segments) {
        final block = segment.block;
        if (block == null) continue;
        final detail =
            detailCache[block.id] ?? await repository.getBlock(block.id);
        detailCache[block.id] = detail;
        if (!blockDetails.any((item) => item.block.id == detail.block.id)) {
          blockDetails.add(detail);
        }
      }

      final items = <TrackedOutcome>[];
      for (final outcome in week.outcomes) {
        final contexts = blockDetails
            .where(
              (detail) => detail.outcomes.any((item) => item.id == outcome.id),
            )
            .map((detail) => OutcomeBlockContext(detail: detail))
            .toList(growable: false);
        final key = outcomeTrackingKey(
          academicYear: weeklyPlan.academicYear,
          outcomeId: outcome.id,
          plannedWeekNumber: week.weekNumber,
        );
        final record = recordsByKey[key];
        final tracked = TrackedOutcome(
          outcome: outcome,
          academicYear: weeklyPlan.academicYear,
          plannedWeekNumber: week.weekNumber,
          displayWeekNumber: week.weekNumber,
          status: record?.status ?? OutcomeTrackingStatus.planned,
          contexts: contexts,
          actualHours: record?.actualHours,
          teacherNote: record?.teacherNote,
          completedAt: record?.completedAt,
          carriedToWeekNumber: record?.carriedToWeekNumber,
        );
        items.add(tracked);
        baseByKey[key] = tracked;
      }
      weekItems[week.weekNumber] = items;
    }

    for (final record in records) {
      final target = record.carriedToWeekNumber;
      if (target == null || target == record.plannedWeekNumber) continue;
      final targetWeek = weeklyPlan.week(target);
      if (targetWeek == null || targetWeek.isEventWeek) continue;
      final base = baseByKey[record.trackingKey];
      if (base == null) continue;
      final targetItems = weekItems[target];
      if (targetItems == null) continue;
      final alreadyProjected = targetItems.any(
        (item) => item.trackingKey == base.trackingKey && item.isCarriedIn,
      );
      if (alreadyProjected) continue;
      targetItems.insert(
        0,
        TrackedOutcome(
          outcome: base.outcome,
          academicYear: base.academicYear,
          plannedWeekNumber: base.plannedWeekNumber,
          displayWeekNumber: target,
          status: record.status,
          contexts: base.contexts,
          actualHours: record.actualHours,
          teacherNote: record.teacherNote,
          completedAt: record.completedAt,
          carriedToWeekNumber: target,
          carriedFromWeekNumber: record.plannedWeekNumber,
          isCarriedIn: true,
        ),
      );
    }

    final summaries = <WeeklyOutcomeSummary>[];
    for (final week in weeklyPlan.weeks) {
      final items = weekItems[week.weekNumber] ?? <TrackedOutcome>[];
      items.sort((a, b) {
        if (a.isCarriedIn != b.isCarriedIn) return a.isCarriedIn ? -1 : 1;
        return a.outcome.code.compareTo(b.outcome.code);
      });
      summaries.add(
        WeeklyOutcomeSummary(week: week, outcomes: List.unmodifiable(items)),
      );
    }

    return AnnualOutcomePlan(
      weeklyPlan: weeklyPlan,
      weeks: List.unmodifiable(summaries),
    );
  }

  Future<LearningOutcomeTrackingRecord?> captureTracking(TrackedOutcome item) =>
      _findCurrentRecord(item);

  Future<void> restoreTracking(
    TrackedOutcome item,
    LearningOutcomeTrackingRecord? record, {
    int? displayWeekNumber,
  }) async {
    if (record == null) {
      await trackingRepository.delete(
        academicYear: item.academicYear,
        outcomeId: item.outcome.id,
        plannedWeekNumber: item.plannedWeekNumber,
      );
    } else {
      await trackingRepository.save(record);
    }
    await _notifyInteraction(
      item,
      record?.status ?? OutcomeTrackingStatus.planned,
      displayWeekNumber ?? item.displayWeekNumber,
    );
  }

  Future<void> restoreTrackingStatus(
    TrackedOutcome item,
    LearningOutcomeTrackingRecord? record, {
    int? displayWeekNumber,
  }) async {
    final current = await _findCurrentRecord(item);
    if (record == null) {
      if (current == null) return;
      if (_hasAuxiliaryState(current)) {
        await trackingRepository.save(
          LearningOutcomeTrackingRecord(
            academicYear: current.academicYear,
            outcomeId: current.outcomeId,
            plannedWeekNumber: current.plannedWeekNumber,
            status: OutcomeTrackingStatus.planned,
            actualHours: current.actualHours,
            teacherNote: current.teacherNote,
            completedAt: null,
            carriedToWeekNumber: null,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await trackingRepository.delete(
          academicYear: item.academicYear,
          outcomeId: item.outcome.id,
          plannedWeekNumber: item.plannedWeekNumber,
        );
      }
    } else {
      await trackingRepository.save(
        LearningOutcomeTrackingRecord(
          academicYear: record.academicYear,
          outcomeId: record.outcomeId,
          plannedWeekNumber: record.plannedWeekNumber,
          status: record.status,
          actualHours: current?.actualHours ?? record.actualHours,
          teacherNote: _cleanText(current?.teacherNote ?? record.teacherNote),
          completedAt: record.completedAt,
          carriedToWeekNumber: record.carriedToWeekNumber,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _notifyInteraction(
      item,
      record?.status ?? OutcomeTrackingStatus.planned,
      displayWeekNumber ?? item.displayWeekNumber,
    );
  }

  Future<void> setStatus(
    TrackedOutcome item,
    OutcomeTrackingStatus status,
  ) async {
    final current = await _findCurrentRecord(item);
    final now = DateTime.now();
    final carriedToWeekNumber =
        current?.carriedToWeekNumber ?? item.carriedToWeekNumber;
    final keepCarry =
        carriedToWeekNumber != null && status != OutcomeTrackingStatus.planned;
    await trackingRepository.save(
      LearningOutcomeTrackingRecord(
        academicYear: item.academicYear,
        outcomeId: item.outcome.id,
        plannedWeekNumber: item.plannedWeekNumber,
        status: status,
        actualHours: current?.actualHours ?? item.actualHours,
        teacherNote: _cleanText(current?.teacherNote ?? item.teacherNote),
        completedAt: status == OutcomeTrackingStatus.completed ? now : null,
        carriedToWeekNumber: keepCarry ? carriedToWeekNumber : null,
        updatedAt: now,
      ),
    );
    await _notifyInteraction(item, status, item.displayWeekNumber);
  }

  Future<void> saveTeacherNote(TrackedOutcome item, String? note) async {
    final current = await _findCurrentRecord(item);
    final now = DateTime.now();
    await trackingRepository.save(
      LearningOutcomeTrackingRecord(
        academicYear: item.academicYear,
        outcomeId: item.outcome.id,
        plannedWeekNumber: item.plannedWeekNumber,
        status: current?.status ?? item.status,
        actualHours: current?.actualHours ?? item.actualHours,
        teacherNote: _cleanText(note),
        completedAt: current?.completedAt ?? item.completedAt,
        carriedToWeekNumber:
            current?.carriedToWeekNumber ?? item.carriedToWeekNumber,
        updatedAt: now,
      ),
    );
    await _notifyInteraction(
      item,
      current?.status ?? item.status,
      item.displayWeekNumber,
    );
  }

  Future<void> saveActualHours(TrackedOutcome item, int? hours) async {
    if (hours != null && hours < 0) {
      throw ArgumentError.value(hours, 'hours', 'Negatif olamaz.');
    }
    final current = await _findCurrentRecord(item);
    final now = DateTime.now();
    await trackingRepository.save(
      LearningOutcomeTrackingRecord(
        academicYear: item.academicYear,
        outcomeId: item.outcome.id,
        plannedWeekNumber: item.plannedWeekNumber,
        status: current?.status ?? item.status,
        actualHours: hours,
        teacherNote: _cleanText(current?.teacherNote ?? item.teacherNote),
        completedAt: current?.completedAt ?? item.completedAt,
        carriedToWeekNumber:
            current?.carriedToWeekNumber ?? item.carriedToWeekNumber,
        updatedAt: now,
      ),
    );
    await _notifyInteraction(
      item,
      current?.status ?? item.status,
      item.displayWeekNumber,
    );
  }

  Future<void> carryToWeek({
    required TrackedOutcome item,
    required int targetWeekNumber,
    required AnnualOutcomePlan plan,
  }) async {
    final target = plan.week(targetWeekNumber);
    if (target == null) {
      throw ArgumentError.value(
        targetWeekNumber,
        'targetWeekNumber',
        'Hedef hafta bulunamadı.',
      );
    }
    if (target.week.isEventWeek) {
      throw StateError('Etkinlik haftasına kazanım taşınamaz.');
    }
    if (targetWeekNumber <= item.plannedWeekNumber) {
      throw StateError(
        'Kazanım yalnız daha sonraki bir öğretim haftasına taşınabilir.',
      );
    }
    final current = await _findCurrentRecord(item);
    final now = DateTime.now();
    await trackingRepository.save(
      LearningOutcomeTrackingRecord(
        academicYear: item.academicYear,
        outcomeId: item.outcome.id,
        plannedWeekNumber: item.plannedWeekNumber,
        status: OutcomeTrackingStatus.carriedOver,
        actualHours: current?.actualHours ?? item.actualHours,
        teacherNote: _cleanText(current?.teacherNote ?? item.teacherNote),
        completedAt: null,
        carriedToWeekNumber: targetWeekNumber,
        updatedAt: now,
      ),
    );
    await _notifyInteraction(
      item,
      OutcomeTrackingStatus.carriedOver,
      targetWeekNumber,
    );
  }

  Future<void> resetTracking(TrackedOutcome item) => trackingRepository.delete(
    academicYear: item.academicYear,
    outcomeId: item.outcome.id,
    plannedWeekNumber: item.plannedWeekNumber,
  );

  Future<LearningOutcomeTrackingRecord?> _findCurrentRecord(
    TrackedOutcome item,
  ) async {
    final records = await trackingRepository.getForAcademicYear(
      item.academicYear,
    );
    for (final record in records) {
      if (record.trackingKey == item.trackingKey) return record;
    }
    return null;
  }

  bool _hasAuxiliaryState(LearningOutcomeTrackingRecord record) =>
      record.actualHours != null || record.teacherNote != null;

  Future<void> _notifyInteraction(
    TrackedOutcome item,
    OutcomeTrackingStatus status,
    int displayWeekNumber,
  ) async {
    final observer = onInteraction;
    if (observer == null) return;
    try {
      await observer(item, status, displayWeekNumber);
    } on Object {
      // Continuity is convenience state; a preference write must never block
      // authoritative teacher tracking persistence.
    }
  }

  String? _cleanText(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
