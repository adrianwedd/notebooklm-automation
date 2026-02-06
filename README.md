# NotebookLM Automation

Automation tools for exporting and interacting with Google NotebookLM notebooks via unofficial APIs.

## Quick Start

### 1. Install CLI Tool

```bash
pip install notebooklm-mcp-cli
```

### 2. Authenticate

```bash
nlm login
```

This opens Chrome to extract authentication cookies. You'll see:
```
✓ Successfully authenticated!
  Profile: default
  Cookies: 42 extracted
  Account: your-email@gmail.com
```

### 3. Export Notebooks

**Single notebook:**
```bash
./scripts/export-notebook.sh "notebook name" ./exports
```

**All notebooks:**
```bash
./scripts/export-all.sh ./exports --continue-on-error
```

## Features

### Phase 1: Export (✅ Complete)

Export NotebookLM notebooks to local directory structures:

- ✅ Sources with content extraction
- ✅ Notes and metadata
- ✅ Studio artifacts:
  - Audio overviews (MP3)
  - Video overviews (MP4)
  - Reports (Markdown)
  - Slide decks (PDF)
  - Infographics (PNG)
  - Mind maps (JSON)
  - Quizzes, flashcards, data tables (JSON/CSV)
- ❌ Chat history (not supported by API)

### Phase 2: Automation (Partial - In Progress)

- ✅ Create notebooks programmatically
- ✅ Add sources (URLs, text, Google Drive)
- ⏳ Generate studio artifacts (planned)
- ⏳ End-to-end automation (planned)
- ❌ File uploads (not supported by nlm CLI)
- ❌ Chat automation (reserved for interactive use)

## Export Structure

```
exports/
└── notebook-slug/
    ├── metadata.json           # Notebook metadata
    ├── sources/
    │   ├── index.json         # Source list
    │   └── *.md               # Source content
    ├── chat/
    │   └── index.json         # Empty (API limitation)
    ├── notes/
    │   ├── index.json         # Notes list
    │   └── *.md               # Individual notes
    └── studio/
        ├── manifest.json      # Artifact list
        ├── audio/
        │   └── *.mp3         # Audio overviews
        ├── video/
        │   └── *.mp4         # Video overviews
        ├── documents/
        │   ├── *.md          # Reports
        │   └── *.pdf         # Slide decks
        ├── visual/
        │   ├── *.png         # Infographics
        │   └── *.json        # Mind maps
        └── interactive/
            ├── *-quiz.json   # Quizzes
            ├── *-flashcards.json  # Flashcards
            └── *-data-table.csv   # Data tables
```

## Scripts

### export-notebook.sh

Export a single notebook by ID or name substring.

**Usage:**
```bash
./scripts/export-notebook.sh <notebook-id-or-name> [output-dir]
```

**Examples:**
```bash
# By name substring (case-insensitive)
./scripts/export-notebook.sh "machine learning" ./exports

# By UUID
./scripts/export-notebook.sh "abc-123-def-456" ./exports
```

### export-all.sh

Batch export all notebooks with progress tracking.

**Usage:**
```bash
./scripts/export-all.sh [output-dir] [--continue-on-error]
```

**Features:**
- Progress tracking (N/total)
- Skip already-exported notebooks
- Error handling with --continue-on-error
- Final summary with statistics

**Example:**
```bash
./scripts/export-all.sh ./exports --continue-on-error
```

Output:
```
=== NotebookLM Batch Export ===
Found 80 notebooks to export

[1/80] Exporting: Machine Learning Fundamentals
  [✓] Export complete

[2/80] Exporting: ADHD Research Notes
  [↷] Already exported, skipping

...

=== Export Complete ===
Total notebooks:  80
Successful:       78
Errors:           2
Skipped:          12
Total size:       12.4 GB
```

### create-notebook.sh

Create a new NotebookLM notebook programmatically.

**Usage:**
```bash
./scripts/create-notebook.sh "Notebook Title"
```

**Returns:** JSON with notebook ID
```json
{
  "id": "abc-123-def-456",
  "title": "Notebook Title",
  "sources_added": 0
}
```

**Example:**
```bash
# Create notebook and capture ID
NOTEBOOK_ID=$(./scripts/create-notebook.sh "My Research" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Created: $NOTEBOOK_ID"
```

### add-sources.sh

Add sources to an existing notebook with automatic type detection.

**Usage:**
```bash
./scripts/add-sources.sh <notebook-id> <source1> [source2] ...
```

