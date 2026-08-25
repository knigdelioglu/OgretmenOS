from pathlib import Path

OUTCOME = Path('lib/features/outcomes/outcome_detail_page.dart')
WIDGET_TEST = Path('test/widget_test.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


text = OUTCOME.read_text()

text = replace_once(
    text,
    """    VoidCallback? primaryAction;\n    String? primaryActionLabel;\n    IconData? primaryActionIcon;\n    if (_item.presentationStatus == OutcomeTrackingStatus.planned) {\n      primaryAction = () => _setStatus(OutcomeTrackingStatus.inProgress);\n      primaryActionLabel = 'Başla';\n      primaryActionIcon = Icons.play_arrow_rounded;\n    } else if (_item.presentationStatus != OutcomeTrackingStatus.completed) {\n      primaryAction = () => _setStatus(OutcomeTrackingStatus.completed);\n      primaryActionLabel = 'İşlendi';\n      primaryActionIcon = Icons.check_rounded;\n    }\n\n""",
    "",
    'remove foreground tracking CTA setup',
)

text = replace_once(
    text,
    """        subtitle: 'Yalnızca ikincil durumlar ve başka haftaya taşıma',\n""",
    """        subtitle:\n            'İsteğe bağlı · ${outcomeStatusLabel(_item.presentationStatus)}',\n""",
    'make tracking status explicitly optional',
)

text = replace_once(
    text,
    """              trailing: OutcomeStatusChip(status: _item.presentationStatus),\n""",
    "",
    'remove tracking chip from page header',
)

text = replace_once(
    text,
    """              primaryAction: _saving ? null : primaryAction,\n              primaryActionLabel: primaryActionLabel,\n              primaryActionIcon: primaryActionIcon,\n              onCopyDiary: _copyDiaryText,\n""",
    """              teacherNote: _noteController.text,\n              onCopyDiary: _copyDiaryText,\n""",
    'pass teacher note instead of tracking CTA',
)

text = replace_once(
    text,
    """    required this.primaryAction,\n    required this.primaryActionLabel,\n    required this.primaryActionIcon,\n    required this.onCopyDiary,\n""",
    """    required this.teacherNote,\n    required this.onCopyDiary,\n""",
    'lesson card constructor fields',
)

text = replace_once(
    text,
    """  final VoidCallback? primaryAction;\n  final String? primaryActionLabel;\n  final IconData? primaryActionIcon;\n  final VoidCallback onCopyDiary;\n""",
    """  final String teacherNote;\n  final VoidCallback onCopyDiary;\n""",
    'lesson card field declarations',
)

text = replace_once(
    text,
    """    final firstActivity = activities.isEmpty ? null : activities.first;\n    final completed =\n        item.presentationStatus == OutcomeTrackingStatus.completed;\n\n""",
    """    final firstActivity = activities.isEmpty ? null : activities.first;\n    final note = teacherNote.trim();\n\n""",
    'lesson card derived state',
)

text = replace_once(
    text,
    """            const SizedBox(height: AppSpacing.lg),\n            if (completed)\n              Row(\n                children: [\n                  Icon(\n                    Icons.check_circle,\n                    color: Theme.of(context).colorScheme.primary,\n                  ),\n                  const SizedBox(width: AppSpacing.sm),\n                  Expanded(\n                    child: Text(\n                      'Bu kazanım işlendi.',\n                      style: Theme.of(context).textTheme.titleSmall?.copyWith(\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),\n                  ),\n                ],\n              ),\n            if (completed) const SizedBox(height: AppSpacing.md),\n            Wrap(\n              spacing: AppSpacing.sm,\n              runSpacing: AppSpacing.sm,\n              children: [\n                if (primaryActionLabel != null && primaryActionIcon != null)\n                  FilledButton.icon(\n                    onPressed: primaryAction,\n                    icon: Icon(primaryActionIcon),\n                    label: Text(primaryActionLabel!),\n                  ),\n                OutlinedButton.icon(\n                  onPressed: onCopyDiary,\n                  icon: const Icon(Icons.copy_outlined),\n                  label: const Text('Deftere kopyala'),\n                ),\n              ],\n            ),\n""",
    """            if (note.isNotEmpty) ...[\n              const SizedBox(height: AppSpacing.md),\n              _LessonCue(\n                icon: Icons.sticky_note_2_outlined,\n                label: 'Öğretmen notu',\n                value: note,\n              ),\n            ],\n            const SizedBox(height: AppSpacing.lg),\n            Wrap(\n              spacing: AppSpacing.sm,\n              runSpacing: AppSpacing.sm,\n              children: [\n                OutlinedButton.icon(\n                  onPressed: onCopyDiary,\n                  icon: const Icon(Icons.copy_outlined),\n                  label: const Text('Deftere kopyala'),\n                ),\n              ],\n            ),\n""",
    'remove tracking state from lesson-ready card and surface note',
)

text = replace_once(
    text,
    """        'Takip, notlar, plan bağlamı, değerlendirme ve kaynaklar',\n""",
    """        'Notlar, plan bağlamı, değerlendirme, kaynaklar ve isteğe bağlı takip',\n""",
    'more information subtitle hierarchy',
)

OUTCOME.write_text(text)

text = WIDGET_TEST.read_text()
text = replace_once(
    text,
    """    expect(find.widgetWithText(FilledButton, 'Başla'), findsOneWidget);\n    expect(find.text('Deftere kopyala'), findsOneWidget);\n""",
    """    expect(find.widgetWithText(FilledButton, 'Başla'), findsNothing);\n    expect(find.widgetWithText(FilledButton, 'İşlendi'), findsNothing);\n    expect(find.text('Planlı'), findsNothing);\n    expect(find.text('Deftere kopyala'), findsOneWidget);\n""",
    'detail foreground expectations',
)
text = replace_once(
    text,
    """    expect(find.text('Öğretmen notu'), findsOneWidget);\n    expect(find.text('Süreç bileşenleri'), findsOneWidget);\n""",
    """    expect(find.text('Öğretmen notu'), findsOneWidget);\n    expect(find.text('Takip seçenekleri'), findsOneWidget);\n    expect(find.text('İsteğe bağlı · Planlı'), findsOneWidget);\n    expect(find.text('Süreç bileşenleri'), findsOneWidget);\n""",
    'detail optional tracking expectations',
)
WIDGET_TEST.write_text(text)
