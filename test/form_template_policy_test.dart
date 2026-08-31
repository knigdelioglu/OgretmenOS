import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/runtime/form_template_policy.dart';

void main() {
  test('Dart runtime policy checked-in canonical JSON ile drift etmez', () {
    final json =
        jsonDecode(
              File(
                'tool/form_templates/form_template_policy.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      FormTemplatePolicy.readyContentBases,
      (json['ready_content_bases'] as List).cast<String>().toSet(),
    );
    expect(
      FormTemplatePolicy.verifiedStatuses,
      (json['verified_statuses'] as List).cast<String>().toSet(),
    );
    expect(
      FormTemplatePolicy.reviewReasons,
      (json['review_reasons'] as List).cast<String>().toSet(),
    );
  });
}
