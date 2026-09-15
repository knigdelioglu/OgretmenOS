#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
COURSE_ROOT = REPO_ROOT / "tymm-verileri" / "turk-dili-ve-edebiyati"
COURSES = ("TDE_12",)


def main() -> int:
    builder = REPO_ROOT / "tool" / "build_curriculum_only_runtime.py"
    for course_id in COURSES:
        package_root = COURSE_ROOT / course_id
        package_manifest = json.loads(
            (package_root / "package_manifest.json").read_text(encoding="utf-8")
        )
        source_commit = str(package_manifest.get("tymm_source_commit") or "").strip()
        if not source_commit:
            raise SystemExit(f"{course_id}: tymm_source_commit missing")
        subprocess.run(
            [
                sys.executable,
                str(builder),
                "--package-root",
                str(package_root),
                "--source-commit",
                source_commit,
            ],
            check=True,
            cwd=REPO_ROOT,
        )
        runtime_manifest = json.loads(
            (package_root / "runtime/runtime_manifest.json").read_text(encoding="utf-8")
        )
        counts = runtime_manifest.get("process_component_counts", {})
        if runtime_manifest.get("process_component_resolution_status") != "PASS":
            raise SystemExit(f"{course_id}: process-component resolution not PASS")
        if counts.get("total_outcomes") != 64:
            raise SystemExit(f"{course_id}: total_outcomes != 64: {counts}")
        if counts.get("inherited_component_outcomes") != 64:
            raise SystemExit(f"{course_id}: inherited_component_outcomes != 64: {counts}")
        if counts.get("unresolved_component_outcomes") != 0:
            raise SystemExit(f"{course_id}: unresolved process components: {counts}")
        if counts.get("inheritance_missing_count") != 0:
            raise SystemExit(f"{course_id}: inheritance missing: {counts}")
        print(f"{course_id}: CURRICULUM_RUNTIME_FRESH / PROCESS_COMPONENTS_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
