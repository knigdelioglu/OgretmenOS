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
    def _build(self, provenance=None):
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
                ("F1", "Canonical form", "source-1", "12", "13", "VERIFIED"),
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
                        "source_id": "source-1",
                        "forms": [{"form_id": "F1", "structural_type": "custom"}],
                    }
                ),
                encoding="utf-8",
            )
            catalog = {"course_id": "TDE_TEST", "templates": {"F1": {"kind": "rating", "options": ["Evet"], "items": ["Ölçüt"]}}}
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
            row = sqlite3.connect(database_path).execute(
                "SELECT render_status, review_reason FROM form_templates WHERE form_id = 'F1'"
            ).fetchone()
            return result, row

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
        self.assertEqual(row, ("ready", None))

    def test_missing_evidence_cannot_be_ready(self):
        result, row = self._build()
        self.assertEqual(result, {"ready": 0, "needs_review": 1})
        self.assertEqual(row, ("needs_review", "missing_verification_evidence"))

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
            self.assertEqual(row, ("needs_review", "invalid_source_provenance"))


if __name__ == "__main__":
    unittest.main()
