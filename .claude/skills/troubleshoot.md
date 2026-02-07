---
name: troubleshoot
description: Diagnose and fix common issues with NotebookLM automation
---

Use this skill when the user encounters errors or unexpected behavior.

## Quick Diagnostics

**Run full diagnostic:**
```bash
echo "=== NotebookLM Automation Diagnostics ==="

echo "1. Check nlm CLI:"
nlm --version
nlm login --status

echo "2. Check dependencies:"
which bash python3 jq

echo "3. Check script permissions:"
ls -l scripts/*.sh | grep -v "rwxr-xr-x"

echo "4. Check Python dependencies:"
pip3 list | grep -E "requests|beautifulsoup4|ddgs"

echo "5. Check git status:"
git status
```

## Common Error Patterns

### Authentication Errors

**Error:** `NotebookLM authentication failed`

**Diagnosis:**
```bash
nlm login --status
```

**Solution:**
```bash
nlm login
# Follow browser authentication flow
```

**Verification:**
```bash
nlm notebook list
# Should return your notebooks
```

---

### Command Not Found

**Error:** `nlm: command not found`

**Solution:**
```bash
pip install notebooklm-mcp-cli
# or
pip3 install --upgrade notebooklm-mcp-cli
```

**Verification:**
```bash
nlm --version
which nlm
```

---

### Script Permission Denied

**Error:** `Permission denied: ./scripts/export-notebook.sh`

**Solution:**
```bash
chmod +x scripts/*.sh
chmod +x lib/*.py
```

**Verification:**
```bash
ls -la scripts/ | head -5
# Should show rwxr-xr-x
```

---

### JSON Parse Errors

**Error:** `parse error: Invalid JSON`

**Diagnosis:**
```bash
cat config.json | jq .
```

**Common causes:**
- Trailing commas
- Missing quotes
- Unescaped special characters

**Solution:**
```bash
# Validate JSON online or with jq
# Fix syntax errors
# Common fixes:
# - Remove trailing commas: {"key": "value",} -> {"key": "value"}
# - Add missing quotes: {key: value} -> {"key": "value"}
# - Escape special chars: "quote"s" -> "quote\"s"
```

---

### Smart Creation No Results

**Error:** `Warning: No quality sources found`

**Diagnosis:**
```bash
# Test search manually
python3 lib/web_search.py "your search query" 5
python3 lib/wikipedia_search.py "your topic" 3
```

**Solutions:**
1. **Broaden search terms:**
   ```bash
   # Too specific: "quantum entanglement Bell inequalities"
   # Better: "quantum entanglement"
   ```

2. **Increase depth:**
   ```bash
   ./scripts/research-topic.sh "topic" --depth 15
   ```

3. **Check internet connection:**
   ```bash
   ping google.com
   curl -I https://duckduckgo.com
   ```

---

### Parallel Generation Hangs

**Error:** Script hangs during parallel generation

**Diagnosis:**
```bash
# Check for hung processes
jobs -l
ps aux | grep generate-studio
```

**Solution:**
```bash
# Kill hung processes
kill <PID>

# Try sequential mode
./scripts/automate-notebook.sh --config config.json
# (without --parallel)
```

---

### Template Variables Not Replaced

**Error:** Notebook title contains `{{variable}}`

**Diagnosis:**
```bash
# Check if variable was passed
./scripts/create-from-template.sh template-name --var missing_var=value
```

**Solution:**
```bash
# List template to see required variables
cat templates/category/template.json | jq .

# Provide all required variables
./scripts/create-from-template.sh template \
  --var var1="value1" \
  --var var2="value2"
```

---

### Export Fails

**Error:** `Failed to export notebook`

**Diagnosis:**
```bash
# Check notebook exists
nlm notebook list | grep "Notebook Name"

# Check output directory permissions
mkdir -p ./test-export
ls -ld ./test-export

# Test with direct ID
./scripts/export-notebook.sh <notebook-id> /tmp/test
```

**Solution:**
```bash
# Ensure output directory exists and is writable
mkdir -p ./exports
chmod 755 ./exports

# Use notebook ID instead of name
nlm notebook list  # Get ID
./scripts/export-notebook.sh <id> ./exports
```

---

