#!/usr/bin/env python3
"""Project semantic form templates into a copied FULL_RUNTIME package.

The source runtime remains immutable. This projector is the canonical
post-sync build step owned by the app repository.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "1.0"
READY = "ready"
NEEDS_REVIEW = "needs_review"


def _identity(labels: list[str]) -> dict[str, Any]:
    return {
        "type": "identityFields",
        "fields": [{"label": label, "flex": 1} for label in labels],
    }


def _definition(
    title: str,
    elements: list[dict[str, Any]],
    *,
    description: str | None,
    instructions: str | None,
    provenance: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "title": title,
        **({"description": description} if description else {}),
        **({"instructions": instructions} if instructions else {}),
        "sections": [{"elements": elements}],
        "provenance": provenance,
    }


def _override_elements(spec: dict[str, Any]) -> list[dict[str, Any]]:
    elements: list[dict[str, Any]] = []
    identity_fields = [str(item) for item in spec.get("identity_fields", [])]
    if identity_fields:
        elements.append(_identity(identity_fields))
    kind = spec.get("kind")
    if kind == "rating":
        elements.append(
            {
                "type": "ratingScale",
                "label": "Değerlendirme ölçütleri",
                "min": 1,
                "max": len(spec["options"]),
                "options": spec["options"],
                "items": spec["items"],
            }
        )
    elif kind == "prompts":
        lines = spec.get("lines", [])
        for index, prompt in enumerate(spec["prompts"]):
            elements.append(
                {
                    "type": "freeText",
                    "label": prompt,
                    "lines": lines[index] if index < len(lines) else 4,
                }
            )
    else:
        raise ValueError(f"Bilinmeyen catalog kind: {kind}")
    return elements


def _index_elements(form: dict[str, Any]) -> list[dict[str, Any]] | None:
    details = form.get("structure_details") or {}
    options = [str(item) for item in form.get("response_options", [])]
    categories = [str(item) for item in details.get("criteria_categories", [])]
    if categories and options:
        elements: list[dict[str, Any]] = [
            _identity(["Adı Soyadı", "Sınıfı", "Numarası", "Tarih"]),
            {
                "type": "ratingScale",
                "label": "Değerlendirme ölçütleri",
                "min": 1,
                "max": len(options),
                "options": options,
                "items": categories,
            },
        ]
        for question in details.get("reflection_questions", []):
            elements.append({"type": "freeText", "label": question, "lines": 3})
        return elements

    prompts = [str(item) for item in details.get("prompts", [])]
    if prompts:
        elements = [_identity(["Değerlendirilen öğrenci", "Tarih", "Çalışmanın adı"])]
        elements.extend(
            {"type": "freeText", "label": prompt, "lines": 4}
            for prompt in prompts
        )
        return elements

    criteria = [str(item) for item in details.get("criteria_list", [])]
    if criteria:
        return [
            _identity(["Adı Soyadı", "Sınıfı", "Numarası", "Tarih"]),
            {
                "type": "table",
                "label": "Gözlem ve değerlendirme",
                "header": True,
                "columns": [
                    {"label": "Gözlem ölçütü", "flex": 4},
                    {"label": "Gözlem sonucu", "flex": 2},
                    {"label": "Yorumlar", "flex": 3},
                ],
                "rows": [[criterion, "", ""] for criterion in criteria],
            },
        ]

    reflection_prompt = details.get("reflection_prompt")
    if reflection_prompt:
        return [
            _identity(["Adı Soyadı", "Sınıfı", "Numarası", "Tarih"]),
            {"type": "freeText", "label": str(reflection_prompt), "lines": 12},
        ]
    return None


def _load_json(path: Path) -> dict[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise ValueError(f"JSON nesnesi bekleniyordu: {path}")
    return decoded


def _provenance(row: sqlite3.Row, index_form: dict[str, Any]) -> dict[str, Any]:
    return {
        "source_id": row["source_id"],
        "printed_page": row["printed_page"],
        "pdf_page": row["pdf_page"],
        "verification_status": row["verification_status"],
        "source_locator": index_form.get("source_locator"),
    }


def build(args: argparse.Namespace) -> dict[str, int]:
    runtime_dir = Path(args.runtime_dir).resolve()
    database_path = runtime_dir / "course_runtime.sqlite"
    manifest_path = runtime_dir / "runtime_manifest.json"
    report_path = runtime_dir / "runtime_validation_report.md"
    if not database_path.exists() or not manifest_path.exists():
        raise FileNotFoundError(f"Runtime paketi eksik: {runtime_dir}")

    forms_index = _load_json(Path(args.forms_index))
    if forms_index.get("course_id") != args.course_id:
        raise ValueError("forms index course_id uyuşmuyor")
    index_by_id = {
        str(item["form_id"]): item for item in forms_index.get("forms", [])
    }

    catalog_templates: dict[str, Any] = {}
    if args.catalog:
        catalog = _load_json(Path(args.catalog))
        if catalog.get("course_id") != args.course_id:
            raise ValueError("template catalog course_id uyuşmuyor")
        catalog_templates = catalog.get("templates", {})

    connection = sqlite3.connect(database_path)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        form_rows = connection.execute(
            "SELECT form_id, title, source_id, printed_page, pdf_page, "
            "verification_status FROM forms ORDER BY form_id"
        ).fetchall()
        form_ids = {str(row["form_id"]) for row in form_rows}
        unknown_catalog_ids = set(catalog_templates) - form_ids
        if unknown_catalog_ids:
            raise ValueError(
                "Catalog runtime'da olmayan form içeriyor: "
                + ", ".join(sorted(unknown_catalog_ids))
            )

        connection.executescript(
            """
            DROP TABLE IF EXISTS form_templates;
            CREATE TABLE form_templates (
              form_id TEXT PRIMARY KEY REFERENCES forms(form_id),
              schema_version TEXT NOT NULL,
              template_json TEXT NOT NULL,
              instructions TEXT,
              render_status TEXT NOT NULL
                CHECK (render_status IN ('ready', 'needs_review')),
              provenance_json TEXT NOT NULL DEFAULT '{}'
            );
            """
        )
        counts = {READY: 0, NEEDS_REVIEW: 0}
        for row in form_rows:
            form_id = str(row["form_id"])
            index_form = index_by_id.get(form_id, {})
            provenance = _provenance(row, index_form)
            spec = catalog_templates.get(form_id)
            if spec is not None:
                elements = _override_elements(spec)
                instructions = spec.get("instructions")
                status = READY
                provenance["content_basis"] = "verified_printed_form_transcription"
            else:
                elements = _index_elements(index_form)
                instructions = None
                status = READY if elements else NEEDS_REVIEW
                provenance["content_basis"] = (
                    "verified_structural_index"
                    if elements
                    else "metadata_only_structure_unresolved"
                )
            if not elements:
                elements = [
                    {
                        "type": "note",
                        "text": (
                            "Bu kaydın ayrıntılı alan yapısı resmî kaynaktan "
                            "kesin olarak üretilemedi; yayımlanmadan önce inceleme gerekir."
                        ),
                    }
                ]
            description = index_form.get("subtitle")
            definition = _definition(
                str(row["title"]),
                elements,
                description=description,
                instructions=instructions,
                provenance=provenance,
            )
            connection.execute(
                "INSERT INTO form_templates "
                "(form_id, schema_version, template_json, instructions, "
                "render_status, provenance_json) VALUES (?, ?, ?, ?, ?, ?)",
                (
                    form_id,
                    SCHEMA_VERSION,
                    json.dumps(definition, ensure_ascii=False, separators=(",", ":")),
                    instructions,
                    status,
                    json.dumps(provenance, ensure_ascii=False, separators=(",", ":")),
                ),
            )
            counts[status] += 1
        connection.commit()
        fk_errors = connection.execute("PRAGMA foreign_key_check").fetchall()
        if fk_errors:
            raise ValueError(f"form_templates foreign key hatası: {fk_errors}")
    finally:
        connection.close()

    manifest = _load_json(manifest_path)
    capabilities = manifest.setdefault("capabilities", {})
    capabilities["form_templates"] = True
    manifest.setdefault("row_counts", {})["form_templates"] = sum(counts.values())
    manifest["form_template_schema_versions"] = [SCHEMA_VERSION]
    manifest["form_template_status_counts"] = counts
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    marker = "## Form Template Projection"
    existing = report_path.read_text(encoding="utf-8") if report_path.exists() else ""
    if marker in existing:
        existing = existing.split(marker, 1)[0].rstrip() + "\n\n"
    existing += (
        f"{marker}\n\n"
        f"- Schema version: `{SCHEMA_VERSION}`\n"
        f"- Ready templates: `{counts[READY]}`\n"
        f"- Needs review: `{counts[NEEDS_REVIEW]}`\n"
        "- Foreign key integrity: `PASS`\n"
        "- JSON parse and element validation: runtime verifier\n"
    )
    report_path.write_text(existing, encoding="utf-8")
    return counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--course-id", required=True)
    parser.add_argument("--runtime-dir", required=True)
    parser.add_argument("--forms-index", required=True)
    parser.add_argument("--catalog")
    args = parser.parse_args()
    counts = build(args)
    print(
        "FORM_TEMPLATES: PASS "
        f"ready={counts[READY]} needs_review={counts[NEEDS_REVIEW]}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
