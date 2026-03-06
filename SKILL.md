## Best Practices and Lessons Learned

Based on extensive real-world experience using Claude Code from OpenClaw, here are the critical techniques and patterns that ensure successful outcomes.

### 1. Calling Claude Code from OpenClaw - Critical Techniques

#### The TTY/PTY Problem and Solution

**The Problem**: Direct calls to `claude -p "task"` fail in non-interactive environments (like OpenClaw exec) because Claude Code requires a TTY/PTY (pseudo-terminal) to function properly.

**The Solution**: Use the `script` command to wrap Claude Code calls:

```bash
# ✅ Correct way - provides TTY environment
script -q /dev/null claude -p --allowedTools "Read,Edit,Write" "your prompt"

# ❌ Wrong way - will fail in automation
claude -p "your task"
```

**Why this works**: The `script` command creates a pseudo-terminal that satisfies Claude Code's requirement for an interactive environment, even when running from automation tools.

#### macOS Compatibility Issues

**The Problem**: The `timeout` command (common on Linux) doesn't exist on macOS, causing wrapper scripts to fail.

**Solutions Implemented**:
1. Check for `gtimeout` (GNU coreutils on macOS)
2. Fallback to custom timeout function using background processes
3. Graceful degradation when timeout tools aren't available

```bash
# Cross-platform timeout function
timeout_cmd() {
    local timeout_seconds=$1
    shift
    
    if command -v gtimeout &> /dev/null; then
        gtimeout "$timeout_seconds" "$@"
    elif command -v timeout &> /dev/null; then
        timeout "$timeout_seconds" "$@"
    else
        # Custom fallback implementation
        "$@" &
        local cmd_pid=$!
        (sleep "$timeout_seconds" && kill -TERM "$cmd_pid" 2>/dev/null) &
        wait "$cmd_pid"
    fi
}
```

#### Complete Working Command Pattern

For reliable execution from OpenClaw:

```bash
script -q /dev/null claude -p \
  --allowedTools "Read,Edit,Write,Bash" \
  --max-budget-usd 10.00 \
  --model sonnet \
  "Your detailed, specific prompt here with clear requirements"
```

**Key flags**:
- `--allowedTools`: Explicitly permit tools needed for the task
- `--max-budget-usd`: Prevent runaway costs
- `--model`: Choose appropriate model (sonnet for most work, haiku for simple tasks, opus for complex architecture)

### 2. Spec Kit Workflow Mastery

#### Real Workflow from Production Experience

**Step 1: Initialize Project**
```bash
specify init . --ai claude --here
```

