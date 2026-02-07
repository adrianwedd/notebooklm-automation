# Phase 3: Maximum Impact Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build high-impact automation features: parallel artifact generation, smart notebook creation, template system, and multi-format export capabilities.

**Architecture:** Extend existing bash scripts with parallel job control, add Python-based web scraping and AI integration for smart creation, create template engine with JSON-driven workflows, and implement format converters for export flexibility.

**Tech Stack:** Bash (parallel processing), Python 3 (web scraping, BeautifulSoup, requests), notebooklm-mcp-cli, jq (JSON processing), pandoc (format conversion)

---

## Prerequisites Verification

Before starting, verify:
- Phase 2 complete: All scripts working, integration tests passing (5/5)
- Repository at `/Users/adrian/repos/notebooklm/`
- Python 3 available with pip
- `nlm` CLI authenticated and working

---

## Phase 3 Overview

**Week 1:**
- Task 1-3: Parallel Artifact Generation (Days 1-3)
- Task 4-5: Smart Notebook Creation Foundation (Days 4-5)

**Week 2:**
- Task 6-7: Smart Notebook Creation Complete (Days 6-8)
- Task 8-9: Template System (Days 9-11)
- Task 10-11: Export Format Options (Days 12-14)

---

### Task 1: Parallel Artifact Generation - Core Infrastructure

**Files:**
- Create: `scripts/generate-parallel.sh`

**Goal:** Generate multiple artifacts concurrently with proper job control and result aggregation.

**Step 1: Create parallel generation script skeleton**

Create `scripts/generate-parallel.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Parallel artifact generation for NotebookLM
# Usage: ./generate-parallel.sh <notebook-id> <type1> [type2] [type3] ...
#
# Examples:
#   ./generate-parallel.sh abc-123 audio quiz report
#   ./generate-parallel.sh abc-123 audio,quiz,report --wait --download ./artifacts

NOTEBOOK_ID="${1:?Usage: generate-parallel.sh <notebook-id> <types...> [--wait] [--download dir]}"
shift

# Parse artifact types and flags
ARTIFACT_TYPES=()
WAIT_FLAG=false
DOWNLOAD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FLAG=true
      shift
      ;;
    --download)
      DOWNLOAD_DIR="$2"
      WAIT_FLAG=true
      shift 2
      ;;
    --help)
      cat <<EOF
Usage: generate-parallel.sh <notebook-id> <types...> [options]

Generate multiple studio artifacts in parallel.

Arguments:
  notebook-id    Notebook ID
  types          Artifact types (space or comma-separated)
                 audio, video, report, quiz, flashcards, mindmap,
                 slides, infographic, data-table

Options:
  --wait              Wait for all artifacts to complete
  --download <dir>    Download all artifacts to directory (implies --wait)

Examples:
  # Generate 3 artifacts in parallel
  ./generate-parallel.sh abc-123 audio quiz report --wait

  # Generate and download
  ./generate-parallel.sh abc-123 audio,video --download ./artifacts
EOF
      exit 0
      ;;
    *)
      # Split comma-separated types
      IFS=',' read -ra TYPES <<< "$1"
      ARTIFACT_TYPES+=("${TYPES[@]}")
      shift
      ;;
  esac
done

if [ ${#ARTIFACT_TYPES[@]} -eq 0 ]; then
  echo "Error: No artifact types specified"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Parallel Artifact Generation ==="
echo "Notebook: $NOTEBOOK_ID"
echo "Artifacts: ${ARTIFACT_TYPES[*]}"
echo "Count: ${#ARTIFACT_TYPES[@]}"
echo ""

# Track background jobs
declare -a PIDS
declare -a TYPES_RUNNING
declare -a OUTPUT_FILES

# Generate artifacts in parallel
echo "Starting parallel generation..."
for artifact_type in "${ARTIFACT_TYPES[@]}"; do
  OUTPUT_FILE="/tmp/generate-${NOTEBOOK_ID}-${artifact_type}-$$.json"
  OUTPUT_FILES+=("$OUTPUT_FILE")
  TYPES_RUNNING+=("$artifact_type")

  echo "  Starting: $artifact_type"

  # Launch generate-studio.sh in background
  if [ "$WAIT_FLAG" = true ]; then
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait \
      > "$OUTPUT_FILE" 2>&1 &
  else
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" \
      > "$OUTPUT_FILE" 2>&1 &
  fi

  PIDS+=($!)
done

echo ""
echo "Launched ${#PIDS[@]} parallel jobs"
echo ""

# Wait for all jobs if requested
if [ "$WAIT_FLAG" = true ]; then
  echo "Waiting for completion..."
  echo ""

  SUCCESS_COUNT=0
  FAILED_COUNT=0

  for i in "${!PIDS[@]}"; do
    pid=${PIDS[$i]}
    artifact_type=${TYPES_RUNNING[$i]}
    output_file=${OUTPUT_FILES[$i]}

    echo "[$((i+1))/${#PIDS[@]}] Waiting for: $artifact_type (PID: $pid)"

    if wait "$pid"; then
      echo "    ✓ Completed successfully"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "    ✗ Failed (see $output_file)"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  done

  echo ""
  echo "=== Generation Complete ==="
  echo "Success: $SUCCESS_COUNT"
  echo "Failed:  $FAILED_COUNT"
  echo ""

  # Aggregate results
  echo "Results:"
  for i in "${!OUTPUT_FILES[@]}"; do
    artifact_type=${TYPES_RUNNING[$i]}
    output_file=${OUTPUT_FILES[$i]}

    if [ -f "$output_file" ]; then
      # Extract artifact_id from JSON output
      ARTIFACT_ID=$(tail -5 "$output_file" | python3 -c "
import sys, json
try:
    for line in sys.stdin:
        if line.strip().startswith('{'):
            data = json.loads(line)
            print(data.get('artifact_id', 'unknown'))
            break
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

      echo "  $artifact_type: $ARTIFACT_ID"
    fi
  done

  # Download if requested
  if [ -n "$DOWNLOAD_DIR" ]; then
    echo ""
    echo "Downloading artifacts to: $DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    for artifact_type in "${TYPES_RUNNING[@]}"; do
      echo "  Downloading: $artifact_type"
      # Note: Download logic depends on nlm CLI support
      # This is a placeholder - actual download may not work for all types
      nlm download "$artifact_type" "$NOTEBOOK_ID" \
        -o "$DOWNLOAD_DIR/${artifact_type}" 2>/dev/null || \
        echo "    (download not supported for $artifact_type)"
    done
  fi

  # Cleanup temp files
  for output_file in "${OUTPUT_FILES[@]}"; do
    rm -f "$output_file"
  done

  exit $FAILED_COUNT
else
  echo "Background jobs launched (not waiting)"
  echo "Job PIDs: ${PIDS[*]}"
  echo ""
  echo "Monitor with: jobs -l"
  echo "Wait for all: wait ${PIDS[*]}"
fi
```

