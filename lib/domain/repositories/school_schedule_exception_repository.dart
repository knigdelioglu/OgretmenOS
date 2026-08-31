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
  ) async {
    final years = academicYear.split('-');
    final startYear = years.length == 2 ? int.tryParse(years.first) : null;
    final endYear = years.length == 2 ? int.tryParse(years.last) : null;
    if (startYear == null || endYear == null || endYear != startYear + 1) {
      throw FormatException('Geçersiz akademik yıl: $academicYear');
    }
    final start = DateTime(startYear, 9, 1);
    final end = DateTime(endYear, 8, 31, 23, 59, 59, 999);
    final result = _items
        .where((item) {
          if (item.academicYear != null)
            return item.academicYear == academicYear;
          final date = DateTime(item.date.year, item.date.month, item.date.day);
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);
    return List.unmodifiable(result);
  }
}
