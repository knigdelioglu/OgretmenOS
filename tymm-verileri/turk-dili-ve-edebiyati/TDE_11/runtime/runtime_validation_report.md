# Runtime Course Package Validation Report

**Final:** PASS

| Check | Status | Detail |
|---|---|---|
| schema validation | PASS | runtime schema loaded |
| foreign key integrity | PASS | PRAGMA foreign_key_check |
| canonical ID uniqueness: themes | PASS |  |
| canonical ID uniqueness: blocks | PASS |  |
| canonical ID uniqueness: outcomes | PASS |  |
| canonical ID uniqueness: activities | PASS |  |
| canonical ID uniqueness: forms | PASS |  |
| canonical ID uniqueness: assessment_artifacts | PASS |  |
| orphan relations | PASS | 0 |
| source fingerprint status | PASS | RUNTIME_FRESH |
| effective process components projected | PASS | empty=0, verified_none=0 |
| process component origins valid | PASS | invalid=0 |
| process component origin counts | PASS | runtime={'ROOF_INHERITED': 64}, canonical={'total_outcomes': 64, 'outcomes_with_roof_components': 64, 'explicit_component_outcomes': 0, 'inherited_component_outcomes': 64, 'verified_no_component_outcomes': 0, 'unresolved_component_outcomes': 0, 'inheritance_missing_count': 0, 'structural_error_count': 0} |
| timeline projection status | PASS | resolved=16, expected=16 |
| block-hour theme totals | PASS | runtime={'TEMA_01': 43, 'TEMA_02': 43, 'TEMA_03': 43, 'TEMA_04': 43}, expected={'TEMA_01': 43, 'TEMA_02': 43, 'TEMA_03': 43, 'TEMA_04': 43} |
| block-hour projection parity | PASS | runtime=16, expected=16 |
| assessment mapping status | PASS | runtime=0, canonical=0 |
| assessment artifact projection status | PASS | runtime=0, canonical=0 |
| resource decision projection status | PASS |  |
| teacher guide projection status | PASS | optional capability consistent |
| application query A | PASS | rows=1 |
| application query B | PASS | rows=1 |
| application query C | PASS | rows=16 |
| application query D | PASS | rows=1 |
| application query E | PASS | rows=1 |
| copyright payload check | PASS |  |
| user state excluded | PASS |  |
| vector/model dependency excluded | PASS |  |

## Row counts

- `courses`: 1
- `themes`: 4
- `blocks`: 16
- `block_activities`: 84
- `outcomes`: 64
- `block_outcomes`: 64
- `textbook_sections`: 24
- `activities`: 84
- `activity_outcomes`: 336
- `forms`: 43
- `activity_forms`: 209
- `resource_decisions`: 64
- `assessment_artifacts`: 0
- `assessment_gap_mappings`: 0
- `assessment_task_bindings`: 0
- `timeline_themes`: 4
- `timeline_blocks`: 16
- `source_references`: 5
- `entity_source_references`: 4
- `lesson_plan_packages`: 88
- `canonical_entities`: 328
- `teacher_guides`: 4
- `teacher_guide_sections`: 28
- `teacher_guide_units`: 94
- `teacher_guide_items`: 283
- `teacher_guide_item_relations`: 3707
## Form Template Projection

- Schema version: `1.0`
- Ready templates: `0`
- Needs review: `43`
- Foreign key integrity: `PASS`
- JSON parse and element validation: runtime verifier

### Needs-review reasons

- `FORM_T1_P035_OZ_DEGERLENDIRME_01`: `insufficient_canonical_evidence`
- `FORM_T1_P054_KONTROL_LISTESI_03`: `insufficient_canonical_evidence`
- `FORM_T1_P058_OZ_DEGERLENDIRME_05`: `insufficient_canonical_evidence`
- `FORM_T1_P064_GOZLEM_FORMU_07`: `insufficient_canonical_evidence`
- `FORM_T1_P073_CIKIS_KARTI_08`: `insufficient_canonical_evidence`
- `FORM_T1_P078_CIKIS_KARTI_11`: `insufficient_canonical_evidence`
- `FORM_T1_P078_OZ_DEGERLENDIRME_10`: `insufficient_canonical_evidence`
- `FORM_T1_P079_TEMA_TEST_12`: `missing_source_structure`
- `FORM_T2_P097_KONTROL_LISTESI_01`: `insufficient_canonical_evidence`
- `FORM_T2_P112_CIKIS_KARTI_02`: `insufficient_canonical_evidence`
- `FORM_T2_P135_OZ_DEGERLENDIRME_04`: `insufficient_canonical_evidence`
- `FORM_T2_P139_GOZLEM_FORMU_07`: `insufficient_canonical_evidence`
- `FORM_T2_P139_KONTROL_LISTESI_06`: `insufficient_canonical_evidence`
- `FORM_T2_P143_KONTROL_LISTESI_08`: `insufficient_canonical_evidence`
- `FORM_T2_P153_OZ_DEGERLENDIRME_10`: `insufficient_canonical_evidence`
- `FORM_T2_P154_OGRENME_GUNLUGU_12`: `missing_source_structure`
- `FORM_T2_P155_TEMA_TEST_13`: `missing_source_structure`
- `FORM_T3_P193_CIKIS_KARTI_01`: `insufficient_canonical_evidence`
- `FORM_T3_P214_OZ_DEGERLENDIRME_03`: `insufficient_canonical_evidence`
- `FORM_T3_P216_GOZLEM_FORMU_05`: `insufficient_canonical_evidence`
- `FORM_T3_P224_OGRENME_GUNLUGU_06`: `missing_source_structure`
- `FORM_T3_P228_OZ_DEGERLENDIRME_08`: `insufficient_canonical_evidence`
- `FORM_T3_P229_CIKIS_KARTI_10`: `insufficient_canonical_evidence`
- `FORM_T3_P229_OZ_DEGERLENDIRME_09`: `insufficient_canonical_evidence`
- `FORM_T3_P230_TEMA_TEST_11`: `missing_source_structure`
- `FORM_T4_P281_KONTROL_LISTESI_01`: `insufficient_canonical_evidence`
- `FORM_T4_P286_KONTROL_LISTESI_03`: `insufficient_canonical_evidence`
- `FORM_T4_P297_OGRENME_GUNLUGU_04`: `missing_source_structure`
- `FORM_T4_P302_OGRENME_GUNLUGU_06`: `missing_source_structure`
- `FORM_T4_P303_TEMA_TEST_07`: `missing_source_structure`
- `LINK_T1_KONUSMA_DPA`: `unresolved_form_reference`
- `LINK_T1_P035_AKRAN_QR_02`: `unresolved_form_reference`
- `LINK_T1_P058_AKRAN_QR_06`: `unresolved_form_reference`
- `LINK_T1_YAZMA_DPA`: `unresolved_form_reference`
- `LINK_T2_KONUSMA_DPA`: `unresolved_form_reference`
- `LINK_T2_P135_AKRAN_QR_05`: `unresolved_form_reference`
- `LINK_T2_P153_AKRAN_QR_11`: `unresolved_form_reference`
- `LINK_T2_YAZMA_DPA`: `unresolved_form_reference`
- `LINK_T3_KONUSMA_DPA`: `unresolved_form_reference`
- `LINK_T3_P214_AKRAN_QR_04`: `unresolved_form_reference`
- `LINK_T3_YAZMA_DPA`: `unresolved_form_reference`
- `LINK_T4_KONUSMA_DPA`: `unresolved_form_reference`
- `LINK_T4_YAZMA_DPA`: `unresolved_form_reference`
