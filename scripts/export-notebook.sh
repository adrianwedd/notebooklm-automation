#!/usr/bin/env bash
set -euo pipefail

# Export a NotebookLM notebook to a local directory structure.
# Usage: ./export-notebook.sh <notebook-id-or-name> [--output DIR] [--format FORMAT] [--match MODE] [--dry-run]

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
Usage: export-notebook.sh <notebook-id-or-name> [options]

Export a NotebookLM notebook to a local directory structure.

Arguments:
  notebook-id-or-name    Notebook UUID or name substring (case-insensitive)

Options:
  --json             Emit JSON summary on stdout (default)
  --quiet            Suppress non-critical logs
  --verbose          Print additional diagnostics
  --output <dir>     Output directory (default: ./exports)
  --format <format>  Export format: notebooklm, obsidian, notion, anki (default: notebooklm)
  --match <mode>     Name matching mode: contains, exact (default: contains)
  --id <uuid>        Explicit notebook UUID (disables name matching)
  --name <string>    Explicit notebook name query (disables UUID parsing of positional arg)
  --dry-run          Print planned export actions and exit without downloading
  --no-retry         Disable retry/backoff for nlm operations
  -h, --help         Show this help message

Examples:
  ./export-notebook.sh "machine learning" --output ./exports
  ./export-notebook.sh abc-123-def-456 --format obsidian
  ./export-notebook.sh "research notes" --output ./out --format anki
  ./export-notebook.sh --name "Research Notes" --match exact
EOF
  exit 0
}

# Parse arguments
NOTEBOOK_ARG=""
BASE_OUTPUT="./exports"
FORMAT="notebooklm"
DRY_RUN=false
MATCH_MODE="contains"
EXPLICIT_ID=""
EXPLICIT_NAME=""
NO_RETRY=false

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
      BASE_OUTPUT="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --match)
      [[ -z "${2:-}" ]] && { echo "Error: --match requires an argument" >&2; exit 1; }
      MATCH_MODE="$2"
      shift 2
      ;;
    --id)
      [[ -z "${2:-}" ]] && { echo "Error: --id requires an argument" >&2; exit 1; }
      EXPLICIT_ID="$2"
      shift 2
      ;;
    --name)
      [[ -z "${2:-}" ]] && { echo "Error: --name requires an argument" >&2; exit 1; }
      EXPLICIT_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
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
      if [[ -z "$NOTEBOOK_ARG" ]]; then
        NOTEBOOK_ARG="$1"
      else
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
fi

if [[ -n "$EXPLICIT_ID" && -n "$EXPLICIT_NAME" ]]; then
  echo "Error: --id and --name are mutually exclusive" >&2
  exit 1
fi
if [[ -n "$EXPLICIT_ID" && -n "$NOTEBOOK_ARG" ]]; then
  echo "Error: provide either --id or a positional notebook-id-or-name, not both" >&2
  exit 1
fi
if [[ -n "$EXPLICIT_NAME" && -n "$NOTEBOOK_ARG" ]]; then
  echo "Error: provide either --name or a positional notebook-id-or-name, not both" >&2
  exit 1
fi

if [[ -z "$NOTEBOOK_ARG" && -z "$EXPLICIT_ID" && -z "$EXPLICIT_NAME" ]]; then
  echo "Error: Missing required notebook selector (positional arg, --id, or --name)" >&2
  echo "Try --help for usage." >&2
  exit 1
fi

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80
}

# --- Resolve notebook ID ---
NOTEBOOK_ID=""
NOTEBOOK_QUERY=""

if [[ -n "$EXPLICIT_ID" ]]; then
  NOTEBOOK_ID="$EXPLICIT_ID"
elif [[ -n "$EXPLICIT_NAME" ]]; then
  NOTEBOOK_QUERY="$EXPLICIT_NAME"
else
  NOTEBOOK_QUERY="$NOTEBOOK_ARG"
fi

