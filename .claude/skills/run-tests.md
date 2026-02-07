---
name: run-tests
description: Run integration tests and validate code quality
---

Use this skill when the user wants to test the project or before making commits.

## Quick Test

**Run all integration tests:**
```bash
./tests/integration-test.sh
```

This validates:
- Notebook creation
- Source addition
- Studio artifact generation
- Export functionality
- End-to-end automation

**Expected output:**
```
=== NotebookLM Integration Tests ===

[Test 1/5] Create Notebook
  ✓ Notebook created successfully

[Test 2/5] Add Sources
  ✓ Sources added successfully

[Test 3/5] Generate Studio Artifact
  ✓ Artifact generated successfully

[Test 4/5] Export Notebook
  ✓ Export completed successfully

[Test 5/5] End-to-End Automation
  ✓ Automation completed successfully

=== All Tests Passed ===
```

## Code Validation

### Bash Scripts

**Syntax validation:**
```bash
for script in scripts/*.sh; do
  bash -n "$script"
done
```

**Check for safety flags:**
```bash
grep -L "set -euo pipefail" scripts/*.sh
# Should return empty (all scripts should have this)
```

**Security check:**
```bash
# Check for dangerous patterns
grep -r "eval\|exec" scripts/
# Should return minimal or safe usage only
```

### Python Code

**Syntax validation:**
```bash
for pyfile in lib/*.py; do
  python3 -m py_compile "$pyfile"
done
```

**Type checking (optional):**
```bash
pip install mypy
mypy lib/*.py --ignore-missing-imports
```

**Linting (optional):**
```bash
pip install flake8
flake8 lib/*.py --max-line-length=100
```

## Pre-Commit Checklist

Before committing code, run:

```bash
# 1. Validate syntax
bash -n scripts/*.sh
python3 -m py_compile lib/*.py

# 2. Run integration tests
./tests/integration-test.sh

# 3. Check permissions
ls -la scripts/*.sh | grep -v "rwxr-xr-x"
# Should return empty (all should be executable)

# 4. Review changes
git diff
```

## Debugging Failed Tests

### Test 1 Failed: Create Notebook

**Common causes:**
- Not authenticated: Run `nlm login`
- Network issues: Check internet connection
- API changes: Check `nlm` CLI version

**Debug:**
```bash
nlm notebook list  # Verify authentication works
nlm --version      # Check CLI version
```

### Test 2 Failed: Add Sources

**Common causes:**
- Invalid URLs
- Source type not supported
- Notebook doesn't exist

**Debug:**
```bash
# Test source addition manually
NOTEBOOK_ID="<test-notebook-id>"
./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Test source"
```

### Test 3 Failed: Generate Artifact

**Common causes:**
- Artifact type not available
- Notebook has no sources
- Generation timeout

**Debug:**
```bash
# Check available artifact types
nlm studio list

# Test with simple artifact
./scripts/generate-studio.sh "$NOTEBOOK_ID" quiz --wait
```

### Test 4 Failed: Export

**Common causes:**
- Permission issues on output directory
- Disk space
- Export script syntax error

**Debug:**
```bash
# Check disk space
df -h

# Test export manually
./scripts/export-notebook.sh "$NOTEBOOK_ID" /tmp/test-export
```

### Test 5 Failed: Automation

**Common causes:**
- Invalid JSON config
- Combined failures from above tests
- Parallel generation issues

**Debug:**
```bash
# Validate JSON
cat config.json | jq .

# Run with debug
bash -x ./scripts/automate-notebook.sh --config config.json
```

## Performance Testing

### Test Parallel vs Sequential

```bash
# Create test notebook
NOTEBOOK_ID=$(./scripts/create-notebook.sh "Performance Test" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

./scripts/add-sources.sh "$NOTEBOOK_ID" "text:Test content"

# Sequential (baseline)
time ./scripts/automate-notebook.sh --config config.json

# Parallel (should be ~67% faster for 3+ artifacts)
time ./scripts/automate-notebook.sh --config config.json --parallel
```

### Test Smart Creation

```bash
# Measure research time
time ./scripts/research-topic.sh "machine learning" --depth 5
```

## Continuous Integration

Tests run automatically on GitHub:
- On every push to main
- On every pull request
- Validates syntax and style

**View CI results:**
```bash
gh run list
gh run view <run-id>
```

## Test Coverage Gaps

Current gaps (manual testing needed):
- [ ] Parallel generation edge cases
- [ ] Smart creation with zero results
- [ ] Template variable validation errors
- [ ] Export format error handling
- [ ] Very large notebooks (100+ sources)

## Success Criteria

Tests are successful when:
- ✅ All 5 integration tests pass
- ✅ No bash syntax errors
- ✅ No Python syntax errors
- ✅ All scripts are executable
- ✅ No new security warnings

## Example: Full Pre-Commit Validation

```bash
#!/bin/bash
set -e

echo "=== Pre-Commit Validation ==="

echo "1. Validating bash scripts..."
for script in scripts/*.sh; do
  bash -n "$script" || exit 1
done

echo "2. Validating Python files..."
for pyfile in lib/*.py; do
  python3 -m py_compile "$pyfile" || exit 1
done

echo "3. Running integration tests..."
./tests/integration-test.sh || exit 1

echo "✅ All validations passed - safe to commit!"
```
