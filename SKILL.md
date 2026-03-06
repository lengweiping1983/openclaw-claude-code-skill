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

1. **Start with print mode** (`-p`) for automation and scripting
2. **Use subagents** for specialized tasks to keep context clean
3. **Set budget limits** (`--max-budget-usd`) for cost control
4. **Use permission modes** appropriately - `plan` for exploration, `acceptEdits` for trusted changes
5. **Leverage worktrees** (`-w`) for parallel Claude Code sessions
6. **Preload skills** into subagents for domain-specific knowledge

## Troubleshooting

### Why Direct Calls Fail

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

### Authentication Issues

**Problem**: "Not authenticated" error
```bash
# Check status
claude auth status

# Login
claude auth login
```

### Session not found
- Use `claude -r` without arguments to see available sessions
- Check `~/.claude/sessions/` for session files

### Tool Approval Issues

When running programmatically, use `--allowedTools` to pre-approve:

```bash
# Allow read-only operations
claude -p --allowedTools "Read,Grep,Glob" "analyze code"

# Allow read and write
claude -p --allowedTools "Read,Edit,Write,Bash" "refactor code"
```

### Timeout Issues

Increase timeout for complex tasks:

```bash
# Set longer timeout
export CLAUDE_CODE_TIMEOUT=600
./scripts/claude-wrapper.sh task --write "implement complex feature"
```

## References

- [Claude Code Docs](https://code.claude.com/docs)
- [Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview)
- [MCP Documentation](https://code.claude.com/docs/en/mcp)
