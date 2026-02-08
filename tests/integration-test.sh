#!/usr/bin/env bash
#
# integration-test.sh - Comprehensive integration tests for NotebookLM automation
#
# Tests the complete automation workflow:
# 1. Notebook creation with ID extraction
# 2. Source addition (URL + text)
# 3. Studio artifact generation (quiz)
# 4. Export functionality
# 5. End-to-end automation from config
# 6. Additional workflow coverage (generate-parallel, template rendering, help flags)
#
# Features:
# - Automatic cleanup of test notebooks
# - Progress tracking
# - Detailed pass/fail reporting
# - Temp directory isolation
#

set -euo pipefail

# shellcheck disable=SC2329
# Usage:
#   ./tests/integration-test.sh [options]
#
# Options:
#   --keep-notebooks    Do not delete created notebooks on exit
#   --run-export-all    Also run export-all.sh (WARNING: exports all notebooks)
#   -h, --help          Show this help
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Options
KEEP_NOTEBOOKS=false
RUN_EXPORT_ALL=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-notebooks)
            KEEP_NOTEBOOKS=true
            shift
            ;;
        --run-export-all)
            RUN_EXPORT_ALL=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: ./tests/integration-test.sh [options]

Options:
  --keep-notebooks    Do not delete created notebooks on exit
  --run-export-all    Also run export-all.sh (WARNING: exports all notebooks)
  -h, --help          Show this help
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Try --help for usage." >&2
            exit 2
            ;;
    esac
done

# Array to track created notebooks for cleanup
CREATED_NOTEBOOKS=()

# Temp directory setup
TEMP_DIR=$(mktemp -d -t nlm-integration.XXXXXX)
trap 'cleanup' EXIT

# Cleanup function
# shellcheck disable=SC2329
cleanup() {
    local exit_code=$?

    echo ""
    echo -e "${BLUE}==== Cleanup ====${NC}"

    # Delete all test notebooks
    if [[ "$KEEP_NOTEBOOKS" == true ]]; then
        warn "Keeping ${#CREATED_NOTEBOOKS[@]} created notebook(s) (--keep-notebooks)"
    else
        cleanup_notebooks
    fi

    # Remove temp directory
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}Removed temp directory: $TEMP_DIR${NC}"
    fi

    exit "$exit_code"
}

# Function to delete all test notebooks
# shellcheck disable=SC2329
cleanup_notebooks() {
    if [[ ${#CREATED_NOTEBOOKS[@]} -eq 0 ]]; then
        echo "No test notebooks to clean up"
        return
    fi

    echo "Cleaning up ${#CREATED_NOTEBOOKS[@]} test notebook(s)..."

    for notebook_id in "${CREATED_NOTEBOOKS[@]}"; do
        echo -n "  Deleting $notebook_id... "
        if nlm delete notebook "$notebook_id" -y >/dev/null 2>&1; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${YELLOW}WARN (may have been already deleted)${NC}"
        fi
    done
}

# Helper functions
info() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}$1${NC}"
}

section() {
    echo ""
    echo -e "${BLUE}==== $1 ====${NC}"
}

test_passed() {
    ((PASSED++))
    info "✓ PASSED: $1"
}

test_failed() {
    ((FAILED++))
    error "✗ FAILED: $1"
}

require_cmd() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        error "Missing required command: $name"
        exit 2
    fi
}

require_nlm_login() {
    if ! nlm login --status >/dev/null 2>&1; then
        error "NotebookLM CLI is not authenticated."
        echo "Run: nlm login" >&2
        exit 2
    fi
}

_safe_name() {
    local s="$1"
    s="${s//[^A-Za-z0-9_.-]/_}"
    printf '%s' "$s"
}

run_cmd_json() {
    local name="$1"
    shift

    local safe
    safe="$(_safe_name "$name")"

    local out="$TEMP_DIR/${safe}.out"
    local err="$TEMP_DIR/${safe}.err"

    set +e
    "$@" >"$out" 2>"$err"
    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
        echo "Command failed ($name) rc=$rc:" >&2
        printf '%q ' "$@" >&2
        echo "" >&2
        echo "stderr (first 200 lines):" >&2
        sed -n '1,200p' "$err" >&2 || true
        return "$rc"
    fi

    if ! python3 - "$out" <<'PY' >/dev/null 2>&1; then
import json
import sys
raw = open(sys.argv[1], "r", encoding="utf-8", errors="replace").read().strip()
obj = json.loads(raw)
assert isinstance(obj, dict)
PY
        echo "stdout did not parse as a JSON object for: $name" >&2
        echo "stdout (first 200 lines):" >&2
        sed -n '1,200p' "$out" >&2 || true
        echo "stderr (first 200 lines):" >&2
        sed -n '1,200p' "$err" >&2 || true
        return 1
    fi

    cat "$out"
}

