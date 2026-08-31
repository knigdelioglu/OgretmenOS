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
POLICY_PATH = Path(__file__).with_name("form_templates") / "form_template_policy.json"
AUTHORITATIVE_PROVENANCE_FIELDS = {
    "source_id",
    "printed_page",
    "pdf_page",
    "verification_status",
    "source_locator",
}


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
        options = [str(item).strip() for item in spec.get("options", [])]
        items = [str(item).strip() for item in spec.get("items", [])]
        if not options:
            raise ValueError("Rating catalog en az bir seçenek içermeli")
        if not items:
            raise ValueError("Rating catalog en az bir ölçüt içermeli")
        elements.append(
            {
                "type": "ratingScale",
                "label": "Değerlendirme ölçütleri",
                "min": 1,
                "max": len(options),
                "options": options,
                "items": items,
            }
        )
    elif kind == "prompts":
        lines = spec.get("lines", [])
        for index, prompt in enumerate(spec["prompts"]):
            if not str(prompt).strip():
                raise ValueError("Prompt catalog boş soru içeremez")
            elements.append(
                {
                    "type": "freeText",
                    "label": prompt,
                    "lines": lines[index] if index < len(lines) else 4,
                }
            )
    elif kind == "table":
        columns = []
        for column in spec.get("columns", []):
            if not isinstance(column, dict) or not str(column.get("label", "")).strip():
                raise ValueError("Table catalog sütun etiketi içermeli")
            columns.append(
                {
                    "label": str(column["label"]),
                    "flex": max(1, int(column.get("flex", 1))),
                }
            )
        if not columns:
            raise ValueError("Table catalog en az bir sütun içermeli")
        rows = []
        for row in spec.get("rows", []):
            values = [str(value) for value in row]
            if len(values) != len(columns):
                raise ValueError(
                    "Table catalog satır/sütun sayısı uyuşmuyor: "
                    f"{len(values)} != {len(columns)}"
                )
            rows.append(values)
        elements.append(
            {
                "type": "table",
                "label": str(spec.get("label", "Form tablosu")),
                "header": bool(spec.get("header", True)),
                "columns": columns,
                "rows": rows,
            }
        )
    elif kind == "rubric":
        levels = [str(level).strip() for level in spec.get("levels", [])]
        if len(levels) < 2:
            raise ValueError("Rubric catalog en az iki seviye içermeli")
        criteria = []
        for criterion in spec.get("criteria", []):
            if not isinstance(criterion, dict):
                raise ValueError("Rubric catalog ölçütleri nesne olmalı")
            label = str(criterion.get("label", "")).strip()
            descriptors = [
                str(descriptor).strip()
                for descriptor in criterion.get("descriptors", [])
            ]
            if not label:
                raise ValueError("Rubric catalog ölçüt etiketi içermeli")
            if len(descriptors) != len(levels) or any(not item for item in descriptors):
                raise ValueError(
                    "Rubric catalog descriptor sayısı seviye sayısıyla eşleşmeli"
                )
            criteria.append({"label": label, "descriptors": descriptors})
        if not criteria:
            raise ValueError("Rubric catalog en az bir ölçüt içermeli")
        elements.append(
            {
                "type": "rubric",
                "label": str(spec.get("label", "Dereceli puanlama anahtarı")),
                "levels": levels,
                "criteria": criteria,
            }
        )
    else:
        raise ValueError(f"Bilinmeyen catalog kind: {kind}")
    extra_elements = spec.get("extra_elements", [])
    if extra_elements:
        if not isinstance(extra_elements, list) or any(
            not isinstance(element, dict) for element in extra_elements
        ):
            raise ValueError("Catalog extra_elements nesne listesi olmalı")
        elements.extend(extra_elements)
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


def _load_policy() -> dict[str, set[str]]:
    raw = _load_json(POLICY_PATH)
    return {
        key: {str(value) for value in raw.get(key, [])}
        for key in ("ready_content_bases", "verified_statuses", "review_reasons")
    }


def _provenance(row: sqlite3.Row, index_form: dict[str, Any]) -> dict[str, Any]:
    return {
        "source_id": row["source_id"],
        "printed_page": row["printed_page"],
        "pdf_page": row["pdf_page"],
        "verification_status": row["verification_status"],
        "source_locator": index_form.get("source_locator"),
    }


def _merge_catalog_provenance(
    canonical: dict[str, Any],
    supplied: dict[str, Any],
) -> tuple[dict[str, Any], bool]:
    """Merge descriptive catalog evidence without letting it rewrite authority.

    Source identity, canonical page coordinates, verification status and the
    canonical locator belong to the runtime/index. Catalogs may repeat them for
    readability, but a conflicting repeated value is evidence corruption and
    must fail closed.
    """
    merged = dict(canonical)
    authority_conflict = False
    for key, value in supplied.items():
        if key in AUTHORITATIVE_PROVENANCE_FIELDS:
            supplied_value = str(value or "").strip()
            canonical_value = str(canonical.get(key) or "").strip()
            if supplied_value and supplied_value != canonical_value:
                authority_conflict = True
            continue
        merged[key] = value
    return merged, authority_conflict


