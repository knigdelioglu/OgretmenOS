import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/models/form_models.dart';
import '../../domain/repositories/course_knowledge_repository.dart';
import 'forms/form_document_view.dart';
import 'forms/form_export_service.dart';

class FormViewerPage extends StatefulWidget {
  const FormViewerPage({
    super.key,
    required this.form,
    required this.repository,
    this.exportService,
  });

  final model.Form form;
  final CourseKnowledgeRepository repository;
  final FormExportService? exportService;

  @override
  State<FormViewerPage> createState() => _FormViewerPageState();
}

class _FormViewerPageState extends State<FormViewerPage> {
  late Future<FormDefinition?> _future;
  late final FormExportService _exportService;
  FormDefinition? _definition;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _exportService = widget.exportService ?? DefaultFormExportService();
    _future = _load();
  }

  Future<FormDefinition?> _load() async {
    final definition = await widget.repository.getFormDefinition(
      widget.form.id,
    );
    _definition = definition;
    return definition;
  }

  void _retry() {
    setState(() {
      _definition = null;
      _future = _load();
    });
  }

  Future<Uint8List> _generate() async {
    final definition = _definition;
    if (definition == null) throw StateError('Form tanımı hazır değil.');
    return _exportService.generate(definition);
  }

  Future<void> _previewPdf() async {
    final definition = _definition;
    if (definition == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _FormPdfPreviewPage(title: definition.title, buildPdf: _generate),
      ),
    );
  }

  Future<void> _runExport(
    Future<FormExportOutcome> Function(Uint8List bytes, String filename) action,
    String successMessage,
  ) async {
    if (_exporting || _definition == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _generate();
      final filename = sanitizeFormPdfFilename(_definition!.title);
      final outcome = await action(bytes, filename);
      if (!mounted || outcome == FormExportOutcome.cancelled) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF işlemi tamamlanamadı. Lütfen yeniden deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveOrShare() => _runExport(
    (bytes, filename) => _exportService.saveOrShare(bytes, filename: filename),
    'PDF hazırlandı.',
  );

  Future<void> _print() => _runExport(
    (bytes, filename) => _exportService.printPdf(bytes, filename: filename),
    'Yazdırma işlemi gönderildi.',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_metadataTitle(widget.form))),
    body: FutureBuilder<FormDefinition?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Form hazırlanıyor…'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _FormLoadMessage(
            icon: Icons.error_outline,
            title: 'Form içeriği açılamadı',
            message:
                'Bu formun içeriği okunamadı. Veri paketini doğrulayıp yeniden deneyin.',
            actionLabel: 'Yeniden dene',
            onAction: _retry,
          );
        }
        final definition = snapshot.data;
        if (definition == null) {
          return const _FormLoadMessage(
            icon: Icons.description_outlined,
            title: 'Form içeriği mevcut değil',
            message:
                'Bu formun görüntülenebilir içeriği mevcut veri paketinde bulunmuyor.',
          );
        }
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _exporting ? null : _previewPdf,
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('PDF Önizle'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _exporting ? null : _saveOrShare,
                            icon: const Icon(Icons.ios_share_outlined),
                            label: const Text('PDF Kaydet / Paylaş'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _exporting ? null : _print,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text('Yazdır'),
                          ),
                        ],
                      ),
                    ),
                    if (_exporting) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: FormDocumentView(definition: definition),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _metadataTitle(model.Form form) {
  final title = form.title.trim();
  if (title.isEmpty || title == form.id.trim()) return 'Değerlendirme formu';
  return title;
}

class _FormPdfPreviewPage extends StatelessWidget {
  const _FormPdfPreviewPage({required this.title, required this.buildPdf});

  final String title;
  final Future<Uint8List> Function() buildPdf;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('PDF Önizleme · $title')),
    body: PdfPreview(
      build: (_) => buildPdf(),
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: false,
      allowSharing: false,
      pdfFileName: sanitizeFormPdfFilename(title),
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'PDF önizlemesi oluşturulamadı. Lütfen geri dönüp yeniden deneyin.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class _FormLoadMessage extends StatelessWidget {
  const _FormLoadMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}
