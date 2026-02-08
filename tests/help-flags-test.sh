#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

scripts=(
  "$ROOT_DIR/scripts/add-sources.sh"
  "$ROOT_DIR/scripts/automate-notebook.sh"
  "$ROOT_DIR/scripts/create-from-template.sh"
  "$ROOT_DIR/scripts/create-notebook.sh"
  "$ROOT_DIR/scripts/doctor.sh"
  "$ROOT_DIR/scripts/download-gdoc-md.sh"
  "$ROOT_DIR/scripts/export-all.sh"
  "$ROOT_DIR/scripts/export-notebook.sh"
  "$ROOT_DIR/scripts/generate-parallel.sh"
  "$ROOT_DIR/scripts/generate-studio.sh"
  "$ROOT_DIR/scripts/research-topic.sh"
  "$ROOT_DIR/scripts/validate-json.sh"
)

for s in "${scripts[@]}"; do
  out="$("$s" --help 2>&1 || true)"
  printf '%s\n' "$out" | grep -q -- "--json" || { echo "missing --json in help: $s" >&2; exit 1; }
  printf '%s\n' "$out" | grep -q -- "--quiet" || { echo "missing --quiet in help: $s" >&2; exit 1; }
  printf '%s\n' "$out" | grep -q -- "--verbose" || { echo "missing --verbose in help: $s" >&2; exit 1; }
done

echo "help flags tests: ok"

