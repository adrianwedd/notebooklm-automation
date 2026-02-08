#!/usr/bin/env python3
"""
Source deduplication for NotebookLM research automation.
"""

import sys
import json
from typing import List, Dict
from urllib.parse import urlparse, urlunparse, parse_qsl, urlencode

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
    tracking_params = {
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
        'ref', 'source'
    }
    query_items = parse_qsl(parsed.query, keep_blank_values=False)
    filtered_items = [
        (k, v) for (k, v) in query_items
        if (k not in tracking_params and not k.startswith('utm_'))
    ]
    query = urlencode(filtered_items, doseq=True)

    # Rebuild without tracking
    path = parsed.path.rstrip('/')

    normalized = urlunparse((
        parsed.scheme,
        netloc,
        path,
        parsed.params,
        query,
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
