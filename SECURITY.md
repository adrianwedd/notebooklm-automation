# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

**Note:** This project is currently in active development. The `main` branch receives all security updates.

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Do NOT create a public GitHub issue for security vulnerabilities.**

Instead, please report security issues by emailing:

📧 **[Maintainer Email - Update this]**

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (if you have them)

### What to Expect

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity

  - **Critical**: Emergency patch within 24-48 hours
  - **High**: Patch within 7 days
  - **Medium**: Patch within 30 days
  - **Low**: Addressed in next regular release

### Security Update Process

1. **Triage**: We evaluate the report and severity
2. **Fix Development**: We develop and test a fix
3. **Disclosure**: We coordinate disclosure timing
4. **Release**: We release the security patch
5. **Credit**: We credit the reporter (if desired)

## Security Best Practices for Users

### Authentication & Credentials

**NotebookLM Authentication:**
- Credentials are stored locally via `nlm login`
- Never commit credentials to git
- `.gitignore` excludes sensitive files by default

**File Exclusions:**
```
.env
*.key
*.pem
cookies.json
profiles/
```

### Script Execution Safety

**Before Running Scripts:**
1. Review script contents (they're bash/python, fully readable)
2. Check for unexpected network calls
3. Verify file paths in scripts

**Security Features:**
- All scripts use `set -euo pipefail` (fail-safe mode)
- No use of `eval` with user input
- Proper variable quoting prevents injection
- Input validation on parameters

### Template Safety

**When Using Templates:**
- Templates use `{{variable}}` interpolation
- No code execution in templates
- Variables are string-replaced, not evaluated

**Creating Custom Templates:**
- Keep templates in JSON format
- Don't include sensitive data in templates
- Review generated configs before execution

### Configuration Files

**Config File Safety:**
- Use JSON format (no code execution)
- Don't include API keys or passwords
- Review configs before use with `jq .`

**Example Safe Config:**
```json
{
  "title": "My Notebook",
  "sources": ["url:https://example.com"],
  "studio": [{"type": "quiz"}]
}
```

### Export Safety

**When Exporting Notebooks:**
- Exported files may contain notebook contents
- Review exports before sharing
- Be aware of what sources you included

### Web Search Features

**Smart Creation:**
- Uses DuckDuckGo and Wikipedia APIs
- Filters spam domains by default
- URL normalization removes tracking parameters

**Verified Safe:**
- No cookies required for searches
- No authentication tokens needed
- Read-only operations

## Known Limitations

### NotebookLM API

- Uses unofficial APIs (may change without notice)
- Requires Google account authentication
- Subject to NotebookLM's terms of service

### Command Injection Prevention

While we've implemented strong protections:
- Always review generated commands
- Don't run scripts from untrusted sources
- Keep your system updated

## Security Audit History

| Date | Auditor | Findings | Status |
|------|---------|----------|--------|
| 2026-02-07 | Code Review Agent | No critical issues | ✅ Resolved |

### Recent Security Improvements

- **2026-02-07**: Comprehensive security review
  - Verified no command injection vulnerabilities
  - Confirmed proper variable quoting throughout
  - Validated input sanitization
  - No use of dangerous commands (`eval`, `exec`)

## Responsible Disclosure

We believe in responsible disclosure and coordinate with security researchers to protect our users.

### Researcher Recognition

Security researchers who report valid vulnerabilities will be:
- Credited in release notes (if desired)
- Listed in a security acknowledgments section
- Eligible for swag/recognition (for significant findings)

## Questions?

For general security questions (not vulnerabilities):
- Open a GitHub issue with the `security` label
- Check existing security-related issues

Thank you for helping keep NotebookLM Automation secure! 🔒