# Find script directory
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

# Preconditions
require_cmd python3
require_cmd nlm
require_nlm_login

# Validate helper scripts exist
if [[ ! -x "$SCRIPT_DIR/create-notebook.sh" ]]; then
    error "Helper script not found: create-notebook.sh"
    exit 1
fi

section "Integration Test Suite"
info "Script directory: $SCRIPT_DIR"
info "Temp directory: $TEMP_DIR"
info "Options: keep_notebooks=$KEEP_NOTEBOOKS run_export_all=$RUN_EXPORT_ALL"

# ============================================================================
# Test 0: Quick CLI smoke (help and template rendering)
# ============================================================================
section "Test 0: CLI Smoke (Help + Templates)"

set +e
"$SCRIPT_DIR/generate-parallel.sh" --help >/dev/null 2>&1
HP1=$?
"$SCRIPT_DIR/create-from-template.sh" --help >/dev/null 2>&1
HP2=$?
"$SCRIPT_DIR/export-all.sh" --help >/dev/null 2>&1
HP3=$?
set -e

if [[ $HP1 -eq 0 && $HP2 -eq 0 && $HP3 -eq 0 ]]; then
    test_passed "Test 0 - help flags for key scripts"
else
    test_failed "Test 0 - help flags (generate-parallel/create-from-template/export-all)"
fi

# Validate templates render to valid JSON (does not call nlm).
set +e
NLM_ROOT="$ROOT_DIR" python3 - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["NLM_ROOT"])
templates = sorted((root / "templates").rglob("*.json"))
assert templates, "no templates found"

samples = {
    "guest_name": "Ada Lovelace",
    "topic": "computing",
    "presentation_topic": "test topic",
    "course_name": "Test Course",
    "paper_topic": "Test Paper",
}

for t in templates:
    data = json.loads(t.read_text(encoding="utf-8"))
    # naive variable detection: {{var}}
    needed = set()
    def scan(obj):
        if isinstance(obj, str):
            for part in obj.split("{{")[1:]:
                v = part.split("}}", 1)[0].strip()
                if v:
                    needed.add(v)
        elif isinstance(obj, list):
            for x in obj:
                scan(x)
        elif isinstance(obj, dict):
            for x in obj.values():
                scan(x)
    scan(data)

    args = ["python3", str(root / "lib" / "template_engine.py"), "render", str(t)]
    # stdin is variables JSON
    vars_json = {k: samples.get(k, "x") for k in needed}
    p = subprocess.run(args, input=json.dumps(vars_json).encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert p.returncode == 0, f"render failed: {t} stderr={p.stderr.decode('utf-8', 'replace')[:500]}"
    json.loads(p.stdout.decode("utf-8"))
PY
TEMPLATE_RC=$?
set -e

if [[ $TEMPLATE_RC -eq 0 ]]; then
    test_passed "Test 0 - templates render to valid JSON"
else
    test_failed "Test 0 - templates render to valid JSON"
fi

# ============================================================================
# Test 1: Create notebook with create-notebook.sh
# ============================================================================
section "Test 1: Notebook Creation"

TEST_TITLE="Integration Test $(date +%s)"
info "Creating notebook: $TEST_TITLE"

if CREATE_OUTPUT="$(run_cmd_json "Test 1 - create-notebook.sh" "$SCRIPT_DIR/create-notebook.sh" --quiet "$TEST_TITLE")"; then
    NOTEBOOK_ID="$(printf '%s' "$CREATE_OUTPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || true)"
    if [[ -n "${NOTEBOOK_ID:-}" ]]; then
        CREATED_NOTEBOOKS+=("$NOTEBOOK_ID")
        test_passed "Test 1 - created notebook $NOTEBOOK_ID"
    else
        test_failed "Test 1 - could not extract notebook ID"
    fi
else
    test_failed "Test 1 - create-notebook.sh failed"
