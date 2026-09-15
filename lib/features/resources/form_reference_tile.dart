import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/models/form_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'form_viewer_page.dart';

/// A form link that keeps local renderability and review state visible.
///
/// The same component is used by the resource library and teacher-guide
/// deep-links so a form never appears actionable merely because it exists in
/// the canonical textbook registry.
class FormReferenceTile extends StatefulWidget {
  const FormReferenceTile({
    super.key,
    required this.formId,
    required this.repository,
    this.form,
    this.compact = false,
  });

  final String formId;
  final CourseKnowledgeRepository repository;
  final model.Form? form;
  final bool compact;

  @override
  State<FormReferenceTile> createState() => _FormReferenceTileState();
}

class _FormReferenceTileState extends State<FormReferenceTile> {
  late Future<_FormReferenceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant FormReferenceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formId != widget.formId ||
        oldWidget.repository != widget.repository ||
        oldWidget.form != widget.form) {
      _future = _load();
    }
  }

  Future<_FormReferenceData> _load() async {
    final form =
        widget.form ??
        await widget.repository.getFormIfAvailable(widget.formId);
    final status = await widget.repository.getFormTemplateStatusIfAvailable(
      widget.formId,
    );
    return _FormReferenceData(form: form, status: status);
  }

  Future<void> _open(BuildContext context, _FormReferenceData reference) async {
    final form = reference.form;
    final status = reference.status;
    if (status != null && !status.isReady) {
      await showFormTemplateStatusDialog(
        context,
        form: form,
        status: status,
        fallbackFormId: widget.formId,
      );
      return;
    }
    if (form == null) return;
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FormViewerPage(form: form, repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_FormReferenceData>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return _FormReferenceShell(
          compact: widget.compact,
          title: widget.form?.title ?? widget.formId,
          subtitle: 'Form durumu denetleniyor…',
          status: null,
          action: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (snapshot.hasError) {
        return _FormReferenceShell(
          compact: widget.compact,
          title: widget.form?.title ?? widget.formId,
          subtitle: 'Form durumu okunamadı.',
          status: null,
          action: IconButton(
            tooltip: 'Yeniden dene',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
          ),
        );
      }
      final reference = snapshot.data!;
      final form = reference.form;
      final status = reference.status;
      final title = form == null || form.title.trim().isEmpty
          ? widget.formId
          : form.title;
      final subtitleParts = <String>[
        if (form != null) formTypeLabel(form),
        if (form?.printedPage != null) 'Ders kitabı s. ${form!.printedPage}',
        if (status == null)
          'Yerel şablon durumu eski paket tarafından bildirilmiyor',
      ];
      final canOpen = form != null && (status == null || status.isReady);
      return _FormReferenceShell(
        compact: widget.compact,
        title: title,
        subtitle: subtitleParts.join(' · '),
        status: status,
        action: OutlinedButton.icon(
          onPressed: canOpen || status != null
              ? () => _open(context, reference)
              : null,
          icon: Icon(
            canOpen ? Icons.open_in_new : Icons.rate_review_outlined,
            size: 18,
          ),
          label: Text(
            canOpen
                ? 'Formu aç'
                : status?.isExternalReference == true
                ? 'Dış kaynak durumu'
                : 'İnceleme durumu',
          ),
        ),
      );
    },
  );
}

class _FormReferenceData {
  const _FormReferenceData({required this.form, required this.status});

  final model.Form? form;
  final FormTemplateStatus? status;
}

class _FormReferenceShell extends StatelessWidget {
  const _FormReferenceShell({
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.action,
  });

  final bool compact;
  final String title;
  final String subtitle;
  final FormTemplateStatus? status;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
    child: Padding(
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.assignment_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                    if (status != null) ...[
                      const SizedBox(height: 6),
                      FormTemplateStatusChip(status: status!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
    ),
  );
}

class FormTemplateStatusChip extends StatelessWidget {
  const FormTemplateStatusChip({super.key, required this.status});

  final FormTemplateStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = status.isReady
        ? scheme.secondaryContainer
        : status.isExternalReference
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = status.isReady
        ? scheme.onSecondaryContainer
        : status.isExternalReference
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Chip(
      avatar: Icon(
        status.isReady
            ? Icons.check_circle_outline
            : status.isExternalReference
            ? Icons.link_off_outlined
            : Icons.rate_review_outlined,
        size: 16,
        color: foreground,
      ),
      label: Text(status.displayLabel),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
      side: BorderSide.none,
    );
  }
}

Future<void> showFormTemplateStatusDialog(
  BuildContext context, {
  required model.Form? form,
  required FormTemplateStatus status,
  required String fallbackFormId,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final urls = status.targetUrlCandidates.isEmpty
          ? [if (status.targetUrl != null) status.targetUrl!]
          : status.targetUrlCandidates;
      return AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              form?.title.trim().isNotEmpty == true
                  ? form!.title
                  : fallbackFormId,
            ),
            const SizedBox(height: 8),
            FormTemplateStatusChip(status: status),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formStatusExplanation(status)),
                if (status.sourcePage case final sourcePage?) ...[
                  const SizedBox(height: 12),
                  Text('Kaynak: TDE_11 ders kitabı · $sourcePage'),
                ],
                if (urls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    urls.length > 1
                        ? 'Resmî hedef URL adayları'
                        : 'Resmî hedef URL',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final url in urls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText(url),
                    ),
                ],
                if (status.isExternalReference) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Bu hedefin rubrik ölçütleri ve puan düzeyleri yerel PDF’de görünmediği için uygulama bunları üretmez.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (urls.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: urls.first));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Hedef URL panoya kopyalandı.')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('URL’yi kopyala'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
        ],
      );
    },
  );
}

String _formStatusExplanation(FormTemplateStatus status) {
  if (status.isExternalReference) {
    return 'Bu kayıt ders kitabındaki resmî QR değerlendirme kaynağına işaret eder. Yerel form şablonu olmadığı için dış kaynak inceleme gerektirir.';
  }
  return switch (status.reviewReason) {
    'missing_source_structure' =>
      'Kaynak formun ayrıntılı alan yapısı yerel runtime’a güvenli biçimde aktarılmadı. Form yayımlanmadan önce kaynak yapı incelenmelidir.',
    'missing_verification_evidence' =>
      'Form için doğrulama kanıtı eksik. Şablon yayımlanmadan önce kaynak sayfa ve yapı doğrulanmalıdır.',
    _ =>
      'Bu formun yerel şablonu öğretmen incelemesi tamamlanana kadar kullanıma açılmadı.',
  };
}

String formTypeLabel(model.Form form) {
  final type = form.assessmentType ?? form.structuralType ?? '';
  return switch (type) {
    'self_assessment_form' => 'Öz değerlendirme',
    'peer_assessment_form' => 'Akran değerlendirmesi',
    'teacher_evaluation_form' => 'Öğretmen değerlendirmesi',
    'checklist' => 'Kontrol listesi',
    'observation_form' => 'Gözlem formu',
    'learning_journal' => 'Öğrenme günlüğü',
    'assessment_criteria_table' => 'Değerlendirme ölçütleri',
    'test_question_set' => 'Ölçme ve değerlendirme',
    'exit_ticket' => 'Çıkış kartı',
    'reflection_prompt' => 'Yansıtma formu',
    'dereceli_puanlama_anahtari_link' => 'Dereceli puanlama anahtarı',
    _ => 'Değerlendirme formu',
  };
}
