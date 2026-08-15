import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;

class FeatureErrorView extends StatelessWidget {
  const FeatureErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class UnresolvedText extends StatelessWidget {
  const UnresolvedText({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class ResourceDecisionCard extends StatelessWidget {
  const ResourceDecisionCard({super.key, required this.decision});

  final model.ResourceDecision decision;

  @override
  Widget build(BuildContext context) {
    final category = decision.appCategory;
    final priority = resourcePriorityLabel(decision.priority);
    final (label, icon, color) = _categoryPresentation(context, category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (priority != null) Chip(label: Text(priority)),
              ],
            ),
            if (decision.purpose != null) ...[
              const SizedBox(height: 8),
              Text(decision.purpose!),
            ],
            if (decision.textbookCoverage != null ||
                decision.locator != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (decision.textbookCoverage != null)
                    Text('Kitap kapsamı: ${decision.textbookCoverage}'),
                  if (decision.locator != null)
                    Text('Kaynak: ${decision.locator}'),
                ],
              ),
            ],
            if (decision.teacherReviewRequired) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Öğretmen incelemesi gerekiyor.'),
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
        'Kitap karşılığı mevcut',
        Icons.menu_book_outlined,
        scheme.primary,
      ),
      'USE_EXISTING_TEXTBOOK_ACTIVITY' => (
        'Mevcut kitap etkinliği kullanılır',
        Icons.auto_stories_outlined,
        scheme.primary,
      ),
      'USE_EXISTING_FORM' => (
        'Mevcut form kullanılır',
        Icons.assignment_turned_in_outlined,
        scheme.primary,
      ),
      'USE_ANNUAL_ASSESSMENT_ARTIFACT' => (
        'Yıllık değerlendirme aracı kullanılır',
        Icons.fact_check_outlined,
        scheme.primary,
      ),
      'ADDITIONAL_SUPPORT_REQUIRED' => (
        'Ek destek gerekli',
        Icons.add_task,
        scheme.tertiary,
      ),
      _ => (
        'Doğrulanmış kaynak kararı',
        Icons.fact_check_outlined,
        scheme.secondary,
      ),
    };
  }
}

String pageReference({String? printed, String? pdf}) {
  final references = <String>[];
  if (printed != null && printed.isNotEmpty) {
    references.add('Basılı s. $printed');
  }
  if (pdf != null && pdf.isNotEmpty) {
    references.add('PDF s. $pdf');
  }
  return references.join(' · ');
}

String timelineResolutionLabel(String value) => switch (value) {
  'THEME_TIME_RESOLVED' => 'Tema süreleri doğrulanmış',
  'UNRESOLVED' => 'Zaman bilgisi henüz çözümlenmemiş',
  _ => 'Runtime zaman bilgisi',
};

String blockTimeStatusLabel(String value) => switch (value) {
  'ORDER_ONLY' => 'Yalnız plan sırası doğrulanmış',
  'RESOLVED' => 'Blok süresi doğrulanmış',
  'UNRESOLVED' => 'Ayrı blok süresi doğrulanmamış',
  _ => 'Runtime zaman bilgisi',
};

String? resourcePriorityLabel(String? value) => switch (value) {
  'HIGH' => 'Yüksek öncelik',
  'MEDIUM' => 'Orta öncelik',
  'LOW' => 'Düşük öncelik',
  _ => null,
};
