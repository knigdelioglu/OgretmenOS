import importlib.util
import json
import sqlite3
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path


SCRIPT = Path(__file__).with_name("build_form_templates.py")
SPEC = importlib.util.spec_from_file_location("build_form_templates", SCRIPT)
assert SPEC and SPEC.loader
PROJECTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROJECTOR)


class FormTemplateEvidenceTest(unittest.TestCase):
    def _build(
        self,
        provenance=None,
        *,
        canonical_source_id="source-1",
        printed_page="12",
        pdf_page="13",
        verification_status="VERIFIED",
        source_locator=None,
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            database_path = root / "course_runtime.sqlite"
            connection = sqlite3.connect(database_path)
            connection.execute(
                "CREATE TABLE forms (form_id TEXT PRIMARY KEY, title TEXT NOT NULL, "
                "source_id TEXT, printed_page TEXT, pdf_page TEXT, "
                "verification_status TEXT)"
            )
            connection.execute(
                "INSERT INTO forms VALUES (?, ?, ?, ?, ?, ?)",
                (
                    "F1",
                    "Canonical form",
                    canonical_source_id,
                    printed_page,
                    pdf_page,
                    verification_status,
                ),
            )
            connection.commit()
            connection.close()
            (root / "runtime_manifest.json").write_text(
                json.dumps({"course_id": "TDE_TEST", "capabilities": {}}),
                encoding="utf-8",
            )
            (root / "textbook_forms_index.json").write_text(
                json.dumps(
                    {
                        "course_id": "TDE_TEST",
                        "source_id": canonical_source_id,
                        "forms": [
                            {
                                "form_id": "F1",
                                "structural_type": "custom",
                                **(
                                    {"source_locator": source_locator}
                                    if source_locator is not None
                                    else {}
                                ),
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            catalog = {
                "course_id": "TDE_TEST",
                "templates": {
                    "F1": {
                        "kind": "rating",
                        "options": ["Evet"],
                        "items": ["Ölçüt"],
                    }
                },
            }
            if provenance is not None:
                catalog["templates"]["F1"]["provenance"] = provenance
            catalog_path = root / "catalog.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")

            result = PROJECTOR.build(
                Namespace(
                    course_id="TDE_TEST",
                    runtime_dir=str(root),
                    forms_index=str(root / "textbook_forms_index.json"),
                    catalog=str(catalog_path),
                )
            )
            connection = sqlite3.connect(database_path)
            row = connection.execute(
                "SELECT render_status, review_reason, provenance_json "
                "FROM form_templates WHERE form_id = 'F1'"
            ).fetchone()
            connection.close()
            return result, (row[0], row[1], json.loads(row[2]))

    def test_valid_evidence_is_ready(self):
        result, row = self._build(
            {
                "content_basis": "verified_printed_form_transcription",
                "source_id": "source-1",
                "source_page": "s.12",
                "verification_status": "VERIFIED",
            }
        )
        self.assertEqual(result, {"ready": 1, "needs_review": 0})
        self.assertEqual(row[:2], ("ready", None))
        self.assertEqual(row[2]["source_id"], "source-1")
        self.assertEqual(row[2]["verification_status"], "VERIFIED")

    def test_missing_evidence_cannot_be_ready(self):
        result, row = self._build()
        self.assertEqual(result, {"ready": 0, "needs_review": 1})
        self.assertEqual(row[:2], ("needs_review", "missing_verification_evidence"))

    def test_invalid_status_and_guessed_basis_are_not_ready(self):
        for provenance in [
            {
                "content_basis": "verified_printed_form_transcription",
                "source_id": "source-1",
                "source_page": "s.12",
                "verification_status": "GENERATED",
            },
            {
                "content_basis": "inferred_from_similar_form",
                "source_id": "source-1",
                "source_page": "s.12",
                "verification_status": "VERIFIED",
            },
        ]:
            result, row = self._build(provenance)
            self.assertEqual(result, {"ready": 0, "needs_review": 1})
            self.assertEqual(row[:2], ("needs_review", "invalid_source_provenance"))

    def test_catalog_cannot_upgrade_canonical_verification_status(self):
        result, row = self._build(
            {
                "content_basis": "verified_printed_form_transcription",
                "source_page": "s.12",
                "verification_status": "VERIFIED",
            },
            verification_status="UNVERIFIED",
        )
        self.assertEqual(result, {"ready": 0, "needs_review": 1})
        self.assertEqual(row[:2], ("needs_review", "invalid_source_provenance"))
        self.assertEqual(row[2]["verification_status"], "UNVERIFIED")

    def test_catalog_cannot_replace_canonical_source_identity(self):
        result, row = self._build(
            {
                "content_basis": "verified_printed_form_transcription",
                "source_id": "other-source",
                "source_page": "s.12",
            }
        )
        self.assertEqual(result, {"ready": 0, "needs_review": 1})
        self.assertEqual(row[:2], ("needs_review", "invalid_source_provenance"))
        self.assertEqual(row[2]["source_id"], "source-1")

    def test_catalog_source_page_may_describe_verified_canonical_source(self):
        result, row = self._build(
            {
                "content_basis": "verified_printed_form_transcription",
                "source_page": "catalog transcription s.12",
            },
            printed_page=None,
            pdf_page=None,
            source_locator=None,
        )
        self.assertEqual(result, {"ready": 1, "needs_review": 0})
        self.assertEqual(row[:2], ("ready", None))
        self.assertEqual(row[2]["source_id"], "source-1")
        self.assertEqual(row[2]["verification_status"], "VERIFIED")
        self.assertEqual(row[2]["source_page"], "catalog transcription s.12")


if __name__ == "__main__":
    unittest.main()
