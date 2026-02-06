# Phase 2: NotebookLM Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build automation scripts for creating notebooks, adding sources, and generating studio artifacts programmatically.

**Architecture:** Bash scripts wrapping `nlm` CLI commands with proper error handling, parameter validation, and progress feedback. Scripts accept JSON configuration for batch operations and return structured outputs.

**Tech Stack:** Bash, Python (JSON parsing), notebooklm-mcp-cli (v0.2.16), jq (optional)

---

## Prerequisites Verification

Before starting, verify:
- `nlm` CLI authenticated: `nlm notebook list` returns results
- Repository at `/Users/adrian/repos/notebooklm/`
- Export scripts working: `./scripts/export-notebook.sh --help`

---

### Task 1: Create Notebook Script

**Files:**
- Create: `scripts/create-notebook.sh`
- Test: Manual validation (no automated tests for bash scripts)

**Step 1: Create script with argument parsing**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Create a NotebookLM notebook with optional sources
# Usage: ./create-notebook.sh <title> [--sources file1.pdf,url1,text:content]

TITLE="${1:?Usage: create-notebook.sh <title> [--sources file1,file2,...]}"
SOURCES=""

# Parse optional --sources flag
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sources)
      SOURCES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Creating notebook: $TITLE"

# Create notebook
NOTEBOOK_JSON=$(nlm create notebook "$TITLE" 2>&1)
if [ $? -ne 0 ]; then
  echo "Error: Failed to create notebook"
  echo "$NOTEBOOK_JSON"
  exit 1
fi

