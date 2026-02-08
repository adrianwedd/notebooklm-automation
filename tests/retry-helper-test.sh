#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

failures=0

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "assert failed: $msg (expected=$expected actual=$actual)" >&2
    failures=$((failures + 1))
  fi
}

test_default_retries() {
  local attempts=0
  flaky() {
    attempts=$((attempts + 1))
    if [[ $attempts -lt 3 ]]; then
      return 7
    fi
    return 0
  }

  NLM_NO_RETRY=false NLM_RETRY_ATTEMPTS=3 NLM_RETRY_BASE_SLEEP=0 NLM_RETRY_MAX_SLEEP=0 retry_cmd "flaky default" flaky
  assert_eq "3" "$attempts" "default retries should try 3 times and succeed"
}

test_insufficient_retries_fails() {
  local attempts=0
  flaky() {
    attempts=$((attempts + 1))
    return 7
  }

  set +e
  NLM_NO_RETRY=false NLM_RETRY_ATTEMPTS=2 NLM_RETRY_BASE_SLEEP=0 NLM_RETRY_MAX_SLEEP=0 retry_cmd "flaky insufficient" flaky
  local rc=$?
  set -e

  assert_eq "7" "$rc" "should return last exit code when retries exhausted"
  assert_eq "2" "$attempts" "should try exactly NLM_RETRY_ATTEMPTS times"
}

test_no_retry() {
  local attempts=0
  flaky() {
    attempts=$((attempts + 1))
    return 7
  }

  set +e
  NLM_NO_RETRY=true NLM_RETRY_ATTEMPTS=5 NLM_RETRY_BASE_SLEEP=0 NLM_RETRY_MAX_SLEEP=0 retry_cmd "flaky no-retry" flaky
  local rc=$?
  set -e

  assert_eq "7" "$rc" "no-retry should return immediately"
  assert_eq "1" "$attempts" "no-retry should only try once"
}

test_default_retries
test_insufficient_retries_fails
test_no_retry

if [[ $failures -ne 0 ]]; then
  echo "retry helper tests failed: $failures" >&2
  exit 1
fi

echo "retry helper tests: ok"