fi

# ============================================================================
# Test 2: Add sources (URL + text) with add-sources.sh
# ============================================================================
section "Test 2: Source Addition"

if [[ -z "${NOTEBOOK_ID:-}" ]]; then
    test_failed "Test 2 - skipped (no notebook from Test 1)"
else
    info "Adding sources to notebook $NOTEBOOK_ID"

    TEST_URL="https://en.wikipedia.org/wiki/Artificial_intelligence"
    TEST_TEXT="text:This is a test source for integration testing. It contains basic information about AI and machine learning."

    if ADD_OUTPUT="$(run_cmd_json "Test 2 - add-sources.sh" "$SCRIPT_DIR/add-sources.sh" --quiet "$NOTEBOOK_ID" "$TEST_URL" "$TEST_TEXT")"; then
        SOURCES_ADDED=$(echo "$ADD_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_added', 0))" 2>/dev/null || echo "0")
        SOURCES_FAILED=$(echo "$ADD_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_failed', 0))" 2>/dev/null || echo "0")

        if [[ "$SOURCES_ADDED" -eq 2 && "$SOURCES_FAILED" -eq 0 ]]; then
            test_passed "Test 2 - added 2 sources (URL + text)"
        else
            test_failed "Test 2 - expected 2 sources added, got $SOURCES_ADDED added, $SOURCES_FAILED failed"
        fi
    else
        test_failed "Test 2 - add-sources.sh failed"
    fi
fi

# ============================================================================
# Test 3: Generate quiz artifact with generate-studio.sh --wait
# ============================================================================
section "Test 3: Studio Artifact Generation"

if [[ -z "${NOTEBOOK_ID:-}" ]]; then
    test_failed "Test 3 - skipped (no notebook from Test 1)"
else
    info "Generating quiz artifact for notebook $NOTEBOOK_ID"
    info "This will take ~1 minute, please wait..."

    if STUDIO_OUTPUT="$(run_cmd_json "Test 3 - generate-studio.sh (quiz --wait)" "$SCRIPT_DIR/generate-studio.sh" --quiet "$NOTEBOOK_ID" quiz --wait)"; then
        ARTIFACT_STATUS=$(echo "$STUDIO_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")

        if [[ "$ARTIFACT_STATUS" == "completed" ]]; then
            test_passed "Test 3 - generated quiz artifact successfully"
        else
            test_failed "Test 3 - quiz artifact status is '$ARTIFACT_STATUS' (expected 'completed')"
        fi
    else
        test_failed "Test 3 - generate-studio.sh failed"
    fi
fi

# ============================================================================
# Test 3b: Generate-parallel coverage (dry-run + live --wait)
# ============================================================================
section "Test 3b: Parallel Generation Coverage"

if [[ -z "${NOTEBOOK_ID:-}" ]]; then
    test_failed "Test 3b - skipped (no notebook from Test 1)"
else
    if run_cmd_json "Test 3b - generate-parallel.sh (--dry-run)" "$SCRIPT_DIR/generate-parallel.sh" --quiet --dry-run "$NOTEBOOK_ID" quiz,report --wait >/dev/null; then
        test_passed "Test 3b - generate-parallel.sh (--dry-run)"
    else
        test_failed "Test 3b - generate-parallel.sh (--dry-run)"
    fi
    if run_cmd_json "Test 3b - generate-parallel.sh (--wait)" "$SCRIPT_DIR/generate-parallel.sh" --quiet "$NOTEBOOK_ID" quiz --wait >/dev/null; then
        test_passed "Test 3b - generate-parallel.sh (--wait)"
    else
        test_failed "Test 3b - generate-parallel.sh (--wait)"
    fi
fi

# ============================================================================
# Test 4: Export notebook with export-notebook.sh
# ============================================================================
section "Test 4: Export Functionality"

if [[ -z "${NOTEBOOK_ID:-}" ]]; then
    test_failed "Test 4 - skipped (no notebook from Test 1)"
