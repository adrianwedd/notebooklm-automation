# NotebookLM Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub last commit](https://img.shields.io/github/last-commit/adrianwedd/notebooklm-automation)](https://github.com/adrianwedd/notebooklm-automation/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/adrianwedd/notebooklm-automation)](https://github.com/adrianwedd/notebooklm-automation/issues)
[![GitHub stars](https://img.shields.io/github/stars/adrianwedd/notebooklm-automation)](https://github.com/adrianwedd/notebooklm-automation/stargazers)
![Bash](https://img.shields.io/badge/bash-%23121011.svg?style=flat&logo=gnu-bash&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=flat&logo=python&logoColor=ffdd54)

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

### Phase 2: Automation (✅ Complete)

- ✅ Create notebooks programmatically
- ✅ Add sources (URLs, text, Google Drive)
- ✅ Generate studio artifacts (9 types)
- ✅ End-to-end automation from JSON config
- ✅ Integration test suite
- ❌ File uploads (not supported by nlm CLI)
- ❌ Chat automation (reserved for interactive use)

### Phase 3: Maximum Impact (✅ Complete)

**Parallel Generation:**
- ✅ Concurrent artifact generation with progress monitoring
- ✅ Background job management and result aggregation
- ✅ `--parallel` flag for automate-notebook.sh

**Smart Notebook Creation:**
- ✅ Automated research from topics (web + Wikipedia)
- ✅ Quality source filtering and deduplication
- ✅ Configurable search depth
- ✅ Smart creation mode in automate-notebook.sh

**Template System:**
- ✅ JSON-driven templates with variable interpolation
- ✅ Pre-built templates (academic, learning, content)
- ✅ Category organization (research/learning/content)
- ✅ Template discovery and selection

**Multi-Format Export:**
- ✅ Obsidian vault structure with wikilinks
- ✅ Notion-compatible markdown
- ✅ Anki flashcard CSV import format

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

## Schemas

This repository includes JSON Schemas for config and template validation:

- `schemas/config.schema.json`
- `schemas/template.schema.json`

Validate a file locally with:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install jsonschema
./scripts/validate-json.sh --schema schemas/config.schema.json --file my-config.json
```

### export-notebook.sh

Export a single notebook by ID or name substring.

**Usage:**
```bash
./scripts/export-notebook.sh <notebook-id-or-name> [output-dir] [--format FORMAT]
```

**Examples:**
```bash
# By name substring (case-insensitive)
./scripts/export-notebook.sh "machine learning" ./exports

# By UUID
./scripts/export-notebook.sh "abc-123-def-456" ./exports
```

### Export Formats

Export notebooks in multiple formats for knowledge management tools.

**Usage:**
```bash
./scripts/export-notebook.sh <notebook-id> <output-dir> [--format FORMAT]
```

**Available formats:**

**Obsidian** - Vault structure with wikilinks
```bash
./scripts/export-notebook.sh abc-123 ./output --format obsidian

# Creates:
# output-obsidian/
# ├── README.md              # Overview with metadata and wikilinks
# ├── Sources/
# │   ├── 01-source.md      # Individual source notes
# │   └── 02-source.md
# └── Artifacts/
#     ├── quiz.md           # Artifact notes with links
#     └── files/
#         └── audio.mp3     # Actual artifact files
```

**Notion** - Single markdown with callouts
```bash
./scripts/export-notebook.sh abc-123 ./output --format notion

# Creates:
# output-notion/
# └── notebook-title.md     # Single file with > callouts
```

**Anki** - Flashcard CSV for import
```bash
./scripts/export-notebook.sh abc-123 ./output --format anki

# Creates:
# output-anki/
# └── anki-import.csv   # Front,Back,Tags format
```

**Features:**
- **Obsidian**: YAML frontmatter, wikilink navigation, backlinks
- **Notion**: Callout blocks, metadata headers, linked sources
- **Anki**: Quiz and flashcard extraction, tagged by notebook

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
./scripts/add-sources.sh <notebook-id> <source1> [source2] ... [--text-chunk-size N]
```

**Source types (auto-detected):**
- URLs: `https://example.com/article`
- Text content: `text:"Your content here"`
- Text file (chunked): `textfile:/path/to/file.txt`
- Google Drive: `drive://document-id`

**Note:** File uploads not supported by nlm CLI. Upload files to Google Drive first, then add via `drive://` prefix.

**Example:**
```bash
./scripts/add-sources.sh "abc-123-def-456" \
  "https://www.anthropic.com" \
  "text:Claude is an AI assistant" \
  "textfile:./long-notes.txt" \
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

### generate-parallel.sh

Generate multiple studio artifacts concurrently with progress monitoring.

**Usage:**
```bash
./scripts/generate-parallel.sh <notebook-id> <types...> [--wait] [--download DIR]
```

**Supported artifact types:**
- Space-separated: `quiz flashcards report`
- Comma-separated: `quiz,flashcards,report`

**Options:**
- `--wait` - Wait for all artifacts to complete with progress monitoring
- `--download <dir>` - Download all artifacts to directory (implies --wait)

**Features:**
- Concurrent generation for faster completion
- Real-time progress: "Progress: X/Y artifacts completed"
- Background job management with PID tracking
- Success/failure tracking with exit codes

**Example:**
```bash
# Generate 3 artifacts in parallel
./scripts/generate-parallel.sh "abc-123" quiz flashcards report --wait

# Output:
# === Parallel Artifact Generation ===
# Notebook: abc-123
# Artifacts: quiz flashcards report
# Count: 3
#
# Starting parallel generation...
#   Starting: quiz
#   Starting: flashcards
#   Starting: report
#
# Launched 3 parallel jobs
#
# Waiting for completion...
# Progress: 3/3 artifacts completed
#
# === Generation Complete ===
# Success: 3
# Failed:  0
```

**Performance:**
- 3 artifacts in parallel: ~60 seconds (vs 180 seconds sequential)
- Audio/video still take 2-10 minutes each (can't parallelize generation time)

### generate-studio.sh

Generate studio artifacts programmatically with polling until completion.

**Usage:**
```bash
./scripts/generate-studio.sh <notebook-id> <artifact-type>
```

**Supported artifact types:**
- `audio` - Audio overview (MP3, 2-10 minutes generation time)
- `video` - Video overview (MP4, 2-10 minutes)
- `report` - Written report (Markdown)
- `slides` - Presentation slides (PDF)
- `infographic` - Visual infographic (PNG)
- `mindmap` - Mind map diagram (JSON)
- `quiz` - Quiz questions (JSON, ~30 seconds)
- `flashcards` - Study flashcards (JSON, ~30 seconds)
- `data-table` - Data table (CSV, ~30 seconds)

**Features:**
- Automatic polling until generation completes
- Configurable timeout (default: 20 minutes)
- Downloads artifact to current directory
- Returns JSON with artifact details

**Example:**
```bash
# Generate quiz (fast, ~30 seconds)
./scripts/generate-studio.sh "abc-123-def-456" quiz

# Generate audio overview (slow, 2-10 minutes)
./scripts/generate-studio.sh "abc-123-def-456" audio
```

**Returns:** JSON with artifact ID and download path
```json
{
  "notebook_id": "abc-123-def-456",
  "artifact_type": "quiz",
  "artifact_id": "xyz-789",
  "status": "completed",
  "download_path": "./quiz-abc-123.json"
}
```

**Notes:**
- Notebook must have sources before generating artifacts
- Audio/video generation takes 2-10 minutes
- Quiz/flashcards typically complete in under 1 minute
- Script polls every 10 seconds until completion or timeout

### research-topic.sh

Automatically create research notebooks from topics with smart source discovery.

**Requires optional research dependencies:** `requests` + `ddgs` (only for smart research features).
```bash
pip3 install -r requirements-research.txt
```

**Usage:**
```bash
./scripts/research-topic.sh "<topic>" [--depth N] [--auto-generate TYPES] [--no-retry]
```

**Options:**
- `--depth <N>` - Number of sources to find (default: 3)
- `--auto-generate <types>` - Comma-separated artifact types to generate
- `--no-retry` - Disable retry/backoff for `nlm` operations

**Features:**
- DuckDuckGo web search for quality sources
- Wikipedia article discovery
- URL deduplication and normalization
- Spam domain filtering
- Automatic notebook creation and source addition

**Example:**
```bash
# Basic research with 3 sources
./scripts/research-topic.sh "quantum computing" --depth 3

# Deep research with artifacts
./scripts/research-topic.sh "machine learning basics" \
  --depth 10 \
  --auto-generate quiz,flashcards,report

# Output:
# === Smart Notebook Creation ===
# Topic: quantum computing
# Depth: 3 sources
#
# [1/3] Searching for sources...
#   Web search...
#   Wikipedia search...
#   Deduplicating sources...
#   Final: 3 unique sources
# [2/3] Creating notebook...
#   Created: abc-123-def-456
#   Adding sources...
#     Adding: https://quantum.example.com
#     Adding: https://en.wikipedia.org/wiki/Quantum_computing
# [3/3] No artifacts requested
#
# === Research Complete ===
# Notebook ID: abc-123-def-456
# URL: https://notebooklm.google.com/notebook/abc-123-def-456
```

### create-from-template.sh

Create notebooks from pre-built templates with variable substitution.

**Usage:**
```bash
./scripts/create-from-template.sh <template-id> [--var KEY=VALUE ...]
```

**Available templates:**
- `research/academic-paper` - Academic research (15 sources, 4 artifacts)
- `learning/course-notes` - Study guide (10 sources, 3 artifacts)
- `content/podcast-prep` - Interview research (8 sources, 2 artifacts)
- `content/presentation` - Presentation builder (12 sources, 3 artifacts)

**Example:**
```bash
# Academic research
./scripts/create-from-template.sh research/academic-paper \
  --var paper_topic="quantum entanglement"

# Course notes
./scripts/create-from-template.sh learning/course-notes \
  --var course_name="Python Programming"

# Podcast prep
./scripts/create-from-template.sh content/podcast-prep \
  --var guest_name="Richard Feynman" \
  --var topic="physics education"
```

**Template format:**
```json
{
  "title": "Research: {{paper_topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{paper_topic}} academic research papers",
    "depth": 15
  },
  "studio": [
    {"type": "report"},
    {"type": "mindmap"},
    {"type": "quiz"}
  ]
}
```

### automate-notebook.sh

End-to-end automation: create notebook, add sources, generate artifacts from JSON config.

**Usage:**
```bash
./scripts/automate-notebook.sh --config <config.json> [--export DIR] [--parallel]
```

**Options:**
- `--config <file>` - JSON configuration file (required)
- `--export <dir>` - Export notebook after generation (optional)
- `--parallel` - Generate artifacts in parallel (faster)

**Manual sources config:**
```json
{
  "title": "Notebook Title",
  "sources": [
    "https://example.com/article",
    "text:Some content here",
    "drive://document-id"
  ],
  "studio": [
    {"type": "quiz"},
    {"type": "report"}
  ]
}
```

**Smart creation config:**
```json
{
  "title": "Machine Learning Fundamentals",
  "smart_creation": {
    "enabled": true,
    "topic": "machine learning basics",
    "depth": 10
  },
  "studio": [
    {"type": "quiz"},
    {"type": "flashcards"},
    {"type": "report"}
  ]
}
```

**Smart creation features:**
1. Web search (DuckDuckGo) for quality sources
2. Wikipedia article discovery
3. URL deduplication and normalization
4. Automatic notebook creation
5. Source addition with retry logic
6. Artifact generation (parallel with `--parallel` flag)

**Features:**
- Creates notebook from title
- Manual or smart source addition
- Generates artifacts sequentially or in parallel
- Exports final notebook to directory
- Returns comprehensive JSON summary

**Example:**
```bash
# Create automation config
cat > my-research.json <<EOF
{
  "title": "AI Research Notes",
  "sources": [
    "https://www.anthropic.com/news/claude-3-5-sonnet",
    "text:Claude 3.5 Sonnet represents a significant advancement in AI capabilities"
  ],
  "artifacts": ["quiz", "report"]
}
EOF

# Run automation
./scripts/automate-notebook.sh my-research.json ./exports
```

**Returns:** Complete automation summary
```json
{
  "notebook_id": "abc-123-def-456",
  "title": "AI Research Notes",
  "sources_added": 2,
  "sources_failed": 0,
  "artifacts_generated": 2,
  "artifacts_failed": 0,
  "export_path": "./exports/ai-research-notes",
  "total_time_seconds": 127
}
```

**Notes:**
- Total time depends on artifact types (audio/video add 2-10 min each)
- Quiz/flashcards generation: ~30 seconds
- Audio/video generation: 2-10 minutes each
- Script handles all errors and provides detailed status

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

### Studio Generation Issues

**Generation hangs or times out:**
- Audio/video generation takes 2-10 minutes
- Quiz/flashcards typically under 1 minute
- Check status manually: `nlm status artifacts <notebook-id>`
- Increase timeout if needed (edit MAX_ATTEMPTS in script)

**Artifact not created:**
- Verify notebook has sources: `nlm source list <notebook-id>`
- Some artifacts require minimum content length
- Check for NotebookLM quota limits

**Download fails:**
- Artifact may still be generating
- Some artifact types may not support download via CLI
- Download manually from NotebookLM web interface

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
- ✅ Generate quiz artifact (completed in 45s)
- ✅ Generate audio artifact (completed in 2m15s)
- ✅ End-to-end automation (notebook + sources + artifacts)
- ✅ Export integration (full workflow with export)
- ✅ Integration test suite (5/5 tests passing)

Phase 3 maximum impact tests (2026-02-07):
- ✅ Parallel generation (3 artifacts in 60s vs 180s sequential)
- ✅ Progress monitoring (real-time updates every 2 seconds)
- ✅ Web search (DuckDuckGo quality source discovery)
- ✅ Wikipedia integration (OpenSearch API)
- ✅ URL deduplication (normalize www, trailing slash, tracking params)
- ✅ Smart creation (automated research from topic)
- ✅ Template system (variable interpolation and discovery)
- ✅ Pre-built templates (4 templates: research/learning/content)
- ✅ Obsidian export (vault structure with wikilinks)
- ✅ Notion export (single markdown with callouts)
- ✅ Anki export (flashcard CSV import)
- ✅ End-to-end validation (template → smart creation → artifacts → export)
  - Template: learning/course-notes
  - Topic: "Python Programming"
  - Result: 5 sources discovered, 3 artifacts generated, 100% success rate

## License

This project uses an unofficial reverse-engineered API. Use at your own risk.

## Credits

Built with:
- [notebooklm-mcp-cli](https://github.com/jacob-bd/notebooklm-mcp-cli) by jacob-bd
- Claude Sonnet 4.5 for implementation assistance
