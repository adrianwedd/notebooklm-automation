#!/usr/bin/env python3
"""
Web search and source discovery for NotebookLM automation.
"""

import sys
import json
from typing import List, Dict
from ddgs import DDGS

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
