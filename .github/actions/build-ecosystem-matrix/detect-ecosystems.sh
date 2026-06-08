#!/usr/bin/env bash
set -euo pipefail

ROOT_PATH="${1:-.}"

if [ ! -d "$ROOT_PATH" ]; then
  echo "Filesystem scan path does not exist: $ROOT_PATH" >&2
  exit 1
fi

any="false"
detected=()
findings_file="$(mktemp)"

cleanup() {
  rm -f "$findings_file"
}
trap cleanup EXIT

detect_one() {
  local ecosystem="$1"
  shift
  local matches
  matches="$(find "$ROOT_PATH" -type f \( "$@" \) -print)"
  if [ -n "$matches" ]; then
    any="true"
    detected+=("$ecosystem")
    while IFS= read -r match; do
      [ -n "$match" ] || continue
      printf '%s\t%s\n' "$ecosystem" "$(dirname "$match")" >> "$findings_file"
    done <<< "$matches"
  fi
}

detect_one node -name package-lock.json -o -name npm-shrinkwrap.json -o -name yarn.lock -o -name pnpm-lock.yaml -o -name package.json
detect_one python -name 'requirements*.txt' -o -name pyproject.toml -o -name poetry.lock -o -name Pipfile.lock -o -name setup.py
detect_one go -name go.mod -o -name go.sum
detect_one java -name pom.xml -o -name build.gradle -o -name build.gradle.kts -o -name settings.gradle -o -name settings.gradle.kts
detect_one dotnet -name '*.sln' -o -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' -o -name Directory.Packages.props
detect_one rust -name Cargo.toml -o -name Cargo.lock
detect_one ruby -name Gemfile -o -name Gemfile.lock
detect_one php -name composer.json -o -name composer.lock
detect_one container -name Dockerfile -o -name Containerfile -o -name '*.Dockerfile'

jq -Rn \
  --argjson any "$any" \
  --slurpfile findings <(sort -u "$findings_file" | jq -R 'split("\t") | {ecosystem: .[0], path: .[1]}') '
  {
    any: $any,
    list: ($findings | map(.ecosystem) | unique),
    findings: $findings
  }
'
