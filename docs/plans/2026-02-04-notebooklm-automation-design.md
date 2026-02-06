# NotebookLM Automation: Solution Design & Implementation Plan

## Problem Statement

Google NotebookLM provides rich content generation (audio overviews, video explainers, mind maps, reports, flashcards, quizzes, infographics, slide decks, data tables) from uploaded sources, but offers no built-in bulk export, no scriptable automation, and no way to programmatically create notebooks or generate studio content. We need:

1. **Export**: Pull all generated materials, sources, chat history, and notes from existing notebooks
2. **Create**: Programmatically create notebooks, add source files, and configure them
3. **Generate**: Trigger studio content generation and download results
4. **Chat**: Interact with notebook chat programmatically
5. **Batch operations**: Apply the above across multiple notebooks

## Constraints

- **Consumer NotebookLM** (notebooklm.google.com) — no Enterprise/Cloud API access
- **No official API** for consumer tier — the Enterprise API (`discoveryengine.googleapis.com/v1alpha`) requires Google Cloud project + Enterprise licensing and only covers notebook/source CRUD anyway (no studio generation, no chat, no content export)
- **Internal RPC architecture**: NotebookLM uses Google's `batchexecute` pattern — a single POST endpoint (`/_/LabsTailwindUi/data/batchexecute`) with obfuscated RPC method IDs (e.g., `cFji9`, `wXbhsf`, `R7cb6c`, `gArtLc`)
- **Authentication**: Consumer NotebookLM uses Google session cookies, not API keys

## Architecture Decision

### Options Evaluated

| Approach | Coverage | Stability | Scriptable | Claude-integrated |
|----------|----------|-----------|------------|-------------------|
| Official Enterprise API | Partial (no studio/chat/export) | Stable (alpha) | Yes | Possible |
| `notebooklm-py` (Python) | Full | Fragile (undocumented RPCs) | Yes | No (needs wrapper) |
| `notebooklm-mcp-cli` | Full | Fragile (undocumented RPCs) | Yes (CLI) | Yes (MCP server) |
| Browser automation (Chrome) | Full | Fragile (UI changes) | Partially | Yes |

### Selected: `notebooklm-mcp-cli` + Claude Skills

**Rationale**: This package uniquely provides both a CLI (`nlm`) for standalone scripting AND an MCP server (`notebooklm-mcp`) for Claude integration — satisfying the "parallel implementations" requirement with a single dependency. It uses the same undocumented RPCs as `notebooklm-py` but adds the MCP layer.

**Risk mitigation**: The undocumented RPCs can break at any time. We mitigate by:
- Pinning to a known-working version
- Keeping browser automation as a fallback path
- Structuring skills to be transport-agnostic where possible

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Skills Layer                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ │
│  │  export   │ │  create  │ │ generate │ │    chat    │ │
│  │ notebook  │ │ notebook │ │  studio  │ │            │ │
│  └─────┬─────┘ └─────┬────┘ └─────┬────┘ └─────┬──────┘ │
│        │             │            │             │        │
│  ┌─────▼─────────────▼────────────▼─────────────▼──────┐ │
│  │              Orchestration Logic                     │ │
│  │   (compose MCP tools, handle polling, retries)      │ │
│  └─────────────────────┬───────────────────────────────┘ │
└────────────────────────┼────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
    ┌─────▼─────┐  ┌────▼────┐  ┌──────▼──────┐
    │ MCP Server │  │   CLI   │  │   Browser   │
    │ (notebooklm│  │  (nlm)  │  │  Automation │
    │   -mcp)    │  │         │  │  (fallback) │
    └─────┬──────┘  └────┬────┘  └──────┬──────┘
          │              │              │
          └──────────────┼──────────────┘
                         │
              ┌──────────▼──────────┐
              │  Google NotebookLM  │
              │  batchexecute RPCs  │
              │  (session cookies)  │
              └─────────────────────┘
