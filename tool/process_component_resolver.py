#!/usr/bin/env python3
from __future__ import annotations

import copy
import re
from typing import Any

COMPONENT_RE = re.compile(r"(TDE\d+\.\d+\.\d+)")
PARENT_RE = re.compile(r"^TDE\d+\.\d+$")


class ProcessComponentError(ValueError):
    pass


def normalize_component_code(value: Any) -> str:
    match = COMPONENT_RE.search(str(value or ""))
    if not match:
        raise ProcessComponentError(f"invalid process component code: {value!r}")
    return match.group(1)


def canonical_outcome_id(outcome: dict[str, Any], theme_id: str | None = None) -> str:
    explicit = outcome.get("outcome_id")
    if explicit:
        return str(explicit)
    stable = outcome.get("stable_entity_key")
    if stable:
        return str(stable)
    code = outcome.get("outcome_code")
    if theme_id and code:
        return f"{theme_id}::{code}"
    return str(code or "")


def build_catalog_index(catalog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    parents = catalog.get("parents", [])
    expected_parent_count = catalog.get("parent_count")
    expected_component_count = catalog.get("component_count")
    if expected_parent_count is not None and len(parents) != expected_parent_count:
        raise ProcessComponentError(
            f"roof parent count mismatch: actual={len(parents)} expected={expected_parent_count}"
        )

    index: dict[str, dict[str, Any]] = {}
    seen_components: set[str] = set()
    component_count = 0
    for parent in parents:
        parent_code = parent.get("parent_code")
        if not isinstance(parent_code, str) or not PARENT_RE.match(parent_code):
            raise ProcessComponentError(f"invalid roof parent code: {parent_code!r}")
        if parent_code in index:
            raise ProcessComponentError(f"duplicate roof parent code: {parent_code}")
        if not parent.get("source_locator"):
            raise ProcessComponentError(f"missing roof source locator: {parent_code}")

        normalized_components = []
        for component in parent.get("components", []):
            code = normalize_component_code(component.get("component_code"))
            if not code.startswith(parent_code + "."):
                raise ProcessComponentError(
                    f"component parent-prefix mismatch: {code} is not under {parent_code}"
                )
            if code in seen_components:
                raise ProcessComponentError(f"duplicate roof component code: {code}")
            if not component.get("component_title_verbatim"):
                raise ProcessComponentError(f"missing roof component title: {code}")
            if not component.get("source_locator"):
                raise ProcessComponentError(f"missing roof component locator: {code}")
            seen_components.add(code)
            component_count += 1
            normalized_components.append({**component, "component_code": code})
        if not normalized_components:
            raise ProcessComponentError(f"roof parent has no components: {parent_code}")
        index[parent_code] = {**parent, "components": normalized_components}

    if expected_component_count is not None and component_count != expected_component_count:
        raise ProcessComponentError(
            f"roof component count mismatch: actual={component_count} expected={expected_component_count}"
        )
    return index


def _explicit_components(outcome: dict[str, Any], parent_code: str) -> list[dict[str, Any]]:
    explicit = outcome.get("process_components_verbatim") or []
    identity = canonical_outcome_id(outcome) or parent_code
    if not isinstance(explicit, list):
        raise ProcessComponentError(
            f"{identity}: process_components_verbatim must be a list"
        )
    seen: set[str] = set()
    normalized: list[dict[str, Any]] = []
    for component in explicit:
        if not isinstance(component, dict):
            raise ProcessComponentError(f"{identity}: explicit component must be an object")
        code = normalize_component_code(component.get("component_code"))
        if not code.startswith(parent_code + "."):
            raise ProcessComponentError(
                f"{identity}: explicit component {code} is not under {parent_code}"
            )
        if code in seen:
            raise ProcessComponentError(f"{identity}: duplicate explicit component {code}")
        if not component.get("source_locator"):
            raise ProcessComponentError(f"{identity}: explicit component locator missing for {code}")
        seen.add(code)
        normalized.append({**component, "component_code_normalized": code})
    return normalized


def resolve_outcome_components(
    outcome: dict[str, Any], catalog_index: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    parent_code = outcome.get("outcome_code")
    if not isinstance(parent_code, str) or not PARENT_RE.match(parent_code):
        raise ProcessComponentError(f"invalid outcome parent code: {parent_code!r}")
    explicit = _explicit_components(outcome, parent_code)
    roof = catalog_index.get(parent_code)
    if explicit:
        return {
            "origin": "THEME_EXPLICIT",
            "parent_code": parent_code,
            "components": copy.deepcopy(explicit),
            "explicit_count": len(explicit),
            "roof_count": len(roof.get("components", [])) if roof else 0,
            "effective_count": len(explicit),
            "status": "RESOLVED",
        }
    if roof and roof.get("components"):
        inherited = [
            {
                "component_code": c["component_code"],
                "component_title": c["component_title_verbatim"],
                "component_verbatim": c["component_title_verbatim"],
                "source_locator": c["source_locator"],
                "resolution_origin": "ROOF_INHERITED",
                "verification_status": "VERIFIED",
            }
            for c in roof["components"]
        ]
        return {
            "origin": "ROOF_INHERITED",
            "parent_code": parent_code,
            "components": inherited,
            "explicit_count": 0,
            "roof_count": len(inherited),
            "effective_count": len(inherited),
            "status": "RESOLVED",
        }
    if outcome.get("process_component_status") == "SOURCE_VERIFIED_NONE":
        return {
            "origin": "SOURCE_VERIFIED_NONE",
            "parent_code": parent_code,
            "components": [],
            "explicit_count": 0,
            "roof_count": 0,
            "effective_count": 0,
            "status": "RESOLVED",
        }
    return {
        "origin": "UNRESOLVED",
        "parent_code": parent_code,
        "components": [],
        "explicit_count": 0,
        "roof_count": 0,
        "effective_count": 0,
        "status": "PROCESS_COMPONENT_INHERITANCE_MISSING",
    }


def audit_curriculum(curriculum: dict[str, Any], catalog: dict[str, Any]) -> dict[str, Any]:
    catalog_index = build_catalog_index(catalog)
    grade = curriculum.get("grade")
    applicable_grades = set(catalog.get("applicable_grades", []))
    if applicable_grades and grade not in applicable_grades:
        raise ProcessComponentError(
            f"catalog {catalog.get('catalog_id')} does not apply to grade {grade}"
        )
    counts = {
        "total_outcomes": 0,
        "outcomes_with_roof_components": 0,
        "explicit_component_outcomes": 0,
        "inherited_component_outcomes": 0,
        "verified_no_component_outcomes": 0,
        "unresolved_component_outcomes": 0,
        "inheritance_missing_count": 0,
        "structural_error_count": 0,
    }
    for theme in curriculum.get("themes", []):
        for outcome in theme.get("learning_outcomes", []):
            counts["total_outcomes"] += 1
            parent_code = outcome.get("outcome_code")
            if parent_code in catalog_index:
                counts["outcomes_with_roof_components"] += 1
            try:
                resolution = resolve_outcome_components(outcome, catalog_index)
            except ProcessComponentError:
                counts["structural_error_count"] += 1
                continue
            origin = resolution["origin"]
            if origin == "THEME_EXPLICIT":
                counts["explicit_component_outcomes"] += 1
            elif origin == "ROOF_INHERITED":
                counts["inherited_component_outcomes"] += 1
            elif origin == "SOURCE_VERIFIED_NONE":
                counts["verified_no_component_outcomes"] += 1
            else:
                counts["unresolved_component_outcomes"] += 1
                counts["inheritance_missing_count"] += 1
    passed = (
        counts["inheritance_missing_count"] == 0
        and counts["unresolved_component_outcomes"] == 0
        and counts["structural_error_count"] == 0
    )
    return {
        "course_id": curriculum.get("course_id"),
        "grade": grade,
        "catalog_id": catalog.get("catalog_id"),
        "counts": counts,
        "final": "PASS" if passed else "FAIL",
    }


def project_effective_components(
    curriculum: dict[str, Any], catalog: dict[str, Any]
) -> dict[str, Any]:
    catalog_index = build_catalog_index(catalog)
    projected = copy.deepcopy(curriculum)
    for theme in projected.get("themes", []):
        theme_id = theme.get("theme_id")
        for outcome in theme.get("learning_outcomes", []):
            resolution = resolve_outcome_components(outcome, catalog_index)
            if resolution["status"] != "RESOLVED":
                raise ProcessComponentError(
                    f"{canonical_outcome_id(outcome, theme_id)}: {resolution['status']}"
                )
            outcome["process_components_effective"] = copy.deepcopy(resolution["components"])
            outcome["process_component_resolution"] = {
                "origin": resolution["origin"],
                "parent_code": resolution["parent_code"],
                "catalog_id": catalog.get("catalog_id")
                if resolution["origin"] == "ROOF_INHERITED"
                else None,
                "explicit_count": resolution["explicit_count"],
                "roof_count": resolution["roof_count"],
                "effective_count": resolution["effective_count"],
            }
    return projected