**Step 2: Make executable**

```bash
chmod +x scripts/generate-parallel.sh
```

**Step 3: Test with dry run (no wait)**

```bash
# Create test notebook
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Parallel Test" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Test content for parallel generation"

# Test parallel launch (don't wait)
./scripts/generate-parallel.sh "$NOTEBOOK_ID" quiz flashcards

# Check jobs
jobs -l
```

Expected: Two background jobs launched

**Step 4: Test with wait flag**

```bash
# Test with wait
./scripts/generate-parallel.sh "$NOTEBOOK_ID" quiz flashcards --wait
```

Expected: Both artifacts complete, summary shows 2 success

**Step 5: Cleanup and commit**

```bash
# Delete test notebook
nlm delete notebook "$NOTEBOOK_ID" -y

git add scripts/generate-parallel.sh
git commit -m "feat: add parallel artifact generation

Generate multiple artifacts concurrently with job control.

Features:
- Background job management
- Result aggregation
- Success/failure tracking
- Optional wait for completion

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: Progress Monitoring for Parallel Generation

**Files:**
- Modify: `scripts/generate-parallel.sh`

**Goal:** Add real-time progress monitoring with status updates during parallel generation.

**Step 1: Add progress monitoring function**

Add after the PIDS declaration (around line 100):

```bash
# Progress monitoring function
monitor_progress() {
  local pids=("$@")
  local total=${#pids[@]}
  local completed=0

  while [ $completed -lt $total ]; do
    completed=0
    for pid in "${pids[@]}"; do
      if ! kill -0 "$pid" 2>/dev/null; then
        completed=$((completed + 1))
      fi
    done

    echo -ne "\rProgress: $completed/$total artifacts completed"
    sleep 2
  done

  echo "" # New line after progress
}
```

**Step 2: Integrate progress monitor**

Replace the simple wait loop with progress monitoring (around line 150):

```bash
# Wait for all jobs if requested
if [ "$WAIT_FLAG" = true ]; then
  echo "Waiting for completion..."
  echo ""

  # Monitor progress in background
  monitor_progress "${PIDS[@]}" &
  MONITOR_PID=$!

  SUCCESS_COUNT=0
  FAILED_COUNT=0

  # Wait for all jobs to complete
  for pid in "${PIDS[@]}"; do
    wait "$pid" || FAILED_COUNT=$((FAILED_COUNT + 1))
  done

  # Stop progress monitor
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true

  SUCCESS_COUNT=$(( ${#PIDS[@]} - FAILED_COUNT ))

  echo ""
  echo "=== Generation Complete ==="
  echo "Success: $SUCCESS_COUNT"
  echo "Failed:  $FAILED_COUNT"
  # ... rest of summary
```

**Step 3: Test progress monitoring**

```bash
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Progress Test" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Test content"

./scripts/generate-parallel.sh "$NOTEBOOK_ID" quiz flashcards --wait
```

Expected: See "Progress: X/2 artifacts completed" updating in real-time

**Step 4: Cleanup and commit**

```bash
nlm delete notebook "$NOTEBOOK_ID" -y

git add scripts/generate-parallel.sh
git commit -m "feat: add progress monitoring to parallel generation

Real-time progress updates during artifact generation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: Integration with automate-notebook.sh

**Files:**
- Modify: `scripts/automate-notebook.sh`

**Goal:** Add --parallel flag to automate-notebook.sh to use parallel generation.

**Step 1: Add --parallel flag parsing**

In automate-notebook.sh, add flag parsing (around line 85):

```bash
CONFIG_FILE=""
EXPORT_DIR=""
PARALLEL_FLAG=false

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
    --parallel)
      PARALLEL_FLAG=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done
```

**Step 2: Update help text**

Add to show_help function:

```bash
Options:
  --config <file>   JSON configuration file (required)
  --export <dir>    Export notebook after generation (optional)
  --parallel        Generate artifacts in parallel (faster)
```

**Step 3: Modify artifact generation logic**

Replace the sequential generation loop (around line 270) with:

```bash
# Step 3: Generate studio artifacts
STUDIO_COUNT=$(echo "$STUDIO_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
if [[ $STUDIO_COUNT -gt 0 ]]; then
  section "Phase 3: Generating Studio Artifacts"

  if [[ "$PARALLEL_FLAG" = true && $STUDIO_COUNT -gt 1 ]]; then
    info "Generating $STUDIO_COUNT artifacts in parallel..."

    # Extract artifact types
    ARTIFACT_TYPES=$(echo "$STUDIO_JSON" | python3 -c "
import sys, json
artifacts = json.load(sys.stdin)
types = [a.get('type') for a in artifacts]
print(' '.join(types))
")

    # Use parallel generation
    if "$SCRIPT_DIR/generate-parallel.sh" "$NOTEBOOK_ID" $ARTIFACT_TYPES --wait; then
      ARTIFACTS_CREATED=$STUDIO_COUNT
      info "All artifacts completed"
    else
      ARTIFACTS_FAILED=$?
      ARTIFACTS_CREATED=$((STUDIO_COUNT - ARTIFACTS_FAILED))
      warn "Some artifacts failed"
    fi
  else
    # Sequential generation (existing code)
    info "Generating $STUDIO_COUNT artifact(s) sequentially..."
    # ... existing sequential loop
  fi
else
  section "Phase 3: Generating Studio Artifacts"
  warn "No studio artifacts requested"
fi
```

**Step 4: Test parallel integration**

```bash
cat > /tmp/parallel-test.json <<'EOF'
{
  "title": "Parallel Integration Test",
  "sources": ["text:Test content for parallel generation"],
  "studio": [
    {"type": "quiz"},
    {"type": "flashcards"}
  ]
}
EOF

./scripts/automate-notebook.sh --config /tmp/parallel-test.json --parallel
```

Expected: Artifacts generate in parallel, faster completion

**Step 5: Commit**

```bash
git add scripts/automate-notebook.sh
git commit -m "feat: add parallel generation to automate-notebook.sh

Use --parallel flag for concurrent artifact generation.
Reduces total time for multiple artifacts.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Smart Notebook Creation - Web Search Foundation

**Files:**
- Create: `scripts/research-topic.sh`
- Create: `lib/web_search.py`

**Goal:** Create foundation for smart notebook creation with web search capabilities.

**Step 1: Install required Python packages**

Create requirements file:

```bash
cat > requirements-research.txt <<EOF
requests>=2.31.0
beautifulsoup4>=4.12.0
duckduckgo-search>=4.0.0
EOF

pip3 install -r requirements-research.txt
```

**Step 2: Create web search library**

Create `lib/web_search.py`:

```python
#!/usr/bin/env python3
"""
Web search and source discovery for NotebookLM automation.
"""

import sys
import json
from typing import List, Dict
from duckduckgo_search import DDGS

def search_web(query: str, max_results: int = 10) -> List[Dict[str, str]]:
    """
    Search the web using DuckDuckGo.

    Returns list of results with 'title', 'url', 'snippet'.
    """
    results = []
    try:
        with DDGS() as ddgs:
            for r in ddgs.text(query, max_results=max_results):
                results.append({
                    'title': r.get('title', ''),
                    'url': r.get('href', ''),
                    'snippet': r.get('body', '')
                })
    except Exception as e:
        print(f"Error searching: {e}", file=sys.stderr)

    return results

def filter_quality_sources(results: List[Dict], min_snippet_length: int = 50) -> List[Dict]:
    """
    Filter search results for quality sources.

    Criteria:
    - Has meaningful snippet
    - URL is not from low-quality domains
    - Title is descriptive
    """
    spam_domains = ['pinterest.com', 'instagram.com', 'facebook.com']

    filtered = []
    for r in results:
        # Skip spam domains
        if any(domain in r['url'] for domain in spam_domains):
            continue

        # Require minimum snippet length
        if len(r.get('snippet', '')) < min_snippet_length:
            continue

        # Require title
        if not r.get('title'):
            continue

        filtered.append(r)

    return filtered

def main():
    """CLI interface for web search."""
    if len(sys.argv) < 2:
        print("Usage: web_search.py <query> [max_results]")
        sys.exit(1)

    query = sys.argv[1]
    max_results = int(sys.argv[2]) if len(sys.argv) > 2 else 10

    results = search_web(query, max_results)
    filtered = filter_quality_sources(results)

    print(json.dumps(filtered, indent=2))

if __name__ == '__main__':
    main()
```

**Step 3: Make library executable**

```bash
chmod +x lib/web_search.py
```

**Step 4: Test web search**

```bash
python3 lib/web_search.py "quantum computing basics" 5
```

Expected: JSON array of 3-5 quality web results

**Step 5: Create research-topic.sh skeleton**

Create `scripts/research-topic.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Smart notebook creation from topic research
# Usage: ./research-topic.sh "<topic>" [--depth N] [--auto-generate types]

TOPIC="${1:?Usage: research-topic.sh <topic> [options]}"
shift

DEPTH=3
AUTO_GENERATE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)
      DEPTH="$2"
      shift 2
      ;;
    --auto-generate)
      AUTO_GENERATE="$2"
      shift 2
      ;;
    --help)
      cat <<EOF
Usage: research-topic.sh <topic> [options]

Automatically create a research notebook on a topic.

Arguments:
  topic          Topic to research (e.g., "quantum computing")

Options:
  --depth <N>           Number of sources to find (default: 3)
  --auto-generate <types>  Comma-separated artifact types to generate

Examples:
  # Basic research
  ./research-topic.sh "quantum computing"

  # Deep research with artifacts
  ./research-topic.sh "machine learning basics" --depth 10 \\
    --auto-generate quiz,summary
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "=== Smart Notebook Creation ==="
echo "Topic: $TOPIC"
echo "Depth: $DEPTH sources"
echo ""

# Step 1: Search for sources
echo "[1/3] Searching for sources..."
SOURCES_JSON=$(python3 "$SCRIPT_DIR/../lib/web_search.py" "$TOPIC" "$DEPTH")
SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

echo "  Found: $SOURCE_COUNT sources"

# Step 2: Create notebook with sources
echo "[2/3] Creating notebook..."
NOTEBOOK_TITLE="Research: $TOPIC"
NOTEBOOK_ID=$("$SCRIPT_DIR/create-notebook.sh" "$NOTEBOOK_TITLE" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

echo "  Created: $NOTEBOOK_ID"

# Add sources
echo "  Adding sources..."
SOURCE_URLS=$(echo "$SOURCES_JSON" | python3 -c "
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s['url'])
")

while IFS= read -r url; do
  echo "    Adding: $url"
  "$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" "$url" > /dev/null 2>&1 || \
    echo "      (failed, continuing)"
done <<< "$SOURCE_URLS"

# Step 3: Generate artifacts if requested
if [ -n "$AUTO_GENERATE" ]; then
  echo "[3/3] Generating artifacts: $AUTO_GENERATE"
  IFS=',' read -ra TYPES <<< "$AUTO_GENERATE"

  for artifact_type in "${TYPES[@]}"; do
    echo "  Generating: $artifact_type"
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait \
      > /dev/null 2>&1 || echo "    (failed)"
  done
else
  echo "[3/3] No artifacts requested"
fi

echo ""
echo "=== Research Complete ==="
echo "Notebook ID: $NOTEBOOK_ID"
echo "URL: https://notebooklm.google.com/notebook/$NOTEBOOK_ID"
```

**Step 6: Make executable and test**

```bash
chmod +x scripts/research-topic.sh

./scripts/research-topic.sh "quantum computing basics" --depth 3
```

Expected: Creates notebook with 3 web sources

**Step 7: Cleanup and commit**

```bash
# Note the notebook ID from output, then delete
nlm delete notebook <notebook-id> -y

git add lib/web_search.py scripts/research-topic.sh requirements-research.txt
git commit -m "feat: add smart notebook creation foundation

Web search integration for automated source discovery.

Features:
- DuckDuckGo web search
- Quality source filtering
- Automated notebook creation from topic

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Smart Creation - Multi-Source Integration

**Files:**
- Create: `lib/wikipedia_search.py`
- Modify: `scripts/research-topic.sh`

**Goal:** Add Wikipedia and academic source discovery.

**Step 1: Create Wikipedia search library**

Create `lib/wikipedia_search.py`:

```python
#!/usr/bin/env python3
"""
Wikipedia search for NotebookLM research automation.
"""

import sys
import json
import requests
from typing import List, Dict

WIKIPEDIA_API = "https://en.wikipedia.org/api/rest_v1"

def search_wikipedia(query: str, limit: int = 3) -> List[Dict[str, str]]:
    """
    Search Wikipedia for articles.

    Returns list with 'title' and 'url'.
    """
    try:
        # Search API
        search_url = f"https://en.wikipedia.org/w/api.php"
        params = {
            'action': 'opensearch',
            'search': query,
            'limit': limit,
            'format': 'json'
        }

        response = requests.get(search_url, params=params, timeout=10)
        response.raise_for_status()

        data = response.json()
        titles = data[1] if len(data) > 1 else []
        urls = data[3] if len(data) > 3 else []

        results = []
        for title, url in zip(titles, urls):
            results.append({
                'title': f"Wikipedia: {title}",
                'url': url,
                'source': 'wikipedia'
            })

        return results

    except Exception as e:
        print(f"Error searching Wikipedia: {e}", file=sys.stderr)
        return []

def main():
    """CLI interface."""
    if len(sys.argv) < 2:
        print("Usage: wikipedia_search.py <query> [limit]")
        sys.exit(1)

    query = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 3

    results = search_wikipedia(query, limit)
    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    main()
```

**Step 2: Add Wikipedia search to research-topic.sh**

Modify research-topic.sh to include Wikipedia sources (after web search):

```bash
# Step 1: Search for sources
echo "[1/3] Searching for sources..."

# Web search
echo "  Web search..."
WEB_SOURCES=$(python3 "$SCRIPT_DIR/../lib/web_search.py" "$TOPIC" "$((DEPTH / 2))")
WEB_COUNT=$(echo "$WEB_SOURCES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

# Wikipedia search
echo "  Wikipedia search..."
WIKI_SOURCES=$(python3 "$SCRIPT_DIR/../lib/wikipedia_search.py" "$TOPIC" 2)
WIKI_COUNT=$(echo "$WIKI_SOURCES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

# Combine sources
SOURCES_JSON=$(python3 -c "
import sys, json
web = $WEB_SOURCES
wiki = $WIKI_SOURCES
all_sources = web + wiki
print(json.dumps(all_sources[:$DEPTH]))  # Limit to depth
")

SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "  Found: $WEB_COUNT web + $WIKI_COUNT Wikipedia = $SOURCE_COUNT total sources"
```

**Step 3: Test multi-source search**

```bash
chmod +x lib/wikipedia_search.py

./scripts/research-topic.sh "artificial intelligence" --depth 5
```

Expected: Mix of web and Wikipedia sources

**Step 4: Commit**

```bash
git add lib/wikipedia_search.py scripts/research-topic.sh
git commit -m "feat: add Wikipedia integration to smart creation

Multi-source discovery: web + Wikipedia.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Smart Creation - Content Deduplication

**Files:**
- Create: `lib/deduplicate_sources.py`
- Modify: `scripts/research-topic.sh`

**Goal:** Prevent duplicate sources in notebooks through URL normalization and content similarity detection.

**Step 1: Create deduplication library**

Create `lib/deduplicate_sources.py`:

```python
#!/usr/bin/env python3
"""
Source deduplication for NotebookLM research automation.
"""

import sys
import json
from typing import List, Dict
from urllib.parse import urlparse, urlunparse

def normalize_url(url: str) -> str:
    """
    Normalize URLs for comparison.

    - Remove www prefix
    - Remove trailing slashes
    - Use lowercase
    - Remove common tracking parameters
    """
    parsed = urlparse(url.lower())

    # Remove www
    netloc = parsed.netloc
    if netloc.startswith('www.'):
        netloc = netloc[4:]

    # Remove tracking params
    tracking_params = ['utm_source', 'utm_medium', 'utm_campaign',
                      'utm_content', 'utm_term', 'ref', 'source']

    # Rebuild without tracking
    path = parsed.path.rstrip('/')

    normalized = urlunparse((
        parsed.scheme,
        netloc,
        path,
        parsed.params,
        '',  # Remove query string for now
        ''   # Remove fragment
    ))

    return normalized

def deduplicate_sources(sources: List[Dict]) -> List[Dict]:
    """
    Remove duplicate sources by normalized URL.

    Keeps first occurrence of each unique URL.
    """
    seen_urls = set()
    unique_sources = []

    for source in sources:
        url = source.get('url', '')
        if not url:
            continue

        normalized = normalize_url(url)

        if normalized not in seen_urls:
            seen_urls.add(normalized)
            unique_sources.append(source)

    return unique_sources

def main():
    """CLI interface for deduplication."""
    if len(sys.argv) < 2:
        print("Usage: deduplicate_sources.py <sources.json>")
        print("       cat sources.json | deduplicate_sources.py -")
        sys.exit(1)

    if sys.argv[1] == '-':
        sources = json.load(sys.stdin)
    else:
        with open(sys.argv[1], 'r') as f:
            sources = json.load(f)

    unique = deduplicate_sources(sources)

    print(json.dumps(unique, indent=2), file=sys.stdout)

    # Stats to stderr
    original_count = len(sources)
    unique_count = len(unique)
    duplicates = original_count - unique_count

    if duplicates > 0:
        print(f"Removed {duplicates} duplicate(s)", file=sys.stderr)

if __name__ == '__main__':
    main()
```

**Step 2: Integrate deduplication into research-topic.sh**

Modify the source combination section (around line 873):

```bash
# Combine sources
SOURCES_JSON=$(python3 <<'PYEOF'
import sys, json, os

web_data = os.environ['WEB_SOURCES_DATA']
wiki_data = os.environ['WIKI_SOURCES_DATA']
depth = int(os.environ['DEPTH_DATA'])

web = json.loads(web_data)
wiki = json.loads(wiki_data)
all_sources = web + wiki

# Limit to depth before deduplication
limited = all_sources[:depth * 2]  # Get extra for dedup

print(json.dumps(limited))
PYEOF
)

# Deduplicate
echo "  Deduplicating sources..."
SOURCES_JSON=$(echo "$SOURCES_JSON" | python3 "$SCRIPT_DIR/../lib/deduplicate_sources.py" -)

# Final trim to depth
SOURCES_JSON=$(echo "$SOURCES_JSON" | python3 -c "
import sys, json
sources = json.load(sys.stdin)
print(json.dumps(sources[:$DEPTH]))
")

SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "  Final: $SOURCE_COUNT unique sources"
```

**Step 3: Test deduplication**

```bash
# Create test data with duplicates
cat > /tmp/test-sources.json <<'EOF'
[
  {"url": "https://example.com/page", "title": "Example 1"},
  {"url": "https://www.example.com/page/", "title": "Example 2"},
  {"url": "https://example.com/page?utm_source=google", "title": "Example 3"},
  {"url": "https://different.com/page", "title": "Different"}
]
EOF

python3 lib/deduplicate_sources.py /tmp/test-sources.json
```

Expected: 2 sources (example.com and different.com), removed 2 duplicates

**Step 4: Test end-to-end**

```bash
chmod +x lib/deduplicate_sources.py

./scripts/research-topic.sh "machine learning" --depth 5
```

Expected: No duplicate URLs in created notebook

**Step 5: Commit**

```bash
git add lib/deduplicate_sources.py scripts/research-topic.sh
git commit -m "feat: add source deduplication to smart creation

URL normalization prevents duplicate sources.

Features:
- Normalize URLs (www, trailing slash, case)
- Remove tracking parameters
- Keep first occurrence

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Smart Creation - Complete Workflow Integration

**Files:**
- Modify: `scripts/research-topic.sh`
- Modify: `scripts/automate-notebook.sh`

**Goal:** Add smart creation as a first-class workflow option in automate-notebook.sh.

**Step 1: Add smart creation mode to automate-notebook.sh**

Add new config format support (after existing config parsing):

```bash
# Check for smart creation mode
SMART_MODE=$(echo "$CONFIG_JSON" | python3 -c "
import sys, json
try:
    config = json.load(sys.stdin)
    print(config.get('smart_creation', {}).get('enabled', 'false'))
except:
    print('false')
")

if [[ "$SMART_MODE" == "true" ]]; then
  info "Smart creation mode enabled"

  # Extract smart creation config
  SMART_TOPIC=$(echo "$CONFIG_JSON" | python3 -c "
import sys, json
config = json.load(sys.stdin)
print(config.get('smart_creation', {}).get('topic', ''))
")

  SMART_DEPTH=$(echo "$CONFIG_JSON" | python3 -c "
import sys, json
config = json.load(sys.stdin)
print(config.get('smart_creation', {}).get('depth', 5))
")

  if [[ -z "$SMART_TOPIC" ]]; then
    error "Smart creation enabled but no topic specified"
  fi

  section "Smart Creation: Researching '$SMART_TOPIC'"

  # Use research-topic.sh for source discovery
  info "Searching for sources (depth: $SMART_DEPTH)..."

  # Create temp file for research output
  RESEARCH_OUTPUT="/tmp/research-$$-output.json"

  # Run research (creates notebook and adds sources)
  "$SCRIPT_DIR/research-topic.sh" "$SMART_TOPIC" --depth "$SMART_DEPTH" \
    > "$RESEARCH_OUTPUT"

  # Extract notebook ID from research output
  NOTEBOOK_ID=$(grep "Notebook ID:" "$RESEARCH_OUTPUT" | awk '{print $NF}')

  if [[ -z "$NOTEBOOK_ID" ]]; then
    error "Failed to create smart notebook"
  fi

  info "Created notebook: $NOTEBOOK_ID"
  rm -f "$RESEARCH_OUTPUT"

  # Skip manual source addition (already added by research-topic.sh)
  SOURCES_COUNT=0
else
  # Normal mode: create notebook and add sources manually
  # ... existing code
fi
```

**Step 2: Update config JSON schema documentation**

Add to README.md (Configuration section):

```markdown
### Smart Creation Mode

Instead of manually specifying sources, let the automation research a topic:

```json
{
  "title": "Machine Learning Fundamentals",
  "smart_creation": {
    "enabled": true,
    "topic": "machine learning basics",
    "depth": 10
  },
  "studio": [
    {"type": "quiz"},
    {"type": "summary"}
  ]
}
```

The automation will:
1. Search web and Wikipedia for quality sources
2. Create notebook with discovered sources
3. Generate requested artifacts
```

**Step 3: Test smart creation in automate-notebook.sh**

```bash
cat > /tmp/smart-test.json <<'EOF'
{
  "title": "Test Smart Creation",
  "smart_creation": {
    "enabled": true,
    "topic": "quantum computing",
    "depth": 3
  },
  "studio": [
    {"type": "quiz"}
  ]
}
EOF

./scripts/automate-notebook.sh --config /tmp/smart-test.json
```

Expected: Creates notebook with researched sources, generates quiz

**Step 4: Test backward compatibility**

```bash
# Old format should still work
cat > /tmp/manual-test.json <<'EOF'
{
  "title": "Manual Test",
  "sources": ["text:Manual content"],
  "studio": []
}
EOF

./scripts/automate-notebook.sh --config /tmp/manual-test.json
```

Expected: Works as before

**Step 5: Commit**

```bash
git add scripts/automate-notebook.sh README.md
git commit -m "feat: integrate smart creation into automate-notebook.sh

Add smart_creation config option for automated research.

Features:
- Topic-based source discovery
- Web + Wikipedia integration
- Backward compatible with manual sources

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: Template System Foundation

**Files:**
- Create: `templates/`
- Create: `lib/template_engine.py`
- Create: `scripts/create-from-template.sh`

**Goal:** Create template system for pre-built notebook workflows.

**Step 1: Create template directory structure**

```bash
mkdir -p templates
mkdir -p templates/research
mkdir -p templates/learning
mkdir -p templates/content
```

**Step 2: Create template engine**

Create `lib/template_engine.py`:

```python
#!/usr/bin/env python3
"""
Template engine for NotebookLM automation.
"""

import sys
import json
from pathlib import Path
from typing import Dict, Any

def load_template(template_path: str) -> Dict[str, Any]:
    """Load template JSON file."""
    with open(template_path, 'r') as f:
        return json.load(f)

def interpolate_variables(template: Dict, variables: Dict[str, str]) -> Dict:
    """
    Replace {{variable}} placeholders in template.

    Supports nested dictionaries and lists.
    """
    def interpolate_value(value):
        if isinstance(value, str):
            # Replace all {{var}} with values
            for key, val in variables.items():
                placeholder = f"{{{{{key}}}}}"
                value = value.replace(placeholder, val)
            return value
        elif isinstance(value, dict):
            return {k: interpolate_value(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [interpolate_value(item) for item in value]
        else:
            return value

    return interpolate_value(template)

def list_templates(templates_dir: str = "templates") -> list:
    """List available templates."""
    templates = []
    templates_path = Path(templates_dir)

    if not templates_path.exists():
        return []

    for template_file in templates_path.rglob("*.json"):
        # Get relative path from templates dir
        rel_path = template_file.relative_to(templates_path)
        templates.append({
            'id': str(rel_path.with_suffix('')),
            'path': str(template_file),
            'category': rel_path.parts[0] if len(rel_path.parts) > 1 else 'general'
        })

    return templates

def main():
    """CLI interface."""
    if len(sys.argv) < 2:
        print("Usage: template_engine.py <command> [args]")
        print("")
        print("Commands:")
        print("  list                    List available templates")
        print("  render <template> <vars>  Render template with variables")
        sys.exit(1)

    command = sys.argv[1]

    if command == 'list':
        templates = list_templates()
        print(json.dumps(templates, indent=2))

    elif command == 'render':
        if len(sys.argv) < 3:
            print("Usage: template_engine.py render <template.json> [vars.json]")
            sys.exit(1)

        template_path = sys.argv[2]
        template = load_template(template_path)

        # Load variables from file or stdin
        if len(sys.argv) >= 4:
            with open(sys.argv[3], 'r') as f:
                variables = json.load(f)
        else:
            # Read from stdin if available
            if not sys.stdin.isatty():
                variables = json.load(sys.stdin)
            else:
                variables = {}

        # Render template
        rendered = interpolate_variables(template, variables)
        print(json.dumps(rendered, indent=2))

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

**Step 3: Create template selection script**

Create `scripts/create-from-template.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Create notebook from template
# Usage: ./create-from-template.sh <template-id> [variables...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

if [[ $# -lt 1 ]]; then
  echo "Usage: create-from-template.sh <template-id> [--var key=value ...]"
  echo ""
  echo "Available templates:"
  python3 "$SCRIPT_DIR/../lib/template_engine.py" list | \
    python3 -c "
import sys, json
templates = json.load(sys.stdin)
for t in templates:
    print(f\"  {t['id']:30} ({t['category']})\")
"
  exit 1
fi

TEMPLATE_ID="$1"
shift

# Parse variables
declare -A VARIABLES
while [[ $# -gt 0 ]]; do
  case "$1" in
    --var)
      # Parse key=value
      if [[ "$2" =~ ^([^=]+)=(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        VARIABLES[$key]="$value"
      else
        echo "Error: Invalid variable format: $2"
        echo "Expected: key=value"
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Build variables JSON
VARIABLES_JSON="{"
first=true
for key in "${!VARIABLES[@]}"; do
  if [ "$first" = false ]; then
    VARIABLES_JSON+=","
  fi
  first=false
  VARIABLES_JSON+="\"$key\":\"${VARIABLES[$key]}\""
done
VARIABLES_JSON+="}"

echo "=== Creating Notebook from Template ==="
echo "Template: $TEMPLATE_ID"
echo "Variables: $VARIABLES_JSON"
echo ""

# Find template file
TEMPLATE_FILE="$TEMPLATES_DIR/${TEMPLATE_ID}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template not found: $TEMPLATE_FILE"
  exit 1
fi

# Render template
echo "Rendering template..."
CONFIG_JSON=$(echo "$VARIABLES_JSON" | python3 "$SCRIPT_DIR/../lib/template_engine.py" render "$TEMPLATE_FILE")

# Save to temp file
TEMP_CONFIG="/tmp/template-config-$$.json"
echo "$CONFIG_JSON" > "$TEMP_CONFIG"

echo "Configuration:"
cat "$TEMP_CONFIG"
echo ""

# Create notebook
echo "Creating notebook..."
"$SCRIPT_DIR/automate-notebook.sh" --config "$TEMP_CONFIG"

# Cleanup
rm -f "$TEMP_CONFIG"
```

**Step 4: Make scripts executable**

```bash
chmod +x lib/template_engine.py
chmod +x scripts/create-from-template.sh
```

**Step 5: Test template engine**

```bash
# Test list command
python3 lib/template_engine.py list

# Test render with simple template
mkdir -p templates/test
cat > templates/test/simple.json <<'EOF'
{
  "title": "{{topic}} Study Guide",
  "sources": ["text:{{topic}} content"],
  "studio": [{"type": "quiz"}]
}
EOF

echo '{"topic": "Python"}' | python3 lib/template_engine.py render templates/test/simple.json
```

Expected: Rendered config with "Python Study Guide"

**Step 6: Commit**

```bash
git add templates/ lib/template_engine.py scripts/create-from-template.sh
git commit -m "feat: add template system foundation

JSON-driven templates with variable interpolation.

Features:
- Template discovery
- Variable substitution
- Category organization

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 9: Pre-Built Templates

**Files:**
- Create: `templates/research/academic-paper.json`
- Create: `templates/learning/course-notes.json`
- Create: `templates/content/podcast-prep.json`
- Create: `templates/content/presentation.json`

**Goal:** Create useful pre-built templates for common workflows.

**Step 1: Create academic research template**

Create `templates/research/academic-paper.json`:

```json
{
  "title": "Research: {{paper_topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{paper_topic}} academic research papers",
    "depth": 15
  },
  "studio": [
    {"type": "summary"},
    {"type": "mindmap"},
    {"type": "quiz"},
    {"type": "data-table"}
  ]
}
```

**Step 2: Create learning/course template**

Create `templates/learning/course-notes.json`:

```json
{
  "title": "{{course_name}} - Study Notes",
  "smart_creation": {
    "enabled": true,
    "topic": "{{course_name}} tutorial guide",
    "depth": 10
  },
  "studio": [
    {"type": "quiz"},
    {"type": "flashcards"},
    {"type": "summary"}
  ]
}
```

**Step 3: Create podcast prep template**

Create `templates/content/podcast-prep.json`:

```json
{
  "title": "Podcast Research: {{guest_name}} - {{topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{guest_name}} {{topic}}",
    "depth": 8
  },
  "studio": [
    {"type": "summary"},
    {"type": "quiz"}
  ]
}
```

**Step 4: Create presentation template**

Create `templates/content/presentation.json`:

```json
{
  "title": "Presentation: {{presentation_topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{presentation_topic}}",
    "depth": 12
  },
  "studio": [
    {"type": "slides"},
    {"type": "mindmap"},
    {"type": "summary"}
  ]
}
```

**Step 5: Test each template**

```bash
# Academic research
./scripts/create-from-template.sh research/academic-paper \
  --var paper_topic="quantum entanglement"

# Course notes
./scripts/create-from-template.sh learning/course-notes \
  --var course_name="Python Programming"

# Podcast prep
./scripts/create-from-template.sh content/podcast-prep \
  --var guest_name="Richard Feynman" \
  --var topic="physics education"

# Presentation
./scripts/create-from-template.sh content/presentation \
  --var presentation_topic="AI Safety"
```

Expected: Each creates notebook with appropriate sources and artifacts

**Step 6: Create template catalog**

Create `templates/README.md`:

```markdown
# NotebookLM Templates

Pre-built notebook workflows for common use cases.

## Research Templates

### academic-paper
Create comprehensive research notebook for academic topics.

**Variables:**
- `paper_topic`: Research topic

**Generates:**
- 15 academic sources (web + Wikipedia)
- Summary, mindmap, quiz, data table

**Example:**
```bash
./scripts/create-from-template.sh research/academic-paper \
  --var paper_topic="quantum computing"
```

## Learning Templates

### course-notes
Study guide for courses and tutorials.

**Variables:**
- `course_name`: Course or subject name

**Generates:**
- 10 learning sources
- Quiz, flashcards, summary

**Example:**
```bash
./scripts/create-from-template.sh learning/course-notes \
  --var course_name="Machine Learning"
```

## Content Creation Templates

### podcast-prep
Research for podcast interviews.

**Variables:**
- `guest_name`: Guest name
- `topic`: Discussion topic

**Generates:**
- 8 sources about guest and topic
- Summary, quiz

### presentation
Presentation research and slide generation.

**Variables:**
- `presentation_topic`: Presentation subject

**Generates:**
- 12 sources
- Slides, mindmap, summary
```

**Step 7: Commit**

```bash
git add templates/
git commit -m "feat: add pre-built templates

Four templates for common workflows.

Templates:
- Academic research (15 sources, 4 artifacts)
- Course notes (10 sources, 3 artifacts)
- Podcast prep (8 sources, 2 artifacts)
- Presentation (12 sources, 3 artifacts)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Export Format - Obsidian

**Files:**
- Create: `lib/export_obsidian.py`
- Modify: `scripts/export-notebook.sh`

**Goal:** Add Obsidian markdown export format.

**Step 1: Create Obsidian export library**

Create `lib/export_obsidian.py`:

```python
#!/usr/bin/env python3
"""
Export NotebookLM notebooks to Obsidian format.
"""

import sys
import json
from pathlib import Path
from datetime import datetime

def export_to_obsidian(notebook_data: dict, output_dir: str):
    """
    Export notebook to Obsidian vault format.

    Structure:
    - notebook-name/
      - README.md (overview with metadata)
      - Sources/
        - 01-source.md
        - 02-source.md
      - Artifacts/
        - quiz.md
        - summary.md
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    notebook_title = notebook_data.get('title', 'Untitled')

    # Create README with metadata
    readme_path = output_path / 'README.md'
    with open(readme_path, 'w') as f:
        f.write(f"# {notebook_title}\n\n")
        f.write(f"**Created:** {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
        f.write(f"**Notebook ID:** {notebook_data.get('id', 'unknown')}\n\n")

        # Add sources section
        sources = notebook_data.get('sources', [])
        if sources:
            f.write(f"## Sources ({len(sources)})\n\n")
            for i, source in enumerate(sources, 1):
                title = source.get('title', f'Source {i}')
                f.write(f"- [[Sources/{i:02d}-{sanitize_filename(title)}|{title}]]\n")
            f.write("\n")

        # Add artifacts section
        artifacts = notebook_data.get('artifacts', [])
        if artifacts:
            f.write(f"## Artifacts ({len(artifacts)})\n\n")
            for artifact in artifacts:
                artifact_type = artifact.get('type', 'unknown')
                f.write(f"- [[Artifacts/{artifact_type}]]\n")
            f.write("\n")

        # Add tags
        f.write("## Tags\n\n")
        f.write("#notebooklm #export\n")

    # Create Sources directory
    sources_dir = output_path / 'Sources'
    sources_dir.mkdir(exist_ok=True)

    for i, source in enumerate(sources, 1):
        title = source.get('title', f'Source {i}')
        filename = f"{i:02d}-{sanitize_filename(title)}.md"
        source_path = sources_dir / filename

        with open(source_path, 'w') as f:
            f.write(f"# {title}\n\n")

            # Add metadata
            if source.get('url'):
                f.write(f"**URL:** {source['url']}\n\n")

            # Add content if available
            content = source.get('content', '')
            if content:
                f.write("## Content\n\n")
                f.write(content)
                f.write("\n")

            # Add backlink
            f.write(f"\n---\n\n")
            f.write(f"[[README|↩ Back to {notebook_title}]]\n")

    # Create Artifacts directory
    artifacts_dir = output_path / 'Artifacts'
    artifacts_dir.mkdir(exist_ok=True)

    for artifact in artifacts:
        artifact_type = artifact.get('type', 'unknown')
        artifact_path = artifacts_dir / f"{artifact_type}.md"

        with open(artifact_path, 'w') as f:
            f.write(f"# {artifact_type.title()}\n\n")

            # Add content
            content = artifact.get('content', 'No content available')
            f.write(content)
            f.write("\n")

            # Add backlink
            f.write(f"\n---\n\n")
            f.write(f"[[README|↩ Back to {notebook_title}]]\n")

    print(f"Exported to Obsidian: {output_path}")
    return str(output_path)

def sanitize_filename(title: str) -> str:
    """Convert title to safe filename."""
    # Remove invalid chars
    safe = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_'))
    # Replace spaces with hyphens
    safe = safe.replace(' ', '-')
    # Lowercase and limit length
    return safe[:50].lower()

def main():
    """CLI interface."""
    if len(sys.argv) < 3:
        print("Usage: export_obsidian.py <notebook.json> <output-dir>")
        sys.exit(1)

    notebook_file = sys.argv[1]
    output_dir = sys.argv[2]

    with open(notebook_file, 'r') as f:
        notebook_data = json.load(f)

    export_to_obsidian(notebook_data, output_dir)

if __name__ == '__main__':
    main()
```

**Step 2: Add Obsidian export to export-notebook.sh**

Modify `scripts/export-notebook.sh` to add format option:

```bash
# Add format flag
FORMAT="notebooklm"  # default

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    # ... existing flags
  esac
done

# After export completes, convert format if needed
if [[ "$FORMAT" != "notebooklm" ]]; then
  echo "Converting to $FORMAT format..."

  case "$FORMAT" in
    obsidian)
      OBSIDIAN_DIR="$OUTPUT_DIR-obsidian"
      python3 "$SCRIPT_DIR/../lib/export_obsidian.py" \
        "$OUTPUT_DIR/notebook.json" "$OBSIDIAN_DIR"
      echo "Obsidian vault: $OBSIDIAN_DIR"
      ;;
    *)
      echo "Warning: Unknown format: $FORMAT (using default)"
      ;;
  esac
fi
```

**Step 3: Test Obsidian export**

```bash
chmod +x lib/export_obsidian.py

# Create test notebook
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Obsidian Test" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Test content for Obsidian export"

# Export to Obsidian
./scripts/export-notebook.sh "$NOTEBOOK_ID" /tmp/obsidian-test --format obsidian

# Verify structure
ls -la /tmp/obsidian-test-obsidian/
cat /tmp/obsidian-test-obsidian/README.md
```

Expected: Obsidian vault with README, Sources/, Artifacts/

**Step 4: Cleanup and commit**

```bash
nlm delete notebook "$NOTEBOOK_ID" -y
rm -rf /tmp/obsidian-test*

git add lib/export_obsidian.py scripts/export-notebook.sh
git commit -m "feat: add Obsidian export format

Export notebooks to Obsidian vault structure.

Features:
- Wikilink-style navigation
- Source and artifact organization
- Metadata frontmatter

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 11: Multi-Format Export Extensions

**Files:**
- Create: `lib/export_notion.py`
- Create: `lib/export_anki.py`
- Modify: `scripts/export-notebook.sh`

**Goal:** Add Notion and Anki export formats.

**Step 1: Create Notion export**

Create `lib/export_notion.py`:

```python
#!/usr/bin/env python3
"""
Export NotebookLM notebooks to Notion-compatible markdown.
"""

import sys
import json
from pathlib import Path
from datetime import datetime

def export_to_notion(notebook_data: dict, output_dir: str):
    """
    Export to Notion import format.

    Single markdown file with Notion-compatible formatting.
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    notebook_title = notebook_data.get('title', 'Untitled')
    notion_file = output_path / f"{sanitize_filename(notebook_title)}.md"

    with open(notion_file, 'w') as f:
        # Title
        f.write(f"# {notebook_title}\n\n")

        # Metadata as callout
        f.write("> **Metadata**\n")
        f.write(f"> Created: {datetime.now().strftime('%Y-%m-%d')}\n")
        f.write(f"> Notebook ID: {notebook_data.get('id', 'unknown')}\n\n")

        # Sources
        sources = notebook_data.get('sources', [])
        if sources:
            f.write(f"## Sources\n\n")
            for source in sources:
                title = source.get('title', 'Untitled Source')
                url = source.get('url', '')

                if url:
                    f.write(f"### [{title}]({url})\n\n")
                else:
                    f.write(f"### {title}\n\n")

                content = source.get('content', '')
                if content:
                    # Notion quote blocks
                    f.write("> " + content.replace('\n', '\n> ') + "\n\n")

        # Artifacts
        artifacts = notebook_data.get('artifacts', [])
        if artifacts:
            f.write(f"## Generated Artifacts\n\n")
            for artifact in artifacts:
                artifact_type = artifact.get('type', 'unknown')
                f.write(f"### {artifact_type.title()}\n\n")

                content = artifact.get('content', '')
                if content:
                    f.write(content + "\n\n")

                f.write("---\n\n")

    print(f"Exported to Notion: {notion_file}")
    return str(notion_file)

def sanitize_filename(title: str) -> str:
    """Convert title to safe filename."""
    safe = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_'))
    return safe.replace(' ', '-')[:50].lower()

def main():
    if len(sys.argv) < 3:
        print("Usage: export_notion.py <notebook.json> <output-dir>")
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        notebook_data = json.load(f)

    export_to_notion(notebook_data, sys.argv[2])

if __name__ == '__main__':
    main()
```

**Step 2: Create Anki export**

Create `lib/export_anki.py`:

```python
#!/usr/bin/env python3
"""
Export NotebookLM quiz/flashcards to Anki CSV format.
"""

import sys
import json
import csv
from pathlib import Path

def export_to_anki(notebook_data: dict, output_dir: str):
    """
    Export quiz and flashcards to Anki CSV.

    Format: Front,Back,Tags
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    notebook_title = notebook_data.get('title', 'Untitled')
    anki_file = output_path / f"{sanitize_filename(notebook_title)}-anki.csv"

    cards = []

    # Extract from artifacts
    artifacts = notebook_data.get('artifacts', [])
    for artifact in artifacts:
        artifact_type = artifact.get('type', '')

        if artifact_type == 'quiz':
            # Parse quiz questions
            questions = artifact.get('questions', [])
            for q in questions:
                front = q.get('question', '')
                back = q.get('answer', '')
                tags = f"notebooklm quiz {notebook_title}"

                if front and back:
                    cards.append((front, back, tags))

        elif artifact_type == 'flashcards':
            # Parse flashcards
            flashcards = artifact.get('cards', [])
            for card in flashcards:
                front = card.get('front', '')
                back = card.get('back', '')
                tags = f"notebooklm flashcard {notebook_title}"

                if front and back:
                    cards.append((front, back, tags))

    # Write CSV
    with open(anki_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['Front', 'Back', 'Tags'])
        writer.writerows(cards)

    print(f"Exported {len(cards)} cards to Anki: {anki_file}")
    return str(anki_file)

def sanitize_filename(title: str) -> str:
    safe = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_'))
    return safe.replace(' ', '-')[:50].lower()

def main():
    if len(sys.argv) < 3:
        print("Usage: export_anki.py <notebook.json> <output-dir>")
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        notebook_data = json.load(f)

    export_to_anki(notebook_data, sys.argv[2])

if __name__ == '__main__':
    main()
```

**Step 3: Integrate into export-notebook.sh**

Add to format conversion section:

```bash
case "$FORMAT" in
  obsidian)
    OBSIDIAN_DIR="$OUTPUT_DIR-obsidian"
    python3 "$SCRIPT_DIR/../lib/export_obsidian.py" \
      "$OUTPUT_DIR/notebook.json" "$OBSIDIAN_DIR"
    echo "Obsidian vault: $OBSIDIAN_DIR"
    ;;
  notion)
    NOTION_DIR="$OUTPUT_DIR-notion"
    python3 "$SCRIPT_DIR/../lib/export_notion.py" \
      "$OUTPUT_DIR/notebook.json" "$NOTION_DIR"
    echo "Notion file: $NOTION_DIR"
    ;;
  anki)
    ANKI_DIR="$OUTPUT_DIR-anki"
    python3 "$SCRIPT_DIR/../lib/export_anki.py" \
      "$OUTPUT_DIR/notebook.json" "$ANKI_DIR"
    echo "Anki CSV: $ANKI_DIR"
    ;;
  *)
    echo "Warning: Unknown format: $FORMAT (using default)"
    ;;
