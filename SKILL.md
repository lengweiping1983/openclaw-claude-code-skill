---
name: claude-code
description: Integrate with Claude Code CLI for agentic coding workflows. IMPORTANT: Claude Code requires TTY/PTY environment. Use the provided wrapper scripts or run in terminal directly. Use when you need to (1) start interactive coding sessions, (2) execute one-off coding tasks via print mode, (3) resume previous Claude Code sessions, (4) create and manage subagents, (5) configure MCP servers, or (6) delegate complex coding tasks to Claude Code from OpenClaw.
---

# Claude Code Integration

This skill provides seamless integration with Claude Code CLI, Anthropic's agentic coding tool. Use it to delegate coding tasks, manage subagents, and leverage Claude Code's specialized capabilities from within OpenClaw.

## ⚠️ Important: TTY/PTY Requirement

**Claude Code requires an interactive terminal (TTY/PTY) to function properly.** When calling from OpenClaw or other automation tools:

1. **Use the wrapper script** (recommended): `scripts/claude-wrapper.sh`
2. **Run in terminal directly**: Execute commands in your terminal, not through background processes
3. **Use PTY mode**: If calling via API/tool, ensure `pty: true` is set

### Why Direct Calls May Fail

```bash
# ❌ This may fail in non-interactive environments
claude -p "create a login page"

# ✅ Use the wrapper script instead
./scripts/claude-wrapper.sh task "create a login page"

# ✅ Or run directly in your terminal
claude "create a login page"
```

### TTY/PTY Solutions for Different Environments

#### Docker Containers
```dockerfile
# Use docker run with -it flags
docker run -it your-image ./scripts/claude-wrapper.sh task "analyze code"

# Or use script command in Dockerfile
RUN apt-get update && apt-get install -y script
```

#### CI/CD Pipelines
```yaml
# GitHub Actions example
- name: Run Claude Code Analysis
  run: |
    export CLAUDE_CODE_TIMEOUT=600
    script -q -c "claude -p 'analyze security issues'" /dev/null
```

#### Remote SSH Sessions
```bash
# Force TTY allocation
ssh -t user@host "cd /path/to/project && ./scripts/claude-wrapper.sh task 'explain code'"

# Use tmux/screen for persistent sessions
tmux new-session -d -s claude "./scripts/claude-wrapper.sh interactive"
```

## Prerequisites

Claude Code must be installed:
```bash
# macOS/Linux/WSL
curl -fsSL https://claude.ai/install.sh | bash

# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```

Verify installation:
```bash
claude --version  # Should show version like "2.1.70 (Claude Code)"
claude auth status  # Check authentication status
```

## Using the Wrapper Script (Recommended)

The wrapper script handles TTY/PTY requirements and provides a reliable way to call Claude Code from OpenClaw:

### Basic Usage

```bash
# Navigate to the skill directory
cd /Users/lengweiping/.openclaw/workspace/skills/claude-code

# Run a task
./scripts/claude-wrapper.sh task "explain this codebase"

# Run with file creation allowed
./scripts/claude-wrapper.sh task --write "create a login page"

# Interactive session
./scripts/claude-wrapper.sh interactive
```

### From OpenClaw

When using OpenClaw to call Claude Code, use the wrapper:

```bash
# In OpenClaw, execute:
bash /Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task "your prompt here"
```

Or use the exec tool with the script path.

## Direct CLI Usage (Terminal Only)

### Start Interactive Session

Enter an interactive Claude Code session in the current directory:

```bash
claude
```

With an initial prompt:
```bash
claude "explain this codebase"
```

### Execute One-Off Tasks (Print Mode)

Run a task and return output without entering interactive mode:

```bash
# Basic task
claude -p "analyze the error in logs.txt"

# With auto-approval for specific tools
claude -p --allowedTools "Read,Edit,Write,Bash" "refactor the auth module"

# With budget limit
claude -p --max-budget-usd 5.00 "implement user authentication"

# Process piped input
cat error.log | claude -p "explain this error"
```

### Resume Sessions

Continue the most recent session:
```bash
claude -c
```

Resume a specific session by name or ID:
```bash
claude -r "auth-refactor" "finish this PR"
```

## Subagent Management

### List All Subagents

```bash
claude agents
```

### Create Subagent via CLI

Define a custom subagent for a single session:

```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer. Use proactively after code changes.",
    "prompt": "You are a senior code reviewer. Focus on code quality, security, and best practices.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

### Create Persistent Subagent File

Create a subagent file in `~/.claude/agents/` for reuse across projects:

```markdown
---
name: api-tester
description: Creates comprehensive API tests for endpoints
tools: Read, Write, Edit, Bash
model: sonnet
---
You are an API testing specialist. When invoked:
1. Read the API endpoint definitions
2. Create comprehensive test suites with edge cases
3. Include both happy path and error scenarios
4. Use appropriate testing frameworks for the project
```

## MCP Server Configuration

### Configure MCP Servers

```bash
claude mcp
```

### Load MCP Config from File

```bash
claude --mcp-config ./mcp.json
```

Example `mcp.json`:
```json
{
  "mcpServers": {
    "slack": {
      "command": "mcp-slack-server",
      "args": ["--token", "$SLACK_TOKEN"]
    }
  }
}
```

## Advanced Flags

| Flag | Description | Example |
|------|-------------|---------|
| `--model` | Specify model (sonnet/opus/haiku) | `claude --model sonnet` |
| `--chrome` | Enable browser automation | `claude --chrome` |
| `--worktree, -w` | Use isolated git worktree | `claude -w feature-branch` |
| `--system-prompt` | Replace system prompt | `claude --system-prompt "You are a Python expert"` |
| `--append-system-prompt` | Add to system prompt | `claude --append-system-prompt "Always use TypeScript"` |
| `--allowedTools` | Restrict available tools | `claude --allowedTools "Read,Edit,Bash"` |
| `--permission-mode` | Set permission mode | `claude --permission-mode plan` |
| `--max-turns` | Limit agent turns | `claude -p --max-turns 5 "task"` |
| `--max-budget-usd` | Set cost limit | `claude -p --max-budget-usd 2.00 "task"` |
| `--verbose` | Show detailed output | `claude --verbose` |

## Permission Modes

- `default` - Standard permission prompts
- `acceptEdits` - Auto-accept file edits
- `dontAsk` - Auto-deny prompts
- `bypassPermissions` - Skip all checks (use with caution)
- `plan` - Read-only exploration mode

## Common Workflows

### Code Review Workflow

```bash
# Start with a code reviewer subagent
claude --agents '{
  "reviewer": {
    "description": "Reviews code for quality and issues",
    "prompt": "Review code for bugs, security issues, and best practices. Be thorough but constructive.",
    "tools": ["Read", "Grep", "Glob"],
    "model": "sonnet"
  }
}'

