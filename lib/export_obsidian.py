#!/usr/bin/env python3
"""
Export NotebookLM notebook to Obsidian vault format.

Usage:
    python3 export_obsidian.py <notebook.json> <output-dir>

Creates an Obsidian vault with:
- README.md (overview with wikilinks)
- Sources/ (individual source notes)
- Artifacts/ (studio outputs)
- Metadata frontmatter
- Wikilink navigation
"""

import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Any


def sanitize_filename(name: str, max_length: int = 80) -> str:
    """Convert title to safe filename for Obsidian."""
    # Remove or replace special characters
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    # Replace multiple spaces with single space
    name = re.sub(r'\s+', ' ', name)
    # Trim and limit length
    name = name.strip()[:max_length]
    # Ensure not empty
    if not name:
        name = "untitled"
    return name


def create_frontmatter(data: Dict[str, Any]) -> str:
    """Create YAML frontmatter for Obsidian note."""
    lines = ["---"]
    for key, value in data.items():
        if isinstance(value, list):
            lines.append(f"{key}:")
            for item in value:
                lines.append(f"  - {item}")
        elif isinstance(value, str):
            # Escape quotes in values
            value = value.replace('"', '\\"')
            lines.append(f'{key}: "{value}"')
        else:
            lines.append(f"{key}: {value}")
    lines.append("---")
    lines.append("")
    return "\n".join(lines)


def create_readme(notebook_data: Dict[str, Any], sources: List[Dict], artifacts: List[Dict], vault_dir: Path) -> None:
    """Create main README.md with overview and wikilinks."""
    readme_path = vault_dir / "README.md"

    title = notebook_data.get("title", "Untitled Notebook")
    notebook_id = notebook_data.get("id", "unknown")
    created_at = notebook_data.get("created_at", "")
    updated_at = notebook_data.get("updated_at", "")

    frontmatter = create_frontmatter({
        "title": title,
        "notebook_id": notebook_id,
        "created": created_at,
        "updated": updated_at,
        "type": "notebook-overview"
    })

    content = [frontmatter]
    content.append(f"# {title}")
    content.append("")
    content.append("## Overview")
    content.append("")
    content.append(f"This Obsidian vault contains an export from NotebookLM notebook `{title}`.")
    content.append("")
    content.append(f"- **Notebook ID**: `{notebook_id}`")
    content.append(f"- **Created**: {created_at}")
    content.append(f"- **Updated**: {updated_at}")
    content.append(f"- **Sources**: {len(sources)}")
    content.append(f"- **Artifacts**: {len(artifacts)}")
    content.append("")

    # Sources section
    if sources:
        content.append("## Sources")
        content.append("")
        for source in sources:
            title = source.get("title", "Untitled")
            source_type = source.get("type", "unknown")
            filename = sanitize_filename(title)
            content.append(f"- [[Sources/{filename}|{title}]] (`{source_type}`)")
        content.append("")

    # Artifacts section
    if artifacts:
        content.append("## Artifacts")
        content.append("")
        artifact_types = {}
        for artifact in artifacts:
            atype = artifact.get("type", "unknown")
            if atype not in artifact_types:
                artifact_types[atype] = []
            artifact_types[atype].append(artifact)

        for atype, items in sorted(artifact_types.items()):
            content.append(f"### {atype.replace('_', ' ').title()}")
            content.append("")
            for artifact in items:
                aid = artifact.get("id", "unknown")
                status = artifact.get("status", "unknown")
                filename = sanitize_filename(f"{atype}_{aid}")
                content.append(f"- [[Artifacts/{filename}|{atype} {aid[:8]}]] (`{status}`)")
            content.append("")

    content.append("## Navigation")
    content.append("")
    content.append("- Browse [[Sources/]] for all source materials")
    content.append("- Browse [[Artifacts/]] for generated content")
    content.append("")

    readme_path.write_text("\n".join(content))


def export_sources(sources: List[Dict], export_dir: Path, vault_dir: Path) -> None:
    """Export sources to Obsidian notes with backlinks."""
    sources_dir = vault_dir / "Sources"
    sources_dir.mkdir(exist_ok=True)

    for source in sources:
        source_id = source.get("id", "unknown")
        title = source.get("title", "Untitled")
        source_type = source.get("type", "unknown")
        created_at = source.get("created_at", "")

        filename = sanitize_filename(title) + ".md"
        source_path = sources_dir / filename

        # Read source content if available
        # The export script uses sed 's/[^a-zA-Z0-9._-]/_/g' for filenames
        content_text = ""
        # Try the export script's naming convention first
        export_safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', title)[:100] + ".md"
        source_file = export_dir / "sources" / export_safe_name
        if source_file.exists():
            content_text = source_file.read_text()

        frontmatter = create_frontmatter({
            "title": title,
            "source_id": source_id,
            "type": source_type,
            "created": created_at,
            "tags": ["source", source_type]
        })

        note_content = [frontmatter]
        note_content.append(f"# {title}")
        note_content.append("")
        note_content.append(f"**Type**: {source_type}")
        note_content.append(f"**ID**: `{source_id}`")
        note_content.append("")

        if content_text:
            note_content.append("## Content")
            note_content.append("")
            note_content.append(content_text)
            note_content.append("")

        note_content.append("---")
        note_content.append("")
        note_content.append("[[README|← Back to Overview]]")

        source_path.write_text("\n".join(note_content))


