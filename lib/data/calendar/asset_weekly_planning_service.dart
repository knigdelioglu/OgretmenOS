// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/course_models.dart';
import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';

class AssetWeeklyPlanningService implements WeeklyPlanningService {
  AssetWeeklyPlanningService({
    required CourseKnowledgeRepository repository,
    AssetBundle? bundle,
  }) : _repository = repository,
       _bundle = bundle ?? rootBundle;

  static const _indexAsset = 'assets/calendars/calendar_index.json';

  final CourseKnowledgeRepository _repository;
  final AssetBundle _bundle;

  @override
  Future<AnnualWeeklyPlan> buildPlan({DateTime? today}) async {
    final course = await _repository.getCourse();
    final calendar = await _loadActiveCalendar();
    final profile = _CourseScheduleProfile.fromJson(
      _requiredMap(
        calendar.courseProfiles[course.courseId],
        'course_profiles.${course.courseId}',
      ),
    );
    final sequence = await _repository.getAnnualSequence();
    if (sequence.isEmpty) {
      throw StateError('Yıllık öğretim sırası boş.');
    }

    final activeWeeks = _buildActiveWeeks(calendar);
    _validateCalendarAndProfile(
      calendar: calendar,
      profile: profile,
      activeWeeks: activeWeeks,
      sequence: sequence,
    );

    final allocations = _buildAllocations(sequence, profile);
    final detailCache = <String, BlockDetail>{};
    final plans = <AcademicWeekPlan>[];
    var allocationIndex = 0;

    for (var index = 0; index < activeWeeks.length; index++) {
      final week = activeWeeks[index];
      final weekNumber = index + 1;
      if (week.type == AcademicWeekType.event) {
        plans.add(
          AcademicWeekPlan(
            weekNumber: weekNumber,
            start: week.start,
            end: week.end,
            type: AcademicWeekType.event,
            label: week.label,
            plannedLessonHours: 0,
            segments: const [],
            outcomes: const [],
          ),
        );
        continue;
      }

      var remainingWeekHours = profile.weeklyLessonHours;
      final segments = <WeeklyPlanSegment>[];

      while (remainingWeekHours > 0) {
        if (allocationIndex >= allocations.length) {
          throw StateError('Haftalık plan annual course-hour budgetini aştı.');
        }
        final allocation = allocations[allocationIndex];
        final consumed = allocation.remainingHours < remainingWeekHours
            ? allocation.remainingHours
            : remainingWeekHours;
        segments.add(
          WeeklyPlanSegment(
            type: allocation.type,
            theme: allocation.theme,
            block: allocation.block,
            hours: consumed,
          ),
        );
        allocation.remainingHours -= consumed;
        remainingWeekHours -= consumed;
        if (allocation.remainingHours == 0) allocationIndex++;
      }

      final outcomesById = <String, Outcome>{};
      for (final segment in segments) {
        final block = segment.block;
        if (block == null) continue;
        final detail = detailCache[block.id] ??
            await _repository.getBlock(block.id);
        detailCache[block.id] = detail;
        for (final outcome in detail.outcomes) {
          outcomesById.putIfAbsent(outcome.id, () => outcome);
        }
      }

      plans.add(
        AcademicWeekPlan(
          weekNumber: weekNumber,
          start: week.start,
          end: week.end,
          type: AcademicWeekType.instruction,
          label: '$weekNumber. Hafta',
          plannedLessonHours: profile.weeklyLessonHours,
          segments: List.unmodifiable(segments),
          outcomes: List.unmodifiable(outcomesById.values),
        ),
      );
    }

    if (allocationIndex != allocations.length ||
        allocations.any((allocation) => allocation.remainingHours != 0)) {
      throw StateError('Annual course-hour budgeti haftalara tam dağıtılamadı.');
    }

    final resolvedToday = _dateOnly(today ?? DateTime.now());
    int? currentWeekNumber;
    for (final plan in plans) {
      final weekWindowEnd = plan.start.add(const Duration(days: 6));
      if (!_isBefore(resolvedToday, plan.start) &&
          !_isAfter(resolvedToday, weekWindowEnd)) {
        currentWeekNumber = plan.weekNumber;
        break;
      }
    }

    return AnnualWeeklyPlan(
      academicYear: calendar.academicYear,
      courseId: course.courseId,
      weeklyLessonHours: profile.weeklyLessonHours,
      annualHours: profile.annualHours,
      weeks: List.unmodifiable(plans),
      currentWeekNumber: currentWeekNumber,
    );
  }

