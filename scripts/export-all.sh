#!/usr/bin/env bash
set -euo pipefail

# Batch export all NotebookLM notebooks to a local directory structure.
# Usage: ./export-all.sh [--output DIR] [--continue-on-error]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

JSON_OUTPUT=true
QUIET=false
VERBOSE=false

log_info() {
  if [[ "$QUIET" != true ]]; then
    echo "$1" >&2
  fi
}

log_warn() {
  echo "$1" >&2
}

debug() {
  if [[ "$VERBOSE" == true && "$QUIET" != true ]]; then
    echo "Debug: $1" >&2
  fi
}

show_help() {
  cat <<EOF
Usage: export-all.sh [options]

Batch export all NotebookLM notebooks to a local directory structure.

Options:
  --json              Emit JSON summary on stdout (default)
  --quiet             Suppress non-critical logs
  --verbose           Print additional diagnostics
  --output <dir>       Output base directory (default: ./exports)
  --continue-on-error  Continue exporting if individual notebooks fail
  --no-retry           Disable retry/backoff for nlm operations
  -h, --help           Show this help message

Examples:
  ./export-all.sh
  ./export-all.sh --output ./my-exports
  ./export-all.sh --output ./exports --continue-on-error
EOF
  exit 0
}

OUTPUT_BASE="./exports"
CONTINUE_ON_ERROR=false
NO_RETRY=false
EXTRA_EXPORT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --output)
      OUTPUT_BASE="$2"
      shift 2
      ;;
    --continue-on-error)
      CONTINUE_ON_ERROR=true
      shift
      ;;
    --no-retry)
      NO_RETRY=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      # Backwards compat: treat first positional arg as output dir
      OUTPUT_BASE="$1"
      shift
      ;;
  esac
done

EXPORT_SCRIPT="$SCRIPT_DIR/export-notebook.sh"

if [ ! -x "$EXPORT_SCRIPT" ]; then
  echo "Error: export-notebook.sh not found or not executable at $EXPORT_SCRIPT"
  exit 1
fi

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
  EXTRA_EXPORT_ARGS+=(--no-retry)
fi

if [[ "$QUIET" == true ]]; then
  EXTRA_EXPORT_ARGS+=(--quiet)
fi

log_info "=== NotebookLM Batch Export ==="
log_info "Output directory: $OUTPUT_BASE"
log_info "Continue on error: $CONTINUE_ON_ERROR"
log_info ""

# Get all notebooks
log_info "Fetching notebook list..."
set +e
NOTEBOOKS=$(retry_cmd "nlm notebook list" nlm notebook list 2>&1)
LIST_EXIT=$?
set -e
if [[ $LIST_EXIT -ne 0 ]]; then
  echo "Error: nlm notebook list failed:" >&2
  echo "$NOTEBOOKS" >&2
  exit 2
fi
TOTAL=$(echo "$NOTEBOOKS" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len 2>/dev/null || echo 0)

log_info "Found $TOTAL notebooks to export"
log_info ""

# Create temp files for counters (to survive subshell)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "0" > "$TEMP_DIR/success"
echo "0" > "$TEMP_DIR/error"
echo "0" > "$TEMP_DIR/skipped"

# Export each notebook
export_count=0
while IFS='|' read -r notebook_id notebook_title; do
  export_count=$((export_count + 1))

  # Display progress
  log_info "[$export_count/$TOTAL] Exporting: $notebook_title"
  log_info "  ID: $notebook_id"

  # Check if already exported (skip to avoid re-downloading)
  slugified=$(echo "$notebook_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80)
  if [ -z "$slugified" ]; then
    slugified="$notebook_id"
  fi

  export_dir="$OUTPUT_BASE/$slugified"
  if [ -d "$export_dir" ] && [ -f "$export_dir/metadata.json" ]; then
    log_info "  [↷] Already exported, skipping"
    skipped=$(<"$TEMP_DIR/skipped")
    echo "$((skipped + 1))" > "$TEMP_DIR/skipped"
    log_info ""
    continue
  fi

  # Run export
  if "$EXPORT_SCRIPT" --id "$notebook_id" --output "$OUTPUT_BASE" "${EXTRA_EXPORT_ARGS[@]}" 2>&1 | sed 's/^/  /' >&2; then
    success=$(<"$TEMP_DIR/success")
    echo "$((success + 1))" > "$TEMP_DIR/success"
    log_info "  [✓] Export complete"
  else
    error=$(<"$TEMP_DIR/error")
    echo "$((error + 1))" > "$TEMP_DIR/error"
    log_warn "  [✗] Export failed"
    if [ "$CONTINUE_ON_ERROR" = false ]; then
      log_info ""
      log_warn "Export failed. Use --continue-on-error to skip failures."
      exit 1
    fi
  fi

  log_info ""
done < <(echo "$NOTEBOOKS" | python3 -c '
import sys, json
notebooks = json.load(sys.stdin)
for nb in notebooks:
    print(nb["id"] + "|" + nb["title"])
')

# Read final counts
success_count=$(<"$TEMP_DIR/success")
error_count=$(<"$TEMP_DIR/error")
skipped_count=$(<"$TEMP_DIR/skipped")

# Final summary
log_info "=== Export Complete ==="
log_info "Total notebooks:  $TOTAL"
log_info "Successful:       $success_count"
log_info "Errors:           $error_count"
log_info "Skipped:          $skipped_count"
log_info ""
du -sh "$OUTPUT_BASE" 2>/dev/null | awk '{print "Total size:       " $1}' >&2 || log_warn "Total size:       (unknown)"

if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_OUT="$OUTPUT_BASE" NLM_TOTAL="$TOTAL" NLM_OK="$success_count" NLM_ERR="$error_count" NLM_SKIPPED="$skipped_count" python3 -c '
import json, os
print(json.dumps({
  "output_base": os.environ["NLM_OUT"],
  "total": int(os.environ["NLM_TOTAL"]),
  "successful": int(os.environ["NLM_OK"]),
  "errors": int(os.environ["NLM_ERR"]),
  "skipped": int(os.environ["NLM_SKIPPED"])
}))'
fi