# Then in the session:
# "Use the reviewer agent to check the src/ directory"
```

### Automated Refactoring

```bash
# One-off refactoring task
claude -p --permission-mode acceptEdits \
  --max-budget-usd 5.00 \
  "Refactor all console.log statements to use a proper logger"
```

### Multi-Step Bug Investigation

```bash
# Start an interactive session with increased budget
claude --max-budget-usd 10.00

# In the session:
# "Investigate why the login flow fails intermittently"
```

## Integration Patterns

### From OpenClaw to Claude Code

When OpenClaw needs to delegate to Claude Code, use the wrapper script:

```bash
# Method 1: Wrapper script (recommended)
bash /Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task "explain this codebase"

# Method 2: Direct terminal command (run in your terminal)
claude "explain this codebase"

# Method 3: With write permissions
bash /Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task --write "create a React component"
```

### For OpenClaw Agent Developers

When building an agent that calls Claude Code:

```python
# Example: OpenClaw exec call with PTY
exec({
    "command": "/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task --write 'create a login page'",
    "pty": True,  # Important: Enables TTY
    "timeout": 300
})
```

### Best Practices for Automation

1. **Always use the wrapper script** for reliable execution
2. **Set budget limits** (`--budget`) to control costs
3. **Use specific allowed tools** to limit scope
4. **Set appropriate timeouts** based on task complexity
5. **Handle read-only vs write modes** explicitly

### Common Workflows

#### Code Review Workflow

```bash
# Using wrapper
./scripts/claude-wrapper.sh review src/

# Direct in terminal
claude -p --allowedTools "Read,Grep,Glob" "Review src/ for code quality issues"
```

#### Automated Refactoring

```bash
# Using wrapper with write permission
./scripts/claude-wrapper.sh task --write --budget 5.00 \
  "Refactor all console.log statements to use a proper logger"
```

#### Multi-Step Development

```bash
# Start interactive session for complex work
./scripts/claude-wrapper.sh interactive

# Or use budget-limited print mode
./scripts/claude-wrapper.sh task --write --budget 10.00 \
  "Implement user authentication with login, signup, and password reset"
```

## Best Practices

### 1. Task Design and Delegation

**Break Down Complex Tasks**
```bash
# ❌ Too complex for single task
./scripts/claude-wrapper.sh task --write "build a full e-commerce app"

# ✅ Break into manageable chunks
./scripts/claude-wrapper.sh task --write "create user authentication system"
./scripts/claude-wrapper.sh task --write "implement product catalog with search"
./scripts/claude-wrapper.sh task --write "add shopping cart functionality"
```

**Use Progressive Enhancement**
```bash
# 1. Start with exploration (read-only)
./scripts/claude-wrapper.sh task "analyze the authentication flow"

# 2. Plan the implementation
./scripts/claude-wrapper.sh task "design JWT-based auth architecture"

# 3. Implement with write permissions
./scripts/claude-wrapper.sh task --write "implement JWT authentication"
```

### 2. Context Management

**Provide Relevant Context**
```bash
# Include specific files
./scripts/claude-wrapper.sh task "review auth.js and middleware/auth.js for security issues"

# Reference existing patterns
./scripts/claude-wrapper.sh task "follow the patterns in src/components/ to create a new UserProfile component"
```

**Use Subagents for Specialization**
```bash
# Create focused subagents
./scripts/claude-wrapper.sh task \
  --agents '{
    "security-scanner": {
      "description": "Scans for security vulnerabilities",
      "prompt": "Focus on OWASP Top 10, input validation, and secure coding practices",
      "tools": ["Read", "Grep", "Glob"],
      "model": "sonnet"
    }
  }' \
  "Use security-scanner to audit src/api/"
```

### 3. Cost and Performance Optimization

**Model Selection Strategy**
- **Haiku**: Quick tasks, simple analysis, prototyping
- **Sonnet**: General coding, architecture design, debugging
- **Opus**: Complex algorithms, security audits, performance optimization

```bash
# Quick syntax check with Haiku
./scripts/claude-wrapper.sh task --model haiku "check syntax in main.py"

# Architecture design with Sonnet
./scripts/claude-wrapper.sh task --model sonnet "design microservices architecture"

# Complex algorithm with Opus
./scripts/claude-wrapper.sh task --model opus --budget 20.00 "implement distributed consensus algorithm"
```

**Budget Management**
```bash
# Set project-wide budget
export CLAUDE_CODE_BUDGET=5.00

# Track usage
./scripts/claude-wrapper.sh task --budget 2.00 --verbose "task with cost tracking"
```

### 4. Error Handling and Recovery

**Graceful Failure Handling**
```bash
# Use timeouts to prevent hanging
./scripts/claude-wrapper.sh task --timeout 300 "potentially long-running task"

# Check for common issues first
./scripts/claude-wrapper.sh task "verify node_modules exists and package.json is valid"
```

**Session Recovery**
```bash
# List available sessions
./scripts/claude-wrapper.sh session

# Resume specific session
./scripts/claude-wrapper.sh session "feature-auth-2024"

# Continue last session
claude -c
```

### 5. Security Best Practices

**Code Review Before Committing**
```bash
# Always review generated code
./scripts/claude-wrapper.sh task --write "implement feature" > changes.md
# Review changes.md before applying

# Use diff to see changes
./scripts/claude-wrapper.sh task --write "refactor auth" && git diff
```

**Secure Defaults**
```bash
# Start with minimal permissions
./scripts/claude-wrapper.sh task --allowedTools "Read,Grep,Glob" "analyze code"

# Gradually expand permissions
./scripts/claude-wrapper.sh task --allowedTools "Read,Edit,Write" "refactor code"
```

### 6. Integration Patterns

**From Makefiles**
```makefile
review:
	@./scripts/claude-wrapper.sh review src/

refactor:
	@./scripts/claude-wrapper.sh refactor "$(PROMPT)"

.PHONY: review refactor
```

**From NPM Scripts**
```json
{
  "scripts": {
    "code:review": "./scripts/claude-wrapper.sh review src/",
    "code:explain": "./scripts/claude-wrapper.sh explain src/main.js",
    "code:fix": "./scripts/claude-wrapper.sh fix"
  }
}
```

**From Python Scripts**
```python
import subprocess
import os

def claude_review(path="."):
    """Run Claude Code review on specified path"""
    script_path = "/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh"
    result = subprocess.run([script_path, "review", path],
                          capture_output=True, text=True)
    return result.stdout