  Future<_AcademicCalendarDefinition> _loadActiveCalendar() async {
    final indexJson = _decodeMap(
      await _bundle.loadString(_indexAsset),
      _indexAsset,
    );
    final activeYear = _requiredString(
      indexJson['active_academic_year'],
      'active_academic_year',
    );
    final calendars = _requiredList(indexJson['calendars'], 'calendars');
    Map<String, dynamic>? selected;
    for (final raw in calendars) {
      final entry = _requiredMap(raw, 'calendars[]');
      if (entry['academic_year'] == activeYear) {
        selected = entry;
        break;
      }
    }
    if (selected == null) {
      throw StateError('Aktif akademik yıl için takvim asset kaydı bulunamadı.');
    }
    final asset = _requiredString(selected['asset'], 'calendars[].asset');
    final calendarJson = _decodeMap(await _bundle.loadString(asset), asset);
    final calendar = _AcademicCalendarDefinition.fromJson(calendarJson);
    if (calendar.academicYear != activeYear) {
      throw StateError('Takvim index ve calendar academic_year uyuşmuyor.');
    }
    return calendar;
  }

  List<_ActiveWeek> _buildActiveWeeks(_AcademicCalendarDefinition calendar) {
    final weeks = <_ActiveWeek>[];
    for (final term in calendar.terms) {
      if (term.start.weekday != DateTime.monday ||
          term.end.weekday != DateTime.friday ||
          _isAfter(term.start, term.end)) {
        throw StateError('Geçersiz dönem tarih aralığı: ${term.id}');
      }
      var cursor = term.start;
      while (!_isAfter(cursor, term.end)) {
        final weekEnd = cursor.add(const Duration(days: 4));
        final overlapsBreak = calendar.breaks.any(
          (pause) => _rangesOverlap(cursor, weekEnd, pause.start, pause.end),
        );
        if (!overlapsBreak) {
          final special = calendar.specialWeeks
              .where(
                (item) => _rangesOverlap(cursor, weekEnd, item.start, item.end),
              )
              .toList(growable: false);
          if (special.length > 1) {
            throw StateError('Bir okul haftasına birden fazla special week bağlı.');
          }
          final specialWeek = special.isEmpty ? null : special.first;
          weeks.add(
            _ActiveWeek(
              start: cursor,
              end: weekEnd,
              type: specialWeek?.type == 'EVENT_WEEK'
                  ? AcademicWeekType.event
                  : AcademicWeekType.instruction,
              label: specialWeek?.label ?? '',
            ),
          );
        }
        cursor = cursor.add(const Duration(days: 7));
      }
    }
    weeks.sort((a, b) => a.start.compareTo(b.start));
    return weeks;
  }

