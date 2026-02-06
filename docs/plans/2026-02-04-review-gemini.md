# Gemini Review: NotebookLM Automation Design

**Reviewer**: Gemini 3 Pro
**Date**: 2026-02-04

---

## 1. Executive Summary

The proposed stack attempts to bridge the gap between a consumer product (NotebookLM) and automated workflows by mimicking a user's browser traffic.

- **Verdict**: Fragile / Hobbyist Only.
- **Primary Issue**: Reliance on Google's internal `batchexecute` protocol. This is not a public API; it is an obfuscated, undocumented internal transport layer that changes frequently.
- **Suitability**: Acceptable for a personal "hacker" project or prototype. Unacceptable for production, business-critical workflows, or any system requiring >90% uptime.

## 2. Architectural Analysis

### The Core: `notebooklm-mcp-cli` & `batchexecute`

The solution relies on a CLI tool that manually constructs `batchexecute` payloads (Google's internal RPC format, usually consisting of deeply nested arrays and JSON serialization).

- **The Mechanism**: The tool likely scrapes a specific token (like `FdrFJe`) from the HTML source and POSTs form-data to `/_/NotebookLibService/UpdateNotebook`.
- **The Problem**: These payloads rely on specific array indices (e.g., `payload[0][2]`). If Google updates the frontend client to push a new feature, the array indices shift. Automation will break instantly and silently.
- **No Error Contracts**: Internal RPCs do not return standard HTTP error codes for logic failures. They often return a `200 OK` with a garbled JSON payload containing the error deep inside a nested structure.

### The Orchestration: Claude Code vs. Bash

**Claude Code (MCP)**:
- Pros: Excellent for semantic tasks (e.g., "Read the CLI output, determine if the summary is good, if not, re-prompt"). It handles the "fuzziness" of GenAI outputs well.
- Cons: Expensive and slow for deterministic tasks. Using an LLM to orchestrate a CLI for simple file uploads is overkill.

**Bash Scripts**:
- Pros: Fast, cheap.
- Cons: Brittle parsing. If the CLI output changes slightly or includes a Google warning banner, `grep/awk` chains will fail.

## 3. Critical Risks & Blockers

### A. Authentication Rot (The "Cookie" Problem)

Consumer Google services do not support Service Accounts or API Keys.

- **The Requirement**: You must extract `__Secure-1PSID`, `__Secure-1PSIDTS`, and other cookies from a logged-in browser session.
- **The Friction**: These cookies expire or rotate. If you run this script too frequently or from a data center IP (like AWS/GCP), Google will invalidate the session or throw a CAPTCHA.
- **Impact**: You cannot "set and forget" this. You will need to manually re-authenticate and update environment variables regularly.

### B. Terms of Service & Account Ban

- **ToS Violation**: Automating the consumer interface via reverse engineering violates Google's Terms of Service.
- **Risk**: Google has sophisticated bot detection. If they detect non-human behavior (e.g., impossible request speeds, lack of mouse movements/telemetry usually sent with the RPCs), they may suspend the associated Google Account.
- **Mitigation**: Never use your primary personal or business Google account for this. Use a "burner" account.

### C. Feature Limitations

- **Uploads**: Uploading PDFs/Sources via `batchexecute` is significantly harder than text queries. It often involves a multi-stage request (upload to a staging blob storage -> get ID -> link ID to Notebook). The CLI tool may not support this reliably.
- **Audio**: If your goal is to extract the generated "Audio Overview," note that the generation is asynchronous. The CLI must implement polling logic to check when the WAV/MP3 is ready, which consumes quota and increases ban risk.

## 4. Strategic Recommendations

### Defensive Implementation

1. **Isolation**: Run this exclusively on a burner Google Account dedicated to this task.
2. **Rate Limiting**: Do not loop the CLI. Implement random `sleep` intervals (e.g., 30-90 seconds) between requests to mimic human latency.
3. **Hybrid Orchestration**: Use Bash for the "dumb" plumbing (cron jobs, file movement). Use Claude only for the cognitive layer (synthesizing the output after the CLI retrieves it), not for driving the CLI itself unless necessary.

### The "Browser Automation" Alternative

Consider replacing the `batchexecute` reverse engineering with Puppeteer or Playwright (running in headful or stealth-headless mode).

- **Why**: Instead of guessing RPC payloads, you script the UI interaction. More robust to backend API changes.
- **Benefit**: If Google changes the RPC protocol but keeps the UI button, browser automation still works.
- **Cost**: Slower and heavier, but significantly more stable for long-term maintenance.

### The "Enterprise" Path

If this is for a business use case — wait for the official Google Gemini API features that mirror NotebookLM (Context Caching + Gemini 1.5 Pro). You can recreate 90% of NotebookLM's functionality (RAG over documents) using the standard Vertex AI or Gemini API, which has an SLA and won't get you banned.
