#!/usr/bin/env bash
#
# automate-notebook.sh - End-to-end NotebookLM automation from JSON config
#
# Usage:
#   automate-notebook.sh --config <file> [--export <dir>] [--parallel] [--help]
#
# Arguments:
#   --config <file>    Path to JSON config file (required)
#   --export <dir>     Export notebook to directory after completion (optional)
#   --parallel         Generate artifacts in parallel (faster)
#
# Config format:
#   {
#     "title": "Notebook Title",
#     "sources": ["https://example.com", "text:content", "drive://file-id"],
#     "studio": [
#       {"type": "quiz"},
#       {"type": "data-table", "description": "Compare prices"}
#     ]
#   }
#
# Output:
#   JSON object with: notebook_id, title, notebook_url, sources_added, sources_failed,
#                     artifacts_created, artifacts_failed
#
# Examples:
#   # Create notebook from config
#   ./automate-notebook.sh --config my-notebook.json
#
#   # Create and export
#   ./automate-notebook.sh --config my-notebook.json --export ./output
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

section() {
    echo -e "${BLUE}==== $1 ====${NC}" >&2
}

# Show help
show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parse arguments
CONFIG_FILE=""
EXPORT_DIR=""
PARALLEL_FLAG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --config)
            [[ -z "${2:-}" ]] && error "--config requires an argument"
            CONFIG_FILE="$2"
            shift 2
            ;;
        --export)
            [[ -z "${2:-}" ]] && error "--export requires an argument"
            EXPORT_DIR="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL_FLAG=true
            shift
            ;;
        *)
            error "Unknown argument: $1. Try --help for usage."
            ;;
    esac
done

# Validate arguments
[[ -z "$CONFIG_FILE" ]] && error "Missing required argument: --config <file>"
[[ ! -f "$CONFIG_FILE" ]] && error "Config file not found: $CONFIG_FILE"

# Validate JSON
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$CONFIG_FILE" 2>/dev/null || error "Invalid JSON in config file: $CONFIG_FILE"

info "Loading config from: $CONFIG_FILE"

# Extract config values using Python
CONFIG_DATA=$(python3 - "$CONFIG_FILE" <<'PYEOF'
import json
import sys

with open(sys.argv[1]) as f:
    config = json.load(f)

# Validate required fields
if 'title' not in config:
    print('ERROR:Missing required field: title', file=sys.stderr)
    sys.exit(1)

title = config['title']
sources = config.get('sources', [])
studio = config.get('studio', [])

# Validate types
if not isinstance(title, str) or not title.strip():
    print('ERROR:Title must be a non-empty string', file=sys.stderr)
    sys.exit(1)

if not isinstance(sources, list):
    print('ERROR:sources must be an array', file=sys.stderr)
    sys.exit(1)

if not isinstance(studio, list):
    print('ERROR:studio must be an array', file=sys.stderr)
    sys.exit(1)

# Output as JSON for bash to parse
output = {
    'title': title,
    'sources': sources,
    'studio': studio
}
print(json.dumps(output))
PYEOF
)

# Check for errors
if [[ "$CONFIG_DATA" == ERROR:* ]]; then
    error "${CONFIG_DATA#ERROR:}"
fi

# Extract individual fields
TITLE=$(echo "$CONFIG_DATA" | python3 -c 'import sys, json; print(json.load(sys.stdin)["title"])')
SOURCES_JSON=$(echo "$CONFIG_DATA" | python3 -c 'import sys, json; print(json.dumps(json.load(sys.stdin)["sources"]))')
STUDIO_JSON=$(echo "$CONFIG_DATA" | python3 -c 'import sys, json; print(json.dumps(json.load(sys.stdin)["studio"]))')

info "Config loaded successfully"
info "  Title: $TITLE"
info "  Sources: $(echo "$SOURCES_JSON" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))')"
info "  Studio artifacts: $(echo "$STUDIO_JSON" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))')"

# Find script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate helper scripts exist
[[ ! -x "$SCRIPT_DIR/create-notebook.sh" ]] && error "Helper script not found or not executable: create-notebook.sh"
[[ ! -x "$SCRIPT_DIR/add-sources.sh" ]] && error "Helper script not found or not executable: add-sources.sh"
[[ ! -x "$SCRIPT_DIR/generate-studio.sh" ]] && error "Helper script not found or not executable: generate-studio.sh"

