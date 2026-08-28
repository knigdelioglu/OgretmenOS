import '../../domain/models/course_models.dart';
import '../../domain/models/lesson_plan_models.dart';

String teacherLessonHourRange(int startHour, int endHour) {
  if (startHour <= 0 || endHour < startHour) return 'Ders saatleri';
  if (startHour == endHour) return '$startHour. ders saati';
  return '$startHour–$endHour. ders saatleri';
}

class LessonPlanTeacherPresentation {
  LessonPlanTeacherPresentation({
    required this.blockPlans,
    this.blockDetail,
  }) : _packageRanges = _buildPackageRanges(blockPlans);

  final List<LessonPlanPackage> blockPlans;
  final BlockDetail? blockDetail;
  final Map<int, ({int start, int end})> _packageRanges;

  String packageLabel(LessonPlanPackage plan) {
    final range = _packageRanges[plan.packageNo];
    if (range != null) return teacherLessonHourRange(range.start, range.end);

    final start = ((plan.packageNo - 1) * plan.lessonHours) + 1;
    final end = start + plan.lessonHours - 1;
    return teacherLessonHourRange(start, end);
  }

  String packageHeaderLabel(LessonPlanPackage plan) => packageLabel(plan)
      .replaceAll('ders saatleri', 'DERS SAATLERİ')
      .replaceAll('ders saati', 'DERS SAATİ');

  String? get locationLabel {
    final detail = blockDetail;
    if (detail == null) return null;
    final theme = _cleanThemeTitle(detail.theme.title);
    final block = _cleanBlockTitle(detail.block.title);
    if (theme.isEmpty) return block.isEmpty ? null : block;
    if (block.isEmpty) return theme;
    return '$theme · $block';
  }

  List<String> outcomeLabels(List<String> codes) => [
    for (final code in codes) _outcomeLabel(code),
  ];

  List<String> activityLabels(List<String> ids) {
    final activities = blockDetail?.activities ?? const <Activity>[];
    final result = <String>[];
    for (final id in ids) {
      final activity = _activityById(activities, id);
      result.add(
        activity == null ? 'Ders kitabı etkinliği' : _activityLabel(activity),
      );
    }
    return List<String>.unmodifiable(result);
  }

  List<String> formLabels(List<String> ids) {
    final forms = blockDetail?.forms ?? const <Form>[];
    final result = <String>[];
    for (final id in ids) {
      final form = _formById(forms, id);
      result.add(form == null ? 'Değerlendirme formu' : _formLabel(form));
    }
    return List<String>.unmodifiable(result);
  }

  String humanize(String raw) {
    var value = raw;
    final detail = blockDetail;

    if (detail != null) {
      final replacements = <String, String>{
        detail.theme.id: _cleanThemeTitle(detail.theme.title),
        detail.block.id: _cleanBlockTitle(detail.block.title),
        for (final activity in detail.activities) activity.id: activity.title,
        for (final form in detail.forms) form.id: form.title,
      };
      final orderedKeys = replacements.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final key in orderedKeys) {
        final replacement = replacements[key];
        if (replacement != null && replacement.trim().isNotEmpty) {
          value = value.replaceAll(key, replacement);
        }
      }
    }

    value = _humanizePackageRangeReferences(value);

    for (final entry in _packageRanges.entries) {
      final number = entry.key.toString().padLeft(2, '0');
      final range = entry.value;
      final label = teacherLessonHourRange(range.start, range.end);
      final locative = range.start == range.end
          ? '${range.start}. ders saatinde'
          : '${range.start}–${range.end}. ders saatlerinde';
      value = value.replaceAll(
        RegExp("\\bP$number['’](?:de|da|te|ta)\\b", caseSensitive: false),
        locative,
      );
      value = value.replaceAll(
        RegExp('\\bP$number\\b', caseSensitive: false),
        label,
      );
    }

    value = value.replaceAllMapped(
      RegExp(r'\bTDE_(\d+)\b'),
      (match) => '${match.group(1)}. Sınıf Türk Dili ve Edebiyatı',
    );
    value = value.replaceAllMapped(
      RegExp(r'\bTEMA_0*(\d+)\b'),
      (match) => '${match.group(1)}. Tema',
    );
    value = value.replaceAllMapped(
      RegExp(r'\bT(\d+)\b'),
      (match) => '${match.group(1)}. Tema',
    );

    value = value.replaceAll(
      RegExp(r'\bT\d+_ACT_[A-Z0-9_]+\b'),
      'Ders kitabı etkinliği',
    );
    value = value.replaceAll(
      RegExp(r'\bFORM_[A-Z0-9_]+\b'),
      'Değerlendirme formu',
    );
    value = value.replaceAll(
      RegExp(r'\bBLOCK_[A-Z0-9_]+\b'),
      'Ders planı bölümü',
    );
    value = value.replaceAll(
      RegExp("\\bP\\d{2}['’](?:de|da|te|ta)\\b", caseSensitive: false),
      'ders planında',
    );
    value = value.replaceAll(
      RegExp(r'\bP\d{2}\b', caseSensitive: false),
      'ders planı',
    );
    value = value.replaceAll(RegExp(r'\bASSESS\b'), 'Ölçme ve değerlendirme');
    value = value.replaceAll(RegExp(r'\bFORM\b'), 'Değerlendirme formu');
    value = value.replaceAll(RegExp(r'\bACT\b'), 'Etkinlik');

