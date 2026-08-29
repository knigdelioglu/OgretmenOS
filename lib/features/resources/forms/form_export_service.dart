import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';

import '../../../domain/models/form_models.dart';
import 'form_pdf_renderer.dart';

enum FormExportOutcome { completed, cancelled }

abstract interface class FormExportService {
  Future<Uint8List> generate(FormDefinition definition);

  Future<FormExportOutcome> saveOrShare(
    Uint8List bytes, {
    required String filename,
  });

  Future<FormExportOutcome> printPdf(
    Uint8List bytes, {
    required String filename,
  });
}

class DefaultFormExportService implements FormExportService {
  DefaultFormExportService({FormPdfRenderer? renderer})
    : _renderer = renderer ?? const FormPdfRenderer();

  final FormPdfRenderer _renderer;

  @override
  Future<Uint8List> generate(FormDefinition definition) =>
      _renderer.generate(definition);

  @override
  Future<FormExportOutcome> saveOrShare(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (Platform.isMacOS) {
      const typeGroup = XTypeGroup(label: 'PDF', extensions: ['pdf']);
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: const [typeGroup],
      );
      if (location == null) return FormExportOutcome.cancelled;
      await XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: filename,
      ).saveTo(location.path);
      return FormExportOutcome.completed;
    }
    final shared = await Printing.sharePdf(bytes: bytes, filename: filename);
    return shared ? FormExportOutcome.completed : FormExportOutcome.cancelled;
  }

  @override
  Future<FormExportOutcome> printPdf(
    Uint8List bytes, {
    required String filename,
  }) async {
    final printed = await Printing.layoutPdf(
      name: filename,
      onLayout: (_) async => bytes,
    );
    return printed ? FormExportOutcome.completed : FormExportOutcome.cancelled;
  }
}

String sanitizeFormPdfFilename(String title) {
  const replacements = {
    'ç': 'c',
    'Ç': 'C',
    'ğ': 'g',
    'Ğ': 'G',
    'ı': 'i',
    'İ': 'I',
    'ö': 'o',
    'Ö': 'O',
    'ş': 's',
    'Ş': 'S',
    'ü': 'u',
    'Ü': 'U',
  };
  final transliterated = title.split('').map((character) {
    return replacements[character] ?? character;
  }).join();
  final normalized = transliterated
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return '${normalized.isEmpty ? 'Form' : normalized}.pdf';
}
