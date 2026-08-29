import '../models/weekly_plan_models.dart';

abstract interface class SchoolScheduleExceptionRepository {
  Future<List<SchoolScheduleException>> getForAcademicYear(String academicYear);
}

class MemorySchoolScheduleExceptionRepository
    implements SchoolScheduleExceptionRepository {
  MemorySchoolScheduleExceptionRepository([
    Iterable<SchoolScheduleException> initial = const [],
  ]) : _items = List<SchoolScheduleException>.from(initial);

  final List<SchoolScheduleException> _items;

  @override
  Future<List<SchoolScheduleException>> getForAcademicYear(
    String academicYear,
  ) async => List.unmodifiable(_items);
}