# Check for smart creation mode
SMART_MODE=$(NLM_CONFIG="$CONFIG_FILE" python3 -c '
import os, json
try:
    with open(os.environ["NLM_CONFIG"]) as f:
        config = json.load(f)
    print(config.get("smart_creation", {}).get("enabled", "false"))
except Exception:
    print("false")
')

if [[ "$SMART_MODE" == "True" || "$SMART_MODE" == "true" ]]; then
  info "Smart creation mode enabled"

  # Extract smart creation config
  SMART_TOPIC=$(NLM_CONFIG="$CONFIG_FILE" python3 -c '
import os, json
with open(os.environ["NLM_CONFIG"]) as f:
    config = json.load(f)
print(config.get("smart_creation", {}).get("topic", ""))
')

  SMART_DEPTH=$(NLM_CONFIG="$CONFIG_FILE" python3 -c '
import os, json
with open(os.environ["NLM_CONFIG"]) as f:
    config = json.load(f)
print(config.get("smart_creation", {}).get("depth", 5))
')

  if [[ -z "$SMART_TOPIC" ]]; then
    error "Smart creation enabled but no topic specified"
  fi

  section "Smart Creation: Researching '$SMART_TOPIC'"

  # Use research-topic.sh for source discovery
  info "Searching for sources (depth: $SMART_DEPTH)..."

  # Create temp file for research output
  RESEARCH_OUTPUT=$(mktemp -t nlm-research.XXXXXX)
  trap 'rm -f "$RESEARCH_OUTPUT"' EXIT

  # Run research (creates notebook and adds sources)
  "$SCRIPT_DIR/research-topic.sh" "$SMART_TOPIC" --depth "$SMART_DEPTH" \
    2>&1 | tee "$RESEARCH_OUTPUT"

  # Extract notebook ID from research output
  NOTEBOOK_ID=$(grep "Notebook ID:" "$RESEARCH_OUTPUT" | awk '{print $NF}')

  if [[ -z "$NOTEBOOK_ID" ]]; then
    error "Failed to create smart notebook"
  fi

  info "Created notebook: $NOTEBOOK_ID"

  # Extract source count from research output
  SOURCES_ADDED=$(grep "Final:" "$RESEARCH_OUTPUT" 2>/dev/null | grep -o '[0-9]\+' | head -1 || echo "0")
  SOURCES_FAILED=0

  rm -f "$RESEARCH_OUTPUT"

  section "Phase 2: Sources Added by Smart Research"
  info "Sources added: $SOURCES_ADDED"
else
  # Normal mode: create notebook and add sources manually

  # Phase 1: Create notebook
  section "Phase 1: Creating Notebook"
  CREATE_OUTPUT=$("$SCRIPT_DIR/create-notebook.sh" "$TITLE" 2>&1) || error "Failed to create notebook"
  NOTEBOOK_ID=$(echo "$CREATE_OUTPUT" | python3 -c '
import sys, json, re
output = sys.stdin.read()

# Try to find JSON in the output
for line in output.split("\n"):
    line = line.strip()
    if line.startswith("{"):
        try:
            data = json.loads(line)
            if "id" in data:
                print(data["id"])
                sys.exit(0)
        except Exception:
            continue

# Fallback: try to extract UUID directly
match = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", output)
if match:
    print(match.group(0))
')

  [[ -z "$NOTEBOOK_ID" ]] && error "Failed to extract notebook ID from create output"

  info "Notebook created: $NOTEBOOK_ID"

  # Phase 2: Add sources
  section "Phase 2: Adding Sources"
  SOURCES_ADDED=0
  SOURCES_FAILED=0

  SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))')

  if [[ "$SOURCE_COUNT" -eq 0 ]]; then
    warn "No sources to add"
  else
    # Convert sources array to space-separated arguments for add-sources.sh
    # We need to properly quote each source
    ADD_SOURCES_CMD=("$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID")

    # Use Python to iterate sources and build command
    while IFS= read -r source; do
        [[ -n "$source" ]] && ADD_SOURCES_CMD+=("$source")
    done < <(echo "$SOURCES_JSON" | python3 -c 'import sys, json; sources=json.load(sys.stdin); [print(s) for s in sources]')

    # Execute add-sources.sh
    set +e
    ADD_OUTPUT=$("${ADD_SOURCES_CMD[@]}" 2>&1)
    ADD_EXIT=$?
    set -e
    if [[ $ADD_EXIT -ne 0 ]]; then
        warn "add-sources.sh exited with code $ADD_EXIT"
    fi

    # Parse results
    LAST_LINE=$(echo "$ADD_OUTPUT" | tail -1)
    if echo "$LAST_LINE" | python3 -c 'import sys, json; json.loads(sys.stdin.read())' 2>/dev/null; then
        SOURCES_ADDED=$(echo "$LAST_LINE" | python3 -c 'import sys, json; print(json.load(sys.stdin)["sources_added"])')
        SOURCES_FAILED=$(echo "$LAST_LINE" | python3 -c 'import sys, json; print(json.load(sys.stdin)["sources_failed"])')
    else
        warn "Could not parse add-sources output, assuming all failed"
        SOURCES_FAILED=$SOURCE_COUNT
    fi

    info "Sources added: $SOURCES_ADDED"
    if [[ $SOURCES_FAILED -gt 0 ]]; then
        warn "Sources failed: $SOURCES_FAILED"
    fi
  fi
fi

# Phase 3: Generate studio artifacts
section "Phase 3: Generating Studio Artifacts"
ARTIFACTS_CREATED=0
ARTIFACTS_FAILED=0

STUDIO_COUNT=$(echo "$STUDIO_JSON" | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))')

if [[ "$STUDIO_COUNT" -eq 0 ]]; then
    warn "No studio artifacts to generate"
else
    # Check if we should use parallel generation
    if [[ "$PARALLEL_FLAG" = true && "$STUDIO_COUNT" -gt 1 ]]; then
        info "Generating $STUDIO_COUNT artifacts in parallel..."

        # Validate parallel script exists
        if [[ ! -x "$SCRIPT_DIR/generate-parallel.sh" ]]; then
            warn "generate-parallel.sh not found, falling back to sequential generation"
            PARALLEL_FLAG=false
        else
            # Extract artifact types into array
            IFS=' ' read -ra ARTIFACT_TYPES <<< "$(echo "$STUDIO_JSON" | python3 -c '
import sys, json
artifacts = json.load(sys.stdin)
types = [a.get("type") for a in artifacts]
print(" ".join(types))
')"

            # Use parallel generation
            set +e
            "$SCRIPT_DIR/generate-parallel.sh" "$NOTEBOOK_ID" "${ARTIFACT_TYPES[@]}" --wait
            PARALLEL_EXIT=$?
            set -e

            if [[ $PARALLEL_EXIT -eq 0 ]]; then
                ARTIFACTS_CREATED=$STUDIO_COUNT
                info "All artifacts completed"
            else
                ARTIFACTS_FAILED=$PARALLEL_EXIT
                ARTIFACTS_CREATED=$((STUDIO_COUNT - ARTIFACTS_FAILED))
                warn "Some artifacts failed"
            fi
        fi
    fi

    # Sequential generation (either by choice or as fallback)
    if [[ "$PARALLEL_FLAG" = false || "$STUDIO_COUNT" -eq 1 ]]; then
        if [[ "$STUDIO_COUNT" -eq 1 ]]; then
            info "Generating 1 artifact sequentially..."
        else
            info "Generating $STUDIO_COUNT artifacts sequentially..."
        fi

        # Iterate through studio artifacts using Python
        # Pass STUDIO_JSON, NOTEBOOK_ID, and SCRIPT_DIR as environment variables
        STUDIO_RESULT=$(STUDIO_JSON_DATA="$STUDIO_JSON" NOTEBOOK_ID_DATA="$NOTEBOOK_ID" SCRIPT_DIR_DATA="$SCRIPT_DIR" python3 <<'PYEOF'
import json
import sys
import subprocess
import os

studio = json.loads(os.environ['STUDIO_JSON_DATA'])
notebook_id = os.environ['NOTEBOOK_ID_DATA']
script_dir = os.environ['SCRIPT_DIR_DATA']

artifacts_created = 0
artifacts_failed = 0

for idx, artifact in enumerate(studio, 1):
    if not isinstance(artifact, dict):
        print(f"Warning: Artifact {idx} is not a valid object, skipping", file=sys.stderr)
        artifacts_failed += 1
        continue

    artifact_type = artifact.get('type')
    if not artifact_type:
        print(f"Warning: Artifact {idx} missing 'type' field, skipping", file=sys.stderr)
        artifacts_failed += 1
        continue

    print(f"Generating {artifact_type} artifact ({idx}/{len(studio)})...", file=sys.stderr)

    # Build command
    cmd = [f"{script_dir}/generate-studio.sh", notebook_id, artifact_type, "--wait"]

    # Add description if present (required for data-table)
    if 'description' in artifact:
        cmd.extend(["--description", artifact['description']])

    # Execute
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)

        if result.returncode == 0:
            artifacts_created += 1
            print(f"✓ Created {artifact_type} artifact", file=sys.stderr)
        else:
            artifacts_failed += 1
            print(f"✗ Failed to create {artifact_type} artifact", file=sys.stderr)
            if result.stderr:
                print(f"  Error: {result.stderr.strip()}", file=sys.stderr)
    except Exception as e:
        artifacts_failed += 1
        print(f"✗ Exception creating {artifact_type}: {e}", file=sys.stderr)

# Output counts for bash to capture
print(f"{artifacts_created}|{artifacts_failed}")
PYEOF
)

        # Capture Python output - the last line contains the counts
        ARTIFACTS_CREATED=$(echo "$STUDIO_RESULT" | tail -1 | cut -d'|' -f1)
        ARTIFACTS_FAILED=$(echo "$STUDIO_RESULT" | tail -1 | cut -d'|' -f2)
    fi

    info "Artifacts created: $ARTIFACTS_CREATED"
    if [[ $ARTIFACTS_FAILED -gt 0 ]]; then
        warn "Artifacts failed: $ARTIFACTS_FAILED"
    fi
