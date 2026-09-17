#!/usr/bin/env python3
"""Create or verify the frozen pre-V2.3 canonical Teacher Guide snapshot.

The source SQLite is extracted from the pinned baseline commit.  If the snapshot is
already versioned, this command verifies byte-for-byte determinism; otherwise it writes
the generated snapshot so the materialization job can commit it.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from export_teacher_guide_v23_canonical_snapshot import (
    BASELINE_RUNTIME_COMMIT,
    export_snapshot,
)

BASELINE_DATABASE_PATH = (
    "tymm-verileri/turk-dili-ve-edebiyati/TDE_11/runtime/course_runtime.sqlite"
)
DEFAULT_OUTPUT = "tool/teacher_guide/v23_canonical_snapshot.json"


def run(*args: str, cwd: Path, stdout=None) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        list(args),
        cwd=cwd,
        stdout=stdout,
        stderr=subprocess.PIPE,
        check=True,
    )


def ensure_commit(repo_root: Path, commit: str) -> None:
    probe = subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        cwd=repo_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if probe.returncode == 0:
        return
    run(
        "git",
        "fetch",
        "--no-tags",
        "--depth=1",
        "origin",
        commit,
        cwd=repo_root,
        stdout=subprocess.DEVNULL,
    )


def canonical_bytes(snapshot: dict) -> bytes:
    return (
        json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument("--output", type=Path, default=Path(DEFAULT_OUTPUT))
    parser.add_argument("--baseline-commit", default=BASELINE_RUNTIME_COMMIT)
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    output = args.output
    if not output.is_absolute():
        output = repo_root / output
    output = output.resolve()
    baseline_commit = str(args.baseline_commit).strip()

    ensure_commit(repo_root, baseline_commit)
    with tempfile.TemporaryDirectory(prefix="tde11-v23-baseline-") as temp_dir:
        database = Path(temp_dir) / "course_runtime.sqlite"
        with database.open("wb") as handle:
            run(
                "git",
                "show",
                f"{baseline_commit}:{BASELINE_DATABASE_PATH}",
                cwd=repo_root,
                stdout=handle,
            )
        snapshot = export_snapshot(database, baseline_commit)

    payload = canonical_bytes(snapshot)
    if output.is_file():
        current = output.read_bytes()
        if current != payload:
            raise SystemExit(
                "TEACHER_GUIDE_V23_CANONICAL_SNAPSHOT: DRIFT "
                f"output={output} baseline={baseline_commit}"
            )
        print(
            "TEACHER_GUIDE_V23_CANONICAL_SNAPSHOT: VERIFIED "
            f"items={snapshot['item_count']} relations={snapshot['relation_count']} output={output}"
        )
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    print(
        "TEACHER_GUIDE_V23_CANONICAL_SNAPSHOT: CREATED "
        f"items={snapshot['item_count']} relations={snapshot['relation_count']} output={output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