esac
```

**Step 4: Test all export formats**

```bash
chmod +x lib/export_notion.py lib/export_anki.py

# Create test notebook with quiz
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Export Test" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Export format test content"
./scripts/generate-studio.sh "$NOTEBOOK_ID" quiz --wait

# Test each format
./scripts/export-notebook.sh "$NOTEBOOK_ID" /tmp/test-obsidian --format obsidian
./scripts/export-notebook.sh "$NOTEBOOK_ID" /tmp/test-notion --format notion
./scripts/export-notebook.sh "$NOTEBOOK_ID" /tmp/test-anki --format anki

# Verify outputs
ls -la /tmp/test-*
```

Expected: Three different export formats created

**Step 5: Update documentation**

Add to README.md:

```markdown
### Export Formats

Export notebooks in multiple formats:

```bash
# Obsidian (vault structure)
./scripts/export-notebook.sh <notebook-id> ./output --format obsidian

# Notion (single markdown)
./scripts/export-notebook.sh <notebook-id> ./output --format notion

# Anki (flashcard CSV)
./scripts/export-notebook.sh <notebook-id> ./output --format anki
```

**Step 6: Cleanup and commit**

```bash
nlm delete notebook "$NOTEBOOK_ID" -y
rm -rf /tmp/test-*

git add lib/export_notion.py lib/export_anki.py scripts/export-notebook.sh README.md
git commit -m "feat: add Notion and Anki export formats

Multi-format export support.

Formats:
- Notion: Single markdown with callouts
- Anki: CSV for flashcard import

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Execution Handoff

**Plan complete!** This provides detailed implementation for all Phase 3 features.

### Implementation Approach

Choose one of these execution options:

**Option 1: Subagent-Driven (Same Session)**
- Stay in this session
- Fresh subagent per task with two-stage review
- Continuous progress with automatic review checkpoints
- **REQUIRED SUB-SKILL:** Use `superpowers:subagent-driven-development`

**Option 2: Parallel Session (Separate)**
- Open new session in this directory
- Batch execution with manual review checkpoints
- **REQUIRED SUB-SKILL:** New session uses `superpowers:executing-plans`

**Which approach would you prefer?**