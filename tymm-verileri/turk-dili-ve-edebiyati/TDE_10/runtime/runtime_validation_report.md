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
| assessment artifact projection status | PASS | runtime=2, canonical=2 |
| resource decision projection status | PASS |  |
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
- `block_activities`: 75
- `outcomes`: 64
- `block_outcomes`: 64
- `textbook_sections`: 24
- `activities`: 75
- `activity_outcomes`: 300
- `forms`: 35
- `activity_forms`: 126
- `resource_decisions`: 64
- `assessment_artifacts`: 2
- `assessment_gap_mappings`: 0
- `assessment_task_bindings`: 8
- `timeline_themes`: 4
- `timeline_blocks`: 16
- `source_references`: 4
- `entity_source_references`: 0

## Assessment rubric payload projection

| Check | Status | Detail |
|---|---|---|
| theme source provenance projection | PASS | runtime=4, expected_at_least=4 |
| artifact identity projection | PASS | runtime=2, canonical=2 |
| rubric criteria payload | PASS | runtime=2, canonical=2 |
| rubric level model payload | PASS | runtime=2, canonical=2 |
| task binding count | PASS | runtime=8, canonical=8 |
| task-specific criteria payload | PASS | runtime=8, canonical=8 |
| payload JSON validity | PASS | all projected JSON columns parse |

## Lesson plan payload projection

| Check | Status | Detail |
|---|---|---|
| lesson plan validation seal | PASS | verified=sha256:9744bfbf54a57b7b7731176d5c6cd93bb8ca2e0f67a6a97d1ee29bf5e04dd223 |
| lesson plan package count | PASS | runtime=88, expected=88 |
| lesson plan instruction hours | PASS | runtime=172, expected=172 |
| lesson plan block topology | PASS | all blocks match package count and planned hours |
| lesson plan payload JSON validity | PASS | all payload_json rows parse |
| lesson plan source payload parity | PASS | all SQLite payloads match source JSON and SHA256 |
| lesson plan foreign key integrity | PASS | PRAGMA foreign_key_check |
