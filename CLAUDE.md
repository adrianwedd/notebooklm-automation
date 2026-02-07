# Claude Code Project Context

This file provides context for Claude Code when working on this project.

## Project Overview

**notebooklm-automation** is a comprehensive automation toolkit for Google NotebookLM, providing export, artifact generation, smart research, and multi-format export capabilities.

## Architecture

**Tech Stack:**
- **Bash scripts** - Main orchestration and CLI interface
- **Python 3** - Data processing, web scraping, export format conversion
- **External CLI** - `nlm` (notebooklm-mcp-cli) for NotebookLM API access

**Directory Structure:**
```
scripts/          # Bash automation scripts
lib/              # Python libraries and utilities
templates/        # JSON-driven notebook templates
tests/            # Integration test suite
docs/             # Implementation plans and documentation
```

## Development Guidelines

### Code Style

**Bash Scripts:**
- MUST use `set -euo pipefail` at the top
- MUST quote all variables to prevent word splitting
- MUST include `--help` flag with usage examples
- NO use of `eval` or `exec` with user input
- Prefer environment variables over string interpolation for security

**Python Code:**
- MUST include type hints for all public functions
- MUST include docstrings for modules and functions
- MUST handle exceptions with appropriate error messages to stderr
- Use standard library when possible, minimize dependencies

### Testing

**Before committing:**
```bash
# Run integration tests
./tests/integration-test.sh

# Validate bash syntax
bash -n scripts/*.sh

# Check Python syntax
python3 -m py_compile lib/*.py
```

### Security Considerations

**Critical:**
- Never use `eval` with user input
- Always quote bash variables: `"$var"` not `$var`
- Validate URLs before passing to external commands
- Use environment variables for passing untrusted data to Python
- Clean up temporary files with specific paths (no `rm -rf *`)

### Common Tasks

**Create new script:**
1. Add to `scripts/` directory
2. Start with shebang: `#!/usr/bin/env bash`
3. Add `set -euo pipefail`
4. Include help text and usage examples
5. Make executable: `chmod +x scripts/your-script.sh`

**Add Python library:**
1. Add to `lib/` directory
2. Include type hints and docstrings
3. Add to requirements-research.txt if needed
4. Make executable: `chmod +x lib/your_lib.py`

**Add template:**
1. Create JSON file in `templates/category/`
2. Use `{{variable}}` placeholders
3. Test with: `./scripts/create-from-template.sh category/name --var key=value`
4. Document in `templates/README.md`

## Dependencies

**Required:**
- `bash` 4.0+
- `python3` 3.8+
- `nlm` CLI (notebooklm-mcp-cli)
- `jq` for JSON processing

**Optional:**
- `gh` CLI for GitHub operations
- Python packages in `requirements-research.txt` for smart creation

## Testing Strategy

**Integration tests** validate end-to-end workflows:
- Notebook creation and source addition
- Studio artifact generation
- Export functionality
- Batch automation

**Test execution:**
```bash
./tests/integration-test.sh
```

## Git Workflow

**Commit message format:**
```
type: short description

Longer explanation if needed.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

## Phase History

- **Phase 1:** Export functionality (notebooks, sources, artifacts)
- **Phase 2:** Automation workflows (batch processing, config-driven)
- **Phase 3:** Advanced features (parallel generation, smart creation, templates, multi-format export)

## Key Files

**Entry points:**
- `scripts/automate-notebook.sh` - Main automation workflow
- `scripts/export-notebook.sh` - Export single notebook
- `scripts/export-all.sh` - Batch export all notebooks

**Core libraries:**
- `lib/web_search.py` - DuckDuckGo integration
- `lib/wikipedia_search.py` - Wikipedia API
- `lib/template_engine.py` - Template rendering
- `lib/export_*.py` - Format exporters (Obsidian, Notion, Anki)

**Configuration:**
- Templates in `templates/` directory (JSON with `{{variables}}`)
- Config files use JSON format (see README examples)

## Common Pitfalls

1. **Forgetting to quote variables** - Always use `"$var"`
2. **Missing error handling** - Check exit codes for external commands
3. **Hardcoding paths** - Use `$SCRIPT_DIR` for relative paths
4. **Not cleaning temp files** - Always cleanup in trap handlers or at script end
5. **Assuming nlm CLI exists** - Check for availability before use

## Resources

- **README.md** - User documentation and examples
- **docs/plans/** - Implementation plans for each phase
- **tests/integration-test.sh** - Working examples of all features
- **templates/README.md** - Template catalog and usage

## Questions or Issues?

When debugging issues:
1. Run with bash debugging: `bash -x scripts/your-script.sh`
2. Check nlm CLI: `nlm --version` and `nlm login --status`
3. Validate JSON: `cat config.json | jq .`
4. Check integration tests for working examples
