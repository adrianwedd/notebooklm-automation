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
#
# Features:
# - Automatic cleanup of test notebooks
# - Progress tracking
# - Detailed pass/fail reporting
# - Temp directory isolation
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Array to track created notebooks for cleanup
CREATED_NOTEBOOKS=()

# Temp directory setup
TEMP_DIR=$(mktemp -d)
trap cleanup EXIT

# Cleanup function
cleanup() {
    local exit_code=$?

    echo ""
    echo -e "${BLUE}==== Cleanup ====${NC}"

    # Delete all test notebooks
    cleanup_notebooks

    # Remove temp directory
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}Removed temp directory: $TEMP_DIR${NC}"
    fi

    exit $exit_code
}

# Function to delete all test notebooks
cleanup_notebooks() {
    if [[ ${#CREATED_NOTEBOOKS[@]} -eq 0 ]]; then
        echo "No test notebooks to clean up"
        return
    fi

    echo "Cleaning up ${#CREATED_NOTEBOOKS[@]} test notebook(s)..."

    for notebook_id in "${CREATED_NOTEBOOKS[@]}"; do
        echo -n "  Deleting $notebook_id... "
        if nlm delete notebook "$notebook_id" -y >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}⚠ (may have been already deleted)${NC}"
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

# Find script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"

# Validate helper scripts exist
if [[ ! -x "$SCRIPT_DIR/create-notebook.sh" ]]; then
    error "Helper script not found: create-notebook.sh"
    exit 1
fi

section "Integration Test Suite"
info "Script directory: $SCRIPT_DIR"
info "Temp directory: $TEMP_DIR"

# ============================================================================
# Test 1: Create notebook with create-notebook.sh
# ============================================================================
section "Test 1: Notebook Creation"

TEST_TITLE="Integration Test $(date +%s)"
info "Creating notebook: $TEST_TITLE"

set +e
CREATE_OUTPUT=$("$SCRIPT_DIR/create-notebook.sh" "$TEST_TITLE" 2>&1)
CREATE_EXIT=$?
set -e

if [[ $CREATE_EXIT -ne 0 ]]; then
    test_failed "Test 1 - create-notebook.sh failed"
    echo "$CREATE_OUTPUT"
else
    # Extract notebook ID
    NOTEBOOK_ID=$(echo "$CREATE_OUTPUT" | python3 -c "
import sys, json, re
output = sys.stdin.read()
for line in output.split('\n'):
    line = line.strip()
    if line.startswith('{'):
        try:
            data = json.loads(line)
            if 'id' in data:
                print(data['id'])
                sys.exit(0)
        except:
            continue
match = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', output)
if match:
    print(match.group(0))
" 2>/dev/null)

    if [[ -z "$NOTEBOOK_ID" ]]; then
        test_failed "Test 1 - could not extract notebook ID"
        echo "$CREATE_OUTPUT"
    else
        CREATED_NOTEBOOKS+=("$NOTEBOOK_ID")
        test_passed "Test 1 - created notebook $NOTEBOOK_ID"
    fi
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

    set +e
    ADD_OUTPUT=$("$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" "$TEST_URL" "$TEST_TEXT" 2>&1)
    ADD_EXIT=$?
    set -e

    if [[ $ADD_EXIT -ne 0 ]]; then
        test_failed "Test 2 - add-sources.sh failed"
        echo "$ADD_OUTPUT"
    else
        # Parse JSON output
        LAST_LINE=$(echo "$ADD_OUTPUT" | tail -1)
        SOURCES_ADDED=$(echo "$LAST_LINE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_added', 0))" 2>/dev/null || echo "0")
        SOURCES_FAILED=$(echo "$LAST_LINE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_failed', 0))" 2>/dev/null || echo "0")

        if [[ "$SOURCES_ADDED" -eq 2 && "$SOURCES_FAILED" -eq 0 ]]; then
            test_passed "Test 2 - added 2 sources (URL + text)"
        else
            test_failed "Test 2 - expected 2 sources added, got $SOURCES_ADDED added, $SOURCES_FAILED failed"
        fi
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

    set +e
    STUDIO_OUTPUT=$("$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" quiz --wait 2>&1)
    STUDIO_EXIT=$?
    set -e

    if [[ $STUDIO_EXIT -ne 0 ]]; then
        test_failed "Test 3 - generate-studio.sh failed"
        echo "$STUDIO_OUTPUT"
    else
        # Parse JSON output
        LAST_LINE=$(echo "$STUDIO_OUTPUT" | tail -1)
        ARTIFACT_STATUS=$(echo "$LAST_LINE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status', 'unknown'))" 2>/dev/null || echo "unknown")

        if [[ "$ARTIFACT_STATUS" == "completed" ]]; then
            test_passed "Test 3 - generated quiz artifact successfully"
        else
            test_failed "Test 3 - quiz artifact status is '$ARTIFACT_STATUS' (expected 'completed')"
        fi
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
        set +e
        EXPORT_OUTPUT=$("$SCRIPT_DIR/export-notebook.sh" "$NOTEBOOK_ID" "$EXPORT_DIR" 2>&1)
        EXPORT_EXIT=$?
        set -e

        if [[ $EXPORT_EXIT -ne 0 ]]; then
            test_failed "Test 4 - export-notebook.sh failed"
            echo "$EXPORT_OUTPUT"
        else
            # Check if files were created
            FILE_COUNT=$(find "$EXPORT_DIR" -type f | wc -l | tr -d ' ')

            if [[ "$FILE_COUNT" -gt 0 ]]; then
                test_passed "Test 4 - exported notebook ($FILE_COUNT files)"
            else
                test_failed "Test 4 - no files were exported"
            fi
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

set +e
E2E_OUTPUT=$("$SCRIPT_DIR/automate-notebook.sh" --config "$CONFIG_FILE" 2>&1)
E2E_EXIT=$?
set -e

if [[ $E2E_EXIT -ne 0 ]]; then
    test_failed "Test 5 - automate-notebook.sh failed"
    echo "$E2E_OUTPUT"
else
    # Parse JSON output - extract complete JSON block from first { to last }
    JSON_OUTPUT=$(echo "$E2E_OUTPUT" | sed -n '/{/,/}/p')
    E2E_NOTEBOOK_ID=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('notebook_id', ''))" 2>/dev/null || echo "")
    E2E_SOURCES_ADDED=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sources_added', 0))" 2>/dev/null || echo "0")
    E2E_ARTIFACTS_CREATED=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('artifacts_created', 0))" 2>/dev/null || echo "0")

    # Track notebook for cleanup
    if [[ -n "$E2E_NOTEBOOK_ID" ]]; then
        CREATED_NOTEBOOKS+=("$E2E_NOTEBOOK_ID")
    fi

    if [[ -n "$E2E_NOTEBOOK_ID" && "$E2E_SOURCES_ADDED" -eq 2 && "$E2E_ARTIFACTS_CREATED" -eq 1 ]]; then
        test_passed "Test 5 - end-to-end automation (notebook: $E2E_NOTEBOOK_ID, sources: $E2E_SOURCES_ADDED, artifacts: $E2E_ARTIFACTS_CREATED)"
    else
        test_failed "Test 5 - unexpected results (notebook: $E2E_NOTEBOOK_ID, sources: $E2E_SOURCES_ADDED, artifacts: $E2E_ARTIFACTS_CREATED)"
    fi
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