    return value;
  }

  String _humanizePackageRangeReferences(String input) {
    var value = input;

    final priorWorkProducts = RegExp(
      r'\bP\d{1,2}\s*[-–—/]\s*P\d{1,2}\s+(?:(öğrenci)\s+)?(çalışma\s+ürünler(?:i|inden|ine|ini|inin|inde))\b',
      caseSensitive: false,
    );
    value = value.replaceAllMapped(priorWorkProducts, (match) {
      final before = value.substring(0, match.start).trimRight();
      final atSentenceStart =
          before.isEmpty || RegExp(r'[.!?]\s*$').hasMatch(before);
      final prefix = atSentenceStart ? 'Önceki' : 'önceki';
      final student = match.group(1) == null ? '' : 'öğrenci ';
      final workProducts = match.group(2) ?? 'çalışma ürünleri';
      return '$prefix derslerde oluşturulan $student$workProducts';
    });

    final connectiveRange = RegExp(
      r'\bP(\d{1,2})\s*[-–—/]\s*P(\d{1,2})(?=\s+(?:boyunca|arasında|ile|ve|öncesinde|sonrasında)\b)',
      caseSensitive: false,
    );
    value = value.replaceAllMapped(connectiveRange, (match) {
      final range = _resolvedPackageRange(match);
      return range == null
          ? 'ilgili ders planları'
          : teacherLessonHourRange(range.start, range.end);
    });

    final bareRange = RegExp(
      r'\bP(\d{1,2})\s*[-–—/]\s*P(\d{1,2})\b',
      caseSensitive: false,
    );
    value = value.replaceAllMapped(bareRange, (match) {
      final range = _resolvedPackageRange(match);
      if (range == null) return 'ilgili ders planlarına ait';
      final label = teacherLessonHourRange(range.start, range.end)
          .replaceFirst('ders saati', 'ders saatine')
          .replaceFirst('ders saatleri', 'ders saatlerine');
      return '$label ait';
    });

    return value;
  }

  ({int start, int end})? _resolvedPackageRange(Match match) {
    final firstPackage = int.tryParse(match.group(1) ?? '');
    final lastPackage = int.tryParse(match.group(2) ?? '');
    if (firstPackage == null || lastPackage == null) return null;
    final first = _packageRanges[firstPackage];
    final last = _packageRanges[lastPackage];
    if (first == null || last == null || first.start > last.end) return null;
    return (start: first.start, end: last.end);
  }

  String validationLabel(String value) => switch (value) {
    'PASS' || 'VERIFIED' => 'Doğrulandı',
    _ => 'Kontrol edildi',
  };

  String _outcomeLabel(String code) {
    final outcomes = blockDetail?.outcomes ?? const <Outcome>[];
    Outcome? match;
    for (final outcome in outcomes) {
      if (outcome.code == code) {
        match = outcome;
        break;
      }
    }
    if (match == null) return code;

    var text = match.officialText.trim();
    text = text.replaceFirst(
      RegExp('^${RegExp.escape(code)}\\.?\\s*', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(
      RegExp(
        r'^[“"][^”"]+[”"]\s+temasında ele alınan\s+',
        caseSensitive: false,
      ),
      '',
    );
    if (text.isEmpty) return code;
    final readable = '${text[0].toUpperCase()}${text.substring(1)}';
    return '$readable ($code)';
  }

  static Map<int, ({int start, int end})> _buildPackageRanges(
    List<LessonPlanPackage> plans,
  ) {
    final result = <int, ({int start, int end})>{};
    var start = 1;
    final ordered = [...plans]
      ..sort((a, b) => a.packageNo.compareTo(b.packageNo));
    for (final plan in ordered) {
      final end = start + plan.lessonHours - 1;
      result[plan.packageNo] = (start: start, end: end);
      start = end + 1;
    }
    return result;
  }
}

Activity? _activityById(List<Activity> activities, String id) {
  for (final activity in activities) {
    if (activity.id == id) return activity;
  }
  return null;
}

Form? _formById(List<Form> forms, String id) {
  for (final form in forms) {
    if (form.id == id) return form;
  }
  return null;
}

String _activityLabel(Activity activity) {
  final page = activity.printedPage?.trim();
  if (page == null || page.isEmpty) return activity.title;
  final normalized = page.startsWith('s.') ? page : 's. $page';
  return '${activity.title} · Ders kitabı $normalized';
}

String _formLabel(Form form) {
  if (form.printedPage == null) return form.title;
  return '${form.title} · Ders kitabı s. ${form.printedPage}';
}

String _cleanThemeTitle(String value) => value
    .replaceFirstMapped(
      RegExp(r'^\s*(\d+)\.\s*TEMA\s*:\s*', caseSensitive: false),
      (match) => '${match.group(1)}. Tema: ',
    )
    .trim();

String _cleanBlockTitle(String value) => value
    .replaceFirst(RegExp(r'^\s*\d+\.\s*Tema\s+', caseSensitive: false), '')
    .replaceFirst(RegExp(r'\s+Bloğu\s*:\s*', caseSensitive: false), ': ')
    .trim();
