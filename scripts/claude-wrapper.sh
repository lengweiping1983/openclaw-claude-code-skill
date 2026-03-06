#!/bin/bash
# Claude Code Wrapper Script
# Handles TTY/PTY requirements for non-interactive environments
# Usage: ./claude-wrapper.sh [command] [options]

set -euo pipefail

# Error handling
trap 'echo -e "${RED}Error occurred in script at line $LINENO${NC}"; exit 1' ERR

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
    status                  Check if Claude Code is ready
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

# macOS-compatible timeout function
timeout_cmd() {
    local timeout_seconds=$1
    shift

    if command -v gtimeout &> /dev/null; then
        # GNU timeout from coreutils
        gtimeout "$timeout_seconds" "$@"
    elif command -v timeout &> /dev/null; then
        # Linux timeout
        timeout "$timeout_seconds" "$@"
    else
        # Fallback implementation for macOS
        local cmd_pid
        "$@" &
        cmd_pid=$!

        (
            sleep "$timeout_seconds"
            kill -TERM "$cmd_pid" 2>/dev/null
            sleep 1
            kill -KILL "$cmd_pid" 2>/dev/null
        ) &
        local sleeper_pid=$!

        if wait "$cmd_pid"; then
            kill "$sleeper_pid" 2>/dev/null
            wait "$sleeper_pid" 2>/dev/null
            return 0
        else
            local exit_code=$?
            kill "$sleeper_pid" 2>/dev/null
            wait "$sleeper_pid" 2>/dev/null
            return $exit_code
        fi
    fi
}

# Check if Claude Code is installed
check_claude() {
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Error: Claude Code is not installed.${NC}"
        echo "Install with: curl -fsSL https://claude.ai/install.sh | bash"
        exit 1
    fi
}

# Check Claude Code status
check_status() {
    echo -e "${BLUE}Checking Claude Code status...${NC}"

    # Check if installed
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}✗ Claude Code is not installed${NC}"
        echo "  Install with: curl -fsSL https://claude.ai/install.sh | bash"
        return 1
    fi
    echo -e "${GREEN}✓ Claude Code is installed${NC}"

    # Check version
    local version
    if version=$(claude --version 2>/dev/null); then
        echo -e "${GREEN}✓ Version: $version${NC}"
    else
        echo -e "${YELLOW}! Unable to determine version${NC}"
    fi

    # Check authentication
    echo -e "${BLUE}Checking authentication...${NC}"
    if claude auth status &> /dev/null; then
        echo -e "${GREEN}✓ Authenticated with Claude Code${NC}"
    else
        echo -e "${RED}✗ Not authenticated with Claude Code${NC}"
        echo "  Run: claude auth login"
        return 1
    fi

    # Check TTY availability
    echo -e "${BLUE}Checking environment...${NC}"
    if [ -t 0 ] && [ -t 1 ]; then
        echo -e "${GREEN}✓ TTY environment available${NC}"
    else
        echo -e "${YELLOW}! Not running in a TTY environment${NC}"
        echo "  Consider running directly in terminal for best experience"
    fi

    # Check for required tools
    if command -v script &> /dev/null; then
        echo -e "${GREEN}✓ 'script' command available${NC}"
    else
        echo -e "${YELLOW}! 'script' command not found${NC}"
    fi

    return 0
}

# Check if running in a TTY
check_tty() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo -e "${YELLOW}Warning: Not running in a TTY environment.${NC}"
        echo "Claude Code works best in an interactive terminal."
        echo "Consider running this command directly in your terminal."
        echo ""

        # Check if we can use script command
        if ! command -v script > /dev/null 2>&1; then
            echo -e "${YELLOW}Warning: 'script' command not found.${NC}"
            echo "Install with: brew install util-linux (macOS) or apt-get install bsdutils (Linux)"
            echo ""
        fi
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
        echo -e "${BLUE}Using TTY wrapper for better compatibility...${NC}"
        script -q /dev/null -c "claude $cmd $args" || {
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo -e "${YELLOW}Retrying without TTY wrapper...${NC}"
                claude $cmd $args || return $?
            fi
            return $exit_code
        }
    else
        # Direct execution
        echo -e "${BLUE}Executing directly (no TTY available)...${NC}"
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
                if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
                    echo -e "${RED}Error: --budget requires a value${NC}"
                    exit 1
                fi
                if ! [[ "$2" =~ ^[0-9]+("."[0-9]+)?$ ]]; then
                    echo -e "${RED}Error: Budget must be a number${NC}"
                    exit 1
                fi
                budget="$2"
                shift 2
                ;;
            --model)
                if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
                    echo -e "${RED}Error: --model requires a value${NC}"
                    exit 1
                fi
                model="$2"
                shift 2
                ;;
            --chrome)
                chrome="--chrome"
                shift
                ;;
            --output)
                if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
                    echo -e "${RED}Error: --output requires a value${NC}"
                    exit 1
                fi
                output="$2"
                shift 2
                ;;
            --timeout)
                if [[ -z "$2" ]] || [[ "$2" =~ ^-- ]]; then
                    echo -e "${RED}Error: --timeout requires a value${NC}"
                    exit 1
                fi
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}Error: Timeout must be a number (seconds)${NC}"
                    exit 1
                fi
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
    local start_time=$(date +%s)
    echo -e "${BLUE}Starting execution...${NC}"

    # Execute command
    if timeout_cmd "$timeout" bash -c "claude $cmd $flags \"$prompt\"" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo -e "${GREEN}✓ Task completed successfully in ${duration}s${NC}"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 137 ]]; then
            echo -e "${RED}✗ Error: Command timed out after ${timeout} seconds.${NC}"
        else
            echo -e "${RED}✗ Error: Command failed with exit code ${exit_code}${NC}"
        fi
        return $exit_code
    fi
}

# Execute with error handling
execute_with_retry() {
    local cmd=("$@")
    local max_retries=2
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if "${cmd[@]}"; then
            return 0
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                echo -e "${YELLOW}Retrying... (attempt $((retry_count + 1))/${max_retries})${NC}"
                sleep 1
            else
                return $exit_code
            fi
        fi
    done
}
}

# Main command handler
main() {
    # Don't check Claude for status/help commands
    if [[ "$1" != "status" ]] && [[ "$1" != "help" ]] && [[ "$1" != "--help" ]] && [[ "$1" != "-h" ]]; then
        check_claude
        check_tty
    fi

    local command="${1:-help}"
    shift || true

    # Handle errors gracefully
    local exit_code=0
    case "$command" in
        task)
            build_task_command "$@"
            ;;

        interactive|i)
            echo -e "${GREEN}Starting interactive Claude Code session...${NC}"
            echo -e "${YELLOW}Press Ctrl+D or type /exit to quit${NC}"
            echo -e "${BLUE}Initializing...${NC}"
            echo ""
            execute_claude ""
            ;;

        review)
            local path="${1:-.}"
            echo -e "${GREEN}Reviewing $path...${NC}"
            echo -e "${BLUE}Analyzing code quality, bugs, and best practices...${NC}"
            build_task_command --write --budget 5.00 "Review the code in $path for quality, bugs, and best practices. Provide specific, actionable feedback."
            ;;

        explain)
            local path="${1:-.}"
            echo -e "${GREEN}Explaining $path...${NC}"
            echo -e "${BLUE}Analyzing architecture and components...${NC}"
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

        status)
            check_status
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

    exit $exit_code
}

# Run main function
main "$@"
