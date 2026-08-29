import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/weekly_plan_models.dart';
import '../../domain/repositories/school_schedule_exception_repository.dart';

class AssetSchoolScheduleExceptionRepository
    implements SchoolScheduleExceptionRepository {
  AssetSchoolScheduleExceptionRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const _indexAsset = 'assets/calendars/calendar_index.json';

  final AssetBundle _bundle;
  final Map<String, Future<List<SchoolScheduleException>>> _cache = {};

  @override
  Future<List<SchoolScheduleException>> getForAcademicYear(
    String academicYear,
  ) => _cache.putIfAbsent(academicYear, () => _load(academicYear));

  Future<List<SchoolScheduleException>> _load(String academicYear) async {
    final index = _decodeMap(await _bundle.loadString(_indexAsset), _indexAsset);
    final calendars = _list(index['calendars']);
    Map<String, dynamic>? selected;
    for (final raw in calendars) {
      final entry = _map(raw);
      if (entry['academic_year']?.toString() == academicYear) {
        selected = entry;
        break;
      }
    }
    if (selected == null) return const [];

    final asset = selected['asset']?.toString().trim() ?? '';
    if (asset.isEmpty) return const [];
    final calendar = _decodeMap(await _bundle.loadString(asset), asset);
    final rawExceptions = _list(calendar['schedule_exceptions']);
    final result = <SchoolScheduleException>[];
    final ids = <String>{};
    for (final raw in rawExceptions) {
      final item = _map(raw);
      final id = _requiredText(item['id'], 'schedule_exceptions[].id');
      if (!ids.add(id)) {
        throw StateError('Tekrarlanan schedule exception id: $id');
      }
      final date = _date(item['date'], 'schedule_exceptions[].date');
      final label = _requiredText(
        item['label'],
        'schedule_exceptions[].label',
      );
      final startMinute = _optionalMinute(item['start_minute'], 0);
      final endMinute = _optionalMinute(item['end_minute'], 24 * 60);
      if (startMinute < 0 ||
          startMinute >= 24 * 60 ||
          endMinute <= 0 ||
          endMinute > 24 * 60 ||
          endMinute <= startMinute) {
        throw StateError(
          'Geçersiz schedule exception minute range: $id '
          '$startMinute-$endMinute',
        );
      }
      result.add(
        SchoolScheduleException(
          id: id,
          date: date,
          label: label,
          startMinute: startMinute,
          endMinute: endMinute,
        ),
      );
    }
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startMinute.compareTo(b.startMinute);
    });
    return List.unmodifiable(result);
  }
}

Map<String, dynamic> _decodeMap(String raw, String source) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  throw StateError('$source map olmalıdır.');
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _requiredText(Object? value, String field) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) throw StateError('$field eksik.');
  return text;
}

DateTime _date(Object? value, String field) {
  final parsed = DateTime.tryParse(_requiredText(value, field));
  if (parsed == null) throw StateError('$field geçerli ISO tarih olmalıdır.');
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int _optionalMinute(Object? value, int fallback) {
  if (value == null) return fallback;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? fallback;
}
