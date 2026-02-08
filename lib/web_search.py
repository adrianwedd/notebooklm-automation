#!/usr/bin/env python3
"""
Web search and source discovery for NotebookLM automation.
"""

import sys
import json
from typing import List, Dict
from urllib.parse import urlparse

def _norm_netloc(url: str) -> str:
    netloc = urlparse(url).netloc.lower()
    if netloc.startswith("www."):
        netloc = netloc[4:]
    return netloc

def _domain_matches(netloc: str, domain: str) -> bool:
    domain = domain.lower().lstrip(".")
    return netloc == domain or netloc.endswith("." + domain)

def search_web(query: str, max_results: int = 10) -> List[Dict[str, str]]:
    """
    Search the web using DuckDuckGo.

    Returns list of results with 'title', 'url', 'snippet'.
    """
    results = []
    try:
        from ddgs import DDGS  # type: ignore
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

def filter_quality_sources(
    results: List[Dict],
    min_snippet_length: int = 50,
    allow_domains: List[str] = None,
    deny_domains: List[str] = None,
    explain: bool = False,
) -> List[Dict]:
    """
    Filter search results for quality sources.

    Criteria:
    - Has meaningful snippet
    - URL is not from low-quality domains
    - Title is descriptive
    """
    spam_domains = ['pinterest.com', 'instagram.com', 'facebook.com']
    allow_domains = allow_domains or []
    deny_domains = deny_domains or []

    filtered = []
    rejected_counts: Dict[str, int] = {}
    for r in results:
        url = r.get('url', '')
        netloc = _norm_netloc(url)
        if not netloc:
            rejected_counts["invalid_url"] = rejected_counts.get("invalid_url", 0) + 1
            continue

        # Skip spam domains
        if any(_domain_matches(netloc, domain) for domain in spam_domains):
            rejected_counts["spam_domain"] = rejected_counts.get("spam_domain", 0) + 1
            continue

        # Deny-list wins
        if deny_domains and any(_domain_matches(netloc, d) for d in deny_domains):
            rejected_counts["deny_domain"] = rejected_counts.get("deny_domain", 0) + 1
            continue

        # Allow-list (if provided) restricts matches
        if allow_domains and not any(_domain_matches(netloc, d) for d in allow_domains):
            rejected_counts["allow_domain_miss"] = rejected_counts.get("allow_domain_miss", 0) + 1
            continue

        # Require minimum snippet length
        if len(r.get('snippet', '')) < min_snippet_length:
            rejected_counts["snippet_too_short"] = rejected_counts.get("snippet_too_short", 0) + 1
            continue

        # Require title
        if not r.get('title'):
            rejected_counts["title_missing"] = rejected_counts.get("title_missing", 0) + 1
            continue

        filtered.append(r)

    if explain and rejected_counts:
        parts = [f"{k}={v}" for k, v in sorted(rejected_counts.items())]
        print("[web_search] filtered_out: " + " ".join(parts), file=sys.stderr)

    return filtered

def main():
    """CLI interface for web search."""
    if len(sys.argv) < 2:
        print("Usage: web_search.py <query> [max_results] [--allow-domains a,b] [--deny-domains x,y] [--mode scholarly] [--explain]", file=sys.stderr)
        sys.exit(1)

    args = sys.argv[1:]
    query = args[0]
    i = 1

    max_results = 10
    if i < len(args) and not args[i].startswith("--"):
        max_results = int(args[i])
        i += 1

    allow_domains: List[str] = []
    deny_domains: List[str] = []
    mode = ""
    explain = False

    while i < len(args):
        a = args[i]
        if a == "--allow-domains":
            i += 1
            allow_domains = [x.strip() for x in args[i].split(",") if x.strip()]
        elif a == "--deny-domains":
            i += 1
            deny_domains = [x.strip() for x in args[i].split(",") if x.strip()]
        elif a == "--mode":
            i += 1
            mode = args[i].strip()
        elif a == "--explain":
            explain = True
        else:
            print(f"Unknown option: {a}", file=sys.stderr)
            sys.exit(2)
        i += 1

    query_final = query
    if mode == "scholarly":
        # Heuristic: bias toward academic/public-sector sources and PDFs.
        query_final = f'{query} (site:edu OR site:ac.uk OR site:gov OR filetype:pdf)'

    results = search_web(query_final, max_results)
    filtered = filter_quality_sources(
        results,
        allow_domains=allow_domains,
        deny_domains=deny_domains,
        explain=explain,
    )

    print(json.dumps(filtered, indent=2))

if __name__ == '__main__':
    main()