if [[ -z "$NOTEBOOK_ID" ]]; then
  # If not explicitly specified as name, allow positional UUID detection.
  if [[ -z "$EXPLICIT_NAME" && "$NOTEBOOK_QUERY" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    NOTEBOOK_ID="$NOTEBOOK_QUERY"
  else
    case "$MATCH_MODE" in
      contains|exact) ;;
      *)
        echo "Error: Invalid --match mode: $MATCH_MODE (expected: contains|exact)" >&2
        exit 1
        ;;
    esac

    log_info "Resolving notebook by name: $NOTEBOOK_QUERY (match: $MATCH_MODE)"
    set +e
    NOTEBOOKS_JSON=$(retry_cmd "nlm notebook list" nlm notebook list 2>&1)
    LIST_EXIT=$?
    set -e
    if [[ $LIST_EXIT -ne 0 ]]; then
      echo "Error: nlm notebook list failed:" >&2
      echo "$NOTEBOOKS_JSON" >&2
      exit 2
    fi

    NOTEBOOK_ID=$(echo "$NOTEBOOKS_JSON" | NLM_QUERY="$NOTEBOOK_QUERY" NLM_MATCH="$MATCH_MODE" python3 -c '
import sys, json, os
notebooks = json.load(sys.stdin)
query = os.environ["NLM_QUERY"].lower()
match = os.environ.get("NLM_MATCH", "contains")

def is_match(title: str) -> bool:
    t = title.lower()
    if match == "exact":
        return t == query
    return query in t

candidates = [(nb.get("id", ""), nb.get("title", "")) for nb in notebooks if is_match(nb.get("title", ""))]

if len(candidates) == 0:
    print("NOT_FOUND", file=sys.stderr)
    sys.exit(2)
if len(candidates) > 1:
    print("AMBIGUOUS", file=sys.stderr)
    for i, (nid, title) in enumerate(candidates, 1):
        print(f"{i}. {title} ({nid})", file=sys.stderr)
    sys.exit(2)

print(candidates[0][0])
')
    if [[ "$NOTEBOOK_ID" == "AMBIGUOUS" || "$NOTEBOOK_ID" == "NOT_FOUND" || -z "$NOTEBOOK_ID" ]]; then
      echo "Error: Notebook name lookup failed or ambiguous. Try --match exact or pass --id." >&2
      exit 2
    fi
  fi
fi

log_info "Notebook ID: $NOTEBOOK_ID"

# --- Get notebook metadata ---
set +e
NOTEBOOKS_JSON=$(retry_cmd "nlm notebook list" nlm notebook list 2>&1)
LIST_EXIT=$?
set -e
if [[ $LIST_EXIT -ne 0 ]]; then
  echo "Error: nlm notebook list failed:" >&2
  echo "$NOTEBOOKS_JSON" >&2
  exit 2
fi

NOTEBOOK_JSON=$(echo "$NOTEBOOKS_JSON" | NLM_NB_ID="$NOTEBOOK_ID" python3 -c '
import sys, json, os
notebooks = json.load(sys.stdin)
target_id = os.environ["NLM_NB_ID"]
for nb in notebooks:
    if nb["id"] == target_id:
        json.dump(nb, sys.stdout, indent=2)
        break
')

TITLE=$(echo "$NOTEBOOK_JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin)["title"])')
SLUG=$(slugify "$TITLE")

if [ -z "$SLUG" ]; then
  SLUG="$NOTEBOOK_ID"
fi

OUTPUT_DIR="$BASE_OUTPUT/$SLUG"
log_info "Exporting: $TITLE"
log_info "Output:    $OUTPUT_DIR"

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run: would create directory structure and export sources/notes/artifacts" >&2
  if [[ "$FORMAT" != "notebooklm" ]]; then
    echo "Dry-run: would run format conversion to $FORMAT" >&2
  fi
  if [[ "$JSON_OUTPUT" == true ]]; then
    NLM_OUT="$OUTPUT_DIR" NLM_FMT="$FORMAT" python3 -c 'import json, os; print(json.dumps({"dry_run": True, "output_dir": os.environ["NLM_OUT"], "format": os.environ["NLM_FMT"]}))'
  fi
  exit 0
fi

# --- Create directory structure ---
mkdir -p "$OUTPUT_DIR"/{sources,chat,notes,studio/{audio,video,documents,visual,interactive}}

# --- Save metadata ---
echo "$NOTEBOOK_JSON" > "$OUTPUT_DIR/metadata.json"
log_info "  [+] metadata.json"

# --- Export sources ---
log_info "  Exporting sources..."
set +e
SOURCES=$(retry_cmd "nlm source list" nlm source list "$NOTEBOOK_ID" 2>&1)
SOURCES_EXIT=$?
set -e
if [[ $SOURCES_EXIT -ne 0 ]]; then
  echo "  [!] nlm source list failed; continuing with empty sources list" >&2
  echo "$SOURCES" >&2
  SOURCES="[]"
fi
echo "$SOURCES" > "$OUTPUT_DIR/sources/index.json"
SOURCE_COUNT=$(echo "$SOURCES" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len 2>/dev/null || echo 0)
log_info "  [+] sources/index.json ($SOURCE_COUNT sources)"

# Try to get source content for each source
echo "$SOURCES" | python3 -c '
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s["id"] + "|" + s["title"] + "|" + s["type"])
' 2>/dev/null | while IFS='|' read -r src_id src_title _src_type; do
  safe_name=$(echo "$src_title" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
  content_file="$OUTPUT_DIR/sources/${safe_name}.md"
  if retry_cmd "nlm content source" nlm content source "$src_id" -o "$content_file"; then
    if [ -s "$content_file" ]; then
      log_info "  [+] sources/$safe_name.md"
    else
      rm -f "$content_file"
    fi
  else
    rm -f "$content_file"
  fi
done

# --- Export chat history ---
# NOTE: NotebookLM's internal API does not expose historical chat conversations.
# The conversation cache in notebooklm-mcp-cli is only for maintaining context
# during active chat sessions, not for retrieving past conversations.
# Chat history export is not currently supported by the underlying API.
log_info "  [.] Chat history export not supported by NotebookLM API"
mkdir -p "$OUTPUT_DIR/chat"
echo "[]" > "$OUTPUT_DIR/chat/index.json"

# --- Export notes ---
log_info "  Exporting notes..."
set +e
NOTES_OUTPUT=$(retry_cmd "nlm note list" nlm note list "$NOTEBOOK_ID" 2>&1)
NOTES_EXIT=$?
set -e
if [[ $NOTES_EXIT -ne 0 ]]; then
  echo "  [!] nlm note list failed; continuing with empty notes list" >&2
  echo "$NOTES_OUTPUT" >&2
  NOTES_OUTPUT="[]"
fi
if echo "$NOTES_OUTPUT" | python3 -c 'import sys, json; json.load(sys.stdin)' 2>/dev/null; then
  echo "$NOTES_OUTPUT" > "$OUTPUT_DIR/notes/index.json"
  NOTE_COUNT=$(echo "$NOTES_OUTPUT" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len)
  log_info "  [+] notes/index.json ($NOTE_COUNT notes)"
  echo "$NOTES_OUTPUT" | python3 -c '
import sys, json
notes = json.load(sys.stdin)
for n in notes:
    title = n.get("title", "untitled")
    content = n.get("content", "")
    safe = "".join(c if c.isalnum() or c in "._- " else "_" for c in title)[:80]
    print(f"{safe}|||{content}")
' 2>/dev/null | while IFS='|||' read -r note_name note_content; do
    if [ -n "$note_name" ]; then
      echo "$note_content" > "$OUTPUT_DIR/notes/${note_name}.md"
      log_info "  [+] notes/${note_name}.md"
    fi
  done
else
  log_info "  [.] No notes found"
  echo "[]" > "$OUTPUT_DIR/notes/index.json"
fi

# --- Export studio artifacts ---
log_info "  Exporting studio artifacts..."
set +e
ARTIFACTS=$(retry_cmd "nlm list artifacts" nlm list artifacts "$NOTEBOOK_ID" 2>&1)
ARTIFACTS_EXIT=$?
set -e
if [[ $ARTIFACTS_EXIT -ne 0 ]]; then
  echo "  [!] nlm list artifacts failed; continuing with empty manifest" >&2
  echo "$ARTIFACTS" >&2
  ARTIFACTS="[]"
fi
echo "$ARTIFACTS" > "$OUTPUT_DIR/studio/manifest.json"
ARTIFACT_COUNT=$(echo "$ARTIFACTS" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len 2>/dev/null || echo 0)
log_info "  [+] studio/manifest.json ($ARTIFACT_COUNT artifacts)"

download_artifact() {
  local atype="$1" aid="$2" outpath="$3"
  if retry_cmd "nlm download $atype" nlm download "$atype" "$NOTEBOOK_ID" --id "$aid" -o "$outpath" --no-progress 1>/dev/null; then
    if [ -f "$outpath" ] && [ -s "$outpath" ]; then
      local size_bytes
      size_bytes=$(wc -c <"$outpath" | tr -d ' ')
      log_info "  [+] $outpath (${size_bytes} bytes)"
      return 0
    fi
  fi
  rm -f "$outpath"
  return 1
}

echo "$ARTIFACTS" | python3 -c '
import sys, json
artifacts = json.load(sys.stdin)
for a in artifacts:
    if a.get("status") == "completed":
        print(a["id"] + "|" + a["type"])
' 2>/dev/null | while IFS='|' read -r art_id art_type; do
  case "$art_type" in
    audio)
      download_artifact audio "$art_id" "$OUTPUT_DIR/studio/audio/${art_id}.mp3" || true
      ;;
    video)
      download_artifact video "$art_id" "$OUTPUT_DIR/studio/video/${art_id}.mp4" || true
      ;;
    report)
      download_artifact report "$art_id" "$OUTPUT_DIR/studio/documents/${art_id}.md" || true
      ;;
    slide_deck)
      download_artifact slide-deck "$art_id" "$OUTPUT_DIR/studio/documents/${art_id}.pdf" || true
      ;;
    infographic)
      download_artifact infographic "$art_id" "$OUTPUT_DIR/studio/visual/${art_id}.png" || true
      ;;
    mind_map)
      download_artifact mind-map "$art_id" "$OUTPUT_DIR/studio/visual/${art_id}.json" || true
      ;;
    quiz)
      download_artifact quiz "$art_id" "$OUTPUT_DIR/studio/interactive/${art_id}-quiz.json" || true
      ;;
    flashcards)
      download_artifact flashcards "$art_id" "$OUTPUT_DIR/studio/interactive/${art_id}-flashcards.json" || true
      ;;
    data_table)
      download_artifact data-table "$art_id" "$OUTPUT_DIR/studio/interactive/${art_id}-data-table.csv" || true
      ;;
    *)
      log_warn "  [?] Unknown artifact type: $art_type ($art_id)"
      ;;
  esac
