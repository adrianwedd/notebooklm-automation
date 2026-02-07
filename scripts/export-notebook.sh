#!/usr/bin/env bash
set -euo pipefail

# Export a NotebookLM notebook to a local directory structure.
# Usage: ./export-notebook.sh <notebook-id-or-name> [output-dir] [--format FORMAT]

NOTEBOOK_ARG="${1:?Usage: export-notebook.sh <notebook-id-or-name> [output-dir] [--format FORMAT]}"
BASE_OUTPUT="${2:-./exports}"
FORMAT="notebooklm"  # default format

# Parse optional format flag
shift 2 2>/dev/null || shift $#
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 80
}

# --- Resolve notebook ID ---
if [[ "$NOTEBOOK_ARG" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  NOTEBOOK_ID="$NOTEBOOK_ARG"
else
  echo "Resolving notebook by name: $NOTEBOOK_ARG"
  NOTEBOOK_ID=$(nlm notebook list 2>/dev/null | python3 -c "
import sys, json
notebooks = json.load(sys.stdin)
query = '$NOTEBOOK_ARG'.lower()
for nb in notebooks:
    if query in nb['title'].lower():
        print(nb['id'])
        break
else:
    print('NOT_FOUND', file=sys.stderr)
    sys.exit(1)
")
fi

echo "Notebook ID: $NOTEBOOK_ID"

# --- Get notebook metadata ---
NOTEBOOK_JSON=$(nlm notebook list 2>/dev/null | python3 -c "
import sys, json
notebooks = json.load(sys.stdin)
for nb in notebooks:
    if nb['id'] == '$NOTEBOOK_ID':
        json.dump(nb, sys.stdout, indent=2)
        break
")

TITLE=$(echo "$NOTEBOOK_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
SLUG=$(slugify "$TITLE")

if [ -z "$SLUG" ]; then
  SLUG="$NOTEBOOK_ID"
fi

OUTPUT_DIR="$BASE_OUTPUT/$SLUG"
echo "Exporting: $TITLE"
echo "Output:    $OUTPUT_DIR"

# --- Create directory structure ---
mkdir -p "$OUTPUT_DIR"/{sources,chat,notes,studio/{audio,video,documents,visual,interactive}}

# --- Save metadata ---
echo "$NOTEBOOK_JSON" > "$OUTPUT_DIR/metadata.json"
echo "  [+] metadata.json"

# --- Export sources ---
echo "  Exporting sources..."
SOURCES=$(nlm source list "$NOTEBOOK_ID" 2>/dev/null)
echo "$SOURCES" > "$OUTPUT_DIR/sources/index.json"
SOURCE_COUNT=$(echo "$SOURCES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "  [+] sources/index.json ($SOURCE_COUNT sources)"

# Try to get source content for each source
echo "$SOURCES" | python3 -c "
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s['id'] + '|' + s['title'] + '|' + s['type'])
" 2>/dev/null | while IFS='|' read -r src_id src_title src_type; do
  safe_name=$(echo "$src_title" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
  content_file="$OUTPUT_DIR/sources/${safe_name}.md"
  if nlm content source "$src_id" -o "$content_file" 2>/dev/null; then
    if [ -s "$content_file" ]; then
      echo "  [+] sources/$safe_name.md"
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
echo "  [.] Chat history export not supported by NotebookLM API"
mkdir -p "$OUTPUT_DIR/chat"
echo "[]" > "$OUTPUT_DIR/chat/index.json"

# --- Export notes ---
echo "  Exporting notes..."
NOTES_OUTPUT=$(nlm note list "$NOTEBOOK_ID" 2>&1)
if echo "$NOTES_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "$NOTES_OUTPUT" > "$OUTPUT_DIR/notes/index.json"
  NOTE_COUNT=$(echo "$NOTES_OUTPUT" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  echo "  [+] notes/index.json ($NOTE_COUNT notes)"
  echo "$NOTES_OUTPUT" | python3 -c "
import sys, json
notes = json.load(sys.stdin)
for n in notes:
    nid = n.get('id','unknown')
    title = n.get('title','untitled')
    content = n.get('content','')
    safe = ''.join(c if c.isalnum() or c in '._- ' else '_' for c in title)[:80]
    print(f'{safe}|||{content}')
" 2>/dev/null | while IFS='|||' read -r note_name note_content; do
    if [ -n "$note_name" ]; then
      echo "$note_content" > "$OUTPUT_DIR/notes/${note_name}.md"
      echo "  [+] notes/${note_name}.md"
    fi
  done
else
  echo "  [.] No notes found"
  echo "[]" > "$OUTPUT_DIR/notes/index.json"
fi

# --- Export studio artifacts ---
echo "  Exporting studio artifacts..."
ARTIFACTS=$(nlm list artifacts "$NOTEBOOK_ID" 2>/dev/null || echo "[]")
echo "$ARTIFACTS" > "$OUTPUT_DIR/studio/manifest.json"
ARTIFACT_COUNT=$(echo "$ARTIFACTS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
echo "  [+] studio/manifest.json ($ARTIFACT_COUNT artifacts)"

download_artifact() {
  local atype="$1" aid="$2" outpath="$3"
  if nlm download "$atype" "$NOTEBOOK_ID" --id "$aid" -o "$outpath" --no-progress 2>/dev/null; then
    if [ -f "$outpath" ] && [ -s "$outpath" ]; then
      local size=$(ls -lh "$outpath" | awk '{print $5}')
      echo "  [+] $outpath ($size)"
      return 0
    fi
  fi
  rm -f "$outpath"
  return 1
}

echo "$ARTIFACTS" | python3 -c "
import sys, json
artifacts = json.load(sys.stdin)
for a in artifacts:
    if a.get('status') == 'completed':
        print(a['id'] + '|' + a['type'])
" 2>/dev/null | while IFS='|' read -r art_id art_type; do
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
      echo "  [?] Unknown artifact type: $art_type ($art_id)"
      ;;
  esac
done

# --- Format conversion ---
if [[ "$FORMAT" != "notebooklm" ]]; then
  echo ""
  echo "Converting to $FORMAT format..."

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  case "$FORMAT" in
    obsidian)
      OBSIDIAN_DIR="$OUTPUT_DIR-obsidian"
      python3 "$SCRIPT_DIR/../lib/export_obsidian.py" \
        "$OUTPUT_DIR" "$OBSIDIAN_DIR"
      echo ""
      echo "Obsidian vault: $OBSIDIAN_DIR"
      ;;
    *)
      echo "Warning: Unknown format: $FORMAT (using default)"
      ;;
  esac
fi

# --- Summary ---
echo ""
echo "Export complete: $OUTPUT_DIR"
echo "  Metadata:  metadata.json"
echo "  Sources:   $SOURCE_COUNT"
echo "  Artifacts: $ARTIFACT_COUNT"
du -sh "$OUTPUT_DIR" | awk '{print "  Total size: " $1}'
