import '../models/form_models.dart';

/// Shared runtime interpretation of the canonical form-template evidence
/// contract. The checked-in JSON policy is consumed by the build projector
/// and runtime verifier; these constants keep the app fail-closed at read time.
class FormTemplatePolicy {
  const FormTemplatePolicy._();

  static const readyContentBases = <String>{
    'verified_printed_form_transcription',
    'verified_structural_index',
  };

  static const verifiedStatuses = <String>{
    'VERIFIED',
    'LOCAL_PDF_PAGE_STRUCTURE_VERIFIED',
    'LOCAL_OFFICIAL_PDF_PAGE_STRUCTURE_VERIFIED',
  };

  static const reviewReasons = <String>{
    'missing_source_structure',
    'ambiguous_columns',
    'ambiguous_scale',
    'missing_rubric_levels',
    'missing_rubric_descriptors',
    'unresolved_form_reference',
    'unsupported_layout',
    'insufficient_canonical_evidence',
    'missing_verification_evidence',
    'invalid_source_provenance',
  };

  static void validateReadyProvenance(Map<String, dynamic> provenance) {
    final contentBasis = provenance['content_basis']?.toString().trim() ?? '';
    if (!readyContentBases.contains(contentBasis)) {
      throw FormDefinitionException(
        'Ready form content_basis canonical evidence sözleşmesini karşılamıyor.',
      );
    }
    final sourceId = provenance['source_id']?.toString().trim() ?? '';
    if (sourceId.isEmpty) {
      throw const FormDefinitionException('Ready form source_id eksik.');
    }
    final hasLocator = [
      provenance['source_locator'],
      provenance['source_page'],
      provenance['printed_page'],
      provenance['pdf_page'],
    ].any((value) => value?.toString().trim().isNotEmpty ?? false);
    if (!hasLocator) {
      throw const FormDefinitionException(
        'Ready form source locator/page eksik.',
      );
    }
    final verificationStatus =
        provenance['verification_status']?.toString().trim() ?? '';
    if (!verifiedStatuses.contains(verificationStatus)) {
      throw const FormDefinitionException(
        'Ready form verification_status geçersiz.',
      );
    }
  }
}
