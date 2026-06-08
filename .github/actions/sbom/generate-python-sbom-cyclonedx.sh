#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   generate-python-sbom-cyclonedx.sh <project_dir> <output_prefix>
# Produces:
#   <output_prefix>.cyclonedx.json

PROJECT_DIR="${1:?project directory is required}"
OUTPUT_PREFIX="${2:?output prefix is required}"
OUTPUT_FILE="$(cd "$(dirname "$OUTPUT_PREFIX")" && pwd)/$(basename "$OUTPUT_PREFIX").cyclonedx.json"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Python project directory does not exist: $PROJECT_DIR" >&2
  exit 1
fi

python -m pip install --upgrade pip
pip install cyclonedx-bom poetry

pushd "$PROJECT_DIR" >/dev/null

if [ -f "poetry.lock" ] || grep -q "\[tool.poetry\]" pyproject.toml 2>/dev/null; then
  echo "Poetry project detected"

  [ -f poetry.lock ] || poetry lock
  poetry install --no-interaction
  poetry run cyclonedx-py environment --output-format JSON --output-file "$OUTPUT_FILE"
elif [ -f "requirements.txt" ]; then
  echo "requirements.txt project detected"

  python -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install -r requirements.txt
  cyclonedx-py environment --output-format JSON --output-file "$OUTPUT_FILE"
else
  echo "No supported Python dependency manifest found in $PROJECT_DIR" >&2
  exit 1
fi

popd >/dev/null
