# NotebookLM Templates

Pre-built templates for common NotebookLM workflows.

## Template variables and validation

`create-from-template.sh` renders templates by substituting `{{snake_case}}` placeholders.

By default, rendering is strict:
- If any required variables are missing, rendering fails with a clear list of missing variable names.
- If any `{{...}}` placeholders remain after rendering, rendering fails.

You can optionally add a metadata block to any template under the `_template` key. This block is removed from the final rendered config:

```json
{
  "_template": {
    "required": ["paper_topic"],
    "defaults": {"depth": "10"}
  },
  "title": "Research: {{paper_topic}}",
  "smart_creation": {"enabled": true, "topic": "{{paper_topic}}", "depth": "{{depth}}"}
}
```

## Available Templates

### Research Templates

#### Academic Paper (`research/academic-paper`)
Deep research notebook for academic topics.

**Variables:**
- `paper_topic` - Research topic or paper subject

**Features:**
- 15 AI-curated sources
- Comprehensive research report
- Mind map visualization
- Knowledge quiz
- Data table for key findings

**Example:**
```bash
./scripts/create-from-template.sh research/academic-paper \
  --var paper_topic="quantum entanglement"
```

### Learning Templates

#### Course Notes (`learning/course-notes`)
Study companion for online courses or tutorials.

**Variables:**
- `course_name` - Name of course or subject

**Features:**
- 10 tutorial-focused sources
- Interactive quiz
- Flashcards for memorization
- Summary report

**Example:**
```bash
./scripts/create-from-template.sh learning/course-notes \
  --var course_name="Python Programming"
```

### Content Creation Templates

#### Podcast Prep (`content/podcast-prep`)
Research notebook for podcast interviews.

**Variables:**
- `guest_name` - Guest or interview subject
- `topic` - Discussion topic

**Features:**
- 8 curated sources
- Research summary
- Interview question quiz

**Example:**
```bash
./scripts/create-from-template.sh content/podcast-prep \
  --var guest_name="Richard Feynman" \
  --var topic="physics education"
```

#### Presentation (`content/presentation`)
Research and outline for presentations.

**Variables:**
- `presentation_topic` - Presentation subject

**Features:**
- 12 comprehensive sources
- Slide deck generator
- Mind map outline
- Summary report

**Example:**
```bash
./scripts/create-from-template.sh content/presentation \
  --var presentation_topic="AI Safety"
```