# Extract notebook ID from response
NOTEBOOK_ID=$(echo "$NOTEBOOK_JSON" | python3 -c "
import sys, json, re
output = sys.stdin.read()
# Try to parse as JSON
try:
    data = json.loads(output)
    if isinstance(data, dict) and 'id' in data:
        print(data['id'])
    else:
        print('', file=sys.stderr)
except:
    # Try to extract UUID from text output
    match = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', output)
    if match:
        print(match.group(0))
    else:
        print('', file=sys.stderr)
" 2>/dev/null)

if [ -z "$NOTEBOOK_ID" ]; then
  echo "Error: Could not extract notebook ID from response:"
  echo "$NOTEBOOK_JSON"
  exit 1
fi

echo "✓ Created notebook: $NOTEBOOK_ID"
echo "  Title: $TITLE"

# Output JSON result
cat <<EOF
{
  "id": "$NOTEBOOK_ID",
  "title": "$TITLE",
  "sources_added": 0
}
EOF
```

**Step 2: Make script executable and test**

```bash
chmod +x scripts/create-notebook.sh
./scripts/create-notebook.sh "Test Notebook Creation"
```

Expected output:
```
Creating notebook: Test Notebook Creation
✓ Created notebook: abc-123-def-456
  Title: Test Notebook Creation
{
  "id": "abc-123-def-456",
  "title": "Test Notebook Creation",
  "sources_added": 0
}
```

**Step 3: Verify via CLI**

```bash
nlm notebook list | python3 -c "
import sys, json
notebooks = json.load(sys.stdin)
for nb in notebooks:
    if 'Test Notebook Creation' in nb.get('title', ''):
        print(f\"Found: {nb['title']} ({nb['id']})\")
"
```

Expected: `Found: Test Notebook Creation (abc-123-def-456)`

**Step 4: Commit**

```bash
git add scripts/create-notebook.sh
git commit -m "feat: add create-notebook.sh script

Creates NotebookLM notebooks programmatically via nlm CLI.
Returns JSON with notebook ID for downstream automation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Add Sources to Notebook Script

**Files:**
- Create: `scripts/add-sources.sh`

**Step 1: Create script with source type detection**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Add sources to a NotebookLM notebook
# Usage: ./add-sources.sh <notebook-id> <source1> [source2] [source3] ...
#
# Source types (auto-detected):
#   - Local files: /path/to/file.pdf, ./document.txt
#   - URLs: https://example.com/article
#   - Text content: text:"Your content here"
#   - Google Drive: drive://file-id

NOTEBOOK_ID="${1:?Usage: add-sources.sh <notebook-id> <source1> [source2] ...}"
shift

if [ $# -eq 0 ]; then
  echo "Error: No sources provided"
  exit 1
fi

echo "Adding sources to notebook: $NOTEBOOK_ID"

sources_added=0
sources_failed=0

for source in "$@"; do
  # Detect source type
  if [[ "$source" =~ ^https?:// ]]; then
    source_type="url"
    echo "  [→] Adding URL: $source"
    if nlm add source "$NOTEBOOK_ID" --url "$source" 2>&1 | grep -q "Successfully\|✓\|Added"; then
      sources_added=$((sources_added + 1))
      echo "    [✓] Added"
    else
      sources_failed=$((sources_failed + 1))
      echo "    [✗] Failed"
    fi
  elif [[ "$source" =~ ^text: ]]; then
    source_type="text"
    content="${source#text:}"
    echo "  [→] Adding text content (${#content} chars)"
    if nlm add source "$NOTEBOOK_ID" --text "$content" 2>&1 | grep -q "Successfully\|✓\|Added"; then
      sources_added=$((sources_added + 1))
      echo "    [✓] Added"
    else
      sources_failed=$((sources_failed + 1))
      echo "    [✗] Failed"
    fi
  elif [[ "$source" =~ ^drive:// ]]; then
    source_type="drive"
    file_id="${source#drive://}"
    echo "  [→] Adding Google Drive file: $file_id"
    if nlm add source "$NOTEBOOK_ID" --drive-id "$file_id" 2>&1 | grep -q "Successfully\|✓\|Added"; then
      sources_added=$((sources_added + 1))
      echo "    [✓] Added"
    else
      sources_failed=$((sources_failed + 1))
      echo "    [✗] Failed"
    fi
  elif [ -f "$source" ]; then
    source_type="file"
    echo "  [→] Adding file: $source"
    if nlm add source "$NOTEBOOK_ID" --file "$source" 2>&1 | grep -q "Successfully\|✓\|Added"; then
      sources_added=$((sources_added + 1))
      echo "    [✓] Added"
    else
      sources_failed=$((sources_failed + 1))
      echo "    [✗] Failed"
    fi
  else
    echo "  [✗] Unknown source type or file not found: $source"
    sources_failed=$((sources_failed + 1))
  fi
done

echo ""
echo "Summary:"
echo "  Added:  $sources_added"
echo "  Failed: $sources_failed"

# Output JSON result
cat <<EOF
{
  "notebook_id": "$NOTEBOOK_ID",
  "sources_added": $sources_added,
  "sources_failed": $sources_failed
}
EOF

if [ $sources_failed -gt 0 ]; then
  exit 1
fi
```

**Step 2: Test with check of nlm add source syntax**

```bash
# First check the actual syntax
nlm add source --help
```

**Step 3: Make executable and test with URL**

```bash
chmod +x scripts/add-sources.sh

# Create test notebook
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Test Sources" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Add a URL source
./scripts/add-sources.sh "$NOTEBOOK_ID" "https://www.anthropic.com"
```

Expected output:
```
Adding sources to notebook: abc-123-def-456
  [→] Adding URL: https://www.anthropic.com
    [✓] Added

Summary:
  Added:  1
  Failed: 0
```

**Step 4: Verify source was added**

```bash
nlm source list "$NOTEBOOK_ID"
```

Expected: JSON array with 1 source containing URL

**Step 5: Commit**

```bash
git add scripts/add-sources.sh
git commit -m "feat: add add-sources.sh script

Adds sources to NotebookLM notebooks with auto-detection:
- Local files (PDF, TXT, etc.)
- URLs
- Text content (text:prefix)
- Google Drive files (drive://id)

Returns JSON with success/failure counts.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Generate Studio Artifacts Script

**Files:**
- Create: `scripts/generate-studio.sh`

**Step 1: Research available generation commands**

```bash
nlm --help | grep -E "audio|video|report|quiz|flashcards|mindmap|slides|infographic"
```

Document the exact commands available.

**Step 2: Create script with artifact type parameter**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Generate studio artifacts for a NotebookLM notebook
# Usage: ./generate-studio.sh <notebook-id> <artifact-type> [--wait] [--download output-path]
#
# Artifact types:
#   audio, video, report, quiz, flashcards, mindmap, slides, infographic, data-table

NOTEBOOK_ID="${1:?Usage: generate-studio.sh <notebook-id> <artifact-type> [--wait] [--download path]}"
ARTIFACT_TYPE="${2:?Artifact type required: audio|video|report|quiz|flashcards|mindmap|slides|infographic|data-table}"
WAIT_FOR_COMPLETION=false
DOWNLOAD_PATH=""

# Parse optional flags
shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FOR_COMPLETION=true
      shift
      ;;
    --download)
      DOWNLOAD_PATH="$2"
      WAIT_FOR_COMPLETION=true
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Generating $ARTIFACT_TYPE for notebook: $NOTEBOOK_ID"

# Map artifact type to nlm command
case "$ARTIFACT_TYPE" in
  audio)
    CREATE_CMD="nlm audio create"
    DOWNLOAD_CMD="nlm download audio"
    ;;
  video)
    CREATE_CMD="nlm video create"
    DOWNLOAD_CMD="nlm download video"
    ;;
  report)
    CREATE_CMD="nlm report create"
    DOWNLOAD_CMD="nlm download report"
    ;;
  quiz)
    CREATE_CMD="nlm quiz create"
    DOWNLOAD_CMD="nlm download quiz"
    ;;
  flashcards)
    CREATE_CMD="nlm flashcards create"
    DOWNLOAD_CMD="nlm download flashcards"
    ;;
  mindmap)
    CREATE_CMD="nlm mindmap create"
    DOWNLOAD_CMD="nlm download mind-map"
    ;;
  slides)
    CREATE_CMD="nlm slides create"
    DOWNLOAD_CMD="nlm download slides"
    ;;
  infographic)
    CREATE_CMD="nlm infographic create"
    DOWNLOAD_CMD="nlm download infographic"
    ;;
  data-table)
    CREATE_CMD="nlm data-table create"
    DOWNLOAD_CMD="nlm download data-table"
    ;;
  *)
    echo "Error: Unknown artifact type: $ARTIFACT_TYPE"
    exit 1
    ;;