```

## Troubleshooting

### TTY/PTY Issues

#### Why Direct Calls Fail

When calling Claude Code directly from OpenClaw or other automation tools:

```bash
# ❌ This often fails in non-TTY environments
exec({
  command: "claude -p 'create a login page'",
  workdir: "/some/path"
})
```

**Problems:**
1. **No TTY available**: Claude Code requires an interactive terminal
2. **Environment variables**: May not have proper shell environment
3. **Timeout issues**: Complex tasks need longer timeouts
4. **Permission prompts**: Claude Code may ask for tool approvals

**Solutions:**

1. **Use the wrapper script** (recommended):
```bash
# ✅ Works from OpenClaw
bash /Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task "create a login page"
```

2. **Run directly in terminal**:
```bash
# ✅ Open terminal and run
claude "create a login page"
```

3. **Use with PTY mode** (if your tool supports it):
```bash
# ✅ With pseudo-terminal
exec({
  command: "claude -p 'create a login page'",
  pty: true,
  timeout: 300
})
```

#### Platform-Specific TTY Solutions

**Docker/Containers**
```dockerfile
# Install script utility
RUN apt-get update && apt-get install -y bsdutils

# Use script to create TTY
CMD ["script", "-q", "-c", "claude-wrapper.sh task 'analyze code'", "/dev/null"]
```

**GitHub Actions**
```yaml
- name: Claude Code Analysis
  run: |
    # Install expect for TTY support
    sudo apt-get update && sudo apt-get install -y expect

    # Run with TTY
    unbuffer ./scripts/claude-wrapper.sh task "analyze security"
```

**Jenkins/CircleCI**
```bash
# Use script command in build steps
script -q -c "./scripts/claude-wrapper.sh review src/" /dev/null
```

### Authentication Issues

**Problem**: "Not authenticated" error
```bash
# Check status
claude auth status

# Login
claude auth login

# For CI/CD, use environment variables
echo "$CLAUDE_API_KEY" | claude auth login
```

**Problem**: "Session expired" error
```bash
# Clear session cache
rm -rf ~/.claude/sessions/

# Re-authenticate
claude auth login
```

### Session Management Issues

**Session not found**
```bash
# List available sessions
claude -r  # Shows all sessions

# Check session directory
ls -la ~/.claude/sessions/

