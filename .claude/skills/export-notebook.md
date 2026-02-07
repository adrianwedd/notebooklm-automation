---
name: export-notebook
description: Export a NotebookLM notebook to local directory
---

Use this skill when the user asks to export a notebook from NotebookLM.

## Workflow

1. **List available notebooks** (if notebook name not provided):
   ```bash
   nlm notebook list
   ```

2. **Get notebook ID**:
   - If user provided a name, search the list
   - If user provided an ID, use it directly

3. **Export the notebook**:
   ```bash
   ./scripts/export-notebook.sh "<notebook-name-or-id>" ./exports
   ```

4. **Confirm export location**:
   ```bash
   ls -la ./exports/<notebook-directory>
   ```

## Options

**Export to custom location:**
```bash
./scripts/export-notebook.sh "Notebook Name" /path/to/output
```

**Export with specific format:**
```bash
# Obsidian vault
./scripts/export-notebook.sh "Notebook Name" ./output --format obsidian

# Notion markdown
./scripts/export-notebook.sh "Notebook Name" ./output --format notion

# Anki flashcards
./scripts/export-notebook.sh "Notebook Name" ./output --format anki
```

## Common Issues

**Notebook not found:**
- Use `nlm notebook list` to verify the name
- Try using the notebook ID instead
- Check if you're authenticated: `nlm login --status`

**Permission denied:**
- Ensure scripts are executable: `chmod +x scripts/*.sh`
- Check you have write permissions to the output directory

## Success Criteria

Export is successful when:
- ✅ Script completes without errors
- ✅ Output directory exists with content
- ✅ Sources, notes, and artifacts are present
- ✅ User receives confirmation message

## Example Session

```bash
# List notebooks
nlm notebook list

# Export by name
./scripts/export-notebook.sh "AI Research Notes" ./exports

# Verify export
ls -la ./exports/ai-research-notes/
```