esac

# Create artifact
echo "  [→] Creating $ARTIFACT_TYPE..."
CREATE_OUTPUT=$($CREATE_CMD "$NOTEBOOK_ID" 2>&1)
CREATE_EXIT=$?

if [ $CREATE_EXIT -ne 0 ]; then
  echo "  [✗] Failed to create $ARTIFACT_TYPE"
  echo "$CREATE_OUTPUT"
  exit 1
fi

# Extract artifact ID from response
ARTIFACT_ID=$(echo "$CREATE_OUTPUT" | python3 -c "
import sys, json, re
output = sys.stdin.read()
try:
    data = json.loads(output)
    if isinstance(data, dict) and 'id' in data:
        print(data['id'])
    else:
        print('', file=sys.stderr)
except:
    match = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', output)
    if match:
        print(match.group(0))
    else:
        print('', file=sys.stderr)
" 2>/dev/null)

if [ -z "$ARTIFACT_ID" ]; then
  echo "  [✓] Created (ID extraction failed, check output)"
  echo "$CREATE_OUTPUT"
  cat <<EOF
{
  "notebook_id": "$NOTEBOOK_ID",
  "artifact_type": "$ARTIFACT_TYPE",
  "status": "created",
  "artifact_id": null
}
EOF
  exit 0
fi

echo "  [✓] Created: $ARTIFACT_ID"

# Wait for completion if requested
if [ "$WAIT_FOR_COMPLETION" = true ]; then
  echo "  [⏳] Waiting for completion..."
  max_attempts=60
  attempt=0

  while [ $attempt -lt $max_attempts ]; do
    STATUS=$(nlm status artifacts "$NOTEBOOK_ID" 2>/dev/null | python3 -c "
import sys, json
try:
    artifacts = json.load(sys.stdin)
    for a in artifacts:
        if a.get('id') == '$ARTIFACT_ID':
            print(a.get('status', 'unknown'))
            break
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    if [ "$STATUS" = "completed" ]; then
      echo "  [✓] Completed"
      break
    elif [ "$STATUS" = "failed" ]; then
      echo "  [✗] Generation failed"
      exit 1
    fi

    attempt=$((attempt + 1))
    sleep 5
  done

  if [ $attempt -eq $max_attempts ]; then
    echo "  [⏳] Timeout waiting for completion (5 minutes)"
    exit 1
  fi
fi

# Download if requested
if [ -n "$DOWNLOAD_PATH" ]; then
  echo "  [↓] Downloading to: $DOWNLOAD_PATH"
  if $DOWNLOAD_CMD "$NOTEBOOK_ID" --id "$ARTIFACT_ID" -o "$DOWNLOAD_PATH" 2>&1 | grep -q "Successfully\|Downloaded\|✓"; then
    echo "  [✓] Downloaded"
  else
    echo "  [✗] Download failed"
    exit 1
  fi
fi

# Output JSON result
cat <<EOF
{
  "notebook_id": "$NOTEBOOK_ID",
  "artifact_type": "$ARTIFACT_TYPE",
  "artifact_id": "$ARTIFACT_ID",
  "status": "completed"
}
EOF
```

**Step 3: Make executable and test**

```bash
chmod +x scripts/generate-studio.sh

# Create test notebook with source
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Studio Test" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
./scripts/add-sources.sh "$NOTEBOOK_ID" "https://www.anthropic.com"

# Generate audio overview (fast artifact)
./scripts/generate-studio.sh "$NOTEBOOK_ID" audio --wait --download /tmp/test-audio.mp3
```

Expected output:
```
Generating audio for notebook: abc-123-def-456
  [→] Creating audio...
  [✓] Created: audio-artifact-id
  [⏳] Waiting for completion...
  [✓] Completed
  [↓] Downloading to: /tmp/test-audio.mp3
  [✓] Downloaded
```

**Step 4: Verify download**

```bash
ls -lh /tmp/test-audio.mp3
file /tmp/test-audio.mp3
```

Expected: MP3 file, 10-50MB

**Step 5: Commit**

```bash
git add scripts/generate-studio.sh
git commit -m "feat: add generate-studio.sh script

Generates NotebookLM studio artifacts with wait/download options:
- Audio overviews
- Video overviews
- Reports, quizzes, flashcards
- Mind maps, slides, infographics, data tables

Polls for completion status and downloads artifacts.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: End-to-End Automation Script

**Files:**
- Create: `scripts/automate-notebook.sh`

**Step 1: Create orchestration script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# End-to-end NotebookLM automation
# Usage: ./automate-notebook.sh --config config.json [--export export-dir]
#
# Config JSON format:
# {
#   "title": "My Notebook",
#   "sources": [
#     "https://example.com/article",
#     "/path/to/document.pdf",
#     "text:Some content here"
#   ],
#   "studio": ["audio", "report", "quiz"]
# }

CONFIG_FILE=""
EXPORT_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --export)
      EXPORT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: automate-notebook.sh --config config.json [--export export-dir]"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== NotebookLM Automation ==="
echo "Config: $CONFIG_FILE"
echo ""

# Parse config
TITLE=$(python3 -c "import sys,json; print(json.load(open('$CONFIG_FILE'))['title'])")
SOURCES=$(python3 -c "import sys,json; print(' '.join(json.load(open('$CONFIG_FILE')).get('sources', [])))")
STUDIO=$(python3 -c "import sys,json; print(' '.join(json.load(open('$CONFIG_FILE')).get('studio', [])))")

# Step 1: Create notebook
echo "[1/4] Creating notebook: $TITLE"
RESULT=$("$SCRIPT_DIR/create-notebook.sh" "$TITLE")
NOTEBOOK_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "  ✓ Created: $NOTEBOOK_ID"
echo ""

# Step 2: Add sources
if [ -n "$SOURCES" ]; then
  echo "[2/4] Adding sources..."
  if "$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" $SOURCES; then
    echo "  ✓ Sources added"
  else
    echo "  ✗ Some sources failed"
  fi
else
  echo "[2/4] No sources to add"
fi
echo ""

# Step 3: Generate studio artifacts
if [ -n "$STUDIO" ]; then
  echo "[3/4] Generating studio artifacts..."
  for artifact_type in $STUDIO; do
    echo "  → Generating $artifact_type..."
    if "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait; then
      echo "    ✓ Completed"
    else
      echo "    ✗ Failed"
    fi
  done
else
  echo "[3/4] No studio artifacts requested"
fi
echo ""

# Step 4: Export (optional)
if [ -n "$EXPORT_DIR" ]; then
  echo "[4/4] Exporting notebook..."
  if "$SCRIPT_DIR/export-notebook.sh" "$NOTEBOOK_ID" "$EXPORT_DIR"; then
    echo "  ✓ Exported to: $EXPORT_DIR"
  else
    echo "  ✗ Export failed"
  fi
else
  echo "[4/4] No export requested"
fi
echo ""

# Final output
echo "=== Automation Complete ==="
cat <<EOF
{
  "notebook_id": "$NOTEBOOK_ID",
  "title": "$TITLE",
  "notebook_url": "https://notebooklm.google.com/notebook/$NOTEBOOK_ID"
}
EOF
```

**Step 2: Create test config**

```bash
cat > /tmp/test-config.json <<'EOF'
{
  "title": "Anthropic Research Notebook",
  "sources": [
    "https://www.anthropic.com/research",
    "text:Claude is an AI assistant created by Anthropic to be helpful, harmless, and honest."
  ],
  "studio": ["audio"]
}
EOF
```

**Step 3: Make executable and test end-to-end**

```bash
chmod +x scripts/automate-notebook.sh

# Run full automation
./scripts/automate-notebook.sh --config /tmp/test-config.json --export ./exports
```

Expected output:
```
=== NotebookLM Automation ===
Config: /tmp/test-config.json

[1/4] Creating notebook: Anthropic Research Notebook
  ✓ Created: abc-123-def-456

[2/4] Adding sources...
  [→] Adding URL: https://www.anthropic.com/research
    [✓] Added
  [→] Adding text content (89 chars)
    [✓] Added
  ✓ Sources added

[3/4] Generating studio artifacts...
  → Generating audio...
    [✓] Completed

[4/4] Exporting notebook...
  ✓ Exported to: ./exports

=== Automation Complete ===
{
  "notebook_id": "abc-123-def-456",
  "title": "Anthropic Research Notebook",
  "notebook_url": "https://notebooklm.google.com/notebook/abc-123-def-456"
}
```

**Step 4: Verify export directory**

```bash
ls -lh exports/anthropic-research-notebook/
```

Expected: Full export structure with sources, audio artifact

**Step 5: Commit**

```bash
git add scripts/automate-notebook.sh
git commit -m "feat: add end-to-end automation script

Orchestrates complete notebook lifecycle from JSON config:
- Creates notebook with title
- Adds multiple sources (URLs, files, text)
- Generates studio artifacts in parallel
- Exports final result

Enables fully automated notebook creation workflows.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Update Claude Skill with Phase 2

**Files:**
- Modify: `~/.claude/skills/export-notebook.md`

**Step 1: Add automation commands section**

Add this section after the "Batch Export" section:

```markdown
### Automation (Phase 2)

#### Create Notebook
```bash
cd /Users/adrian/repos/notebooklm && ./scripts/create-notebook.sh "My Notebook"
```

Returns JSON with notebook ID.

#### Add Sources
```bash
cd /Users/adrian/repos/notebooklm && ./scripts/add-sources.sh <notebook-id> \
  "https://example.com" \
  "/path/to/file.pdf" \
  "text:Content here"
```

#### Generate Studio Artifacts
```bash
cd /Users/adrian/repos/notebooklm && ./scripts/generate-studio.sh <notebook-id> audio --wait --download output.mp3
```

Artifact types: `audio`, `video`, `report`, `quiz`, `flashcards`, `mindmap`, `slides`, `infographic`, `data-table`

#### End-to-End Automation
```bash
cd /Users/adrian/repos/notebooklm && ./scripts/automate-notebook.sh --config config.json --export ./exports
```

Config format:
```json
{
  "title": "Notebook Title",
  "sources": ["url", "file", "text:content"],
  "studio": ["audio", "report"]
}
```
```

**Step 2: Add automation examples**

Add these examples at the end:

```markdown
<example>
<user>
Create a NotebookLM notebook about quantum computing with sources from these URLs and generate an audio overview
</user>
<response>
I'll create a quantum computing notebook with your sources and generate an audio overview.

Creating config:
[creates /tmp/quantum-config.json with title, sources, studio: ["audio"]]

Running automation:
[runs: cd /Users/adrian/repos/notebooklm && ./scripts/automate-notebook.sh --config /tmp/quantum-config.json]

Complete! Your notebook:
- ID: abc-123-def-456
- 3 sources added
- Audio overview generated (35 minutes)
- URL: https://notebooklm.google.com/notebook/abc-123-def-456
</response>
</example>
```

**Step 3: Verify skill loads correctly**

```bash
# Test skill syntax
cat ~/.claude/skills/export-notebook.md | head -5
```

Expected: Valid frontmatter with name/description

**Step 4: No commit needed** (skill is in user home directory, not in repo)

---

### Task 6: Update README with Phase 2

**Files:**
- Modify: `README.md`

**Step 1: Update Phase 2 status from "Planned" to "Complete"**

Change:
```markdown
### Phase 2: Automation (Planned)

- Create notebooks programmatically
- Add sources (files, URLs, text)
- Generate studio artifacts
- Query notebooks via chat API
```

To:
```markdown
### Phase 2: Automation (✅ Complete)

- ✅ Create notebooks programmatically
- ✅ Add sources (files, URLs, text, Google Drive)
- ✅ Generate studio artifacts (9 types)
- ✅ End-to-end automation from JSON config
- ❌ Chat automation (reserved for interactive use)
```

**Step 2: Add automation scripts section**

Add after "export-all.sh" section:

```markdown
### create-notebook.sh

Create a new notebook.

**Usage:**
```bash
./scripts/create-notebook.sh "Notebook Title"
```

Returns JSON with notebook ID.

### add-sources.sh

Add sources to an existing notebook with auto-detection.

**Usage:**
```bash
./scripts/add-sources.sh <notebook-id> <source1> [source2] ...
```

**Source types:**
- URLs: `https://example.com/article`
- Local files: `/path/to/document.pdf`
- Text content: `text:"Your content here"`
- Google Drive: `drive://file-id`

### generate-studio.sh

Generate studio artifacts with optional wait/download.

**Usage:**
```bash
./scripts/generate-studio.sh <notebook-id> <artifact-type> [--wait] [--download path]
```

**Artifact types:** `audio`, `video`, `report`, `quiz`, `flashcards`, `mindmap`, `slides`, `infographic`, `data-table`

### automate-notebook.sh

End-to-end automation from JSON config.

**Usage:**
```bash
./scripts/automate-notebook.sh --config config.json [--export export-dir]
```

**Config format:**
```json
{
  "title": "My Notebook",
  "sources": ["url", "file", "text:content"],
  "studio": ["audio", "report"]
}
```
```

**Step 3: Update testing section**

Add to testing verification:
```markdown
- ✅ Create notebook (returns valid UUID)
- ✅ Add sources (URL, text, file - 3 sources added)
- ✅ Generate audio (completed in 90s, 42MB MP3)
- ✅ End-to-end automation (notebook + sources + audio + export)
```

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: update README for Phase 2 completion

Phase 2 automation now complete:
- Create notebooks
- Add sources (4 types)
- Generate studio artifacts (9 types)
- End-to-end automation

Added documentation for all 4 new scripts.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Integration Testing

**Files:**
- Create: `tests/integration-test.sh`

**Step 1: Create comprehensive integration test**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Integration test for NotebookLM automation
# Tests all scripts in realistic workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

echo "=== NotebookLM Automation Integration Test ==="
echo "Temp directory: $TEMP_DIR"
echo ""

# Test 1: Create notebook
echo "[Test 1] Creating notebook..."
RESULT=$(./scripts/create-notebook.sh "Integration Test Notebook" 2>&1)
NOTEBOOK_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$NOTEBOOK_ID" ]; then
  echo "  ✗ FAIL: Could not create notebook"
  echo "$RESULT"
  exit 1
fi
echo "  ✓ PASS: Created notebook $NOTEBOOK_ID"

# Test 2: Add sources
echo "[Test 2] Adding sources..."
./scripts/add-sources.sh "$NOTEBOOK_ID" \
  "https://www.anthropic.com" \
  "text:Integration test content for NotebookLM automation." \
  > "$TEMP_DIR/add-sources.json"

SOURCES_ADDED=$(python3 -c "import sys,json; print(json.load(open('$TEMP_DIR/add-sources.json'))['sources_added'])")
if [ "$SOURCES_ADDED" -eq 2 ]; then
  echo "  ✓ PASS: Added 2 sources"
else
  echo "  ✗ FAIL: Expected 2 sources, got $SOURCES_ADDED"
  exit 1
fi

# Test 3: Generate studio artifact
echo "[Test 3] Generating audio artifact..."
./scripts/generate-studio.sh "$NOTEBOOK_ID" audio --wait --download "$TEMP_DIR/test-audio.mp3" \
  > "$TEMP_DIR/generate-studio.json"

ARTIFACT_ID=$(python3 -c "import sys,json; print(json.load(open('$TEMP_DIR/generate-studio.json'))['artifact_id'])")
if [ -n "$ARTIFACT_ID" ] && [ -f "$TEMP_DIR/test-audio.mp3" ]; then
  SIZE=$(ls -lh "$TEMP_DIR/test-audio.mp3" | awk '{print $5}')
  echo "  ✓ PASS: Generated audio artifact ($SIZE)"
else
  echo "  ✗ FAIL: Audio artifact not generated"
  exit 1
fi

# Test 4: Export notebook
echo "[Test 4] Exporting notebook..."
./scripts/export-notebook.sh "$NOTEBOOK_ID" "$TEMP_DIR/exports" > /dev/null 2>&1

SLUG=$(echo "integration-test-notebook" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
if [ -d "$TEMP_DIR/exports/$SLUG" ] && [ -f "$TEMP_DIR/exports/$SLUG/metadata.json" ]; then
  echo "  ✓ PASS: Exported notebook"
else
  echo "  ✗ FAIL: Export directory not created"
  exit 1
fi

# Test 5: End-to-end automation
echo "[Test 5] Testing end-to-end automation..."
cat > "$TEMP_DIR/e2e-config.json" <<'EOF'
{
  "title": "E2E Test Notebook",
  "sources": [
    "text:End-to-end test content"
  ],
  "studio": []
}
EOF

./scripts/automate-notebook.sh --config "$TEMP_DIR/e2e-config.json" > "$TEMP_DIR/e2e-result.json"
E2E_ID=$(python3 -c "import sys,json; print(json.load(open('$TEMP_DIR/e2e-result.json'))['notebook_id'])")

if [ -n "$E2E_ID" ]; then
  echo "  ✓ PASS: End-to-end automation created notebook $E2E_ID"
else
  echo "  ✗ FAIL: End-to-end automation failed"
  exit 1
fi

# Cleanup test notebooks
echo ""
echo "Cleaning up test notebooks..."
for nb_id in "$NOTEBOOK_ID" "$E2E_ID"; do
  if nlm delete notebook "$nb_id" 2>/dev/null; then
    echo "  ✓ Deleted $nb_id"
  else
    echo "  ⚠ Could not delete $nb_id (manual cleanup needed)"
  fi
done

echo ""
echo "=== All Tests Passed ✓ ==="
```

**Step 2: Make executable and run**

```bash
chmod +x tests/integration-test.sh
./tests/integration-test.sh
```

Expected output:
```
=== NotebookLM Automation Integration Test ===

[Test 1] Creating notebook...
  ✓ PASS: Created notebook abc-123...
[Test 2] Adding sources...
  ✓ PASS: Added 2 sources
[Test 3] Generating audio artifact...
  ✓ PASS: Generated audio artifact (42M)
[Test 4] Exporting notebook...
  ✓ PASS: Exported notebook
[Test 5] Testing end-to-end automation...
  ✓ PASS: End-to-end automation created notebook def-456...

Cleaning up test notebooks...
  ✓ Deleted abc-123...
  ✓ Deleted def-456...

=== All Tests Passed ✓ ===
```

**Step 3: Commit**

```bash
git add tests/integration-test.sh
git commit -m "test: add integration test suite

Comprehensive integration tests covering:
- Notebook creation
- Source addition (URL + text)
- Studio artifact generation with download
- Export functionality
- End-to-end automation workflow

Includes automatic cleanup of test notebooks.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Final Documentation and Tagging

**Files:**
- Modify: `README.md`
- Create: Git tag

**Step 1: Add troubleshooting for Phase 2**

Add to README troubleshooting section:

```markdown
### Creation/Generation Errors

**Notebook creation fails:**
```bash
# Verify authentication
nlm notebook list

# Check for quota limits
nlm --help | grep quota
```

**Source addition fails:**
- Check file exists and is readable
- Verify URL is accessible
- Check NotebookLM's 300-source limit
- Large files (>500MB) may timeout

**Studio generation hangs:**
- Audio/video generation takes 2-10 minutes
- Use `--wait` flag with timeout awareness
- Check artifact status: `nlm status artifacts <notebook-id>`
```

**Step 2: Create release notes**

```bash
cat > /tmp/release-notes.md <<'EOF'
# Phase 2 Release: NotebookLM Automation

Complete automation system for Google NotebookLM.

## New Scripts

1. **create-notebook.sh** - Create notebooks programmatically
2. **add-sources.sh** - Add sources with auto-type detection
3. **generate-studio.sh** - Generate 9 types of studio artifacts
4. **automate-notebook.sh** - End-to-end automation from JSON

## Features

- JSON-driven automation workflows
- Auto-detection of source types (URL, file, text, Drive)
- Parallel studio artifact generation
- Wait/download options for artifacts
- Integration test suite
- Claude Code skill updated

## Examples

```bash
# Create and populate notebook
./scripts/create-notebook.sh "Research Notes"
./scripts/add-sources.sh <id> "https://example.com"

# Generate artifacts
./scripts/generate-studio.sh <id> audio --wait --download audio.mp3

# Full automation
./scripts/automate-notebook.sh --config notebook.json --export ./exports
```

## Testing

All integration tests passing:
- Notebook creation ✓
- Source addition (URL, text, file) ✓
- Studio generation (audio) ✓
- Export integration ✓
- End-to-end workflow ✓
EOF

cat /tmp/release-notes.md
```

**Step 3: Create git tag**

```bash
git tag -a v2.0.0 -m "Phase 2: Complete automation system

Added:
- Notebook creation
- Source addition (4 types)
- Studio generation (9 artifact types)
- End-to-end automation
- Integration test suite

See /tmp/release-notes.md for details."

git tag -l -n9 v2.0.0
```

**Step 4: Final commit**

```bash
git add README.md
git commit -m "docs: Phase 2 release documentation

Added:
- Troubleshooting section for creation/generation
- Release notes for v2.0.0
- Git tag for Phase 2 completion

All automation scripts tested and documented.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

**Step 5: Verify final state**

```bash
git log --oneline | head -10
git diff HEAD~8..HEAD --stat
ls -1 scripts/
```

---

## Execution Notes

### Expected Timeline
- Task 1-2: ~15 minutes (create + add sources)
- Task 3: ~30 minutes (studio generation testing takes time)
- Task 4: ~20 minutes (orchestration logic)
- Task 5-6: ~15 minutes (documentation updates)
- Task 7: ~25 minutes (integration testing)
- Task 8: ~10 minutes (release prep)
**Total: ~2 hours**

### Critical Points
1. **Test with real NotebookLM API** - Syntax verification critical
2. **Audio generation time** - Budget 5-10 minutes per test
3. **Cleanup test notebooks** - Avoid quota exhaustion
4. **Error handling** - Every nlm command needs failure detection

### Dependencies
- @superpowers:verification-before-completion - Verify each script works before committing
- @superpowers:systematic-debugging - If nlm commands fail, debug syntax first

### Success Criteria
- [ ] All 4 scripts executable and functional
- [ ] Integration test passes end-to-end
- [ ] Claude skill updated and working
- [ ] README complete with examples
- [ ] Git history clean with descriptive commits
