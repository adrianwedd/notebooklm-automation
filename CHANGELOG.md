# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Planned: GitHub Actions workflows for CI/CD (not yet added)
- Comprehensive issue templates
- Security policy documentation
- Contributing guidelines
- Claude Code project context (CLAUDE.md)

## [0.3.0] - 2026-02-07 - Phase 3: Maximum Impact

### Added
- **Parallel Artifact Generation**
  - Generate multiple artifacts concurrently with `--parallel` flag
  - Real-time progress monitoring
  - 67% faster generation for 3+ artifacts
  - Background job management with proper cleanup

- **Smart Notebook Creation**
  - Automated topic research with `research-topic.sh`
  - DuckDuckGo web search integration
  - Wikipedia API integration
  - URL deduplication and normalization
  - Spam domain filtering
  - Smart creation mode in `automate-notebook.sh`

- **Template System**
  - JSON-driven templates with `{{variable}}` interpolation
  - Template discovery and listing
  - Category organization (research, learning, content)
  - 4 pre-built templates:
    - Academic research (15 sources, 4 artifacts)
    - Course notes (10 sources, 3 artifacts)
    - Podcast prep (8 sources, 2 artifacts)
    - Presentation (12 sources, 3 artifacts)

- **Multi-Format Export**
  - Obsidian export with wikilinks and vault structure
  - Notion export with markdown and callouts
  - Anki export with flashcard CSV format
  - `--format` flag for export-notebook.sh

### New Scripts
- `scripts/generate-parallel.sh` - Parallel artifact generation
- `scripts/research-topic.sh` - Automated topic research
- `scripts/create-from-template.sh` - Template instantiation

### New Libraries
- `lib/web_search.py` - DuckDuckGo integration
- `lib/wikipedia_search.py` - Wikipedia API client
- `lib/deduplicate_sources.py` - URL normalization
- `lib/template_engine.py` - Template rendering
- `lib/export_obsidian.py` - Obsidian vault exporter
- `lib/export_notion.py` - Notion markdown exporter
- `lib/export_anki.py` - Anki CSV exporter

### Changed
- Updated `automate-notebook.sh` with `--parallel` flag
- Updated `automate-notebook.sh` with smart creation support
- Updated `export-notebook.sh` with multi-format support
- Enhanced README.md with Phase 3 features and examples

## [0.2.0] - 2026-02-06 - Phase 2: Automation Workflows

### Added
- **Batch Automation**
  - Configuration-driven notebook creation
  - JSON config file support
  - Automatic source addition from URLs and text
  - Studio artifact generation automation
  - Export integration

- **Integration Testing**
  - Comprehensive test suite (`tests/integration-test.sh`)
  - 5 test scenarios covering all workflows
  - Automatic cleanup of test resources
  - CI-friendly test structure

- **Enhanced Export**
  - Continue-on-error flag for batch exports
  - Progress tracking during exports
  - Better error reporting

### New Scripts
- `scripts/automate-notebook.sh` - Main automation workflow
- `tests/integration-test.sh` - Integration test suite

### Changed
- Improved `export-all.sh` with `--continue-on-error` flag
- Enhanced error handling across all scripts
- Better logging and user feedback

### Fixed
- JSON parsing robustness in automation scripts
- Status extraction from generate-studio.sh
- Command injection prevention in automation workflows

## [0.1.0] - 2026-02-04 - Phase 1: Export Foundation

### Added
- **Core Export Functionality**
  - Export complete notebooks to local directory structure
  - Source content extraction and preservation
  - Notes and metadata export
  - Studio artifact downloads (Audio, Video, Reports, etc.)

- **Batch Export**
  - Export all notebooks with single command
  - Parallel export support
  - Progress tracking

### New Scripts
- `scripts/export-notebook.sh` - Single notebook export
- `scripts/export-all.sh` - Batch export all notebooks
- `scripts/create-notebook.sh` - Create new notebooks
- `scripts/add-sources.sh` - Add sources to notebooks
- `scripts/generate-studio.sh` - Generate studio artifacts

### Infrastructure
- Initial repository structure
- Integration with `nlm` CLI
- Basic error handling
- Shell script best practices (set -euo pipefail)

## [0.0.1] - 2026-02-03 - Initial Setup

### Added
- Project initialization
- Basic repository structure
- README with project overview
- MIT License
- .gitignore configuration

---

## Release Strategy

### Versioning
- **Major (X.0.0)**: Breaking changes or major feature sets
- **Minor (0.X.0)**: New features, backwards compatible
- **Patch (0.0.X)**: Bug fixes, minor improvements

### Release Phases
- **Phase 1 (0.1.0)**: Export functionality
- **Phase 2 (0.2.0)**: Automation workflows
- **Phase 3 (0.3.0)**: Advanced features (parallel, smart, templates, export formats)
- **Future**: API improvements, additional integrations, performance optimizations

### Links
[Unreleased]: https://github.com/adrianwedd/notebooklm-automation/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/adrianwedd/notebooklm-automation/releases/tag/v0.3.0
[0.2.0]: https://github.com/adrianwedd/notebooklm-automation/releases/tag/v0.2.0
[0.1.0]: https://github.com/adrianwedd/notebooklm-automation/releases/tag/v0.1.0
[0.0.1]: https://github.com/adrianwedd/notebooklm-automation/releases/tag/v0.0.1