```

## Export Format Specification

Each exported notebook produces a self-contained directory:

```
exports/<notebook-slug>/
├── metadata.json            # Notebook metadata, source list, timestamps
├── sources/
│   ├── index.json           # Source manifest with IDs, types, titles
│   ├── <source-1>.pdf       # Original source files where downloadable
│   ├── <source-2>.txt       # Text sources
│   └── <source-n>.md        # Source guides / summaries from NotebookLM
├── chat/
│   ├── history.json         # Full chat Q&A pairs with timestamps
│   └── history.md           # Human-readable markdown version
├── notes/
│   ├── index.json           # Note manifest
│   └── <note-title>.md      # Individual notes as markdown
└── studio/
    ├── manifest.json         # All generated artifacts with metadata
    ├── audio/
    │   ├── <title>.mp3       # Audio overviews
    │   └── <title>.json      # Transcript + metadata
    ├── video/
    │   ├── <title>.mp4       # Video overviews
    │   └── <title>.json      # Metadata
    ├── documents/
    │   ├── <title>.pdf       # Reports, slide decks
    │   └── <title>.md        # Markdown fallback
    ├── visual/
    │   ├── <title>.png       # Infographics, mind maps
    │   └── <title>.json      # Structured data
    └── interactive/
        ├── flashcards.json   # Structured flashcard data
        ├── quiz.json         # Structured quiz data
        └── data-table.csv    # Tabular data
```

## Skill Designs

### Skill 1: `notebooklm:export-notebook`

**Purpose**: Export all content from a single notebook to local filesystem.

**Inputs**:
- Notebook name or ID (or "current" if in browser context)
- Output directory (default: `./exports/<notebook-slug>/`)
- What to export: `all` | subset of `[sources, chat, notes, studio]`

**Workflow**:
1. Resolve notebook ID (list notebooks, match by name)
2. Fetch notebook metadata
3. List and download sources (original files + source guides)
4. Fetch chat history, format as JSON + markdown
5. List and download notes
6. List studio artifacts, download each by type (mp3/mp4/pdf/png/csv/json)
7. Write manifest files (metadata.json, index.json, manifest.json)

**CLI equivalent** (for scripting):
```bash
nlm notebooks list
nlm notebook <id> sources list
nlm notebook <id> artifacts list
nlm notebook <id> artifacts download --all --output ./exports/<slug>/studio/
```

### Skill 2: `notebooklm:create-notebook`

**Purpose**: Create a new notebook and populate it with sources.

**Inputs**:
- Notebook title
- Source files: list of local file paths, URLs, YouTube links, or text content
- Chat configuration: goal (default/learning-guide/custom), response length, custom instructions

**Workflow**:
1. Create notebook with title
2. For each source:
   - Local files: upload via file upload API
   - URLs: add via web source API
   - YouTube: add via video source API
   - Text: add via text content API
3. Configure chat settings if non-default
4. Return notebook ID and URL

**CLI equivalent**:
```bash
nlm notebook create --title "My Research"
nlm notebook <id> sources add-file paper1.pdf paper2.pdf
nlm notebook <id> sources add-url https://example.com/article
```

### Skill 3: `notebooklm:generate-studio`

**Purpose**: Generate studio content and download results.

**Inputs**:
- Notebook name or ID
- Content types to generate: `all` | subset of `[audio, video, mind-map, report, flashcards, quiz, infographic, slide-deck, data-table]`
- Source selection: which sources to include (default: all)
- Custom instructions for generation (optional)
- Download after generation: yes/no

**Workflow**:
1. Resolve notebook ID
2. For each requested content type:
   a. Trigger generation via appropriate RPC
   b. Poll for completion (generation can take minutes for audio/video)
   c. On completion, download artifact to local filesystem
3. Write manifest with metadata for all generated items

**Polling strategy**: Check every 10 seconds, timeout after 10 minutes per artifact, generate multiple types in parallel where possible.

**CLI equivalent**:
```bash
nlm notebook <id> generate audio --sources all
nlm notebook <id> generate video
nlm notebook <id> artifacts download --latest --output ./studio/
```

### Skill 4: `notebooklm:chat`

**Purpose**: Send messages to notebook chat and capture responses.

**Inputs**:
- Notebook name or ID
- Message(s) to send (single string or list for batch)
- Source selection: which sources to query against
- Save responses as notes: yes/no
- Output file for conversation log (optional)

**Workflow**:
1. Resolve notebook ID
2. Select sources if subset specified
3. Send message via chat RPC
4. Capture response with citations
5. Optionally save response as a note
6. Append to conversation log file

**CLI equivalent**:
```bash
nlm notebook <id> chat "What are the key findings?"
nlm notebook <id> chat --save-as-note "Summarize methodology"
```

### Skill 5: `notebooklm:batch-export`

**Purpose**: Export multiple (or all) notebooks.

**Inputs**:
- Filter: `all` | list of notebook names/IDs | date range
- Output base directory
- What to export per notebook (same options as export-notebook)

**Workflow**:
1. List all notebooks
2. Apply filter
3. For each matching notebook, run export-notebook workflow
4. Write top-level index: `exports/index.json` with notebook manifest
5. Report summary (notebooks exported, total artifacts, any failures)

## Scripts (Standalone Automation)

### `scripts/setup.sh`
```bash
# Install notebooklm-mcp-cli
pip install notebooklm-mcp-cli  # or npm, depending on package manager

