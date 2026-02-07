#!/usr/bin/env python3
"""
Export NotebookLM notebook to Notion-compatible markdown format.
Converts exported notebook structure to a single markdown file with callouts.
"""
import json
import os
import sys
from pathlib import Path


def export_to_notion(notebook_dir: str, output_dir: str):
    """Export notebook to Notion format (single markdown with callouts)."""
    notebook_path = Path(notebook_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    # Read metadata
    with open(notebook_path / "metadata.json") as f:
        metadata = json.load(f)

    title = metadata.get("title", "Untitled Notebook")

    # Start building Notion markdown
    lines = [
        f"# {title}",
        "",
        f"> **Created:** {metadata.get('created_at', 'Unknown')}",
        f"> **Updated:** {metadata.get('updated_at', 'Unknown')}",
        "",
    ]

    # Add sources
    sources_file = notebook_path / "sources" / "index.json"
    if sources_file.exists():
        with open(sources_file) as f:
            sources = json.load(f)

        if sources:
            lines.append("## Sources")
            lines.append("")
            for source in sources:
                source_type = source.get("type", "unknown")
                source_title = source.get("title", "Untitled")
                lines.append(f"> **{source_type}:** {source_title}")
            lines.append("")

    # Add notes
    notes_file = notebook_path / "notes" / "index.json"
    if notes_file.exists():
        with open(notes_file) as f:
            notes = json.load(f)

        if notes:
            lines.append("## Notes")
            lines.append("")
            for note in notes:
                note_title = note.get("title", "Untitled Note")
                note_content = note.get("content", "")
                lines.append(f"### {note_title}")
                lines.append("")
                lines.append(f"> {note_content.replace(chr(10), chr(10) + '> ')}")
                lines.append("")

    # Add studio artifacts
    manifest_file = notebook_path / "studio" / "manifest.json"
    if manifest_file.exists():
        with open(manifest_file) as f:
            artifacts = json.load(f)

        completed = [a for a in artifacts if a.get("status") == "completed"]
        if completed:
            lines.append("## Studio Artifacts")
            lines.append("")
            for artifact in completed:
                atype = artifact.get("type", "unknown")
                aid = artifact.get("id", "unknown")
                lines.append(f"> **{atype}:** `{aid}`")
            lines.append("")

    # Write Notion markdown
    output_file = output_path / f"{title.replace('/', '-')}.md"
    with open(output_file, "w") as f:
        f.write("\n".join(lines))

    print(f"Notion export: {output_file}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: export_notion.py <notebook-dir> <output-dir>")
        sys.exit(1)

    export_to_notion(sys.argv[1], sys.argv[2])
