# Codex Comprehensive Review Prompt

Use this prompt with Codex to perform a full review of the `adrianwedd/notebooklm-automation` repository.

---

## Prompt

You are performing a comprehensive review of the `notebooklm-automation` repository - a Bash/Python automation toolkit for Google NotebookLM. Review the entire codebase across three dimensions: **code quality**, **documentation quality**, and **holistic project health**. Be thorough, specific, and actionable.

### 1. Code Review

**Bash Scripts (`scripts/*.sh`)**:
- Verify every script uses `set -euo pipefail` at the top
- Check that ALL variables are properly quoted (`"$var"` not `$var`) to prevent word splitting
- Confirm no use of `eval` or `exec` with user input (security critical)
- Verify each script has a `--help` flag with usage examples
- Check error handling: are exit codes checked for external commands (`nlm`, `jq`, `python3`)?
- Verify temp files are cleaned up (trap handlers or explicit cleanup)
- Check that `$SCRIPT_DIR` is used for relative paths instead of hardcoded paths
- Look for race conditions in parallel execution (`generate-parallel.sh`)
- Verify URL validation before passing to external commands
- Check for consistent coding style across all scripts

**Python Libraries (`lib/*.py`)**:
- Verify type hints on all public functions
- Check docstrings exist for modules and functions
- Verify exceptions are caught and errors go to stderr (not stdout)
- Check that standard library is preferred over external dependencies
- Look for potential injection vulnerabilities (URL handling, subprocess calls)
- Verify `requirements-research.txt` matches actual imports
- Check for Python 3.8+ compatibility (no walrus operators if targeting 3.8)

**Configuration & Templates**:
- Validate all JSON templates in `templates/` are valid JSON
- Check template variable naming consistency (`{{snake_case}}`)
- Verify `create-from-template.sh` handles all edge cases (missing vars, invalid templates)

### 2. Documentation Review

**README.md**:
- Is it accurate and up-to-date with the current feature set (Phase 1-3)?
- Are all code examples correct and runnable?
- Are badges rendering correctly?
- Is the installation process complete and correct?
- Are all scripts documented with their flags and options?

**CLAUDE.md**:
- Does it accurately describe the architecture?
- Are the development guidelines correct and complete?
- Are common pitfalls still relevant?
- Does the dependency list match reality?

**CONTRIBUTING.md**:
- Is the development setup process accurate?
- Are code style guidelines consistent with what's actually in the codebase?
- Is the PR process clearly described?

**CHANGELOG.md**:
- Does it accurately reflect the features in each phase?
- Are there any features mentioned that don't exist, or missing features that do exist?

**SECURITY.md**:
- Are the security practices described actually followed in the code?
- Is the vulnerability reporting process clear?

**templates/README.md**:
- Are all templates documented?
- Are the usage examples correct?

**Inline Documentation**:
- Are complex sections of bash scripts well-commented?
- Do Python modules have proper module-level docstrings?

### 3. Holistic Project Review

**Architecture**:
- Is the separation between bash orchestration and Python data processing clean?
- Are there any circular dependencies or unnecessary coupling?
- Is the template system well-designed and extensible?
- Is the smart creation (web search + Wikipedia) pipeline robust?

**Testing**:
- Does `tests/integration-test.sh` cover all major workflows?
- Are there any untested code paths that should be tested?
- Is the CI/CD pipeline (`.github/workflows/`) correctly configured?
- Do the GitHub Actions workflows actually work (check syntax, paths, commands)?

**Security**:
- Audit all scripts for command injection vectors
- Check that credentials/cookies are properly gitignored
- Verify no secrets or tokens are hardcoded
- Check that `.gitignore` covers all sensitive files

**DevEx (Developer Experience)**:
- Is it easy for a new contributor to set up and start developing?
- Are error messages helpful and actionable?
- Is the skill system (`.claude/skills/`) well-structured?

**Project Health**:
- Are GitHub issue templates well-designed?
- Is the labeler configuration comprehensive?
- Are there any TODO comments that should be tracked as issues?
- Is the git history clean and commit messages consistent?

### Output Format

Please structure your review as:

```markdown
## Code Review

### Critical Issues (must fix)
- [file:line] Description and fix

### Important Issues (should fix)
- [file:line] Description and fix

### Minor Issues (nice to fix)
- [file:line] Description and fix

## Documentation Review

### Inaccuracies
- [file] What's wrong and the correction

### Missing Documentation
- What should be documented and where

### Improvements
- Suggestions for clarity/completeness

## Holistic Review

### Architecture Concerns
- Description and recommendation

### Security Findings
- [severity] Description and remediation

### Testing Gaps
- What's untested and suggested test

### Project Health
- Observations and recommendations

## Summary

- Overall quality score: X/10
- Production readiness: Yes/No with conditions
- Top 3 priorities for improvement
```

Be specific with file paths and line numbers. Don't just flag issues - provide the fix or recommendation.