  void _validateCalendarAndProfile({
    required _AcademicCalendarDefinition calendar,
    required _CourseScheduleProfile profile,
    required List<_ActiveWeek> activeWeeks,
    required List<TimelineEntry> sequence,
  }) {
    if (profile.weeklyLessonHours <= 0 ||
        profile.annualHours <= 0 ||
        profile.themeHours <= 0 ||
        profile.structuredHoursPerTheme <= 0 ||
        profile.schoolBasedHoursPerTheme < 0) {
      throw StateError('Course scheduling profile saat değerleri geçersiz.');
    }
    if (profile.structuredHoursPerTheme +
            profile.schoolBasedHoursPerTheme !=
        profile.themeHours) {
      throw StateError('43+2 benzeri theme-hour conservation bozuk.');
    }
    if (profile.instructionalWeekCount * profile.weeklyLessonHours !=
        profile.annualHours) {
      throw StateError('Instructional week × weekly hour annual total ile eşleşmiyor.');
    }

    final instructionWeeks = activeWeeks
        .where((week) => week.type == AcademicWeekType.instruction)
        .length;
    final eventWeeks = activeWeeks
        .where((week) => week.type == AcademicWeekType.event)
        .length;
    if (instructionWeeks != profile.instructionalWeekCount ||
        eventWeeks != profile.eventWeekCount) {
      throw StateError(
        'Academic calendar active-week sayısı scheduling profile ile uyuşmuyor.',
      );
    }

    final groupedThemeIds = <String>[];
    for (final entry in sequence) {
      if (!groupedThemeIds.contains(entry.theme.id)) {
        groupedThemeIds.add(entry.theme.id);
      }
    }
    if (groupedThemeIds.length * profile.themeHours != profile.annualHours) {
      throw StateError('Theme sayısı ve annual-hour budget uyuşmuyor.');
    }
    if (profile.blockHourAllocation.fold<int>(0, (sum, value) => sum + value) !=
        profile.structuredHoursPerTheme) {
      throw StateError('Block planning allocation structured theme hours ile eşleşmiyor.');
    }
    if (calendar.terms.isEmpty) {
      throw StateError('Academic calendar dönem bilgisi içermiyor.');
    }
  }

  List<_MutableAllocation> _buildAllocations(
    List<TimelineEntry> sequence,
    _CourseScheduleProfile profile,
  ) {
    final grouped = <String, List<TimelineEntry>>{};
    for (final entry in sequence) {
      grouped.putIfAbsent(entry.theme.id, () => []).add(entry);
    }

    final allocations = <_MutableAllocation>[];
    for (final entries in grouped.values) {
      entries.sort((a, b) => a.block.order.compareTo(b.block.order));
      if (entries.length != profile.blockHourAllocation.length) {
        throw StateError(
          '${entries.first.theme.id} block sayısı planning profile ile uyuşmuyor.',
        );
      }
      for (var index = 0; index < entries.length; index++) {
        final hours = profile.blockHourAllocation[index];
        if (hours <= 0) {
          throw StateError('Block planning hour pozitif olmalıdır.');
        }
        allocations.add(
          _MutableAllocation(
            type: WeeklyPlanSegmentType.block,
            theme: entries[index].theme,
            block: entries[index].block,
            remainingHours: hours,
          ),
        );
      }
      if (profile.schoolBasedHoursPerTheme > 0) {
        allocations.add(
          _MutableAllocation(
            type: WeeklyPlanSegmentType.schoolBasedPlanning,
            theme: entries.first.theme,
            block: null,
            remainingHours: profile.schoolBasedHoursPerTheme,
          ),
        );
      }
    }
    return allocations;
  }
}

class _AcademicCalendarDefinition {
  const _AcademicCalendarDefinition({
    required this.academicYear,
    required this.terms,
    required this.breaks,
    required this.specialWeeks,
    required this.courseProfiles,
  });

  factory _AcademicCalendarDefinition.fromJson(Map<String, dynamic> json) =>
      _AcademicCalendarDefinition(
        academicYear: _requiredString(json['academic_year'], 'academic_year'),
        terms: _requiredList(json['terms'], 'terms')
            .map((item) => _DateRange.fromJson(_requiredMap(item, 'terms[]')))
            .toList(growable: false),
        breaks: _requiredList(json['breaks'], 'breaks')
            .map((item) => _DateRange.fromJson(_requiredMap(item, 'breaks[]')))
            .toList(growable: false),
        specialWeeks: _requiredList(json['special_weeks'], 'special_weeks')
            .map(
              (item) => _SpecialWeek.fromJson(
                _requiredMap(item, 'special_weeks[]'),
              ),
            )
            .toList(growable: false),
        courseProfiles: _requiredMap(json['course_profiles'], 'course_profiles'),
      );

  final String academicYear;
  final List<_DateRange> terms;
  final List<_DateRange> breaks;
  final List<_SpecialWeek> specialWeeks;
  final Map<String, dynamic> courseProfiles;
}

class _DateRange {
  const _DateRange({required this.id, required this.start, required this.end});

