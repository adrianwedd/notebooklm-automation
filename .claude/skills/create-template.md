---
name: create-template
description: Create a new notebook template with variables
---

Use this skill when the user wants to create a reusable notebook template.

## Workflow

1. **Choose template category:**
   - `research/` - Academic research, papers
   - `learning/` - Course notes, study guides
   - `content/` - Podcasts, presentations, articles

2. **Create template JSON** with `{{variables}}`:
   ```json
   {
     "title": "{{topic}} Study Guide",
     "sources": [
       "text:Introduction to {{topic}}",
       "text:{{topic}} best practices"
     ],
     "studio": [
       {"type": "quiz"},
       {"type": "summary"}
     ]
   }
   ```

3. **Save to templates directory:**
   ```bash
   # Choose a descriptive name
   templates/category/template-name.json
   ```

4. **Test the template:**
   ```bash
   ./scripts/create-from-template.sh category/template-name \
     --var topic="Python Programming"
   ```

5. **Document in templates/README.md**

## Template Best Practices

### Variable Naming

**Use descriptive, lowercase names:**
- ✅ `{{topic}}`, `{{course_name}}`, `{{guest_name}}`
- ❌ `{{t}}`, `{{var1}}`, `{{X}}`

**Common variables:**
- `{{topic}}` - Main subject
- `{{title}}` - Notebook title
- `{{author}}` - Author/creator name
- `{{level}}` - Difficulty level
- `{{duration}}` - Time estimate
- `{{date}}` - Date/period

### Smart Creation Templates

**Enable auto-research:**
```json
{
  "title": "{{topic}} Research",
  "smart_creation": {
    "enabled": true,
    "topic": "{{topic}} {{subtopic}}",
    "depth": 10
  },
  "studio": [
    {"type": "quiz"}
  ]
}
```

### Nested Variables

**Variables work in nested structures:**
```json
{
  "studio": [
    {
      "type": "quiz",
      "prompt": "Create quiz about {{topic}}"
    },
    {
      "type": "summary",
      "focus": "{{aspect}} of {{topic}}"
    }
  ]
}
```

## Template Categories

### Research Templates

**Purpose:** Academic research, literature reviews

**Example structure:**
```json
{
  "title": "Research: {{paper_topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{paper_topic}} academic papers",
    "depth": 15
  },
  "studio": [
    {"type": "summary"},
    {"type": "mindmap"},
    {"type": "data-table"}
  ]
}
```

**Required variables:**
- `paper_topic` - Research subject

### Learning Templates

**Purpose:** Course notes, study guides, tutorials

**Example structure:**
```json
{
  "title": "{{course_name}} - Study Notes",
  "smart_creation": {
    "enabled": true,
    "topic": "{{course_name}} tutorial",
    "depth": 10
  },
  "studio": [
    {"type": "quiz"},
    {"type": "flashcards"},
    {"type": "summary"}
  ]
}
```

**Required variables:**
- `course_name` - Course or subject name

### Content Templates

**Purpose:** Podcasts, presentations, articles

**Example structure:**
```json
{
  "title": "Podcast: {{guest_name}} on {{topic}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{guest_name}} {{topic}}",
    "depth": 8
  },
  "studio": [
    {"type": "summary"},
    {"type": "quiz"}
  ]
}
```

**Required variables:**
- `guest_name` - Person/expert name
- `topic` - Discussion topic

## Testing Templates

### Basic Test

```bash
# 1. Create template
cat > templates/test/example.json <<'EOF'
{
  "title": "{{subject}} Notes",
  "sources": ["text:{{subject}} content"],
  "studio": []
}
EOF

# 2. Test variable substitution
./scripts/create-from-template.sh test/example \
  --var subject="Testing"

# 3. Verify output
# Check that {{subject}} was replaced with "Testing"
```

### Advanced Test

```bash
# Test with multiple variables
./scripts/create-from-template.sh learning/course-notes \
  --var course_name="Advanced Python" \
  --var level="intermediate" \
  --var duration="8 weeks"
```

### Validation

**Check for unused variables:**
```bash
# Template should not contain {{var}} after rendering
# This would indicate a missing variable
```

## Documentation

### Update templates/README.md

Add your template to the catalog:

```markdown
### template-name
Brief description of template purpose.

**Variables:**
- `variable_name`: Description of what this variable controls

**Generates:**
- X sources (from smart creation or manual)
- Y artifacts (list types)

**Example:**
```bash
./scripts/create-from-template.sh category/template-name \
  --var variable_name="value"
```
```

## Common Issues

**Template not found:**
- Ensure file is in `templates/category/` directory
- Check file extension is `.json`
- Verify path when calling create-from-template.sh

**Variables not replaced:**
- Check variable syntax: `{{varname}}` not `{varname}`
- Ensure variable is passed with `--var varname=value`
- Variable names are case-sensitive

**Invalid JSON:**
- Validate with: `cat template.json | jq .`
- Check for missing commas, quotes
- JSON doesn't support trailing commas

## Success Criteria

Template is successful when:
- ✅ Valid JSON structure
- ✅ Variables clearly defined
- ✅ Creates functional notebook
- ✅ Documented in README
- ✅ Tested with example values

## Complete Example

```bash
# 1. Create new template
mkdir -p templates/learning
cat > templates/learning/workshop.json <<'EOF'
{
  "title": "{{workshop_name}} Workshop Notes",
  "smart_creation": {
    "enabled": true,
    "topic": "{{workshop_name}} {{focus_area}}",
    "depth": 12
  },
  "studio": [
    {"type": "quiz"},
    {"type": "summary"},
    {"type": "slides"}
  ]
}
EOF

# 2. Test template
./scripts/create-from-template.sh learning/workshop \
  --var workshop_name="Web Development" \
  --var focus_area="React basics"

# 3. Document
echo "### workshop
Workshop notes template with auto-research.

**Variables:**
- \`workshop_name\`: Workshop subject
- \`focus_area\`: Specific topic within workshop

**Generates:**
- 12 research sources
- Quiz, summary, and slides

**Example:**
\`\`\`bash
./scripts/create-from-template.sh learning/workshop \\
  --var workshop_name=\"Machine Learning\" \\
  --var focus_area=\"neural networks\"
\`\`\`
" >> templates/README.md

# 4. Add to git
git add templates/learning/workshop.json templates/README.md
git commit -m "feat: add workshop template"
```

## Advanced: Template with Conditional Logic

While templates don't support conditionals directly, you can create variants:

```bash
# Basic version
templates/content/podcast-basic.json

# Advanced version with more features
templates/content/podcast-advanced.json

# Quick version with fewer sources
templates/content/podcast-quick.json
```

Users can choose the variant that fits their needs.
