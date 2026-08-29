import 'package:flutter/material.dart';

import '../../../domain/models/form_models.dart';
import 'form_document_layout.dart';
import 'form_element_renderer.dart';

class FormDocumentView extends StatelessWidget {
  const FormDocumentView({super.key, required this.definition});

  final FormDefinition definition;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final padding = compact
          ? FormDocumentLayout.compactPreviewPadding
          : FormDocumentLayout.previewPadding;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: FormDocumentLayout.maxPreviewWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      definition.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (definition.description case final description?) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (definition.instructions case final instructions?) ...[
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(instructions),
                      ),
                    ),
                  ],
                  for (final section in definition.sections) ...[
                    const SizedBox(height: 24),
                    if (section.title case final title?)
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    if (section.title != null) const SizedBox(height: 12),
                    for (
                      var index = 0;
                      index < section.elements.length;
                      index++
                    ) ...[
                      FormElementRenderer(
                        element: section.elements[index],
                        compact: compact,
                      ),
                      if (index != section.elements.length - 1)
                        const SizedBox(
                          height: FormDocumentLayout.elementSpacing,
                        ),
                    ],
                  ],
                  if (definition.sections.isEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Bu formda gösterilecek bölüm bulunmuyor.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