else
    EXPORT_DIR="$TEMP_DIR/export-test"
    mkdir -p "$EXPORT_DIR"

    info "Exporting notebook to $EXPORT_DIR"

    if [[ ! -x "$SCRIPT_DIR/export-notebook.sh" ]]; then
        test_failed "Test 4 - export-notebook.sh not found or not executable"
    else
        if ! run_cmd_json "Test 4 - export-notebook.sh" "$SCRIPT_DIR/export-notebook.sh" --quiet --id "$NOTEBOOK_ID" --output "$EXPORT_DIR" >/dev/null; then
            test_failed "Test 4 - export-notebook.sh failed"
        fi

        # Check if files were created
        FILE_COUNT=$(find "$EXPORT_DIR" -type f | wc -l | tr -d ' ')
        if [[ "$FILE_COUNT" -gt 0 ]]; then
            test_passed "Test 4 - exported notebook ($FILE_COUNT files)"
        else
            test_failed "Test 4 - no files were exported"
        fi
    fi
fi

# ============================================================================
# Test 5: End-to-end automation with automate-notebook.sh
# ============================================================================
section "Test 5: End-to-End Automation"

CONFIG_FILE="$TEMP_DIR/test-config.json"

# Create test config
cat > "$CONFIG_FILE" <<'EOF'
{
  "title": "E2E Test Notebook",
  "sources": [
    "https://en.wikipedia.org/wiki/Machine_learning",
    "text:Machine learning is a subset of AI that enables systems to learn from data."
  ],
  "studio": [
    {
      "type": "quiz"
    }
  ]
}
EOF

info "Created test config: $CONFIG_FILE"
info "Running end-to-end automation (this will take ~1-2 minutes)..."

if E2E_OUTPUT="$(run_cmd_json "Test 5 - automate-notebook.sh" "$SCRIPT_DIR/automate-notebook.sh" --quiet --config "$CONFIG_FILE")"; then
    # Parse JSON output (stdout is reserved for JSON)
    E2E_NOTEBOOK_ID=$(echo "$E2E_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('notebook_id', ''))" 2>/dev/null || echo "")
    E2E_SOURCES_ADDED=$(echo "$E2E_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_added', 0))" 2>/dev/null || echo "0")
    E2E_ARTIFACTS_CREATED=$(echo "$E2E_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('artifacts_created', 0))" 2>/dev/null || echo "0")

    # Track notebook for cleanup
    if [[ -n "$E2E_NOTEBOOK_ID" ]]; then
        CREATED_NOTEBOOKS+=("$E2E_NOTEBOOK_ID")
    fi

    if [[ -n "$E2E_NOTEBOOK_ID" && "$E2E_SOURCES_ADDED" -eq 2 && "$E2E_ARTIFACTS_CREATED" -eq 1 ]]; then
        test_passed "Test 5 - end-to-end automation (notebook: $E2E_NOTEBOOK_ID, sources: $E2E_SOURCES_ADDED, artifacts: $E2E_ARTIFACTS_CREATED)"
    else
        test_failed "Test 5 - unexpected results (notebook: $E2E_NOTEBOOK_ID, sources: $E2E_SOURCES_ADDED, artifacts: $E2E_ARTIFACTS_CREATED)"
    fi
else
    test_failed "Test 5 - automate-notebook.sh failed"
fi

# ============================================================================
# Optional: export-all.sh (dangerous; exports all notebooks)
# ============================================================================
section "Optional: export-all.sh"
if [[ "$RUN_EXPORT_ALL" == true ]]; then
    EXPORT_ALL_DIR="$TEMP_DIR/export-all"
    mkdir -p "$EXPORT_ALL_DIR"
    info "Running export-all.sh to $EXPORT_ALL_DIR (this exports ALL notebooks and may take a long time)"
    if run_cmd_json "Optional - export-all.sh" "$SCRIPT_DIR/export-all.sh" --quiet --output "$EXPORT_ALL_DIR" --continue-on-error >/dev/null; then
        test_passed "Optional - export-all.sh"
    else
        test_failed "Optional - export-all.sh"
    fi
else
    warn "Skipping export-all.sh (pass --run-export-all to enable)"
fi

# ============================================================================
# Summary
# ============================================================================
section "Test Summary"

TOTAL=$((PASSED + FAILED))

echo ""
echo "Total tests:  $TOTAL"
info "Passed:       $PASSED"

if [[ $FAILED -gt 0 ]]; then
    error "Failed:       $FAILED"
    echo ""
    error "INTEGRATION TESTS FAILED"
    exit 1
else
    echo "Failed:       $FAILED"
    echo ""
    info "ALL INTEGRATION TESTS PASSED!"
    exit 0
fi
