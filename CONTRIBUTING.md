# Contributing to NotebookLM Automation

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)

## Code of Conduct

Be respectful and inclusive in all interactions. This project follows standard open-source etiquette in issues, discussions, and pull requests.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/notebooklm-automation.git
   cd notebooklm-automation
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/adrianwedd/notebooklm-automation.git
   ```

## Development Setup

### Prerequisites

- **Bash** 4.0 or later
- **Python** 3.8 or later
- **NotebookLM MCP CLI**: `pip install notebooklm-mcp-cli`
- **jq**: For JSON processing (`brew install jq` on macOS)

### Install Development Dependencies

```bash
# Optional: install Python dependencies for smart creation features
pip3 install -r requirements-research.txt

# Authenticate with NotebookLM
nlm login
```

Note: If pip is blocked by an externally-managed environment, use a venv:
```bash
python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements-research.txt
```

### Verify Setup

```bash
# Run integration tests
./tests/integration-test.sh

# Validate bash syntax
bash -n scripts/*.sh

# Check Python syntax
python3 -m py_compile lib/*.py
```

## Making Changes

### Branch Naming

Create a descriptive branch name:

```bash
git checkout -b feature/add-export-format
git checkout -b fix/parallel-generation-bug
git checkout -b docs/improve-readme
```

### Commit Messages

Follow conventional commit format:

```
type: short description (max 72 chars)

Longer explanation if needed. Wrap at 72 characters.
Explain what changed and why, not how.

Co-Authored-By: Your Name <your.email@example.com>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or changes
- `refactor`: Code refactoring
- `chore`: Maintenance tasks

**Examples:**
```
feat: add JSON export format

Implements JSON export with full metadata preservation.
Includes notebook sources, artifacts, and timestamps.

Closes #123
```

```
fix: resolve parallel generation race condition

The progress monitor could outlive the parent process.
Now properly waits for monitor to exit.

Fixes #456
```

## Testing

### Run Tests Before Committing

```bash
# CI-equivalent no-auth checks (fast)
bash -n scripts/*.sh
shellcheck -x scripts/*.sh
python3 -m py_compile lib/*.py

bash tests/help-flags-test.sh
bash tests/dry-run-smoke-test.sh
bash tests/json-tools-test.sh
bash tests/retry-helper-test.sh

# Integration tests (requires nlm login; creates and deletes notebooks; takes a few minutes)
nlm login
./tests/integration-test.sh

# Test specific functionality
./scripts/export-notebook.sh "test-notebook" /tmp/test-export
./scripts/automate-notebook.sh --config tests/fixtures/example-config.json
```

Integration test notes:
- By default it creates one notebook and runs live `nlm` operations against it, then deletes it in cleanup.
- Use `./tests/integration-test.sh --keep-notebooks` to keep notebooks for debugging.
- `./tests/integration-test.sh --run-export-all` will export all notebooks (slow; maintainer-only).

### Add Tests for New Features

If adding new functionality:

1. Add test case to `tests/integration-test.sh`
2. Include both success and error cases
3. Clean up test resources (notebooks, temp files)

Example test structure:
```bash
# Test 6: New Feature
section "Test 6: New Feature"
info "Creating test setup..."

# Test implementation
if NEW_FEATURE_TEST; then
    success "New feature works correctly"
else
    error "New feature test failed"
fi

# Cleanup
info "Cleaning up test resources..."
```

## Code Style

### Bash Scripts

**Required:**
- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` (fail on errors, undefined vars, pipe failures)
- Quote all variables: `"$var"` not `$var`
- Include `--help` flag with usage examples
- Add descriptive comments for complex logic

**Security:**
- Never use `eval` with user input
- Avoid `exec` except for specific use cases
- Use environment variables when passing untrusted data to Python
- Validate input parameters

**Example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Script description and usage
SCRIPT_NAME="${1:?Usage: script.sh <required-arg>}"

if [[ "$SCRIPT_NAME" == "--help" ]]; then
    cat <<EOF
Usage: script.sh <name>

Description of what this script does.

Examples:
  ./script.sh example-name
EOF
    exit 0
fi

# Script implementation...
```

### Python Code

**Required:**
- Include type hints for all functions
- Add docstrings for modules and public functions
- Handle exceptions with clear error messages to stderr
- Make scripts executable with proper shebang

**Example:**
```python
#!/usr/bin/env python3
"""
Module description.
"""

import sys
from typing import List, Dict

def process_data(input_data: List[Dict]) -> List[Dict]:
    """
    Process input data and return results.

    Args:
        input_data: List of dictionaries to process

    Returns:
        Processed list of dictionaries

    Raises:
        ValueError: If input_data is empty
    """
    if not input_data:
        raise ValueError("Input data cannot be empty")

    # Implementation...
    return []

if __name__ == '__main__':
    # CLI interface
    pass
```

### File Organization

- **Scripts**: Place in `scripts/` directory
- **Libraries**: Place in `lib/` directory
- **Templates**: Place in `templates/category/` subdirectories
- **Tests**: Place in `tests/` directory
- **Documentation**: Place in `docs/` or update README.md

## Submitting Changes

### Before Submitting

1. **Run all tests**: `./tests/integration-test.sh`
2. **Validate syntax**: `bash -n scripts/*.sh && python3 -m py_compile lib/*.py`
3. **Update documentation**: Ensure README.md reflects changes
4. **Check git diff**: Review your changes carefully

### Pull Request Process

1. **Update your branch** with latest upstream:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request** on GitHub:
   - Use a clear, descriptive title
   - Reference any related issues
   - Describe what changed and why
   - Include testing steps if applicable

4. **PR Description Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Related Issues
   Closes #123
   Relates to #456

   ## Changes Made
   - Added feature X
   - Fixed bug Y
   - Updated documentation

   ## Testing
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   - [ ] Documentation updated

   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Self-review completed
   - [ ] Comments added for complex code
   - [ ] Documentation updated
   - [ ] No new warnings introduced
   ```

5. **Respond to feedback**: Address review comments promptly

### After Merge

1. **Delete your branch**:
   ```bash
   git branch -d feature/your-feature-name
   git push origin --delete feature/your-feature-name
   ```

2. **Update your fork**:
   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   ```

## Development Tips

### Common Tasks

**Add a new script:**
```bash
# Create script
cat > scripts/my-script.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Implementation
EOF

# Make executable
chmod +x scripts/my-script.sh

# Test
./scripts/my-script.sh --help
```

**Add a template:**
```bash
# Create template JSON
cat > templates/category/template-name.json <<'EOF'
{
  "title": "{{variable}} Template",
  "sources": ["text:{{content}}"],
  "studio": [{"type": "quiz"}]
}
EOF

# Test template
./scripts/create-from-template.sh category/template-name \
  --var variable="Test" \
  --var content="Sample content"
```

**Debug a script:**
```bash
# Run with debug output
bash -x scripts/my-script.sh

# Check syntax without running
bash -n scripts/my-script.sh
```

### Getting Help

- **Check CLAUDE.md**: Project context for AI assistance
- **Review tests**: `tests/integration-test.sh` has working examples
- **Read docs**: Implementation plans in `docs/plans/`
- **Ask questions**: Open an issue with the "question" label

## Questions?

If you have questions not covered here:

1. Check existing [issues](https://github.com/adrianwedd/notebooklm-automation/issues)
2. Review [CLAUDE.md](CLAUDE.md) for project architecture
3. Open a new issue with the "question" label

Thank you for contributing! 🎉