def _provenance_review_reason(
    provenance: dict[str, Any],
    *,
    row: sqlite3.Row,
    forms_index: dict[str, Any],
    content_was_explicitly_provided: bool,
    policy: dict[str, set[str]],
) -> str | None:
    if not content_was_explicitly_provided:
        return "missing_verification_evidence"

    content_basis = str(provenance.get("content_basis", "")).strip()
    source_id = str(provenance.get("source_id", "")).strip()
    indexed_source_id = str(forms_index.get("source_id", "")).strip()
    verification_status = str(provenance.get("verification_status", "")).strip()
    # A descriptive catalog `source_page` is useful metadata but is not
    # authoritative enough to make a form ready on its own. Readiness needs a
    # locator/page that came from the canonical runtime/index.
    locator_values = (
        provenance.get("source_locator"),
        provenance.get("printed_page"),
        provenance.get("pdf_page"),
    )
    has_locator = any(str(value).strip() for value in locator_values if value is not None)

    if content_basis not in policy["ready_content_bases"]:
        return "invalid_source_provenance"
    if not source_id or (indexed_source_id and source_id != indexed_source_id):
        return "invalid_source_provenance"
    if str(row["source_id"] or "").strip() != source_id:
        return "invalid_source_provenance"
    if not has_locator:
        return "missing_verification_evidence"
    if verification_status not in policy["verified_statuses"]:
        return "invalid_source_provenance"
    return None


def _review_reason(index_form: dict[str, Any]) -> str:
    structural_type = str(index_form.get("structural_type", ""))
    if structural_type == "linked_assessment_resource":
        return "unresolved_form_reference"
    if structural_type in {
        "assessment_criteria_table",
        "teacher_evaluation_form",
        "test_question_set",
        "learning_journal",
    }:
        return "missing_source_structure"
    return "insufficient_canonical_evidence"


def build(args: argparse.Namespace) -> dict[str, int]:
    runtime_dir = Path(args.runtime_dir).resolve()
    database_path = runtime_dir / "course_runtime.sqlite"
    manifest_path = runtime_dir / "runtime_manifest.json"
    report_path = runtime_dir / "runtime_validation_report.md"
    if not database_path.exists() or not manifest_path.exists():
        raise FileNotFoundError(f"Runtime paketi eksik: {runtime_dir}")

    forms_index = _load_json(Path(args.forms_index))
    policy = _load_policy()
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
              provenance_json TEXT NOT NULL DEFAULT '{}',
              review_reason TEXT
            );
            """
        )
        counts = {READY: 0, NEEDS_REVIEW: 0}
        review_reasons: dict[str, str] = {}
        for row in form_rows:
            form_id = str(row["form_id"])
            index_form = index_by_id.get(form_id, {})
            provenance = _provenance(row, index_form)
            spec = catalog_templates.get(form_id)
            if spec is not None:
                elements = _override_elements(spec)
                instructions = spec.get("instructions")
                spec_provenance = spec.get("provenance") or {}
                if not isinstance(spec_provenance, dict):
                    raise ValueError(f"Catalog provenance nesne olmalı: {form_id}")
                provenance, authority_conflict = _merge_catalog_provenance(
                    provenance,
                    spec_provenance,
                )
                review_reason = (
                    "invalid_source_provenance"
                    if authority_conflict
                    else _provenance_review_reason(
                        provenance,
                        row=row,
                        forms_index=forms_index,
                        content_was_explicitly_provided=bool(spec.get("provenance")),
                        policy=policy,
                    )
                )
                status = NEEDS_REVIEW if review_reason else READY
            else:
                elements = _index_elements(index_form)
                instructions = None
                provenance["content_basis"] = "verified_structural_index" if elements else (
                    "metadata_only_structure_unresolved"
                )
                review_reason = (
                    _review_reason(index_form)
                    if not elements
                    else _provenance_review_reason(
                        provenance,
                        row=row,
                        forms_index=forms_index,
                        content_was_explicitly_provided=True,
                        policy=policy,
                    )
                )
                status = NEEDS_REVIEW if review_reason else READY
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
            if status == NEEDS_REVIEW:
                if review_reason not in policy["review_reasons"]:
                    raise ValueError(
                        f"Geçersiz form review reason: {form_id}: {review_reason}"
                    )
            elif review_reason is not None:
                raise ValueError(f"Ready form review reason taşıyor: {form_id}")
            if review_reason is not None:
                review_reasons[form_id] = review_reason
                provenance["review_reason"] = review_reason
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
                "render_status, provenance_json, review_reason) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    form_id,
                    SCHEMA_VERSION,
                    json.dumps(definition, ensure_ascii=False, separators=(",", ":")),
                    instructions,
                    status,
                    json.dumps(provenance, ensure_ascii=False, separators=(",", ":")),
                    review_reason,
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
    # The capability advertises usable structured forms, not merely the
    # existence of a metadata row for every form. A package whose entire form
    # catalog needs review must remain explicitly unavailable to the UI.
    capabilities["form_templates"] = counts[READY] > 0
    manifest.setdefault("row_counts", {})["form_templates"] = sum(counts.values())
    manifest["form_template_schema_versions"] = [SCHEMA_VERSION]
    manifest["form_template_status_counts"] = counts
    manifest["form_template_review_reasons"] = dict(sorted(review_reasons.items()))
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
    if review_reasons:
        existing += "\n### Needs-review reasons\n\n"
        existing += "\n".join(
            f"- `{form_id}`: `{reason}`"
            for form_id, reason in sorted(review_reasons.items())
        )
        existing += "\n"
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