done

# --- Format conversion ---
if [[ "$FORMAT" != "notebooklm" ]]; then
  log_info ""
  log_info "Converting to $FORMAT format..."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  case "$FORMAT" in
    obsidian)
      OBSIDIAN_DIR="$OUTPUT_DIR-obsidian"
      python3 "$SCRIPT_DIR/../lib/export_obsidian.py" \
        "$OUTPUT_DIR" "$OBSIDIAN_DIR"
      log_info ""
      log_info "Obsidian vault: $OBSIDIAN_DIR"
      ;;
    notion)
      NOTION_DIR="$OUTPUT_DIR-notion"
      python3 "$SCRIPT_DIR/../lib/export_notion.py" \
        "$OUTPUT_DIR" "$NOTION_DIR"
      log_info "Notion file: $NOTION_DIR"
      ;;
    anki)
      ANKI_DIR="$OUTPUT_DIR-anki"
      python3 "$SCRIPT_DIR/../lib/export_anki.py" \
        "$OUTPUT_DIR" "$ANKI_DIR"
      log_info "Anki CSV: $ANKI_DIR"
      ;;
    *)
      log_warn "Warning: Unknown format: $FORMAT (using default)"
      ;;
  esac
fi

# --- Summary ---
log_info ""
log_info "Export complete: $OUTPUT_DIR"
log_info "  Metadata:  metadata.json"
log_info "  Sources:   $SOURCE_COUNT"
log_info "  Artifacts: $ARTIFACT_COUNT"
du -sh "$OUTPUT_DIR" | awk '{print "  Total size: " $1}' >&2

if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_NB_ID="$NOTEBOOK_ID" NLM_TITLE="$TITLE" NLM_OUT="$OUTPUT_DIR" NLM_SOURCES="$SOURCE_COUNT" NLM_ARTIFACTS="$ARTIFACT_COUNT" NLM_FORMAT="$FORMAT" python3 -c '
import json, os
print(json.dumps({
  "notebook_id": os.environ["NLM_NB_ID"],
  "title": os.environ["NLM_TITLE"],
  "output_dir": os.environ["NLM_OUT"],
  "format": os.environ["NLM_FORMAT"],
  "sources": int(os.environ["NLM_SOURCES"]),
  "artifacts": int(os.environ["NLM_ARTIFACTS"])
}))'
fi
