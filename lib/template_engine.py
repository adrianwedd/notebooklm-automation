#!/usr/bin/env python3
"""
Template engine for NotebookLM automation.
"""

import sys
import json
from pathlib import Path
from typing import Dict, Any, List

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

def list_templates(templates_dir: str = "templates") -> List[Dict[str, str]]:
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

def main() -> None:
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
