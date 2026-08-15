import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import 'feature_widgets.dart';

/// Teacher-facing presentation helpers.
///
/// Runtime/domain codes remain available to the data and debug layers, but
/// production screens should translate them before rendering.
String teacherTimelineResolutionLabel(String value) => switch (value) {
  'THEME_TIME_RESOLVED' => 'Tema süreleri programda belirli',
  'UNRESOLVED' => 'Tema süreleri henüz belirli değil',
  _ => 'Tema süreleri bilgisi bulunmuyor',
};

String teacherBlockTimeLabel(String? value) => switch (value) {
  'ORDER_ONLY' => 'Bu blok için yalnız plan sırası kullanılabilir.',
  'RESOLVED' => 'Blok süresi programda belirli.',
  'UNRESOLVED' => 'Bu blok için ayrı süre bilgisi bulunmuyor.',
  _ => 'Bu blok için ayrı süre bilgisi bulunmuyor.',
};

String? teacherResourcePriorityLabel(String? value) => switch (value) {
  'REQUIRED' => 'Gerekli',
  'RECOMMENDED' => 'Önerilen',
  'OPTIONAL' => 'İsteğe bağlı',
  'NOT_NEEDED' => null,
  'HIGH' => 'Yüksek öncelik',
  'MEDIUM' => 'Orta öncelik',
  'LOW' => 'Düşük öncelik',
  _ => null,
};

String? teacherTextbookCoverageLabel(String? value) => switch (value) {
  'COVERED' => 'Ders kitabında karşılığı var',
  'PARTIALLY_COVERED' => 'Ders kitabı kısmen karşılıyor',
  'NOT_COVERED' || 'UNCOVERED' => 'Ders kitabında karşılığı yok',
  _ => null,
};

String? teacherEvaluatorLabel(String? value) => switch (value) {
  'student_self' => 'Öğrenci öz değerlendirmesi',
  'student_peer' || 'peer' => 'Akran değerlendirmesi',
  'teacher' => 'Öğretmen değerlendirmesi',
  'teacher_and_student' || 'student_and_teacher' =>
    'Öğretmen ve öğrenci değerlendirmesi',
  'teacher_and_peer' || 'peer_and_teacher' =>
    'Öğretmen ve akran değerlendirmesi',
  _ => null,
};

String? teacherLocatorLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();

  final printedMatch = RegExp(
    r'\bs\.\s*([0-9][0-9,\s\-–]*)',
    caseSensitive: false,
  ).firstMatch(value);
  final pdfMatch = RegExp(
    r'PDF\s*:?\s*(?:s\.\s*)?([0-9][0-9,\s\-–]*)',
    caseSensitive: false,
  ).firstMatch(value);

  final references = <String>[];
  final printed = _cleanPageToken(printedMatch?.group(1));
  final pdf = _cleanPageToken(pdfMatch?.group(1));
  if (printed != null) references.add('Ders kitabı s. $printed');
  if (pdf != null && pdf != printed) references.add('PDF s. $pdf');
  if (references.isNotEmpty) return references.join(' · ');

  final looksTechnical =
      value.contains('/') ||
      value.contains('\\') ||
      value.endsWith('.json') ||
      value.endsWith('.sqlite') ||
      value.endsWith('.pdf') ||
      RegExp(
        r'\b(?:T\d+_|FORM_|RES_|NEED_|ACT_|BLOCK_|TEMA_|SRC_)[A-Z0-9_]*',
      ).hasMatch(value);
  if (looksTechnical) return null;

  return value.length <= 96 ? value : null;
}

String? teacherSourceSubtitle(model.SourceReference source) {
  final parts = <String>[];
  final typeLabel = _sourceTypeLabel(source.sourceType);
  final locatorLabel = teacherLocatorLabel(source.locator);
  if (typeLabel != null) parts.add(typeLabel);
  if (locatorLabel != null && !parts.contains(locatorLabel)) {
    parts.add(locatorLabel);
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

class TeacherResourceDecisionCard extends StatelessWidget {
  const TeacherResourceDecisionCard({super.key, required this.decision});

  final model.ResourceDecision decision;

  @override
  Widget build(BuildContext context) {
    final priority = teacherResourcePriorityLabel(decision.priority);
    final coverage = teacherTextbookCoverageLabel(decision.textbookCoverage);
    final locator = teacherLocatorLabel(decision.locator);
    final (label, icon, color) = _categoryPresentation(
      context,
      decision.appCategory,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (priority != null) Chip(label: Text(priority)),
              ],
            ),
            if (decision.purpose != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(decision.purpose!, style: const TextStyle(height: 1.4)),
            ],
            if (coverage != null || locator != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  if (coverage != null)
                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 17),
                      label: Text(coverage),
                    ),
                  if (locator != null)
                    Chip(
                      avatar: const Icon(Icons.place_outlined, size: 17),
                      label: Text(locator),
                    ),
                ],
              ),
            ],
            if (decision.expectedEvidence != null) ...[
              const SizedBox(height: AppSpacing.md),
              LabeledValue(
                label: 'Beklenen ürün',
                value: decision.expectedEvidence!,
                icon: Icons.check_circle_outline,
              ),
            ],
            if (decision.teacherReviewRequired) ...[
              const SizedBox(height: AppSpacing.md),
              const StatusPanel(
                icon: Icons.visibility_outlined,
                title: 'Öğretmen incelemesi',
                message: 'Bu içerik kullanımdan önce öğretmen kontrolü gerektiriyor.',
                tone: StatusTone.attention,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, IconData, Color) _categoryPresentation(
    BuildContext context,
    String? category,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (category) {
      'BOOK_SUFFICIENT' => (
        'Kitap karşılığı yeterli',
        Icons.menu_book_outlined,
        scheme.primary,
      ),
      'USE_EXISTING_TEXTBOOK_ACTIVITY' => (
        'Kitaptaki etkinliği kullanın',
        Icons.auto_stories_outlined,
        scheme.primary,
      ),
      'USE_EXISTING_FORM' => (
        'Mevcut formu kullanın',
        Icons.assignment_turned_in_outlined,
        scheme.primary,
      ),
      'USE_ANNUAL_ASSESSMENT_ARTIFACT' => (
        'Mevcut değerlendirme aracını kullanın',
        Icons.fact_check_outlined,
        scheme.primary,
      ),
      'ADDITIONAL_SUPPORT_REQUIRED' => (
        'Ek destek gerekli',
        Icons.add_task,
        scheme.tertiary,
      ),
      _ => (
        'Kaynak kullanımı',
        Icons.fact_check_outlined,
        scheme.secondary,
      ),
    };
  }
}

String? _sourceTypeLabel(String? sourceType) {
  if (sourceType == null || sourceType.trim().isEmpty) return null;
  final normalized = sourceType.toUpperCase();
  if (normalized.contains('CURRICULUM') || normalized.contains('PROGRAM')) {
    return 'Öğretim programı';
  }
  if (normalized.contains('TEXTBOOK') || normalized.contains('BOOK')) {
    return 'Ders kitabı';
  }
  return null;
}

String? _cleanPageToken(String? value) {
  if (value == null) return null;
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[,;:\s]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? null : cleaned;
}
