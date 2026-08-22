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
| timeline projection status | PASS | block hours remain ORDER_ONLY |
| assessment mapping status | PASS |  |
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
- `block_activities`: 61
- `outcomes`: 54
- `block_outcomes`: 54
- `textbook_sections`: 24
- `activities`: 61
- `activity_outcomes`: 197
- `forms`: 28
- `activity_forms`: 138
- `resource_decisions`: 50
- `assessment_artifacts`: 3
- `assessment_gap_mappings`: 7
- `assessment_task_bindings`: 7
- `timeline_themes`: 4
- `timeline_blocks`: 16
- `source_references`: 2
- `entity_source_references`: 4
