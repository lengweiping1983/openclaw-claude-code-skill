# Claude Code Integration Skill for OpenClaw

A production-ready skill that enables seamless integration between OpenClaw and Claude Code CLI, Anthropic's agentic coding tool. This skill provides reliable wrappers, utilities, and best practices for delegating coding tasks to Claude Code from within OpenClaw workflows.

## 🚀 Quick Start

```bash
# Navigate to skill directory
cd /Users/lengweiping/.openclaw/workspace/skills/claude-code

# Run a simple task
./scripts/claude-wrapper.sh task "explain this codebase"

# Create files with write permissions
./scripts/claude-wrapper.sh task --write "create a React login component"

# Start interactive session
./scripts/claude-wrapper.sh interactive
```

## 📋 Prerequisites

1. **Claude Code Installation**:
   ```bash
   # macOS/Linux/WSL
   curl -fsSL https://claude.ai/install.sh | bash

   # Windows PowerShell
   irm https://claude.ai/install.ps1 | iex
   ```

2. **Authentication**:
   ```bash
   claude auth login
   ```

3. **Verify Installation**:
   ```bash
   claude --version
   claude auth status
   ```

## 🛠️ Available Scripts

### 1. `claude-wrapper.sh` - Main Wrapper Script

The primary wrapper that handles TTY/PTY requirements and provides a reliable interface:

```bash
# Basic usage patterns
./scripts/claude-wrapper.sh task "analyze the error logs"
./scripts/claude-wrapper.sh task --write --budget 5.00 "implement user authentication"
./scripts/claude-wrapper.sh review src/
./scripts/claude-wrapper.sh refactor "optimize database queries"
./scripts/claude-wrapper.sh session my-feature-branch
```

### 2. `claude-launcher.sh` - Quick Launcher

Fast launcher with preset configurations for common tasks:

```bash
# Quick tasks
./scripts/claude-launcher.sh quick "explain main.py"

# Code review with automatic agent
./scripts/claude-launcher.sh review src/

# Refactoring with auto-accept
./scripts/claude-launcher.sh refactor "optimize these functions"

# Fix issues automatically
./scripts/claude-launcher.sh fix
```

### 3. Additional Utility Scripts

- `claude-config-validator.sh` - Validates Claude Code configuration
- `claude-project-setup.sh` - Sets up Claude Code for new projects
- `claude-batch-runner.sh` - Runs multiple Claude Code tasks

## 🔧 Configuration

### Environment Variables

```bash
# Set defaults in your shell profile
export CLAUDE_CODE_TIMEOUT=600        # Default timeout (seconds)
export CLAUDE_CODE_BUDGET=10.00        # Default budget (USD)
export CLAUDE_CODE_MODEL=sonnet        # Default model
export CLAUDE_CODE_DISABLE_TELEMETRY=0 # Enable telemetry
```

### MCP Server Configuration

Configure external tools via MCP:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token"
      }
    }
  }
}
```

## 🎯 Common Use Cases

### 1. Code Review Workflow

```bash
# Review entire codebase
./scripts/claude-wrapper.sh review .

# Review specific directory
./scripts/claude-wrapper.sh review src/components/

# Review with custom agent
./scripts/claude-wrapper.sh task --write \
  --agents "examples/agents/security-auditor.md" \
  "Review src/ for security vulnerabilities"
```

### 2. Development Tasks

```bash
# Create new feature
./scripts/claude-wrapper.sh task --write --budget 10.00 \
  "Implement user authentication with JWT tokens"

# Debug issues
./scripts/claude-wrapper.sh task \
  "Debug why tests are failing in test/auth.test.js"

# Optimize performance
./scripts/claude-wrapper.sh refactor \
  "Optimize database queries in models/"
```

### 3. Documentation

```bash
# Generate documentation
./scripts/claude-wrapper.sh task --write \
  "Create comprehensive API documentation for src/api/"

# Update README
./scripts/claude-wrapper.sh task --write \
  "Update README.md with installation instructions"
```

## 🤝 Integration with OpenClaw

### From OpenClaw Skills

```bash
# Use the wrapper script for reliable execution
bash /Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh \
  task --write "create a new React component"
