#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   generate-sbom-cyclonedx.sh <source> <output_prefix>
# Example:
#   generate-sbom-cyclonedx.sh "dir:." "sbom/filesystem"
# Produces:
#   sbom/filesystem.cyclonedx.json

SOURCE="${1:?source is required}"
OUTPUT_PREFIX="${2:?output prefix is required}"
OUTPUT_FILE="${OUTPUT_PREFIX}.cyclonedx.json"

echo "[sbom] Generating SBOM from source: ${SOURCE}"
echo "[sbom] SBOM output path: ${OUTPUT_FILE}"

syft "${SOURCE}" \
  --output "cyclonedx-json=${OUTPUT_FILE}"
