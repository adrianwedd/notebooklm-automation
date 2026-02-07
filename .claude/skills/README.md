# Claude Code Skills for NotebookLM Automation

These skills help Claude Code users work with the NotebookLM automation toolkit more effectively.

## Available Skills

### 📤 export-notebook
Export NotebookLM notebooks to local directories with support for multiple formats.

**Use when:**
- User wants to export a notebook
- Need to backup notebook content
- Want to convert to Obsidian/Notion/Anki format

**Key features:**
- Lists available notebooks
- Supports multiple export formats
- Handles errors gracefully

---

### ⚡ create-automated-notebook
Create notebooks with automated workflows using configuration files or templates.

**Use when:**
- User wants to create a new notebook
- Need to automate notebook creation
- Want to use smart research features

**Key features:**
- Configuration file support
- Smart creation (auto-research)
- Template-based creation
- Parallel artifact generation

---

### 🧪 run-tests
Run integration tests and validate code quality before committing.

**Use when:**
- User wants to test the project
- Before making commits
- Debugging test failures

**Key features:**
- Full integration test suite
- Code validation (Bash + Python)
- Pre-commit checklist
- Performance testing

---

### 📋 create-template
Create reusable notebook templates with variable interpolation.

**Use when:**
- User wants to create a template
- Need to standardize notebook creation
- Want to share workflow patterns

**Key features:**
- Template structure guidance
- Variable naming conventions
- Smart creation integration
- Testing procedures

---

### 🔧 troubleshoot
Diagnose and fix common issues with the automation toolkit.

**Use when:**
- User encounters errors
- Scripts aren't working
- Need debugging guidance

**Key features:**
- Quick diagnostics
- Common error patterns
- Step-by-step solutions
- Recovery procedures

---

## Using Skills

Skills are automatically available in Claude Code when working in this project directory.

**Claude will use these skills when you:**
- Ask to export a notebook
- Want to create an automated notebook
- Need to run tests
- Want to create a template
- Encounter errors or issues

**Example interactions:**
```
You: "Export my AI Research notebook to Obsidian format"
→ Claude uses export-notebook skill

You: "Create a notebook about quantum physics with a quiz"
→ Claude uses create-automated-notebook skill

You: "The tests are failing, help me debug"
→ Claude uses run-tests and troubleshoot skills
```

## Skill Structure

Each skill follows this structure:

```markdown
---
name: skill-name
description: Brief description of what the skill does
---

## Workflow
Step-by-step instructions...

## Options
Available options and flags...

## Common Issues
Troubleshooting guidance...

## Success Criteria
How to verify success...

## Examples
Working examples...
```

## Contributing

When adding new skills:

1. **Create in `.claude/skills/`** directory
2. **Use descriptive names** (lowercase-with-hyphens)
3. **Include YAML frontmatter** (name + description)
4. **Provide clear workflows** with code examples
5. **Document common issues** and solutions
6. **Add to this README** with description

**Template:**
```markdown
---
name: your-skill-name
description: What this skill helps with
---

Use this skill when...

## Workflow
1. Step one
2. Step two

## Examples
```bash
# Working example
```
```

## Testing Skills

Skills are automatically loaded by Claude Code. To verify they work:

1. **Check YAML syntax:**
   ```bash
   head -4 .claude/skills/*.md
   ```

2. **Test in Claude Code:**
   - Open Claude Code in this directory
   - Ask a question that should trigger the skill
   - Verify Claude uses the skill's guidance

3. **Review skill content:**
   - Ensure examples are accurate
   - Verify file paths are correct
   - Check commands are up-to-date

## Skill Priority

Claude will choose the most relevant skill based on:
- User's question or request
- Skill description match
- Current context/task

If multiple skills apply, Claude may combine them or ask for clarification.

## Updating Skills

When project features change:

1. **Update relevant skills** with new commands/options
2. **Test examples** to ensure they still work
3. **Document new features** in appropriate skills
4. **Commit changes** with clear description

---

**Questions?** See [CLAUDE.md](../../CLAUDE.md) for project context.