fi

# Phase 4: Export (optional)
if [[ -n "$EXPORT_DIR" ]]; then
    section "Phase 4: Exporting Notebook"

    if [[ ! -x "$SCRIPT_DIR/export-notebook.sh" ]]; then
        warn "export-notebook.sh not found, skipping export"
    else
        info "Exporting to: $EXPORT_DIR"
        "$SCRIPT_DIR/export-notebook.sh" "$NOTEBOOK_ID" "$EXPORT_DIR" 2>&1 || warn "Export failed"
        info "Export complete"
    fi
fi

# Generate notebook URL
NOTEBOOK_URL="https://notebooklm.google.com/notebook/${NOTEBOOK_ID}"

# Final output
section "Automation Complete"
info "Notebook ID: $NOTEBOOK_ID"
info "Notebook URL: $NOTEBOOK_URL"

# Output JSON summary
NOTEBOOK_ID_DATA="$NOTEBOOK_ID" TITLE_DATA="$TITLE" NOTEBOOK_URL_DATA="$NOTEBOOK_URL" SOURCES_ADDED_DATA="$SOURCES_ADDED" SOURCES_FAILED_DATA="$SOURCES_FAILED" ARTIFACTS_CREATED_DATA="$ARTIFACTS_CREATED" ARTIFACTS_FAILED_DATA="$ARTIFACTS_FAILED" python3 <<'PYEOF'
import json
import os

print(json.dumps({
    'notebook_id': os.environ['NOTEBOOK_ID_DATA'],
    'title': os.environ['TITLE_DATA'],
    'notebook_url': os.environ['NOTEBOOK_URL_DATA'],
    'sources_added': int(os.environ['SOURCES_ADDED_DATA']),
    'sources_failed': int(os.environ['SOURCES_FAILED_DATA']),
    'artifacts_created': int(os.environ['ARTIFACTS_CREATED_DATA']),
    'artifacts_failed': int(os.environ['ARTIFACTS_FAILED_DATA'])
}, indent=2))
PYEOF