## Performance Issues

### Slow Artifact Generation

**Symptom:** Generation takes >5 minutes per artifact

**Diagnosis:**
- Check NotebookLM web interface (might be service-wide)
- Test with simple artifact: `quiz` is usually fastest

**Solutions:**
1. **Use parallel mode** (if 3+ artifacts):
   ```bash
   --parallel
   ```

2. **Generate in batches:**
   ```bash
   # Generate 2 at a time instead of 5
   ```

3. **Check system resources:**
   ```bash
   top
   # Look for high CPU/memory usage
   ```

---

### Slow Smart Creation

**Symptom:** research-topic.sh takes >2 minutes

**Diagnosis:**
```bash
# Time each component
time python3 lib/web_search.py "topic" 5
time python3 lib/wikipedia_search.py "topic" 3
```

**Solutions:**
1. **Reduce depth:**
   ```bash
   --depth 5  # Instead of --depth 15
   ```

2. **Check network:**
   ```bash
   ping 8.8.8.8
   traceroute duckduckgo.com
   ```

---

## Debugging Techniques

### Enable Bash Debug Mode

```bash
bash -x ./scripts/your-script.sh
# Shows each command as it executes
```

### Add Debug Logging

```bash
# Temporary debug output
set -x  # Enable debug
# ... your code ...
set +x  # Disable debug
```

### Check Script Syntax

```bash
bash -n scripts/problematic-script.sh
# Returns nothing if syntax is valid
```

### Validate Python Syntax

```bash
python3 -m py_compile lib/problematic-script.py
```

### Trace Network Calls

```bash
# Add to Python scripts temporarily
import logging
logging.basicConfig(level=logging.DEBUG)
```

---

## Environment Issues

### Wrong Python Version

**Error:** `SyntaxError` or `ModuleNotFoundError`

**Check version:**
```bash
python3 --version
# Need 3.8 or later
```

**Solution:**
```bash
# Use specific Python version
python3.10 lib/web_search.py
# or update system Python
```

---

### Missing Dependencies

**Error:** `ModuleNotFoundError: No module named 'requests'`

**Solution:**
```bash
pip3 install -r requirements-research.txt
```

**Verification:**
```bash
python3 -c "import requests; import bs4; print('OK')"
```

---

### Path Issues

**Error:** `No such file or directory`

**Check current directory:**
```bash
pwd
# Should be in /path/to/notebooklm-automation
```

**Solution:**
```bash
cd /path/to/notebooklm-automation
./scripts/export-notebook.sh ...
```

---

## Getting Help

**Check documentation:**
1. README.md - User guide
2. CLAUDE.md - Project architecture
3. CONTRIBUTING.md - Development guidelines
4. templates/README.md - Template guide

**Search existing issues:**
```bash
gh issue list --search "error message"
```

**Create detailed bug report:**
```bash
gh issue create --template bug_report.md
```

Include:
- Error message (full output)
- Command you ran
- Configuration file (if applicable)
- Environment (`bash --version`, `python3 --version`, `nlm --version`)
- Steps to reproduce

---

## Recovery Procedures

### Clean Stuck State

```bash
# Remove temp files
rm -f /tmp/generate-*.json
rm -f /tmp/research-*.txt

# Kill background jobs
jobs -l
kill %1 %2  # or kill <PID>

# Reset to clean state
git status
git clean -n  # Dry run, shows what would be deleted
git clean -f  # Actually delete untracked files (be careful!)
```

### Re-authenticate

```bash
# Clear auth and re-login
nlm logout
nlm login
```

### Reinstall Dependencies

```bash
pip3 uninstall notebooklm-mcp-cli
pip3 install notebooklm-mcp-cli

pip3 install -r requirements-research.txt --force-reinstall
```

---

## Prevention

**Before running commands:**
1. ✅ Check authentication: `nlm login --status`
2. ✅ Validate config: `cat config.json | jq .`
3. ✅ Verify paths exist: `ls -la ./exports`
4. ✅ Test with small dataset first

**Regular maintenance:**
```bash
# Weekly
pip3 install --upgrade notebooklm-mcp-cli
./tests/integration-test.sh

# Monthly
pip3 install --upgrade -r requirements-research.txt
```
