#!/usr/bin/env bash
set -euo pipefail

# Batch export all NotebookLM notebooks to a local directory structure.
# Usage: ./export-all.sh [--output DIR] [--continue-on-error]

show_help() {
  cat <<EOF
Usage: export-all.sh [options]

Batch export all NotebookLM notebooks to a local directory structure.

Options:
  --output <dir>       Output base directory (default: ./exports)
  --continue-on-error  Continue exporting if individual notebooks fail
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    --output)
      OUTPUT_BASE="$2"
      shift 2
      ;;
    --continue-on-error)
      CONTINUE_ON_ERROR=true
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCRIPT="$SCRIPT_DIR/export-notebook.sh"

if [ ! -x "$EXPORT_SCRIPT" ]; then
  echo "Error: export-notebook.sh not found or not executable at $EXPORT_SCRIPT"
  exit 1
fi

echo "=== NotebookLM Batch Export ==="
echo "Output directory: $OUTPUT_BASE"
echo "Continue on error: $CONTINUE_ON_ERROR"
echo ""

# Get all notebooks
echo "Fetching notebook list..."
NOTEBOOKS=$(nlm notebook list 2>/dev/null)
TOTAL=$(echo "$NOTEBOOKS" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))')

echo "Found $TOTAL notebooks to export"
echo ""

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
  echo "[$export_count/$TOTAL] Exporting: $notebook_title"
  echo "  ID: $notebook_id"

  # Check if already exported (skip to avoid re-downloading)
  slugified=$(echo "$notebook_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80)
  if [ -z "$slugified" ]; then
    slugified="$notebook_id"
  fi

  export_dir="$OUTPUT_BASE/$slugified"
  if [ -d "$export_dir" ] && [ -f "$export_dir/metadata.json" ]; then
    echo "  [↷] Already exported, skipping"
    skipped=$(<"$TEMP_DIR/skipped")
    echo "$((skipped + 1))" > "$TEMP_DIR/skipped"
    echo ""
    continue
  fi

  # Run export
  if "$EXPORT_SCRIPT" "$notebook_id" "$OUTPUT_BASE" 2>&1 | sed 's/^/  /'; then
    success=$(<"$TEMP_DIR/success")
    echo "$((success + 1))" > "$TEMP_DIR/success"
    echo "  [✓] Export complete"
  else
    error=$(<"$TEMP_DIR/error")
    echo "$((error + 1))" > "$TEMP_DIR/error"
    echo "  [✗] Export failed"
    if [ "$CONTINUE_ON_ERROR" = false ]; then
      echo ""
      echo "Export failed. Use --continue-on-error to skip failures."
      exit 1
    fi
  fi

  echo ""
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
echo "=== Export Complete ==="
echo "Total notebooks:  $TOTAL"
echo "Successful:       $success_count"
echo "Errors:           $error_count"
echo "Skipped:          $skipped_count"
echo ""
du -sh "$OUTPUT_BASE" 2>/dev/null | awk '{print "Total size:       " $1}' || echo "Total size:       (unknown)"
