#!/usr/bin/env python3
"""
Small JSON helper utilities for bash scripts.

This module is intentionally dependency-free (stdlib only) and Python 3.8+ compatible.
"""

import argparse
import json
import sys
from typing import Any, List, Dict


def _read_json_stdin() -> Any:
    try:
        return json.load(sys.stdin)
    except Exception as e:
        print(f"Error: failed to parse JSON from stdin: {e}", file=sys.stderr)
        raise


def cmd_len(_: argparse.Namespace) -> int:
    try:
        obj = _read_json_stdin()
    except Exception:
        return 1
    try:
        print(len(obj))  # type: ignore[arg-type]
        return 0
    except Exception as e:
        print(f"Error: object has no len(): {e}", file=sys.stderr)
        return 1


def _get_path(obj: Any, path: str) -> Any:
    cur: Any = obj
    for part in path.split("."):
        if part == "":
            raise KeyError("empty path segment")
        # Allow list indexes: foo.0.bar
        if isinstance(cur, list):
            try:
                idx = int(part)
            except ValueError:
                raise KeyError(f"expected list index, got: {part}")
            cur = cur[idx]
            continue
        if isinstance(cur, dict):
            if part not in cur:
                raise KeyError(part)
            cur = cur[part]
            continue
        raise KeyError(f"cannot traverse into non-container at segment: {part}")
    return cur


def cmd_get(args: argparse.Namespace) -> int:
    try:
        obj = _read_json_stdin()
    except Exception:
        return 1
    try:
        val = _get_path(obj, args.path)
    except Exception as e:
        print(f"Error: failed to get path '{args.path}': {e}", file=sys.stderr)
        return 1

    # Keep bash-friendly output: scalars as text, containers as JSON.
    if isinstance(val, (dict, list)):
        json.dump(val, sys.stdout)
        sys.stdout.write("\n")
        return 0
    if val is None:
        print("null")
        return 0
    if isinstance(val, bool):
        print("true" if val else "false")
        return 0
    print(val)
    return 0


def cmd_print_templates(_: argparse.Namespace) -> int:
    try:
        data = _read_json_stdin()
    except Exception:
        return 1

    if not isinstance(data, list):
        print("Error: expected a JSON array of templates", file=sys.stderr)
        return 1

    for t in data:
        if not isinstance(t, dict):
            continue
        tid = t.get("id", "")
        cat = t.get("category", "")
        print(f"  {tid:30} ({cat})")
    return 0


def main(argv: List[str]) -> int:
    p = argparse.ArgumentParser(prog="json_tools.py", add_help=True)
    sub = p.add_subparsers(dest="cmd", required=True)

    sp_len = sub.add_parser("len", help="Print len(JSON) from stdin")
    sp_len.set_defaults(func=cmd_len)

    sp_get = sub.add_parser("get", help="Get a dotted-path value from JSON stdin")
    sp_get.add_argument("path", help="Dotted path (supports list indexes), e.g. title or items.0.id")
    sp_get.set_defaults(func=cmd_get)

    sp_tpl = sub.add_parser("print-templates", help="Pretty-print template list JSON to stdout")
    sp_tpl.set_defaults(func=cmd_print_templates)

    args = p.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