**Source types (auto-detected):**
- URLs: `https://example.com/article`
- Text content: `text:"Your content here"`
- Google Drive: `drive://document-id`

**Note:** File uploads not supported by nlm CLI. Upload files to Google Drive first, then add via `drive://` prefix.

**Example:**
```bash
./scripts/add-sources.sh "abc-123-def-456" \
  "https://www.anthropic.com" \
  "text:Claude is an AI assistant" \
  "drive://1A2B3C4D5E"
```

**Returns:** JSON with success counts
```json
{
  "notebook_id": "abc-123-def-456",
  "sources_added": 3,
  "sources_failed": 0
}
```

## Claude Code Integration

A Claude Code skill is available for interactive exports:

```
/export-notebook
```

The skill provides:
- Interactive notebook selection
- Progress feedback
- Error handling
- Summary of exported content

## Architecture

### Stack

1. **notebooklm-mcp-cli**: Python CLI that reverse-engineers NotebookLM's internal `batchexecute` RPC protocol
2. **Export scripts**: Bash scripts orchestrating CLI operations
3. **Claude skill**: Interactive wrapper for Claude Code users

### Authentication

Cookie-based authentication via Chrome DevTools Protocol:
- Extracts `__Secure-1PSID` and other session cookies
- Stores in `~/.notebooklm-mcp-cli/profiles/default`
- Requires re-authentication when cookies expire

### API Endpoints

Internal RPC endpoints (reverse-engineered):
- `/NotebookLibService/*` - Notebook CRUD
- `/LabsTailwindUi/GenerateFreeFormStreamed` - Chat queries
- `/NotebookLibService/CreateAudio` - Studio audio generation
- Various studio endpoints for other artifact types

## Known Limitations

### Chat History
NotebookLM's internal API does not expose historical chat conversations. The `chat/` directory will contain only an empty `index.json`. Chat history appears to be:
- Stored client-side in the web UI, or
- In a database not accessible via the `batchexecute` endpoint

The CLI's conversation cache is only for maintaining context during active chat sessions, not for retrieving past conversations.

### API Fragility
The tool uses reverse-engineered RPCs that:
- Are undocumented and unsupported by Google
- May break with any NotebookLM frontend update
- Return errors in non-standard formats
- Require specific array indices that can shift

### Rate Limiting
Batch exports may trigger rate limits:
- Slow down requests if seeing errors
- Use `--continue-on-error` to skip failures
- Consider exporting incrementally

### Terms of Service
Using unofficial APIs violates Google's ToS:
- Use a dedicated/burner Google account
- Don't use your primary work/personal account
- Google may suspend accounts detected as automated

## Troubleshooting

### Authentication Errors

```bash
# Re-authenticate
nlm login

# Verify authentication
nlm notebook list
```

### Export Failures

```bash
# Check individual notebook
nlm get notebook <notebook-id>

# Test source access
nlm source list <notebook-id>

# Verify studio artifacts
nlm list artifacts <notebook-id>
```

### Slow Exports

Large notebooks with many artifacts (especially audio/video) can take time:
- Audio overviews: 20-60MB each
- Video overviews: 30-100MB each
- Consider selective exports for testing

## Documentation

- `docs/plans/2026-02-04-notebooklm-automation-design.md` - Architecture and implementation plan
- `docs/plans/2026-02-04-review-gemini.md` - External review (Gemini 3 Pro)
- `docs/plans/2026-02-04-review-codex.md` - External review (GPT-5.1-Codex)

## Testing

Smoke tests verified (2026-02-06):
- ✅ Authentication (42 cookies extracted)
- ✅ List notebooks (80 found)
- ✅ List sources (8 sources in test notebook)
- ✅ List artifacts (9 artifacts in test notebook)
- ✅ Download audio (42MB MP3 downloaded)
- ✅ Export notebook (323MB with 8 artifacts)
- ✅ Source content extraction (5-50KB per source)

Phase 2 automation tests (2026-02-06):
- ✅ Create notebook (returns valid UUID)
- ✅ Add URL source (successfully added)
- ✅ Add text source (successfully added)
- ✅ Add Drive source (not tested - no Drive file available)
- ✅ JSON output (properly escaped)
- ✅ Error handling (proper exit codes)

## License

This project uses an unofficial reverse-engineered API. Use at your own risk.

## Credits

Built with:
- [notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli) by jacob-bd
- Claude Sonnet 4.5 for implementation assistance
