#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - <<'PY'
import sys

sys.path.insert(0, ".")

from lib.web_search import filter_quality_sources  # type: ignore

results = [
    {"title": "Spam", "url": "https://pinterest.com/x", "snippet": "x" * 200},
    {"title": "", "url": "https://example.com/no-title", "snippet": "x" * 200},
    {"title": "Short", "url": "https://example.com/short", "snippet": "x" * 10},
    {"title": "Good A", "url": "https://example.com/a", "snippet": "x" * 200},
    {"title": "Good Sub", "url": "https://sub.example.com/b", "snippet": "x" * 200},
    {"title": "Denied", "url": "https://deny.example.com/c", "snippet": "x" * 200},
]

# Baseline: spam, missing title, short snippet filtered out.
filtered = filter_quality_sources(results, explain=False)
urls = {r["url"] for r in filtered}
assert "https://example.com/a" in urls
assert "https://sub.example.com/b" in urls
assert "https://pinterest.com/x" not in urls
assert "https://example.com/no-title" not in urls
assert "https://example.com/short" not in urls

# Allow list restricts to example.com (incl subdomains).
filtered = filter_quality_sources(results, allow_domains=["example.com"], explain=False)
urls = {r["url"] for r in filtered}
assert urls == {"https://example.com/a", "https://sub.example.com/b", "https://deny.example.com/c"}

# Deny list removes matching domains, including subdomains.
filtered = filter_quality_sources(
    results,
    allow_domains=["example.com"],
    deny_domains=["deny.example.com"],
    explain=False,
)
urls = {r["url"] for r in filtered}
assert urls == {"https://example.com/a", "https://sub.example.com/b"}

print("web search filter tests: ok")
PY