**Step 2: Create Constitution** (Critical - don't skip!)
```bash
claude "/speckit.constitution Define design principles: skeuomorphic style 
with leather textures, realistic shadows, paper textures for content areas,
3D button effects with press states. Code standards: semantic HTML5, 
BEM CSS, ES6+ JavaScript. Performance: 60fps animations, lazy loading."
```

**Key insight**: The more detailed your constitution, the better the output. Include specific examples and visual descriptions.

**Step 3: Create Specification**
```bash
claude "/speckit.specify Create a todo list app with leather-bound notebook UI.
Features: add/edit/delete tasks, mark complete with animation, categories 
(Personal/Work/Shopping/Health), filter by status, localStorage persistence.
Visual: leather cover with stitching, paper notepad texture, realistic 
checkboxes, 3D buttons that depress when clicked."
```

**Step 4: Implementation Plan**
```bash
claude "/speckit.plan Tech stack: HTML5, CSS3 with advanced gradients and 
shadows for skeuomorphic effects, vanilla JavaScript. No external libraries.
File structure: index.html, css/style.css, js/app.js. Use CSS custom 
properties for theming."
```

**Step 5: Generate and Execute**
```bash
claude "/speckit.tasks"
claude "/speckit.implement"
```

#### Lessons from Successful Spec Kit Projects

**What Works**:
1. **Detailed Constitutions**: Projects with comprehensive design principles produce significantly better results
2. **Visual Examples**: Describing textures, colors, and effects in detail helps Claude understand the vision
3. **Specific Constraints**: Clear limitations ("no external libraries", "vanilla JS only") lead to cleaner implementations
4. **Iterative Refinement**: Using `/speckit.clarify` to refine unclear specifications saves time

**What to Avoid**:
1. **Vague Specifications**: "Make it look good" produces inconsistent results
2. **Skipping Constitution**: Results lack cohesion and consistency
3. **Over-specifying Implementation**: Let Claude decide "how" - you focus on "what" and "why"

### 3. Subagent Development and Usage

#### Creating Production-Ready Subagents

**File Location**: `~/.claude/agents/{agent-name}.md`

**Template Structure**:
```markdown
---
name: code-review-expert
description: Expert code reviewer that analyzes for quality, security, 
performance, and best practices. Use proactively after code changes.
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: default
memory: user
---

You are an expert code reviewer. When invoked:

1. **Security Analysis**: Check for SQL injection, XSS, auth vulnerabilities, 
   sensitive data exposure
2. **Performance Review**: Analyze algorithms, database queries, memory usage
3. **Code Quality**: Check for anti-patterns, complexity, maintainability
4. **Best Practices**: Verify language-specific conventions

**Output Format**:
- Severity: 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low
- Issue: Clear description
- Location: file:line
- Impact: What could go wrong
- Fix: Specific code example

Always provide actionable, specific feedback with code examples.
```

#### Using Subagents Effectively

**Direct Invocation**:
```bash
claude "Use the code-review-expert subagent to review src/auth.js"
```

**From OpenClaw with Wrapper**:
```bash
script -q /dev/null claude -p \
  --allowedTools "Read,Agent(code-review-expert)" \
  "Use the code-review-expert subagent to review vulnerable-app.js"
```

**Pro Tips**:
- Use `memory: user` for subagents that should learn from previous reviews
- Limit tools to prevent unwanted modifications
- Create specialized agents for specific domains (security, performance, accessibility)

### 4. Project Development Patterns

#### Pattern 1: Rapid Prototyping (Simple Projects)

For quick proofs-of-concept or simple features:

```bash
script -q /dev/null claude -p --write --max-budget-usd 3.00 \
  "Create a landing page with hero section, features grid, and contact form.
   Modern design with gradients. Single HTML file with embedded CSS/JS."
```

**When to use**: Simple marketing pages, prototypes, one-off features

#### Pattern 2: Structured Development (Production Projects)

For complex, production-quality applications:

```bash
# 1. Initialize with Spec Kit
specify init . --ai claude --here

# 2. Follow 5-step workflow
claude "/speckit.constitution ..."
claude "/speckit.specify ..."
claude "/speckit.plan ..."
claude "/speckit.tasks"
claude "/speckit.implement"
```

**When to use**: Production applications, team projects, code that will be maintained

#### Pattern 3: Subagent-Assisted Development

For projects requiring specialized expertise:

```bash
# Create specialized agents first
# Then use them in development workflow
claude "Use the security-auditor agent to review authentication module"
claude "Use the performance-optimizer agent to analyze database queries"
claude "Use the test-writer agent to create test suites"
```

**When to use**: Security-critical code, performance-sensitive applications, complex testing scenarios

### 5. Budget Control and Cost Management

#### Setting Appropriate Budgets

Based on real-world experience:

| Task Complexity | Budget | Model | Typical Time |
|----------------|--------|-------|--------------|
| Simple (single file) | $2-3 | haiku | 1-2 min |
| Medium (feature) | $5-8 | sonnet | 3-5 min |
| Complex (full app) | $10-15 | sonnet | 5-10 min |
| Architecture review | $5-10 | opus | 3-7 min |

**Always set `--max-budget-usd`** to prevent unexpected costs from runaway processes.

#### Model Selection Strategy

**Haiku** (Fast, Low-Cost):
- Simple text processing
- Code review summaries
- Documentation generation
- Quick answers

**Sonnet** (Balanced, Recommended):
- Most development work
- Feature implementation
- Debugging and refactoring
- General-purpose coding

**Opus** (High-Capability):
- Complex architecture decisions
- Algorithm design
- Security analysis
- Performance optimization

### 6. Troubleshooting Guide

#### Problem: Claude Code Doesn't Create Files

**Symptoms**: Process runs but no files appear, or partial files created

**Diagnosis**:
1. Check if TTY is available: `tty` command
2. Verify tool permissions in command
3. Check timeout settings
4. Review Claude Code auth status

**Solutions**:
```bash
# Ensure proper TTY with script command
script -q /dev/null claude -p --allowedTools "Read,Edit,Write,Bash" "..."

# Increase timeout for complex tasks
export CLAUDE_CODE_TIMEOUT=600

# Check authentication
claude auth status
```

#### Problem: Commands Hang or Timeout

**Symptoms**: Process never completes, exceeds timeout

**Common Causes**:
- Prompt too vague, causing endless clarification
- Task too complex for single execution
- Resource constraints

**Solutions**:
1. Break into smaller, specific tasks
2. Use iterative approach: plan → implement → review
3. Monitor with `ps` and kill if necessary
4. Use shorter timeouts and retry logic

#### Problem: Authentication Failures

**Symptoms**: "Not authenticated" errors

**Fix**:
```bash
# Check status
claude auth status

# Login if needed
claude auth login

# Verify
claude auth status
```

#### Problem: Subagent Not Found

**Symptoms**: "Subagent not available" or not using defined subagent

**Fixes**:
1. Ensure agent file is in `~/.claude/agents/`
2. Check YAML frontmatter syntax
3. Verify `name` field matches invocation
4. Restart Claude Code session to reload agents

### 7. Productivity Hacks

#### Template-Driven Development

Create reusable templates for common project types:

```bash
# Save successful constitution as template
cp .specify/constitution.md ~/templates/web-app-constitution.md

# Reuse for similar projects
cp ~/templates/web-app-constitution.md new-project/.specify/
```

#### Batch Operations

For repetitive tasks across multiple files:

```bash
#!/bin/bash
# batch-review.sh

for file in src/*.js; do
    echo "Reviewing $file..."
    script -q /dev/null claude -p \
        --allowedTools "Read" \
        "Review $file for security issues" >> reviews.txt
done
```

#### Version Control Integration

Best practices for Git workflow:

```bash
# After constitution creation
git add .specify/constitution.md
git commit -m "Add project constitution"

# After specification
git add .specify/specifications/
git commit -m "Add feature specifications"

# After implementation
git add .
git commit -m "Implement features via Claude Code"
```

### 8. Real-World Command Reference

#### Login Page Creation

```bash
script -q /dev/null claude -p \
  --allowedTools "Read,Edit,Write" \
  --max-budget-usd 5.00 \
  "Create a modern login page with HTML, CSS, and JavaScript.
   Requirements:
   - Purple gradient background
   - Email and password inputs with Font Awesome icons
   - Password show/hide toggle
   - Form validation with error messages
   - Remember me checkbox
   - Social login buttons (Google/GitHub style)
   - Responsive design
   - Smooth animations
   
   Create three files: index.html, style.css, script.js"
```

#### Code Review with Subagent

```bash
# Create test file first
cat > test-code.js << 'EOF'
// Intentionally vulnerable code for testing
const query = `SELECT * FROM users WHERE id = ${userId}`;
EOF

# Review with subagent
script -q /dev/null claude -p \
  --allowedTools "Read,Agent(code-review-expert)" \
  --max-budget-usd 3.00 \
  "Use the code-review-expert subagent to analyze test-code.js.
   Focus on security vulnerabilities and provide specific fixes."
```

#### Complete Spec Kit Project

```bash
# Full workflow for production-quality app
cd /projects/new-app

# Initialize
specify init . --ai claude --here

# Constitution - spend time on this!
claude "/speckit.constitution 
Define modern minimalist design with ample whitespace, 
inter font family, subtle shadows, smooth transitions.
Code: React functional components, TypeScript, Tailwind CSS.
Standards: Accessibility WCAG 2.1, mobile-first responsive."

# Specification - be specific!
claude "/speckit.specify 
Create a task manager with:
- Kanban board view (To Do, In Progress, Done)
- Drag-and-drop task movement
- Task details: title, description, due date, priority, tags
- Search and filter capabilities
- Dark/light mode toggle
- Export to JSON/CSV"

# Plan - choose tech wisely
claude "/speckit.plan 
React 18 with TypeScript, Vite for build, Tailwind CSS for styling,
@dnd-kit for drag-and-drop, date-fns for date handling,
localStorage for persistence, lucide-react for icons."

# Generate and implement
claude "/speckit.tasks"
claude "/speckit.implement"
```

### 9. Key Insights from Production Use

#### What Makes Claude Code Effective

1. **Specificity Wins**: Detailed prompts produce better results than vague ones
2. **Context Matters**: Providing background and constraints improves output quality
3. **Iteration Works**: Breaking complex tasks into steps yields better outcomes
4. **Tools Enable**: Proper tool configuration prevents frustration

#### Common Pitfalls to Avoid

1. **Vague Requirements**: "Make it nice" → inconsistent results
2. **No Budget Limits**: Unexpected costs from runaway processes
3. **Wrong Model Choice**: Using opus for simple tasks (wasteful), haiku for complex (insufficient)
4. **Skipping Planning**: Ad-hoc development produces technical debt

#### Unexpected Discoveries

- **Claude Code excels at CSS**: Complex gradients, animations, responsive design
- **Subagents are game-changers**: Specialized expertise on-demand
- **Spec Kit produces maintainable code**: Structured approach yields cleaner architecture
- **TTY issues are solvable**: `script` command is the key

## 10. Real-World Case Study: X-Diary Project

### Project Overview
Built a complete X-style private diary web application using Claude Code + Spec Kit:
- **Features**: Post input, infinite scroll timeline, mood tags, image upload, calendar, "On This Day" review
- **Stack**: Vanilla HTML/CSS/JS, no frameworks, LocalStorage persistence
- **Result**: 60KB codebase, GitHub Pages deployment

### Problems Encountered & Solutions

#### Problem 1: Spec Kit Interactive Commands Hang
**Symptom**: `/speckit.constitution`, `/speckit.implement` hang waiting for user confirmation (Yes/No prompts)

**Root Cause**: Spec Kit commands require interactive confirmation, but `claude -p` non-interactive mode + `script` wrapper still can't handle the prompts properly

**Solution - Hybrid Approach**:
```bash
# Step 1: Initialize (works non-interactively)
specify init . --ai claude --here

# Step 2: Generate tasks (works with script wrapper)
script -q /dev/null claude -p "/speckit.tasks"

# Step 3: For interactive steps (constitution/specify/implement),
# manually create files OR use yes pipe:
yes | script -q /dev/null claude -p "/speckit.constitution ..."

# Step 4: If implement fails, manually execute based on tasks.md
```

**Key Insight**: Spec Kit is great for planning, but full automation requires handling interactive prompts. Manual intervention is acceptable for critical steps.

#### Problem 2: Process Interruption During Long Operations
**Symptom**: `/speckit.implement` was terminated mid-execution (SIGTERM)

**Root Cause**: Long-running processes may hit timeout limits or be interrupted by system

**Solution**:
1. Run implement in background with logging
2. Monitor progress via log files
3. If interrupted, manually complete remaining tasks
4. Break large implementations into smaller chunks

```bash
# Background execution with logging
script -q /dev/null claude -p "/speckit.implement" > /tmp/implement.log 2>&1 &

# Monitor
tail -f /tmp/implement.log
```

#### Problem 3: TTY Issues with Different Commands
**Symptom**: Some commands work with `script`, others fail with "tcgetattr/ioctl: Operation not supported"

**Solution Matrix**:
| Command | Works With | Notes |
|---------|-----------|-------|
| `claude -p "task"` | `script -q /dev/null` | Basic tasks |
| `claude` interactive | Direct terminal | Must have real TTY |
| `specify init` | Direct | No wrapper needed |
| `/speckit.*` | `script` + sometimes `yes` pipe | May need confirmation handling |

### Successful Workflow Pattern

For reliable Spec Kit + Claude Code execution from OpenClaw:

```bash
# 1. Initialize project
specify init . --ai claude --here

# 2. Create constitution manually or use yes pipe
yes | script -q /dev/null claude -p "/speckit.constitution Your design principles"

# 3. Create specification manually
# (Write to .specify/specifications/project.md)

# 4. Create plan manually  
# (Write to .specify/plans/project.md)

# 5. Generate tasks (usually works)
script -q /dev/null claude -p "/speckit.tasks"

# 6. For implement, try with yes pipe or do manually
# Option A: Automated (may hang)
yes | script -q /dev/null claude -p "/speckit.implement"

# Option B: Manual (reliable)
# Read tasks.md and implement each task yourself
```

### Lessons Learned

1. **Hybrid approach is practical**: Use Spec Kit for structure/planning, manual implementation for reliability
2. **Always commit after each phase**: `git add .specify/ && git commit -m "phase complete"`
3. **Keep tasks.md as reference**: Even if implement fails, the task list is valuable
4. **Budget for manual work**: Complex projects will need manual intervention
5. **Script wrapper is essential but not universal**: Know when to use direct execution

### Recommended Approach for Complex Projects

1. **Use Spec Kit for**: Project structure, task generation, documentation
2. **Use Claude Code direct for**: Coding tasks, file editing (with `--write` flag when available)
3. **Use manual for**: Final integration, testing, deployment

This hybrid workflow delivers the benefits of structured planning while maintaining reliability.

---

## References

- [Claude Code Docs](https://code.claude.com/docs)
- [Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview)
- [MCP Documentation](https://code.claude.com/docs/en/mcp)
- [Spec Kit Repository](https://github.com/github/spec-kit)