def export_artifacts(artifacts: List[Dict], export_dir: Path, vault_dir: Path) -> None:
    """Export artifacts as Obsidian notes with links to files."""
    artifacts_dir = vault_dir / "Artifacts"
    artifacts_dir.mkdir(exist_ok=True)

    # Create subdirectories for artifact files
    files_dir = artifacts_dir / "files"
    files_dir.mkdir(exist_ok=True)

    for artifact in artifacts:
        aid = artifact.get("id", "unknown")
        atype = artifact.get("type", "unknown")
        status = artifact.get("status", "unknown")
        created_at = artifact.get("created_at", "")
        config = artifact.get("config", {})

        filename = sanitize_filename(f"{atype}_{aid}") + ".md"
        artifact_path = artifacts_dir / filename

        frontmatter = create_frontmatter({
            "title": f"{atype.replace('_', ' ').title()}",
            "artifact_id": aid,
            "type": atype,
            "status": status,
            "created": created_at,
            "tags": ["artifact", atype]
        })

        note_content = [frontmatter]
        note_content.append(f"# {atype.replace('_', ' ').title()}")
        note_content.append("")
        note_content.append(f"**Type**: {atype}")
        note_content.append(f"**Status**: {status}")
        note_content.append(f"**ID**: `{aid}`")
        note_content.append("")

        # Add configuration details
        if config:
            note_content.append("## Configuration")
            note_content.append("")
            for key, value in config.items():
                note_content.append(f"- **{key}**: {value}")
            note_content.append("")

        # Link to actual artifact file if it exists
        artifact_file_patterns = {
            "audio": f"studio/audio/{aid}.mp3",
            "video": f"studio/video/{aid}.mp4",
            "report": f"studio/documents/{aid}.md",
            "slide_deck": f"studio/documents/{aid}.pdf",
            "infographic": f"studio/visual/{aid}.png",
            "mind_map": f"studio/visual/{aid}.json",
            "quiz": f"studio/interactive/{aid}-quiz.json",
            "flashcards": f"studio/interactive/{aid}-flashcards.json",
            "data_table": f"studio/interactive/{aid}-data-table.csv"
        }

        if atype in artifact_file_patterns:
            artifact_file = export_dir / artifact_file_patterns[atype]
            if artifact_file.exists():
                # Copy to vault
                target_file = files_dir / artifact_file.name
                target_file.write_bytes(artifact_file.read_bytes())

                note_content.append("## File")
                note_content.append("")
                note_content.append(f"[[files/{artifact_file.name}|View {atype}]]")
                note_content.append("")

                # For reports, embed the content
                if atype == "report" and artifact_file.suffix == ".md":
                    report_content = artifact_file.read_text()
                    note_content.append("## Content")
                    note_content.append("")
                    note_content.append(report_content)
                    note_content.append("")

        note_content.append("---")
        note_content.append("")
        note_content.append("[[README|← Back to Overview]]")

        artifact_path.write_text("\n".join(note_content))


def main():
    if len(sys.argv) != 3:
        print("Usage: python3 export_obsidian.py <notebook-export-dir> <output-vault-dir>", file=sys.stderr)
        sys.exit(1)

    export_dir = Path(sys.argv[1])
    vault_dir = Path(sys.argv[2])

    # Read notebook data
    metadata_file = export_dir / "metadata.json"
    if not metadata_file.exists():
        print(f"Error: metadata.json not found in {export_dir}", file=sys.stderr)
        sys.exit(1)

    with open(metadata_file) as f:
        notebook_data = json.load(f)

    # Read sources
    sources_file = export_dir / "sources" / "index.json"
    sources = []
    if sources_file.exists():
        with open(sources_file) as f:
            sources = json.load(f)

    # Read artifacts
    artifacts_file = export_dir / "studio" / "manifest.json"
    artifacts = []
    if artifacts_file.exists():
        with open(artifacts_file) as f:
            artifacts = json.load(f)

    # Create vault directory
    vault_dir.mkdir(parents=True, exist_ok=True)

    # Export components
    print(f"Creating Obsidian vault: {vault_dir}")
    create_readme(notebook_data, sources, artifacts, vault_dir)
    print(f"  [+] README.md")

    export_sources(sources, export_dir, vault_dir)
    print(f"  [+] Sources/ ({len(sources)} sources)")

    export_artifacts(artifacts, export_dir, vault_dir)
    print(f"  [+] Artifacts/ ({len(artifacts)} artifacts)")

    print(f"\nObsidian vault created: {vault_dir}")
    print(f"Open this folder in Obsidian to browse the notebook.")


if __name__ == "__main__":
    main()
