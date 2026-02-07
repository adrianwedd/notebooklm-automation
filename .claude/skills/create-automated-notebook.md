---
name: create-automated-notebook
description: Create a NotebookLM notebook with automated workflows
---

Use this skill when the user wants to create a new notebook with sources and artifacts.

## Workflow

### Option 1: Using Configuration File (Recommended)

1. **Create JSON configuration**:
   ```json
   {
     "title": "Notebook Title",
     "sources": [
       "url:https://example.com",
       "text:Direct text content"
     ],
     "studio": [
       {"type": "quiz"},
       {"type": "summary"}
     ]
   }
   ```

2. **Run automation**:
   ```bash
   ./scripts/automate-notebook.sh --config /path/to/config.json
   ```

3. **Optional: Export immediately**:
   ```bash
   ./scripts/automate-notebook.sh --config config.json --export ./output
   ```

### Option 2: Smart Creation (Research Mode)

1. **Create config with smart creation**:
   ```json
   {
     "title": "Research: Topic Name",
     "smart_creation": {
       "enabled": true,
       "topic": "quantum computing basics",
       "depth": 10
     },
     "studio": [
       {"type": "quiz"},
       {"type": "flashcards"}
     ]
   }
   ```

2. **Run automation** (it will auto-research sources):
   ```bash
   ./scripts/automate-notebook.sh --config config.json
   ```

### Option 3: Using Templates

1. **List available templates**:
   ```bash
   ./scripts/create-from-template.sh
   ```

2. **Create from template**:
   ```bash
   # Academic research
   ./scripts/create-from-template.sh research/academic-paper \
     --var paper_topic="quantum entanglement"

   # Course notes
   ./scripts/create-from-template.sh learning/course-notes \
     --var course_name="Machine Learning"

   # Podcast prep
   ./scripts/create-from-template.sh content/podcast-prep \
     --var guest_name="Expert Name" \
     --var topic="AI Safety"
   ```

### Option 4: Research-Only

1. **Quick research without full automation**:
   ```bash
   ./scripts/research-topic.sh "artificial intelligence" --depth 10
   ```

2. **With auto-generation**:
   ```bash
   ./scripts/research-topic.sh "machine learning" \
     --depth 10 \
     --auto-generate quiz,summary
   ```

## Parallel Generation

For faster artifact generation (3+ artifacts):

```bash
./scripts/automate-notebook.sh --config config.json --parallel
```

**Performance:**
- Sequential: ~180 seconds for 3 artifacts
- Parallel: ~60 seconds for 3 artifacts (67% faster)

## Configuration Options

### Source Types

**URL sources:**
```json
"sources": ["url:https://example.com"]
```

**Text sources:**
```json
"sources": ["text:Your content here"]
```

**File sources:**
```json
"sources": ["file:/path/to/file.pdf"]
```

### Studio Artifact Types

Available types:
- `audio` - Audio overview
- `video` - Video overview
- `report` - Written report
- `quiz` - Interactive quiz
- `flashcards` - Study flashcards
- `summary` - Summary document
- `mindmap` - Mind map visualization
- `slides` - Presentation slides

## Common Issues

**Smart creation finds no sources:**
- Try broader search terms
- Increase depth: `--depth 15`
- Check internet connection

**Template not found:**
- List templates first: `./scripts/create-from-template.sh`
- Check template path is correct
- Ensure template file exists in `templates/`

**Artifact generation fails:**
- Some artifact types may not be available for all notebooks
- Check NotebookLM supports the artifact type
- Try sequential mode instead of parallel

## Success Criteria

Creation is successful when:
- ✅ Notebook ID returned
- ✅ All sources added successfully
- ✅ Requested artifacts generated
- ✅ Confirmation message displayed

## Example: Complete Workflow

```bash
# 1. Create config
cat > /tmp/my-notebook.json <<'EOF'
{
  "title": "AI Safety Research",
  "smart_creation": {
    "enabled": true,
    "topic": "AI safety alignment",
    "depth": 8
  },
  "studio": [
    {"type": "quiz"},
    {"type": "summary"}
  ]
}
EOF

# 2. Create and export
./scripts/automate-notebook.sh \
  --config /tmp/my-notebook.json \
  --parallel \
  --export ./exports

# 3. Export in additional format
# (Get notebook ID from previous output)
./scripts/export-notebook.sh <notebook-id> ./obsidian --format obsidian
```
