#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   build-ecosystem-matrix.sh <mode> <source_path> [supported_ecosystems_csv]
# Modes:
#   audit - emits matrix entries like {"ecosystem":"node"}
#   sbom  - emits filesystem matrix entries for unique detected ecosystem directories, like
#           {"scan_kind":"filesystem","scan_label":"filesystem-node-src-app","source":"dir:src/app","output_prefix":"sbom/filesystem-node-src-app"}
#
# Output JSON shape:
# {
#   "detected": ["node", "python"],
#   "targets": ["filesystem-node-src-app"],
#   "count": 1,
#   "matrix": {"include": [...]}
# }

MODE="${1:?mode is required (audit|sbom)}"
SOURCE_PATH="${2:-.}"
SUPPORTED_CSV="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ecosystem_json="$(bash "$SCRIPT_DIR/detect-ecosystems.sh" "$SOURCE_PATH")"
detected="$(jq -c '.list' <<< "$ecosystem_json")"

build_supported_json() {
  local csv="$1"
  jq -cn --arg supported "$csv" '
    $supported
    | split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
  '
}

case "$MODE" in
  audit)
    supported_json="$(build_supported_json "${SUPPORTED_CSV:-node,python}")"
    entries="$(jq -c --argjson supported "$supported_json" '
      [.list[] | select(. as $e | $supported | index($e) != null) | {ecosystem:.}]
    ' <<< "$ecosystem_json")"
    targets="$(jq -c '[.[].ecosystem]' <<< "$entries")"
    ;;

  sbom)
    entries="$(jq -c --arg sourcePath "$SOURCE_PATH" '
      def slug:
        if . == "." then "root"
        else
          gsub("^\\./"; "")
          | gsub("[^A-Za-z0-9._-]+"; "-")
          | gsub("^-+|-+$"; "")
          | if length == 0 then "root" else . end
        end;
      def relative_to_root($root):
        if . == $root then "."
        elif ($root != "." and startswith($root + "/")) then ltrimstr($root + "/")
        else gsub("^\\./"; "")
        end;

      if .any then
        [.findings
          | group_by(.path)[]
          | {
              path: .[0].path,
              label_path: (.[0].path | relative_to_root($sourcePath)),
              ecosystems: (map(.ecosystem) | unique)
            }
          | .label = ("filesystem-" + (.ecosystems | join("-")) + "-" + (.label_path | slug))
          | {
              scan_kind: "filesystem",
              scan_label: .label,
              source: ("dir:" + .path),
              output_prefix: ("sbom/" + .label),
              ecosystems: .ecosystems
            }]
      else
        [{
          scan_kind: "filesystem",
          scan_label: "filesystem-generic",
          source: ("dir:" + $sourcePath),
          output_prefix: "sbom/filesystem-generic",
          ecosystems: []
        }]
      end
    ' <<< "$ecosystem_json")"
    targets="$(jq -c '[.[].scan_label]' <<< "$entries")"
    ;;

  *)
    echo "Unsupported mode: $MODE (expected audit or sbom)" >&2
    exit 1
    ;;
esac

count="$(jq -r 'length' <<< "$entries")"
matrix="$(jq -c --argjson include "$entries" '{include:$include}' <<< '{}')"

jq -cn \
  --argjson detected "$detected" \
  --argjson targets "$targets" \
  --argjson count "$count" \
  --argjson matrix "$matrix" \
  '{detected:$detected, targets:$targets, count:$count, matrix:$matrix}'
