#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   generate-python-sbom-cyclonedx.sh <project_dir> <output_prefix>
#
# Produces:
#   <output_prefix>.cyclonedx.json

PROJECT_DIR="${1:?project directory is required}"
OUTPUT_PREFIX="${2:?output prefix is required}"

OUTPUT_FILE="$(cd "$(dirname "$OUTPUT_PREFIX")" && pwd)/$(basename "$OUTPUT_PREFIX").cyclonedx.json"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Python project directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

# Pin versions for reproducibility
python -m pip install --disable-pip-version-check \
    "cyclonedx-bom==4.1.6" \
    "pip-audit==2.9.0" \
    "poetry==2.2.1"

pushd "$PROJECT_DIR" >/dev/null
trap 'popd >/dev/null 2>&1 || true' EXIT

if [[ -f "pyproject.toml" ]] && grep -q '\[tool\.poetry\]' pyproject.toml; then
    echo "Detected Poetry project"

    if [[ ! -f "poetry.lock" ]]; then
        echo "poetry.lock is required for reproducible SBOM generation" >&2
        exit 1
    fi

    poetry install \
        --no-root \
        --no-interaction \
        --sync

    poetry run cyclonedx-py environment \
        --output-format JSON \
        --output-file "$OUTPUT_FILE"

elif [[ -f "requirements.txt" ]]; then
    echo "Detected requirements.txt project"

    pip-audit \
        --requirement requirements.txt \
        --format cyclonedx-json \
        > "$OUTPUT_FILE" || true  # pip-audit exits with non-zero if vulnerabilities are found, but we still want the SBOM

else
    echo "No supported dependency manifest found in $PROJECT_DIR" >&2
    echo "Expected one of:" >&2
    echo "  - pyproject.toml (Poetry project)" >&2
    echo "  - requirements.txt" >&2
    exit 1
fi

echo "SBOM written to: $OUTPUT_FILE"