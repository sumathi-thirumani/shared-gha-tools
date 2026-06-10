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

syft "${SOURCE}" \
  --output "cyclonedx-json=${OUTPUT_PREFIX}.cyclonedx.json"
