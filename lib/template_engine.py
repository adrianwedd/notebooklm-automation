#!/usr/bin/env python3
"""
Template engine for NotebookLM automation.
"""

import sys
import json
import re
from pathlib import Path
from typing import Dict, Any, List

_PLACEHOLDER_RE = re.compile(r"{{\s*([a-zA-Z0-9_]+)\s*}}")

def load_template(template_path: str) -> Dict[str, Any]:
    """Load template JSON file."""
    with open(template_path, 'r') as f:
        return json.load(f)

def _find_placeholders(value: Any) -> List[str]:
    """Collect placeholder variable names ({{var}}) from any nested JSON-like value."""
    found: List[str] = []
    if isinstance(value, str):
        found.extend(m.group(1) for m in _PLACEHOLDER_RE.finditer(value))
        return found
    if isinstance(value, dict):
        for v in value.values():
            found.extend(_find_placeholders(v))
        return found
    if isinstance(value, list):
        for v in value:
            found.extend(_find_placeholders(v))
        return found
    return found

def interpolate_variables(template: Any, variables: Dict[str, str]) -> Any:
    """
    Replace {{variable}} placeholders in template.

    Supports nested dictionaries and lists.
    """
    def interpolate_value(value):
        if isinstance(value, str):
            def _repl(match: re.Match) -> str:
                key = match.group(1)
                if key in variables:
                    return str(variables[key])
                # Leave unresolved placeholders intact for reporting.
                return match.group(0)

            return _PLACEHOLDER_RE.sub(_repl, value)
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

def _normalize_vars(obj: Any) -> Dict[str, str]:
    if obj is None:
        return {}
    if not isinstance(obj, dict):
        raise ValueError("template variables must be a JSON object")
    out: Dict[str, str] = {}
    for k, v in obj.items():
        if not isinstance(k, str):
            raise ValueError("template variable keys must be strings")
        if isinstance(v, (str, int, float, bool)) or v is None:
            out[k] = "" if v is None else str(v)
        else:
            raise ValueError(f"template variable '{k}' must be a string/number/bool/null")
    return out

def _extract_template_meta(template: Dict[str, Any]) -> Dict[str, Any]:
    """
    Optional metadata block. If present, it is removed from the rendered output.

    Supported keys:
      - required: list[str]
      - defaults: dict[str, str]
      - allow_unresolved: bool (if true, skip placeholder checks)
    """
    meta = template.get("_template")
    if not isinstance(meta, dict):
        return {}
    return meta

def _render_strict(template: Dict[str, Any], input_vars: Dict[str, str], allow_unresolved: bool) -> Dict[str, Any]:
    meta = _extract_template_meta(template)

    # Remove metadata from output config if present.
    if "_template" in template:
        template = dict(template)
        template.pop("_template", None)

    defaults = meta.get("defaults") if isinstance(meta.get("defaults"), dict) else {}
    variables = dict(_normalize_vars(defaults))
    variables.update(_normalize_vars(input_vars))

    required = meta.get("required") if isinstance(meta.get("required"), list) else None
    if required is None:
        required_set = set(_find_placeholders(template))
    else:
        required_set = set(x for x in required if isinstance(x, str))

    missing = sorted(v for v in required_set if v not in variables)
    if missing and not allow_unresolved and not bool(meta.get("allow_unresolved", False)):
        raise ValueError("Missing template variables: " + ", ".join(missing))

    rendered = interpolate_variables(template, variables)
    unresolved = sorted(set(_find_placeholders(rendered)))
    if unresolved and not allow_unresolved and not bool(meta.get("allow_unresolved", False)):
        raise ValueError("Unresolved template placeholders remain: " + ", ".join(unresolved))

    return rendered

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
        allow_unresolved = False
        args = sys.argv[2:]
        if "--allow-unresolved" in args:
            allow_unresolved = True
            args = [a for a in args if a != "--allow-unresolved"]

        if len(args) < 1:
            print("Usage: template_engine.py render <template.json> [vars.json] [--allow-unresolved]", file=sys.stderr)
            sys.exit(1)

        template_path = args[0]
        template = load_template(template_path)

        # Load variables from file or stdin
        if len(args) >= 2:
            with open(args[1], 'r') as f:
                variables_obj = json.load(f)
        else:
            # Read from stdin if available
            if not sys.stdin.isatty():
                raw = sys.stdin.read()
                if raw.strip() == "":
                    variables_obj = {}
                else:
                    variables_obj = json.loads(raw)
            else:
                variables_obj = {}

        try:
            variables = _normalize_vars(variables_obj)
            rendered = _render_strict(template, variables, allow_unresolved=allow_unresolved)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(2)

        print(json.dumps(rendered, indent=2))

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == '__main__':
    main()
