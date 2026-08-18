import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/models/course_models.dart' as model;

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 32;
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.onRefresh,
    this.controller,
    this.maxWidth = AppLayoutTokens.contentMaxWidth,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding =
          constraints.maxWidth >= AppLayoutTokens.wideContentBreakpoint
              ? AppLayoutTokens.wideHorizontalPadding
              : AppLayoutTokens.phoneHorizontalPadding;
      final content = ListView(
        controller: controller,
        physics: onRefresh == null
            ? const ClampingScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.lg,
          horizontalPadding,
          AppLayoutTokens.pageBottomComfort,
        ),
        children: children,
      );
      final scrollable = onRefresh == null
          ? content
          : RefreshIndicator(onRefresh: onRefresh!, child: content);
      final width = constraints.maxWidth < maxWidth ? constraints.maxWidth : maxWidth;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          height: constraints.maxHeight,
          child: scrollable,
        ),
      );
    },
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailing = trailing != null &&
            (constraints.maxWidth < 560 || textScale >= 1.5);
        final text = _HeaderText(
          title: title,
          eyebrow: eyebrow,
          description: description,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: stackTrailing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    const SizedBox(height: AppSpacing.md),
                    trailing!,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: text),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      trailing!,
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText({required this.title, this.eyebrow, this.description});

  final String title;
  final String? eyebrow;
  final String? description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(
          eyebrow!.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (description != null) ...[
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutTokens.textMeasureMaxWidth,
          ),
          child: Text(
            description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ],
  );
}

class FeatureErrorView extends StatelessWidget {
  const FeatureErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayoutTokens.stateMaxWidth),
        child: StatusPanel(
          icon: Icons.error_outline,
          title: 'Bir şeyler ters gitti',
          message: message,
          tone: StatusTone.error,
          action: onRetry == null
              ? null
              : FilledButton.tonal(
                  onPressed: onRetry,
                  child: const Text('Tekrar dene'),
                ),
        ),
      ),
    ),
  );
}

class UnresolvedText extends StatelessWidget {
  const UnresolvedText({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'İçerik hazırlanıyor…'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayoutTokens.stateMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.icon,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.section, bottom: AppSpacing.md),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

        if (action == null) return heading;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        );
      },
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    ),
  );
}

enum StatusTone { neutral, positive, attention, error }

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = StatusTone.neutral,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final StatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      StatusTone.positive => (scheme.primaryContainer, scheme.onPrimaryContainer),
      StatusTone.attention => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      StatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      StatusTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadiusTokens.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text('$value $label', style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    ),
  );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stack = constraints.maxWidth < 440 ||
          MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      final labelWidget = Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
      final valueWidget = Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );

      if (stack) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelWidget,
                  const SizedBox(height: AppSpacing.xs),
                  valueWidget,
                ],
              ),
            ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          SizedBox(width: 118, child: labelWidget),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: valueWidget),
        ],
      );
    },
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadiusTokens.compact),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (priority != null) Chip(label: Text(priority)),
              ],
            ),
            if (decision.purpose != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(decision.purpose!, style: const TextStyle(height: 1.4)),
            ],
            if (decision.textbookCoverage != null || decision.locator != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  if (decision.textbookCoverage != null)
                    Text('Kitap kapsamı: ${decision.textbookCoverage}'),
                  if (decision.locator != null) Text('Kaynak: ${decision.locator}'),
                ],
              ),
            ],
            if (decision.teacherReviewRequired) ...[
              const SizedBox(height: AppSpacing.md),
              const StatusPanel(
                icon: Icons.visibility_outlined,
                title: 'Öğretmen incelemesi',
                message: 'Bu karar kullanımdan önce öğretmen kontrolü gerektiriyor.',
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
  _ => 'Zaman bilgisi',
};

String blockTimeStatusLabel(String value) => switch (value) {
  'ORDER_ONLY' => 'Yalnız plan sırası doğrulanmış',
  'RESOLVED' => 'Blok süresi doğrulanmış',
  'UNRESOLVED' => 'Ayrı blok süresi doğrulanmamış',
  _ => 'Zaman bilgisi',
};

String? resourcePriorityLabel(String? value) => switch (value) {
  'HIGH' => 'Yüksek öncelik',
  'MEDIUM' => 'Orta öncelik',
  'LOW' => 'Düşük öncelik',
  _ => null,
};