# Authenticate (opens Chrome for Google login)
nlm auth login

# Verify
nlm notebooks list
```

### `scripts/export-all.sh`
Standalone bash script that uses `nlm` CLI to export all notebooks without requiring Claude. Useful for cron jobs, CI, or manual bulk export.

### `scripts/create-and-generate.sh`
Template script for the common workflow: create notebook -> add sources -> generate all studio content -> download.

## Implementation Plan

### Phase 1: Foundation (setup + export)
1. Install and configure `notebooklm-mcp-cli`
2. Verify authentication and basic CLI operations
3. Register MCP server in Claude Code config
4. Write `notebooklm:export-notebook` skill
5. Write `scripts/export-all.sh` standalone script
6. Test: export one notebook, verify directory structure

### Phase 2: Creation + Generation
7. Write `notebooklm:create-notebook` skill
8. Write `notebooklm:generate-studio` skill
9. Write `scripts/create-and-generate.sh`
10. Test: create notebook from local PDFs, generate all studio types, download

### Phase 3: Chat + Batch
11. Write `notebooklm:chat` skill
12. Write `notebooklm:batch-export` skill
13. Test: interactive chat session, batch export of all notebooks

### Phase 4: Hardening
14. Add error handling and retry logic to skills
15. Add progress reporting for long-running operations
16. Document usage in project README
17. Test edge cases (large notebooks, failed generations, auth expiry)

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Undocumented RPCs change/break | High | Medium | Pin version, keep browser automation fallback, monitor `notebooklm-mcp-cli` releases |
| Auth cookies expire mid-export | Medium | Medium | Auto-refresh logic in mcp-cli, skill retry with re-auth prompt |
| Studio generation times out | Medium | Low | Configurable timeout, skip-and-continue for batch ops |
| Rate limiting on bulk operations | Medium | Medium | Add delays between requests, configurable concurrency |
| `notebooklm-mcp-cli` abandoned | High | Low | Fork capability, `notebooklm-py` as alternative backend |

## Key References

- [NotebookLM Enterprise API: Notebooks](https://docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks)
- [NotebookLM Enterprise API: Sources](https://docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks-sources)
- [notebooklm-py (Python, unofficial)](https://github.com/teng-lin/notebooklm-py)
- [notebooklm-mcp-cli (MCP + CLI)](https://github.com/jacob-bd/notebooklm-mcp-cli)
- [nblm-rs (Rust/Python, unofficial)](https://github.com/K-dash/nblm-rs)
- [Apify NotebookLM exporter](https://apify.com/clearpath/notebooklm-api)
