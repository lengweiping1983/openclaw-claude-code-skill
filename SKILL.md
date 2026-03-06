---
name: claude-code
description: Integrate with Claude Code CLI for agentic coding workflows. Use when you need to (1) start interactive coding sessions, (2) execute one-off coding tasks via print mode, (3) resume previous Claude Code sessions, (4) create and manage subagents, (5) configure MCP servers, or (6) delegate complex coding tasks to Claude Code from OpenClaw.
---

# Claude Code Integration

This skill provides seamless integration with Claude Code CLI, Anthropic's agentic coding tool. Use it to delegate coding tasks, manage subagents, and leverage Claude Code's specialized capabilities from within OpenClaw.

## Prerequisites

Claude Code must be installed:
```bash
# macOS/Linux/WSL
curl -fsSL https://claude.ai/install.sh | bash

# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```

## Core Commands

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
claude -p "analyze the error in logs.txt"
```

Process piped input:
```bash
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

When OpenClaw needs to delegate to Claude Code:

1. **Simple task**: Use `claude -p` for one-shot execution
2. **Complex project work**: Use `claude` for interactive session
3. **Resume work**: Use `claude -c` or `claude -r`
4. **Safe exploration**: Use `--permission-mode plan` first

### Capturing Output

For programmatic use from OpenClaw:

```bash
# JSON output
claude -p --output-format json "analyze dependencies"

# Stream JSON for real-time processing
claude -p --output-format stream-json --include-partial-messages "task"
```

## Best Practices

1. **Start with print mode** (`-p`) for automation and scripting
2. **Use subagents** for specialized tasks to keep context clean
3. **Set budget limits** (`--max-budget-usd`) for cost control
4. **Use permission modes** appropriately - `plan` for exploration, `acceptEdits` for trusted changes
5. **Leverage worktrees** (`-w`) for parallel Claude Code sessions
6. **Preload skills** into subagents for domain-specific knowledge

## Troubleshooting

### Session not found
- Use `claude -r` without arguments to see available sessions
- Check `~/.claude/sessions/` for session files

### Permission denied
- Run `claude auth login` to authenticate
- Check `claude auth status`

### Tool not available
- Verify tools in `claude --allowedTools` list
- Check if MCP server is running: `claude mcp`

## References

- [Claude Code Docs](https://code.claude.com/docs)
- [Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview)
- [MCP Documentation](https://code.claude.com/docs/en/mcp)
