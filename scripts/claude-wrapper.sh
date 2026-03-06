#!/bin/bash
# Claude Code Wrapper Script
# Handles TTY/PTY requirements for non-interactive environments
# Usage: ./claude-wrapper.sh [command] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Help message
show_help() {
    cat << EOF
Claude Code Wrapper Script
Handles TTY/PTY requirements when calling Claude Code from OpenClaw or other automation tools.

USAGE:
    ./claude-wrapper.sh [COMMAND] [OPTIONS]

COMMANDS:
    task "prompt"           Execute a one-off task (print mode)
    task --write "prompt"   Execute task with write permissions
    interactive             Start interactive session
    review [path]           Code review of directory or file
    explain [path]          Explain code at path
    refactor "prompt"       Refactoring with auto-accept edits
    session [name]          Resume or list sessions
    agents                  List and manage subagents
    auth                    Check authentication status
    doctor                  Diagnose Claude Code installation

OPTIONS FOR 'task' COMMAND:
    --write, -w             Allow file writes (Edit, Write tools)
    --budget [USD]          Set max budget (default: 10.00)
    --model [sonnet|opus]   Select model (default: sonnet)
    --chrome                Enable browser automation
    --output [text|json]    Output format (default: text)
    --timeout [seconds]     Set timeout (default: 300)

EXAMPLES:
    # Basic task execution
    ./claude-wrapper.sh task "explain the main function"

    # Create files (allows write operations)
    ./claude-wrapper.sh task --write "create a login page with HTML/CSS/JS"

    # With budget limit
    ./claude-wrapper.sh task --write --budget 5.00 "implement user auth"

    # Start interactive session
    ./claude-wrapper.sh interactive

    # Code review
    ./claude-wrapper.sh review src/

    # Resume session
    ./claude-wrapper.sh session my-feature

ENVIRONMENT VARIABLES:
    CLAUDE_CODE_TIMEOUT     Default timeout in seconds (default: 300)
    CLAUDE_CODE_BUDGET      Default budget in USD (default: 10.00)
    CLAUDE_CODE_MODEL       Default model (default: sonnet)

EOF
}

# Check if Claude Code is installed
check_claude() {
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Error: Claude Code is not installed.${NC}"
        echo "Install with: curl -fsSL https://claude.ai/install.sh | bash"
        exit 1
    fi

    # Check authentication
    if ! claude auth status &> /dev/null; then
        echo -e "${RED}Error: Not authenticated with Claude Code.${NC}"
        echo "Run: claude auth login"
        exit 1
    fi
}

# Check if running in a TTY
check_tty() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo -e "${YELLOW}Warning: Not running in a TTY environment.${NC}"
        echo "Claude Code works best in an interactive terminal."
        echo "Consider running this command directly in your terminal."
        echo ""
    fi
}

# Execute Claude Code with proper environment
execute_claude() {
    local cmd="$1"
    shift
    local args="$@"

    # Set environment variables for better compatibility
    export FORCE_COLOR=1
    export CLAUDE_CODE_DISABLE_TELEMETRY=0

    # Execute with script command to ensure TTY if available
    if command -v script &> /dev/null && [ -t 0 ]; then
        # Use script to ensure TTY
        script -q /dev/null -c "claude $cmd $args"
    else
        # Direct execution
        claude $cmd $args
    fi
}

# Build task command with options
build_task_command() {
    local prompt=""
    local allow_write=false
    local budget="${CLAUDE_CODE_BUDGET:-10.00}"
    local model="${CLAUDE_CODE_MODEL:-sonnet}"
    local chrome=""
    local output="text"
    local timeout="${CLAUDE_CODE_TIMEOUT:-300}"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --write|-w)
                allow_write=true
                shift
                ;;
            --budget)
                budget="$2"
                shift 2
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --chrome)
                chrome="--chrome"
                shift
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                prompt="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$prompt" ]]; then
        echo -e "${RED}Error: No prompt provided.${NC}"
        echo "Usage: ./claude-wrapper.sh task [options] \"your prompt here\""
        exit 1
    fi

    # Build command
    local cmd="-p"
    local flags="--model $model --max-budget-usd $budget --output-format $output"

    if [[ -n "$chrome" ]]; then
        flags="$flags $chrome"
    fi

    # Set allowed tools based on write permission
    if [[ "$allow_write" == true ]]; then
        flags="$flags --allowedTools \"Read,Edit,Write,Bash,Glob,Grep\""
        echo -e "${BLUE}Running with write permissions enabled...${NC}"
    else
        flags="$flags --allowedTools \"Read,Bash(ls *),Bash(cat *),Grep,Glob\""
        echo -e "${BLUE}Running in read-only mode (use --write to allow file modifications)...${NC}"
    fi

    echo -e "${GREEN}Executing Claude Code task...${NC}"
    echo -e "${YELLOW}Prompt:${NC} $prompt"
    echo -e "${YELLOW}Budget:${NC} \$$budget | ${YELLOW}Model:${NC} $model | ${YELLOW}Timeout:${NC} ${timeout}s"
    echo ""

    # Execute with timeout
    timeout "$timeout" bash -c "claude $cmd $flags \"$prompt\"" || {
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${RED}Error: Command timed out after ${timeout} seconds.${NC}"
        fi
        return $exit_code
    }
}

# Main command handler
main() {
    check_claude
    check_tty

    local command="${1:-help}"
    shift || true

    case "$command" in
        task)
            build_task_command "$@"
            ;;

        interactive|i)
            echo -e "${GREEN}Starting interactive Claude Code session...${NC}"
            echo -e "${YELLOW}Press Ctrl+D or type /exit to quit${NC}"
            echo ""
            execute_claude ""
            ;;

        review)
            local path="${1:-.}"
            echo -e "${GREEN}Reviewing $path...${NC}"
            build_task_command --write --budget 5.00 "Review the code in $path for quality, bugs, and best practices. Provide specific, actionable feedback."
            ;;

        explain)
            local path="${1:-.}"
            echo -e "${GREEN}Explaining $path...${NC}"
            build_task_command "Explain the code in $path. Include architecture overview, key components, and how they interact."
            ;;

        refactor)
            local prompt="$1"
            if [[ -z "$prompt" ]]; then
                echo -e "${RED}Error: Please provide refactoring instructions${NC}"
                echo "Usage: ./claude-wrapper.sh refactor \"optimize these functions\""
                exit 1
            fi
            echo -e "${GREEN}Refactoring: $prompt${NC}"
            build_task_command --write --budget 10.00 "$prompt"
            ;;

        session|s)
            local name="$1"
            if [[ -z "$name" ]]; then
                echo -e "${YELLOW}Available sessions:${NC}"
                claude agents
                echo ""
                echo "To resume a session: ./claude-wrapper.sh session <name-or-id>"
            else
                echo -e "${GREEN}Resuming session: $name${NC}"
                execute_claude "-r \"$name\""
            fi
            ;;

        agents|a)
            echo -e "${GREEN}Managing subagents...${NC}"
            claude agents
            ;;

        auth)
            echo -e "${GREEN}Checking authentication...${NC}"
            claude auth status
            ;;

        doctor)
            echo -e "${GREEN}Running diagnostics...${NC}"
            claude /doctor
            ;;

        help|--help|-h)
            show_help
            ;;

        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
