#!/bin/bash
# Claude Code Quick Launcher
# Usage: ./claude-launcher.sh [command] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help message
show_help() {
    cat << EOF
Claude Code Quick Launcher

USAGE:
    ./claude-launcher.sh [COMMAND] [OPTIONS]

COMMANDS:
    quick "prompt"        Quick one-off task (print mode)
    review [path]         Code review of directory or file
    explain [path]        Explain code at path
    refactor "prompt"     Refactoring task with auto-accept edits
    fix                   Fix issues (uses recent error context)
    session [name]        Resume session by name
    continue              Continue last session
    agent [name]          Create custom subagent
    mcp                   Configure MCP servers

OPTIONS:
    --model [sonnet|opus|haiku]  Select model (default: sonnet)
    --budget [USD]               Set max budget (default: 5.00)
    --chrome                     Enable browser automation
    --plan                       Plan mode (read-only)
    --verbose                    Verbose output

EXAMPLES:
    ./claude-launcher.sh quick "explain main.py"
    ./claude-launcher.sh review src/
    ./claude-launcher.sh refactor "optimize database queries" --budget 10
    ./claude-launcher.sh session "feature-auth"
    ./claude-launcher.sh agent "security-auditor"

EOF
}

# Check if Claude Code is installed
check_claude() {
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Claude Code is not installed.${NC}"
        echo "Install with: curl -fsSL https://claude.ai/install.sh | bash"
        exit 1
    fi
}

# Parse model argument
MODEL="sonnet"
BUDGET=""
CHROME=""
PLAN=""
VERBOSE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --model)
                MODEL="$2"
                shift 2
                ;;
            --budget)
                BUDGET="$2"
                shift 2
                ;;
            --chrome)
                CHROME="--chrome"
                shift
                ;;
            --plan)
                PLAN="--permission-mode plan"
                shift
                ;;
            --verbose)
                VERBOSE="--verbose"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done
}

# Build common flags
build_flags() {
    local flags="--model $MODEL"
    if [[ -n "$BUDGET" ]]; then
        flags="$flags --max-budget-usd $BUDGET"
    fi
    if [[ -n "$CHROME" ]]; then
        flags="$flags $CHROME"
    fi
    if [[ -n "$PLAN" ]]; then
        flags="$flags $PLAN"
    fi
    if [[ -n "$VERBOSE" ]]; then
        flags="$flags $VERBOSE"
    fi
    echo "$flags"
}

# Main command handler
main() {
    check_claude
    
    local command="$1"
    shift || true
    
    parse_args "$@"
    
    case "$command" in
        quick)
            shift || true
            local prompt="$1"
            if [[ -z "$prompt" ]]; then
                echo -e "${RED}Error: Please provide a prompt${NC}"
                echo "Usage: ./claude-launcher.sh quick \"your prompt here\""
                exit 1
            fi
            echo -e "${GREEN}Running quick task...${NC}"
            claude -p $(build_flags) "$prompt"
            ;;
            
        review)
            shift || true
            local path="${1:-.}"
            echo -e "${GREEN}Reviewing $path...${NC}"
            claude -p $(build_flags) --agents '{
                "code-reviewer": {
                    "description": "Reviews code for quality, security, and best practices",
                    "prompt": "You are a senior code reviewer. Analyze the code for bugs, security issues, performance problems, and best practice violations. Provide specific, actionable feedback.",
                    "tools": ["Read", "Grep", "Glob", "Bash"],
                    "model": "sonnet"
                }
            }' "Use the code-reviewer agent to review $path"
            ;;
            
        explain)
            shift || true
            local path="${1:-.}"
            echo -e "${GREEN}Explaining $path...${NC}"
            claude -p $(build_flags) "Explain the code in $path. Include architecture, key components, and how they interact."
            ;;
            
        refactor)
            shift || true
            local prompt="$1"
            if [[ -z "$prompt" ]]; then
                echo -e "${RED}Error: Please provide refactoring instructions${NC}"
                echo "Usage: ./claude-launcher.sh refactor \"optimize these functions\""
                exit 1
            fi
            echo -e "${GREEN}Refactoring: $prompt${NC}"
            claude -p $(build_flags) --permission-mode acceptEdits "$prompt"
            ;;
            
        fix)
            echo -e "${GREEN}Attempting to fix issues...${NC}"
            claude -p $(build_flags) --permission-mode acceptEdits "Find and fix any bugs, errors, or issues in the codebase. Check for: syntax errors, logic errors, failing tests, and common anti-patterns."
            ;;
            
        session)
            shift || true
            local name="$1"
            if [[ -z "$name" ]]; then
                echo -e "${YELLOW}Available sessions:${NC}"
                claude agents
                exit 0
            fi
            echo -e "${GREEN}Resuming session: $name${NC}"
            claude -r "$name" $(build_flags)
            ;;
            
        continue)
            echo -e "${GREEN}Continuing last session...${NC}"
            claude -c $(build_flags)
            ;;
            
        agent)
            shift || true
            local agent_name="$1"
            if [[ -z "$agent_name" ]]; then
                echo -e "${RED}Error: Please provide agent name${NC}"
                echo "Usage: ./claude-launcher.sh agent \"security-auditor\""
                exit 1
            fi
            echo -e "${GREEN}Creating subagent: $agent_name${NC}"
            claude --agents "{\"$agent_name\": {\"description\": \"Custom agent for $agent_name tasks\", \"prompt\": \"You are a specialized agent for $agent_name. Focus on delivering high-quality results.\", \"tools\": [\"Read\", \"Edit\", \"Write\", \"Bash\"], \"model\": \"sonnet\"}}"
            ;;
            
        mcp)
            echo -e "${GREEN}Opening MCP configuration...${NC}"
            claude mcp
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            if [[ -z "$command" ]]; then
                echo -e "${YELLOW}Starting interactive Claude Code session...${NC}"
                claude $(build_flags)
            else
                echo -e "${RED}Unknown command: $command${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
}

main "$@"
