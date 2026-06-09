#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   generate-python-sbom-cyclonedx.sh <project_dir> <output_prefix>
#
# Produces:
#   <output_prefix>.cyclonedx.json

PROJECT_DIR="${1:?project directory is required}"
OUTPUT_PREFIX="${2:?output prefix is required}"

OUTPUT_FILE="$(mkdir -p "$(dirname "$OUTPUT_PREFIX")" && \
    cd "$(dirname "$OUTPUT_PREFIX")" && pwd)/$(basename "$OUTPUT_PREFIX").cyclonedx.json"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Project directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

TOOL_VENV="$(mktemp -d)"
cleanup() {
    rm -rf "$TOOL_VENV"
}
trap cleanup EXIT

python -m venv "$TOOL_VENV"

# shellcheck disable=SC1091
source "$TOOL_VENV/bin/activate"

python -m pip install \
    --disable-pip-version-check \
    --quiet \
    "cyclonedx-bom==7.3.0" \
    "poetry==2.2.1"

pushd "$PROJECT_DIR" >/dev/null

if [[ -f "pyproject.toml" ]] && grep -q '^\[tool\.poetry\]$' pyproject.toml; then
    echo "Detected Poetry project"

    if [[ ! -f "poetry.lock" ]]; then
        echo "poetry.lock is required for reproducible SBOM generation" >&2
        exit 1
    fi

    cyclonedx-py poetry \
        --output-format JSON \
        --output-file "$OUTPUT_FILE"

elif [[ -f "requirements.txt" ]]; then
    echo "Detected requirements.txt project"

    PROJECT_VENV="$(mktemp -d)"

    cleanup_project_venv() {
        rm -rf "$PROJECT_VENV"
    }
    trap 'cleanup_project_venv; cleanup' EXIT

    python -m venv "$PROJECT_VENV"

    # shellcheck disable=SC1091
    source "$PROJECT_VENV/bin/activate"

    python -m pip install \
        --disable-pip-version-check \
        --upgrade pip

    python -m pip install \
        --disable-pip-version-check \
        -r requirements.txt

    cyclonedx-py environment \
        --output-format JSON \
        --output-file "$OUTPUT_FILE"

else
    echo "No supported dependency manifest found in $PROJECT_DIR" >&2
    echo "Expected one of:" >&2
    echo "  - pyproject.toml (Poetry project)" >&2
    echo "  - requirements.txt" >&2
    exit 1
fi

popd >/dev/null

echo "SBOM written to: $OUTPUT_FILE"