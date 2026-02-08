#!/usr/bin/env bash
set -euo pipefail

# Preflight diagnostics for notebooklm-automation.
# This script is read-only: it does not mutate NotebookLM state or credentials.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

JSON_OUTPUT=true
QUIET=false
VERBOSE=false

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() { ((PASS_COUNT++)); if [[ "$QUIET" != true ]]; then echo -e "${GREEN}PASS${NC} $*" >&2; fi }
warn() { ((WARN_COUNT++)); echo -e "${YELLOW}WARN${NC} $*" >&2; }
fail() { ((FAIL_COUNT++)); echo -e "${RED}FAIL${NC} $*" >&2; }

debug() { if [[ "$VERBOSE" == true && "$QUIET" != true ]]; then echo "Debug: $*" >&2; fi }

show_help() {
  cat <<EOF
Usage: doctor.sh [options]

Run preflight diagnostics for notebooklm-automation.

Options:
  --json         Emit JSON summary on stdout (default)
  --quiet        Suppress non-critical logs
  --verbose      Print additional diagnostics
  -h, --help     Show this help message

Checks:
  - Tooling: bash, python3, nlm (required), shellcheck (optional), jq (optional)
  - NotebookLM auth: nlm login status
  - Python deps for smart creation: requests, ddgs (optional, warns if missing)
  - Repo script permissions: scripts/*.sh and lib/*.py executable
  - JSON validity: templates/**/*.json
  - Network DNS: notebooklm.google.com (best-effort)

Examples:
  ./scripts/doctor.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
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
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

debug "verbose enabled"

echo -e "${BLUE}=== notebooklm-automation diagnostics ===${NC}" >&2
echo "Repo: $REPO_ROOT" >&2
echo "" >&2

check_cmd() {
  local name="$1"
  local required="$2" # true/false
  if command -v "$name" >/dev/null 2>&1; then
    pass "Found $name: $(command -v "$name")"
    return 0
  fi

  if [[ "$required" == "true" ]]; then
    fail "Missing $name (required)."
    return 1
  fi

  warn "Missing $name (optional)."
  return 0
}

echo "Tooling:" >&2
check_cmd bash true || true
check_cmd python3 true || true
check_cmd nlm true || true
check_cmd shellcheck false || true
check_cmd jq false || true
echo "" >&2

echo "NotebookLM auth:" >&2
if command -v nlm >/dev/null 2>&1; then
  # Prefer a non-interactive status check.
  if nlm login --status >/dev/null 2>&1; then
    pass "nlm login status OK"
  else
    fail "nlm not authenticated. Run: nlm login"
  fi
else
  fail "nlm missing; cannot check authentication"
fi
echo "" >&2

echo "Python deps (optional, for smart creation):" >&2
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import requests' >/dev/null 2>&1; then
    pass "Python module available: requests"
  else
    warn "Missing Python module: requests. Install: pip3 install -r requirements-research.txt"
  fi

  if python3 -c 'import ddgs' >/dev/null 2>&1; then
    pass "Python module available: ddgs"
  else
    warn "Missing Python module: ddgs. Install: pip3 install -r requirements-research.txt"
  fi
else
  fail "python3 missing; cannot check Python deps"
fi
echo "" >&2

echo "Permissions:" >&2
perm_fail=false
while IFS= read -r f; do
  if [[ ! -x "$f" ]]; then
    perm_fail=true
    fail "Not executable: ${f#"$REPO_ROOT"/}. Fix: chmod +x \"$f\""
  fi
done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name "*.sh" -print)

while IFS= read -r f; do
  if [[ ! -x "$f" ]]; then
    perm_fail=true
    fail "Not executable: ${f#"$REPO_ROOT"/}. Fix: chmod +x \"$f\""
  fi
done < <(find "$REPO_ROOT/lib" -maxdepth 1 -type f -name "*.py" -print)

if [[ "$perm_fail" == "false" ]]; then
  pass "All scripts are executable"
fi
echo "" >&2

echo "Template JSON validity:" >&2
json_fail=false
while IFS= read -r f; do
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1], "r", encoding="utf-8"))' "$f" >/dev/null 2>&1; then
    json_fail=true
    fail "Invalid JSON: ${f#"$REPO_ROOT"/}"
  fi
done < <(find "$REPO_ROOT/templates" -type f -name "*.json" -print)

if [[ "$json_fail" == "false" ]]; then
  pass "All templates are valid JSON"
fi
echo "" >&2

echo "Network (best-effort):" >&2
if python3 -c 'import socket; socket.gethostbyname("notebooklm.google.com")' >/dev/null 2>&1; then
  pass "DNS resolution OK: notebooklm.google.com"
else
  warn "DNS resolution failed for notebooklm.google.com (may be transient)."
fi
echo "" >&2

echo -e "${BLUE}=== Summary ===${NC}" >&2
echo "PASS: $PASS_COUNT" >&2
echo "WARN: $WARN_COUNT" >&2
echo "FAIL: $FAIL_COUNT" >&2

if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_PASS="$PASS_COUNT" NLM_WARN="$WARN_COUNT" NLM_FAIL="$FAIL_COUNT" python3 -c '
import json, os
fail = int(os.environ["NLM_FAIL"])
print(json.dumps({
  "pass": int(os.environ["NLM_PASS"]),
  "warn": int(os.environ["NLM_WARN"]),
  "fail": fail,
  "status": "fail" if fail > 0 else "ok",
}))'
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