```

### From OpenClaw Agents

```python
# Example: Calling from an OpenClaw agent
exec({
    "command": "/Users/lengweiping/.openclaw/workspace/skills/claude-code/scripts/claude-wrapper.sh task --write 'implement user login'",
    "timeout": 600,
    "pty": True  # Important for TTY support
})
```

## 🎨 Custom Subagents

### Using Pre-built Agents

The skill includes several pre-configured subagents:

- **Security Auditor** (`examples/agents/security-auditor.md`) - Scans for vulnerabilities
- **Performance Optimizer** (`examples/agents/performance-optimizer.md`) - Optimizes code performance
- **Test Writer** (`examples/agents/test-writer.md`) - Creates comprehensive tests
- **Documentation Writer** (`examples/agents/documentation-writer.md`) - Writes documentation

### Creating Custom Agents

```bash
# Create agent inline
./scripts/claude-wrapper.sh task \
  --agents '{"api-tester": {"description": "API test creator", "tools": ["Read", "Write"], "model": "sonnet"}}' \
  "Use api-tester to create tests for src/api/"

# Use agent file
./scripts/claude-wrapper.sh task \
  --agents "examples/agents/security-auditor.md" \
  "Audit the authentication module"
```

## ⚠️ Troubleshooting

### Common Issues

1. **"Not in TTY environment" Error**
   - Use the wrapper scripts (they handle TTY requirements)
   - Run commands directly in your terminal
   - Ensure `pty: true` when calling from automation

2. **Authentication Issues**
   ```bash
   # Check status
   claude auth status

   # Re-authenticate
   claude auth login
   ```

3. **Timeout Issues**
   ```bash
   # Increase timeout
   export CLAUDE_CODE_TIMEOUT=600
   ./scripts/claude-wrapper.sh task --timeout 600 "complex task"
   ```

4. **Permission Denied**
   ```bash
   # Use --write flag for file modifications
   ./scripts/claude-wrapper.sh task --write "modify files"
   ```

### Debug Mode

```bash
# Enable verbose output
./scripts/claude-wrapper.sh task --verbose "debug this issue"

# Run diagnostics
./scripts/claude-wrapper.sh doctor
```

## 📊 Best Practices

### 1. Task Delegation

- **Start with read-only tasks** to understand the codebase
- **Use specific prompts** for better results
- **Set budget limits** to control costs
- **Break complex tasks** into smaller chunks

### 2. Security Considerations

- **Review generated code** before committing
- **Use read-only mode** for initial exploration
- **Audit security** with dedicated agents
- **Never commit secrets** or credentials

### 3. Performance Optimization

- **Use appropriate models**: Sonnet for coding, Haiku for quick tasks, Opus for complex analysis
- **Set reasonable timeouts** based on task complexity
- **Use worktrees** for parallel development
- **Cache results** when possible

## 🔗 Advanced Features

### Worktree Support

```bash
# Use isolated worktree
./scripts/claude-wrapper.sh task -w feature-branch "implement new feature"
```

### Browser Automation

```bash
# Enable Chrome automation
./scripts/claude-wrapper.sh task --chrome "test the login flow"
```

### Batch Operations

```bash
# Run multiple tasks
./scripts/claude-batch-runner.sh tasks.txt
```

## 📚 Examples

See the `examples/` directory for:

- Pre-configured subagents
- MCP server configurations
- Common workflow examples
- Integration patterns

## 🔗 References

- [Claude Code Documentation](https://code.claude.com/docs)
- [Agent SDK Guide](https://platform.claude.com/docs/en/agent-sdk/overview)
- [MCP Protocol](https://code.claude.com/docs/en/mcp)
- [OpenClaw Documentation](https://openclaw.ai/docs)

## 🤝 Contributing

To contribute to this skill:

1. Test changes thoroughly with different Claude Code versions
2. Update documentation for new features
3. Add examples for new use cases
4. Ensure backward compatibility

## 📄 License

This skill is part of the OpenClaw project and follows the same licensing terms.