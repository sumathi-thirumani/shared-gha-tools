#!/usr/bin/env python3
"""Generate a GitHub dependency graph snapshot from a CycloneDX SBOM."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def component_key(component: dict) -> str | None:
    return component.get("bom-ref") or component.get("purl") or component.get("name")


def component_purl(component: dict) -> str | None:
    purl = component.get("purl")
    if purl:
        return purl

    name = component.get("name")
    version = component.get("version")
    if name and version:
        return f"pkg:generic/{name}@{version}"
    return None


def build_snapshot(cyclonedx_file: Path, source_location: str) -> dict:
    sbom = json.loads(cyclonedx_file.read_text(encoding="utf-8"))
    manifest_name = "cyclonedx-sbom"
    resolved = {}

    for component in sbom.get("components") or []:
        key = component_key(component)
        purl = component_purl(component)
        if not key or not purl:
            continue

        resolved[key] = {
            "package_url": purl,
            "relationship": "indirect",
            "scope": "runtime",
        }

    return {
        "version": 0,
        "sha": "",
        "ref": "",
        "scanned": datetime.now(timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z"),
        "job": {
            "id": "",
            "correlator": "",
        },
        "detector": {
            "name": "cyclonedx-sbom",
            "version": str(sbom.get("specVersion") or "unknown"),
            "url": "https://github.com/sumathi-thirumani/shared-gha-tools",
        },
        "manifests": {
            manifest_name: {
                "name": manifest_name,
                "file": {
                    "source_location": source_location,
                },
                "resolved": dict(sorted(resolved.items())),
            }
        },
    }


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: generate-cyclonedx-snapshot.py <cyclonedx_file> <source_location> <output_file>",
            file=sys.stderr,
        )
        return 2

    cyclonedx_file = Path(sys.argv[1]).resolve()
    source_location = sys.argv[2].removeprefix("dir:")
    output_file = Path(sys.argv[3]).resolve()
    snapshot = build_snapshot(cyclonedx_file, source_location)
    output_file.write_text(
        json.dumps(snapshot, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
