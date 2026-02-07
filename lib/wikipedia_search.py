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

        headers = {
            'User-Agent': 'NotebookLM-Research/1.0 (Educational Research Tool)'
        }
        response = requests.get(search_url, params=params, headers=headers, timeout=10)
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