  factory _DateRange.fromJson(Map<String, dynamic> json) => _DateRange(
    id: _requiredString(json['id'], 'date_range.id'),
    start: _parseDate(json['start'], 'date_range.start'),
    end: _parseDate(json['end'], 'date_range.end'),
  );

  final String id;
  final DateTime start;
  final DateTime end;
}

class _SpecialWeek extends _DateRange {
  const _SpecialWeek({
    required super.id,
    required super.start,
    required super.end,
    required this.type,
    required this.label,
  });

  factory _SpecialWeek.fromJson(Map<String, dynamic> json) => _SpecialWeek(
    id: _requiredString(json['id'], 'special_week.id'),
    start: _parseDate(json['start'], 'special_week.start'),
    end: _parseDate(json['end'], 'special_week.end'),
    type: _requiredString(json['type'], 'special_week.type'),
    label: _requiredString(json['label'], 'special_week.label'),
  );

  final String type;
  final String label;
}

class _CourseScheduleProfile {
  const _CourseScheduleProfile({
    required this.weeklyLessonHours,
    required this.annualHours,
    required this.themeHours,
    required this.structuredHoursPerTheme,
    required this.schoolBasedHoursPerTheme,
    required this.instructionalWeekCount,
    required this.eventWeekCount,
    required this.blockHourAllocation,
  });

  factory _CourseScheduleProfile.fromJson(Map<String, dynamic> json) =>
      _CourseScheduleProfile(
        weeklyLessonHours: _requiredInt(
          json['weekly_lesson_hours'],
          'weekly_lesson_hours',
        ),
        annualHours: _requiredInt(json['annual_hours'], 'annual_hours'),
        themeHours: _requiredInt(json['theme_hours'], 'theme_hours'),
        structuredHoursPerTheme: _requiredInt(
          json['structured_hours_per_theme'],
          'structured_hours_per_theme',
        ),
        schoolBasedHoursPerTheme: _requiredInt(
          json['school_based_hours_per_theme'],
          'school_based_hours_per_theme',
        ),
        instructionalWeekCount: _requiredInt(
          json['instructional_week_count'],
          'instructional_week_count',
        ),
        eventWeekCount: _requiredInt(
          json['event_week_count'],
          'event_week_count',
        ),
        blockHourAllocation: _requiredList(
          json['block_hour_allocation'],
          'block_hour_allocation',
        ).map((value) => _requiredInt(value, 'block_hour_allocation[]')).toList(
          growable: false,
        ),
      );

  final int weeklyLessonHours;
  final int annualHours;
  final int themeHours;
  final int structuredHoursPerTheme;
  final int schoolBasedHoursPerTheme;
  final int instructionalWeekCount;
  final int eventWeekCount;
  final List<int> blockHourAllocation;
}

class _ActiveWeek {
  const _ActiveWeek({
    required this.start,
    required this.end,
    required this.type,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final AcademicWeekType type;
  final String label;
}

class _MutableAllocation {
  _MutableAllocation({
    required this.type,
    required this.theme,
    required this.block,
    required this.remainingHours,
  });

  final WeeklyPlanSegmentType type;
  final Theme theme;
  final Block? block;
  int remainingHours;
}

Map<String, dynamic> _decodeMap(String raw, String source) {
  final decoded = jsonDecode(raw);
  return _requiredMap(decoded, source);
}

Map<String, dynamic> _requiredMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw StateError('$field map olmalıdır.');
}

List<dynamic> _requiredList(Object? value, String field) {
  if (value is List) return value;
  throw StateError('$field liste olmalıdır.');
}

String _requiredString(Object? value, String field) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) throw StateError('$field eksik.');
  return text;
}

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) throw StateError('$field integer olmalıdır.');
  return parsed;
}

DateTime _parseDate(Object? value, String field) {
  final raw = _requiredString(value, field);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw StateError('$field geçerli ISO tarih olmalıdır.');
  return _dateOnly(parsed);
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _isBefore(DateTime a, DateTime b) => a.compareTo(b) < 0;
bool _isAfter(DateTime a, DateTime b) => a.compareTo(b) > 0;

bool _rangesOverlap(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) =>
    !_isAfter(aStart, bEnd) && !_isBefore(aEnd, bStart);