# Resume by partial name match
claude -r "auth"  # Resumes session with "auth" in name
```

**Session corruption**
```bash
# Clear corrupted sessions
rm ~/.claude/sessions/*

# Or use specific session ID
claude -r "session-id-12345"
```

### Tool Approval Issues

When running programmatically, use `--allowedTools` to pre-approve:

```bash
# Allow read-only operations
claude -p --allowedTools "Read,Grep,Glob" "analyze code"

# Allow read and write
claude -p --allowedTools "Read,Edit,Write,Bash" "refactor code"

# Allow specific bash commands only
claude -p --allowedTools "Read,Bash(ls),Bash(grep),Bash(find)" "explore structure"
```

**Permission denied errors**
```bash
# Use permission modes
claude -p --permission-mode acceptEdits "refactor code"

# Bypass permissions (use carefully)
claude -p --permission-mode bypassPermissions "emergency fix"
```

### Timeout Issues

Increase timeout for complex tasks:

```bash
# Set longer timeout
export CLAUDE_CODE_TIMEOUT=600
./scripts/claude-wrapper.sh task --timeout 600 "implement complex feature"

# Set infinite timeout (not recommended)
./scripts/claude-wrapper.sh task --timeout 0 "very long task"
```

**Hanging commands**
```bash
# Check for background processes
ps aux | grep claude

# Kill hanging processes
pkill -f claude

# Run with strace for debugging
strace -f ./scripts/claude-wrapper.sh task "debug this"
```

### Network and API Issues

**Connection timeouts**
```bash
# Check network connectivity
curl -I https://claude.ai

# Set custom timeout
export CLAUDE_API_TIMEOUT=60

# Use proxy if behind firewall
export HTTPS_PROXY=http://proxy.company.com:8080
```

**Rate limiting**
```bash
# Add delays between requests
./scripts/claude-wrapper.sh task "task 1" && sleep 5 && ./scripts/claude-wrapper.sh task "task 2"

# Use batch mode for multiple tasks
./scripts/claude-batch-runner.sh tasks.txt --delay 5
```

### Model-Specific Issues

**Opus model availability**
```bash
# Check model availability
claude --model opus --help

# Fallback to Sonnet if Opus unavailable
./scripts/claude-wrapper.sh task --model sonnet "complex analysis"
```

**Context window exceeded**
```bash
# Split large codebases
./scripts/claude-wrapper.sh task "analyze src/module1/"
./scripts/claude-wrapper.sh task "analyze src/module2/"

# Use grep to focus on specific patterns
./scripts/claude-wrapper.sh task "search for 'TODO' comments in src/"
```

### Debugging Tools

**Enable verbose logging**
```bash
# Verbose output
./scripts/claude-wrapper.sh task --verbose "debug this issue"

# Debug with trace
bash -x ./scripts/claude-wrapper.sh task "analyze code"

# Log to file
./scripts/claude-wrapper.sh task "task" 2>&1 | tee claude-debug.log
```

**Run diagnostics**
```bash
# Claude Code doctor
./scripts/claude-wrapper.sh doctor

# System health check
./scripts/claude-wrapper.sh task "check system requirements"

# Configuration validation
./scripts/claude-config-validator.sh
```

## Working with Subagents

Subagents are specialized AI agents that you can create and deploy for specific tasks within Claude Code. They allow you to delegate work to purpose-built agents with custom prompts, tools, and configurations.

### What are Subagents and When to Use Them

Subagents are lightweight, task-focused agents that:
- **Specialize in specific domains** (testing, security, documentation, etc.)
- **Have custom prompts and tool sets** tailored to their purpose
- **Can be invoked on-demand** from your main Claude session
- **Share context** with the parent agent while maintaining their focus

**Use subagents when you need to:**
- Perform repetitive specialized tasks (code reviews, test generation)
- Ensure consistent analysis patterns across your codebase
- Delegate work while maintaining quality standards
- Create reusable expertise for your team

### Creating Subagents from OpenClaw

#### Method 1: Using /agents Command in Interactive Mode

From within a Claude Code session, use the `/agents` command to create and manage subagents:

```bash
# Start interactive session
./scripts/claude-wrapper.sh interactive

# In the session, create a subagent
/agents create code-reviewer "Expert code reviewer focused on security and performance"

# Or load from a file
/agents load ~/.claude/agents/security-auditor.md
```

#### Method 2: Creating .md Files Manually

Create subagent definition files in `~/.claude/agents/`:

```bash
# Create agents directory if it doesn't exist
mkdir -p ~/.claude/agents/

# Create a subagent file
nano ~/.claude/agents/api-tester.md
```

#### Method 3: Using CLI --agents Flag for One-Time Use

Define subagents for a single session:

```bash
./scripts/claude-wrapper.sh task \
  --agents '{
    "performance-optimizer": {
      "description": "Analyzes and optimizes code performance",
      "prompt": "You are a performance optimization expert. Focus on:",
      "tools": ["Read", "Grep", "Bash", "mcp__chrome-devtools__performance_start_trace"],
      "model": "sonnet"
    }
  }' \
  "Use performance-optimizer to analyze src/components/"
```

### Complete Workflow Example from OpenClaw

Let's walk through creating and using a code review subagent:

#### Step 1: Create a Code-Review Subagent

Create `~/.claude/agents/code-reviewer.md`:

```markdown
---
name: code-reviewer
description: Senior developer focused on code quality, security, and best practices
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: plan
---

You are an experienced code reviewer with expertise in:
- Security vulnerabilities (OWASP Top 10)
- Code quality and maintainability
- Performance optimization
- Design patterns and architecture

When reviewing code:
1. Identify potential security issues
2. Check for code smells and anti-patterns
3. Suggest performance improvements
4. Verify adherence to best practices
5. Provide constructive feedback with examples

Always be thorough but constructive in your reviews.
```

#### Step 2: Create Test Files with Intentional Issues

```bash
# Create a test directory
mkdir -p test-review
cd test-review

# Create a file with intentional issues
cat > vulnerable-api.js << 'EOF'
const express = require('express');
const app = express();

// Security issues: No input validation, SQL injection possible
app.get('/users/:id', (req, res) => {
  const userId = req.params.id;
  const query = `SELECT * FROM users WHERE id = ${userId}`;
  // Direct SQL execution - vulnerable to injection
  db.query(query, (err, results) => {
    if (err) {
      console.log('Error: ' + err);
      res.status(500).send('Database error');
    }
    res.json(results);
  });
});

// Performance issue: Inefficient loop
app.get('/process', (req, res) => {
  const items = Array(10000).fill(0).map((_, i) => i);
  let sum = 0;
  // O(n^2) operation for simple sum
  for (let i = 0; i < items.length; i++) {
    for (let j = 0; j <= i; j++) {
      if (j === i) sum += items[i];
    }
  }
  res.json({ sum });
});

app.listen(3000);
EOF
```

#### Step 3: Invoke the Subagent to Review Code

```bash
# Load the subagent and review the code
./scripts/claude-wrapper.sh task \
  --agents "$(cat ~/.claude/agents/code-reviewer.md)" \
  "Use the code-reviewer agent to review test-review/vulnerable-api.js for security and performance issues"
```

#### Step 4: View Results

The subagent will provide detailed analysis including:
- **Security Issues**: SQL injection vulnerability, lack of input validation
- **Performance Problems**: O(n^2) algorithm where O(n) would suffice
- **Code Quality**: Error handling improvements, logging practices
- **Recommendations**: Parameterized queries, algorithm optimization

### Subagent Configuration Options

#### Basic Configuration

```yaml
name: security-auditor              # Unique identifier
description: Scans for security vulnerabilities  # Short purpose description
tools: Read, Grep, Glob, Bash      # Available tools (comma-separated)
model: sonnet                       # Model choice: haiku, sonnet, or opus
permissionMode: plan               # Permission handling mode
```

#### Advanced Configuration Options

```yaml
---
name: documentation-writer
description: Creates comprehensive documentation for codebases
tools: Read, Grep, Glob, Write, Edit
model: sonnet
permissionMode: acceptEdits         # Auto-accept file modifications
memory:                             # Memory settings
  enabled: true                     # Enable memory for this subagent
  namespace: docs                   # Memory namespace
  fallbackToParent: true            # Use parent agent's memory if needed
hooks:                              # Lifecycle hooks
  beforeStart: |
    echo "Documentation generation starting..."
    # Validate project structure
    if [ ! -f "README.md" ]; then
      echo "Warning: No README.md found"
    fi
  afterComplete: |
    echo "Documentation complete!"
    # Trigger rebuild if needed
    if command -v mkdocs &> /dev/null; then
      mkdocs build
    fi
disallowedTools: Bash(rm), Bash(sudo)  # Explicitly forbidden tools
timeout: 300                        # Maximum execution time in seconds
maxTurns: 20                        # Maximum number of turns
```

### Example Subagent File Format with Comments

```markdown
---
# Required: Unique identifier for the subagent
name: test-generator

# Required: Brief description of purpose and capabilities
description: Creates comprehensive test suites with high coverage

# Required: Comma-separated list of available tools
tools: Read, Write, Edit, Grep, Glob, Bash

# Optional: Model selection (default: sonnet)
model: sonnet

# Optional: Permission mode (default: default)
# Options: default, acceptEdits, dontAsk, bypassPermissions, plan
permissionMode: acceptEdits

# Optional: Memory configuration
memory:
  enabled: true              # Enable persistent memory
  namespace: tests           # Isolate memory by namespace
  fallbackToParent: false    # Don't use parent memory

# Optional: Hooks for lifecycle events
hooks:
  # Run before subagent starts
  beforeStart: |
    echo "Analyzing codebase structure..."
    find . -name "*.test.*" -o -name "*.spec.*" | head -5

  # Run after subagent completes
  afterComplete: |
    echo "Test generation complete!"
    npm test 2>/dev/null || echo "Run tests manually"

# Optional: Tools to explicitly disallow
disallowedTools: Bash(rm -rf), Bash(sudo), Write(/etc/)

# Optional: Execution limits
timeout: 600                 # 10 minute timeout
maxTurns: 50                 # Limit conversation turns

# Optional: Custom working directory
workDir: ./test-output       # Relative to project root

# Optional: Environment variables
env:
  TEST_FRAMEWORK: jest       # Set framework preference
  COVERAGE_THRESHOLD: 80     # Set coverage target
---

# System prompt for the subagent
You are a test generation specialist with expertise in:
- Unit testing best practices
- Integration test design
- Test coverage optimization
- Mocking and stubbing strategies

When creating tests:
1. Analyze the existing code structure and patterns
2. Follow the project's testing conventions
3. Aim for >80% code coverage
4. Include edge cases and error scenarios
5. Use descriptive test names that explain the behavior

Always verify tests pass before completing.
```

### Best Practices for Using Subagents from OpenClaw

#### 1. Use Wrapper Script with Subagent Parameter

Always use the wrapper script when invoking subagents from OpenClaw:

```bash
# ✅ Correct: Uses wrapper with proper TTY handling
./scripts/claude-wrapper.sh task \
  --agents "$(cat ~/.claude/agents/my-subagent.md)" \
  "Use my-subagent to analyze the codebase"

# ❌ Incorrect: Direct call may fail
claude --agents "my-subagent" "analyze code"
```

#### 2. Handle TTY Requirements

For automation scripts that call subagents:

```python
# Python example with proper TTY handling
import subprocess
import os

def invoke_subagent(agent_file, task):
    script_path = "/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh"

    # Read agent configuration
    with open(agent_file, 'r') as f:
        agent_config = f.read()

    # Build command with proper escaping
    cmd = [
        script_path,
        "task",
        f"--agents", agent_config,
        f"Use subagent to {task}"
    ]

    # Execute with TTY support
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        # Use script command for TTY simulation if needed
        shell=True
    )

    return result.stdout, result.stderr
```

#### 3. Set Appropriate Budgets

Control costs by setting budgets for subagent tasks:

```bash
# Budget-friendly subagent usage
./scripts/claude-wrapper.sh task \
  --agents "$(cat ~/.claude/agents/code-reviewer.md)" \
  --max-budget-usd 2.00 \
  --model haiku \
  "Review src/utils/ for security issues"

# Complex analysis with higher budget
./scripts/claude-wrapper.sh task \
  --agents "$(cat ~/.claude/agents/architecture-analyzer.md)" \
  --max-budget-usd 10.00 \
  --model sonnet \
  "Analyze microservices architecture"
```

#### 4. Create Reusable Subagent Library

Build a collection of subagents for your team:

```bash
# Create shared agents directory
mkdir -p ~/claude-agents/team/

# Create common subagents
cat > ~/claude-agents/team/security-scanner.md << 'EOF'
---
name: security-scanner
description: OWASP-focused security vulnerability scanner
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: plan
---

Scan code for security vulnerabilities focusing on:
- SQL injection risks
- XSS vulnerabilities
- Authentication bypasses
- Sensitive data exposure
- Dependency vulnerabilities

Provide severity ratings and remediation steps.
EOF

# Create usage script for team
#!/bin/bash
# team-security-scan.sh
AGENT_PATH="$HOME/claude-agents/team/security-scanner.md"
WRAPPER_PATH="/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh"

$WRAPPER_PATH task \
  --agents "$(cat $AGENT_PATH)" \
  --max-budget-usd 5.00 \
  "Use security-scanner to audit $1"
```

#### 5. Chain Subagents for Complex Workflows

Use multiple subagents in sequence:

```bash
#!/bin/bash
# Complete code quality workflow

WRAPPER="/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh"

# Step 1: Security scan
$WRAPPER task \
  --agents "$(cat ~/.claude/agents/security-scanner.md)" \
  --max-budget-usd 3.00 \
  "Scan src/ for vulnerabilities" > security-report.md

# Step 2: Performance analysis
$WRAPPER task \
  --agents "$(cat ~/.claude/agents/performance-analyzer.md)" \
  --max-budget-usd 5.00 \
  "Analyze performance bottlenecks in src/" > performance-report.md

# Step 3: Generate tests based on findings
$WRAPPER task \
  --agents "$(cat ~/.claude/agents/test-generator.md)" \
  --max-budget-usd 4.00 \
  "Create tests for issues found in security and performance reports"
```

#### 6. Monitor Subagent Performance

Track subagent effectiveness:

```bash
# Create monitoring wrapper
#!/bin/bash
# monitored-subagent.sh

START_TIME=$(date +%s)
WRAPPER="/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh"

# Run subagent with output capture
OUTPUT=$("$WRAPPER" task \
  --agents "$(cat ~/.claude/agents/$1.md)" \
  --verbose \
  "${@:2}" 2>&1)

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Log performance metrics
echo "$(date): Subagent $1 completed in ${DURATION}s" >> subagent-performance.log
echo "Task: $2" >> subagent-performance.log
echo "---" >> subagent-performance.log

# Output results
echo "$OUTPUT"
```

## Spec Kit Workflow Guide

Spec Kit is a powerful tool for spec-driven development that integrates seamlessly with Claude Code. It enables you to create detailed specifications for your projects and leverage AI to generate implementation plans and execute them systematically.

### What is Spec Kit

Spec Kit is a CLI tool that implements **Spec-Driven Development** - a methodology where you:
1. Define clear project specifications before implementation
2. Generate structured implementation plans from specs
3. Execute tasks systematically with AI assistance

#### Benefits of Using Spec Kit with Claude Code

- **Consistent Architecture**: Specifications ensure consistent design patterns
- **Better Requirements**: Clear specs lead to better implementations
- **Reusable Templates**: Create project templates for common patterns
- **Team Alignment**: Specifications serve as documentation and contracts
- **AI-Guided Implementation**: Claude Code follows your specs precisely

### Installation and Setup

#### Install specify-cli

```bash
# Install via npm
npm install -g specify-cli

# Or install locally
npm install specify-cli

# Verify installation
specify --version
```

#### Initialize a Project with AI Integration

```bash
# Create new project with Claude integration
specify init my-project --ai claude

# Or in existing project
specify init --ai claude

# This creates:
# - .spec/ directory with configuration
# - spec.config.json
# - Templates for constitutions, specs, and plans
```

### Complete Workflow Steps

#### Step 1: Create Constitution (Design Principles)

The constitution defines your project's design principles, coding standards, and architectural guidelines.

```bash
# Create constitution interactively
specify create constitution

# Or create from template
specify create constitution --template web-app
```

**Example Constitution (`constitution.md`)**:
```markdown
---
name: skeuomorphic-todo-constitution
description: Design principles for skeuomorphic todo app
version: 1.0.0
---

# Design Principles

## Visual Design
- **Skeuomorphic Style**: Realistic textures, shadows, and materials
- **3D Elements**: Depth, lighting, and perspective
- **Real-world Metaphors**: Paper, leather, wood textures
- **Rich Color Palette**: Warm, natural colors with gradients

## User Experience
- **Tactile Feedback**: Visual responses to interactions
- **Intuitive Controls**: Familiar real-world analogies
- **Smooth Animations**: Realistic physics and transitions
- **Accessibility**: WCAG 2.1 AA compliance

## Technical Standards
- **React 18+** with TypeScript
- **CSS Modules** or **Styled Components**
- **Responsive Design** (mobile-first)
- **Performance**: < 3s load time, 60fps animations
- **Browser Support**: Chrome, Firefox, Safari, Edge (latest 2 versions)

## Code Quality
- **TypeScript Strict Mode**: No implicit any
- **ESLint + Prettier**: Consistent formatting
- **Component Composition**: Small, reusable components
- **Custom Hooks**: Extract and reuse stateful logic
```

#### Step 2: Create Specification (Features & Requirements)

Specifications define what your project will do in detail.

```bash
# Create specification
specify create spec

# Link to constitution
specify create spec --constitution constitution.md
```

**Example Specification (`spec.md`)**:
```markdown
---
name: skeuomorphic-todo-spec
description: Feature specification for skeuomorphic todo application
constitution: constitution.md
version: 1.0.0
---

# Skeuomorphic Todo Application

## Core Features

### 1. Task Management
- **Create Tasks**: Add new todos with title, description, and due date
- **Edit Tasks**: Modify task details inline
- **Delete Tasks**: Remove tasks with confirmation
- **Complete Tasks**: Mark as done with satisfying animation
- **Priority Levels**: High, medium, low with visual indicators

### 2. Visual Design
- **Paper Texture Background**: Realistic notebook paper look
- **Leather Header**: Rich leather texture with stitching
- **3D Buttons**: Raised buttons with press-down animations
- **Hand-drawn Icons**: Sketch-style icons for actions
- **Realistic Shadows**: Dynamic shadows based on lighting

### 3. User Interactions
- **Drag & Drop**: Reorder tasks with physics
- **Swipe Actions**: Mobile swipe to complete/delete
- **Keyboard Shortcuts**: Power user shortcuts
- **Voice Input**: Speech-to-text for quick task addition
- **Haptic Feedback**: Vibration on mobile for actions

### 4. Data Persistence
- **Local Storage**: Tasks saved in browser
- **Export/Import**: JSON backup and restore
- **Sync Simulation**: Fake sync with loading states
- **Offline Support**: Works without internet

## Technical Requirements

### Performance
- Initial load: < 2 seconds
- Task operations: < 100ms response
- Animations: 60fps minimum
- Bundle size: < 200KB gzipped

### Accessibility
- Screen reader support
- Keyboard navigation
- High contrast mode
- Font size controls
- VoiceOver compatibility

## File Structure
```
src/
  components/
    TaskItem/
      TaskItem.tsx
      TaskItem.module.css
    TaskList/
      TaskList.tsx
      TaskList.module.css
  hooks/
    useLocalStorage.ts
    useDragDrop.ts
  styles/
    textures.css
    animations.css
  utils/
    dateHelpers.ts
    animationHelpers.ts
```
```

#### Step 3: Create Implementation Plan (Tech Stack & Architecture)

The implementation plan translates specs into technical tasks.

```bash
# Generate implementation plan
specify create plan --spec spec.md

# Review and edit plan
specify edit plan
```

**Example Plan (`plan.md`)**:
```markdown
---
name: skeuomorphic-todo-plan
description: Implementation plan for skeuomorphic todo app
spec: spec.md
version: 1.0.0
---

# Implementation Plan

## Phase 1: Project Setup
1. **Initialize React TypeScript Project**
   - Create with Create React App
   - Configure TypeScript strict mode
   - Set up folder structure

2. **Configure Development Environment**
   - Set up ESLint and Prettier
   - Configure CSS modules
   - Add texture assets

## Phase 2: Core Components
1. **Create Base Components**
   - `App` component with leather header
   - `TaskList` with paper texture
   - `TaskItem` with 3D styling

2. **Implement Task Operations**
   - Add task functionality
   - Edit task inline
   - Delete with confirmation
   - Mark complete animation

## Phase 3: Advanced Features
1. **Drag and Drop**
   - Implement drag handles
   - Add physics animations
   - Save new order

2. **Visual Polish**
   - Add realistic shadows
   - Implement press animations
   - Create hand-drawn icons

## Phase 4: Testing & Optimization
1. **Performance Optimization**
   - Optimize animations
   - Lazy load components
   - Minimize bundle size

2. **Accessibility**
   - Add ARIA labels
   - Implement keyboard nav
   - Test screen readers

## Technology Stack
- **Frontend**: React 18 + TypeScript
- **Styling**: CSS Modules + CSS3 animations
- **State**: React Context + useReducer
- **Icons**: SVG with hand-drawn style
- **Textures**: CSS gradients and filters
```

#### Step 4: Generate Tasks

Convert the plan into actionable tasks for Claude Code.

```bash
# Generate tasks from plan
specify generate tasks

# Output to specific format
specify generate tasks --format claude-code

# Save to file
specify generate tasks --output tasks.md
```

**Generated Tasks Structure**:
```markdown
# Implementation Tasks

## Task 1: Project Setup
- Create React TypeScript app
- Configure strict TypeScript
- Set up folder structure
- Install dependencies

## Task 2: Create Constitution Components
- Build leather header component
- Style with realistic texture
- Add stitched border effect
- Implement responsive design

## Task 3: Implement Task List
- Create paper texture background
- Build task list container
- Add subtle paper lines
- Implement shadow effects

## Task 4: Task Item Component
- Design 3D task item
- Add hover animations
- Implement checkbox styling
- Create delete button

## Task 5: Task Operations
- Implement add task form
- Create inline edit mode
- Add confirmation dialogs
- Build complete animations

## Task 6: Drag and Drop
- Install drag-drop library
- Implement drag handles
- Add physics animations
- Save order to state

## Task 7: Visual Polish
- Add realistic shadows
- Create press animations
- Design hand-drawn icons
- Implement lighting effects

## Task 8: State Management
- Create task context
- Implement useReducer
- Add local storage sync
- Handle edge cases

## Task 9: Performance
- Optimize animations
- Add React.memo
- Implement lazy loading
- Minimize re-renders

## Task 10: Accessibility
- Add ARIA labels
- Implement keyboard nav
- Test with screen readers
- Add focus management
```

#### Step 5: Execute Implementation

Use Claude Code to implement each task systematically.

```bash
# Start Claude Code session
claude

# In the session, work through tasks
# "Implement Task 1: Create React TypeScript project with the following requirements..."

# Or use the wrapper script
./scripts/claude-wrapper.sh task --write "Implement Task 1: Create React TypeScript project with strict mode enabled and set up the folder structure as defined in the spec"
```

### Practical Example: Skeuomorphic Todo Project

Let's walk through a real example of creating a skeuomorphic todo application.

#### 1. Project Initialization

```bash
# Create project directory
mkdir skeuomorphic-todo
cd skeuomorphic-todo

# Initialize with Spec Kit
specify init --ai claude

# Project structure created:
# .
# ├── .spec/
# │   ├── config.json
# │   └── templates/
# ├── constitution.md (template)
# ├── spec.md (template)
# └── plan.md (template)
```

#### 2. Create Constitution

```bash
# Edit constitution
nano constitution.md

# Add skeuomorphic design principles
```

#### 3. Define Specification

```bash
# Create detailed spec
specify create spec --template web-app

# Edit with todo-specific features
nano spec.md
```

#### 4. Generate Implementation Plan

```bash
# Auto-generate plan from spec
specify create plan --ai claude

# Review and adjust
specify review plan
```

#### 5. Generate Tasks and Execute

```bash
# Generate actionable tasks
specify generate tasks --format claude-code > TASKS.md

# Start implementation with Claude Code
./scripts/claude-wrapper.sh task --write "Implement Phase 1: Create React TypeScript app with the structure defined in TASKS.md"
```

#### File Structure Created

After running the Spec Kit workflow, you'll have:

```
skeuomorphic-todo/
├── .spec/
│   ├── config.json
│   └── templates/
├── public/
│   ├── index.html
│   └── textures/
│       ├── paper-texture.jpg
│       └── leather-texture.jpg
├── src/
│   ├── components/
│   │   ├── App/
│   │   │   ├── App.tsx
│   │   │   └── App.module.css
│   │   ├── TaskList/
│   │   │   ├── TaskList.tsx
│   │   │   └── TaskList.module.css
│   │   └── TaskItem/
│   │       ├── TaskItem.tsx
│   │       └── TaskItem.module.css
│   ├── hooks/
│   │   ├── useLocalStorage.ts
│   │   └── useDragDrop.ts
│   ├── styles/
│   │   ├── textures.css
│   │   └── animations.css
│   ├── utils/
│   │   └── dateHelpers.ts
│   └── index.tsx
├── constitution.md
├── spec.md
├── plan.md
├── TASKS.md
└── package.json
```

#### Commands Used During Implementation

```bash
# Task 1: Setup
./scripts/claude-wrapper.sh task --write "Create React TypeScript app with the name 'skeuomorphic-todo', enable strict TypeScript mode, and create the folder structure defined in the constitution"

# Task 2: Header Component
./scripts/claude-wrapper.sh task --write "Create a leather-textured header component with stitched border effects using CSS gradients and filters. Make it responsive and follow the skeuomorphic design principles from the constitution"

# Task 3: Paper Texture Background
./scripts/claude-wrapper.sh task --write "Implement paper texture background for the task list using CSS with subtle paper lines effect. Use CSS gradients to create realistic paper appearance"

# Task 4: 3D Task Items
./scripts/claude-wrapper.sh task --write "Create TaskItem component with 3D styling including realistic shadows, press-down animations on click, and hover effects. Use CSS transforms and transitions"

# Task 5: Task Operations
./scripts/claude-wrapper.sh task --write "Implement add, edit, delete, and complete task functionality with smooth animations. Use React hooks for state management"

# Task 6: Drag and Drop
./scripts/claude-wrapper.sh task --write "Add drag and drop functionality to reorder tasks using react-beautiful-dnd library. Include physics-based animations"

# Task 7: Visual Polish
./scripts/claude-wrapper.sh task --write "Add final visual polish including hand-drawn style SVG icons, improved shadows and lighting effects, and micro-interactions"

# Task 8: Performance Optimization
./scripts/claude-wrapper.sh task --write "Optimize performance by adding React.memo to components, implementing lazy loading, and reducing bundle size"

# Task 9: Accessibility
./scripts/claude-wrapper.sh task --write "Add comprehensive accessibility features including ARIA labels, keyboard navigation, screen reader support, and focus management"
```

### Best Practices

#### Writing Effective Constitutions

1. **Be Specific About Design Principles**
   ```markdown
   # Good: Specific
   - **Typography**: Use system fonts with 1.5 line height for readability
   - **Color Palette**: Primary #FF6B6B, Secondary #4ECDC4, Neutral #F7F7F7

   # Avoid: Vague
   - Make it look nice
   - Use good colors
   ```

2. **Include Technical Constraints**
   ```markdown
   # Good: Concrete
   - **Browser Support**: Chrome 90+, Firefox 88+, Safari 14+
   - **Bundle Size**: < 150KB gzipped for initial load

   # Avoid: Ambiguous
   - Support modern browsers
   - Keep it lightweight
   ```

3. **Define Measurable Standards**
   ```markdown
   # Good: Measurable
   - **Performance**: LCP < 2.5s, FID < 100ms, CLS < 0.1
   - **Accessibility**: WCAG 2.1 AA compliance, keyboard navigation
   ```

#### Creating Detailed Specifications

1. **Break Down Features**
   ```markdown
   ## Feature: User Authentication

   ### Requirements:
   - Email/password login
   - OAuth (Google, GitHub)
   - Password reset via email
   - Two-factor authentication

   ### Acceptance Criteria:
   - Users can register with email validation
   - Password must be 8+ chars with special characters
   - Session persists for 30 days
   - Failed login shows generic error
   ```

2. **Include User Stories**
   ```markdown
   ## User Story: Task Creation

   As a busy professional,
   I want to quickly add tasks,
   So that I don't forget important work.

   ### Scenarios:
   - Quick add with just title
   - Detailed add with due date and notes
   - Voice input on mobile
   ```

3. **Define Edge Cases**
   ```markdown
   ## Edge Cases:
   - Network failure during sync
   - Maximum task length (500 chars)
   - Special characters in task names
   - Browser storage quota exceeded
   ```

#### Managing the Workflow

1. **Version Control Your Specs**
   ```bash
   # Track all spec files
   git add constitution.md spec.md plan.md
   git commit -m "Update specification with new features"

   # Tag stable versions
   git tag v1.0-spec
   ```

2. **Iterate on Specifications**
   ```bash
   # Review and update specs
   specify review spec

   # Update plan after spec changes
   specify update plan

   # Regenerate tasks
   specify generate tasks --force
   ```

3. **Use Branching for Experiments**
   ```bash
   # Create feature branch
   git checkout -b feature/advanced-animations

   # Update spec for new feature
   specify edit spec

   # Generate new tasks
   specify generate tasks
   ```

#### Tips for Successful Implementation

1. **Start Small**
   - Begin with MVP features
   - Get core functionality working
   - Add polish incrementally

2. **Review Generated Tasks**
   ```bash
   # Always review before implementing
   specify generate tasks > TASKS.md
   nano TASKS.md  # Edit as needed
   ```

3. **Use Appropriate Models**
   ```bash
   # Quick tasks with Haiku
   ./scripts/claude-wrapper.sh task --model haiku --write "Implement basic button component"

   # Complex features with Sonnet
   ./scripts/claude-wrapper.sh task --model sonnet --write "Implement drag and drop with physics"

   # Architecture decisions with Opus
   ./scripts/claude-wrapper.sh task --model opus --write "Design state management architecture"
   ```

4. **Set Realistic Budgets**
   ```bash
   # Simple component: $0.50
   ./scripts/claude-wrapper.sh task --max-budget-usd 0.50 --write "Create button component"

   # Complex feature: $5.00
   ./scripts/claude-wrapper.sh task --max-budget-usd 5.00 --write "Implement authentication system"
   ```

### Troubleshooting

#### Common Issues and Solutions

1. **"Spec not found" Error**
   ```bash
   # Check current directory
   pwd

   # Initialize if needed
   specify init --ai claude

   # Verify spec files exist
   ls *.md
   ```

2. **"Invalid constitution" Error**
   ```bash
   # Validate YAML frontmatter
   # Ensure proper format:
   ---
   name: my-constitution
   description: My project principles
   version: 1.0.0
   ---
   ```

3. **Tasks Not Generating**
   ```bash
   # Check spec completeness
   specify validate spec

   # Ensure plan exists
   specify create plan --force

   # Try verbose output
   specify generate tasks --verbose
   ```

4. **Claude Code Integration Issues**
   ```bash
   # Use wrapper script
   ./scripts/claude-wrapper.sh task --write "Your task here"

   # Check TTY issues
   # See TTY/PTY section in main documentation
   ```

#### How to Iterate on Specs

1. **Incremental Updates**
   ```bash
   # Small changes to spec
   specify edit spec

   # Update only affected tasks
   specify update tasks --incremental
   ```

2. **Major Refactoring**
   ```bash
   # Backup current spec
   cp spec.md spec.md.backup

   # Make major changes
   nano spec.md

   # Regenerate everything
   specify create plan --force
   specify generate tasks --force
   ```

3. **A/B Testing Approaches**
   ```bash
   # Create variant specs
   cp spec.md spec-variant-a.md
   cp spec.md spec-variant-b.md

   # Generate tasks for each
   specify generate tasks --spec spec-variant-a.md > tasks-a.md
   specify generate tasks --spec spec-variant-b.md > tasks-b.md

   # Implement and compare
   ```

4. **Collaborative Editing**
   ```bash
   # Share spec for review
   specify export spec --format pdf > spec-review.pdf

   # Merge feedback
   specify merge spec --input feedback.md
   ```

## References

- [Claude Code Docs](https://code.claude.com/docs)
- [Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview)
- [MCP Documentation](https://code.claude.com/docs/en/mcp)

## Spec Kit Workflow Guide

Spec Kit is a toolkit for Spec-Driven Development that works seamlessly with Claude Code. It helps you build high-quality software by making specifications executable.

### What is Spec-Driven Development?

Spec-Driven Development flips traditional development on its head. Instead of writing code first, you:
1. Define principles and standards (Constitution)
2. Specify what you want to build (Specification)
3. Plan the implementation (Implementation Plan)
4. Generate actionable tasks
5. Execute with AI assistance

### Installation

```bash
# Install specify-cli
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# Verify installation
specify check
```

### Setting Up a Project with Claude Code

```bash
# Create new project
specify init my-project --ai claude

# Or initialize in current directory
specify init . --ai claude --here
```

### The Complete Workflow

#### Step 1: Establish Constitution

Create `.specify/constitution.md` with your design principles:

```markdown
# Project Constitution

## Design Principles
- Visual hierarchy and consistency
- Mobile-first responsive design
- Performance optimization

## Code Standards
- Semantic HTML5
- BEM CSS methodology
- ES6+ JavaScript
```

Use in Claude Code:
```bash
claude "/speckit.constitution Create principles for a modern web app"
```

#### Step 2: Create Specification

Define what to build in `.specify/specifications/`:

```bash
claude "/speckit.specify Build a task management app with categories, 
priorities, and due dates. Include drag-and-drop functionality."
```

#### Step 3: Create Implementation Plan

Define technical approach:

```bash
claude "/speckit.plan Use React with TypeScript, Tailwind CSS for styling,
and localStorage for persistence."
```

#### Step 4: Generate Tasks

Break down into actionable items:

```bash
claude "/speckit.tasks"
```

#### Step 5: Execute Implementation

Implement all tasks:

```bash
claude "/speckit.implement"
```

### Real-World Example: Skeuomorphic Todo App

Here's a complete example:

**Project Structure Created:**
```
skeuomorphic-todo/
├── .specify/
│   ├── constitution.md      # Design principles
│   └── specifications/
│       ├── todo-app.md      # Feature specs
│       └── implementation-plan.md
├── index.html
├── css/style.css           # 14KB of skeuomorphic styles
└── js/app.js              # Full functionality
```

**Commands Used:**
```bash
# Initialize
specify init . --ai claude --here

# Create constitution with design principles
claude "/speckit.constitution Define skeuomorphic design with leather textures,
realistic shadows, and 3D button effects"

# Specify features
claude "/speckit.specify Create a todo app with leather-bound notebook UI,
paper texture for tasks, realistic checkbox animations, and localStorage"

# Plan implementation
claude "/speckit.plan Use vanilla HTML/CSS/JS with advanced CSS gradients
for textures, no external libraries"

# Generate and implement
claude "/speckit.tasks"
claude "/speckit.implement"
```

### Best Practices

1. **Detailed Constitutions**: The more specific your principles, the better the output
2. **Clear Specifications**: Focus on 'what' and 'why', not 'how'
3. **Iterative Refinement**: Use /speckit.clarify to refine unclear specs
4. **Version Control**: Commit after each major step
5. **Review Tasks**: Always review generated tasks before implementing

### Tips for Success

- Start with a clear vision
- Be specific in specifications
- Use examples in your constitution
- Don't skip the planning step
- Review and iterate on specs

### Common Commands Reference

| Command | Purpose |
|---------|---------|
| `/speckit.constitution` | Define project principles |
| `/speckit.specify` | Create feature specification |
| `/speckit.plan` | Technical implementation plan |
| `/speckit.tasks` | Generate actionable tasks |
| `/speckit.implement` | Execute all tasks |
| `/speckit.clarify` | Refine unclear specifications |

