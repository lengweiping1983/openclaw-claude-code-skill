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
    status                  Check Claude Code installation status
    config                  Show current configuration
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

    # Check status
    ./claude-wrapper.sh status

    # Show configuration
    ./claude-wrapper.sh config

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
    echo -e "${BLUE}=== Claude Code Status Check ===${NC}"
    echo

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
    echo
    echo -e "${BLUE}Authentication Status:${NC}"
    if claude auth status &> /dev/null; then
        echo -e "${GREEN}✓ Authenticated with Claude Code${NC}"
        # Try to get more auth details
        local auth_output=$(claude auth status 2>&1)
        if [[ "$auth_output" =~ "Logged in as" ]]; then
            echo -e "  $auth_output"
        fi
    else
        echo -e "${RED}✗ Not authenticated with Claude Code${NC}"
        echo "  Run: claude auth login"
    fi

    # Check environment
    echo
    echo -e "${BLUE}Environment Check:${NC}"
    if [ -t 0 ] && [ -t 1 ]; then
        echo -e "${GREEN}✓ TTY environment available${NC}"
    else
        echo -e "${YELLOW}! Not running in a TTY environment${NC}"
        echo "  Consider running directly in terminal for best experience"
    fi

    # Check for required tools
    local missing_tools=()

    # Check for 'script' command
    if command -v script &> /dev/null; then
        echo -e "${GREEN}✓ 'script' command available${NC}"
    else
        echo -e "${YELLOW}! 'script' command not found${NC}"
        missing_tools+=("script")
    fi

    # Check for timeout commands
    if command -v gtimeout &> /dev/null || command -v timeout &> /dev/null; then
        echo -e "${GREEN}✓ Timeout command available${NC}"
    else
        echo -e "${YELLOW}! No timeout command found (gtimeout/timeout)${NC}"
    fi

    # Check Claude Code configuration
    echo
    echo -e "${BLUE}Configuration:${NC}"
    local config_dir="$HOME/.config/claude"
    if [[ -d "$config_dir" ]]; then
        echo -e "${GREEN}✓ Config directory exists${NC}"
        if [[ -f "$config_dir/config.json" ]]; then
            echo -e "${GREEN}✓ Config file found${NC}"
        else
            echo -e "${YELLOW}! No config file found${NC}"
        fi
    else
        echo -e "${YELLOW}! No config directory found${NC}"
    fi

    # Check environment variables
    echo
    echo -e "${BLUE}Environment Variables:${NC}"
    local env_vars=("CLAUDE_CODE_TIMEOUT" "CLAUDE_CODE_BUDGET" "CLAUDE_CODE_MODEL" "ANTHROPIC_API_KEY")
    for var in "${env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            echo -e "${GREEN}✓ $var=${!var}${NC}"
        else
            echo -e "  $var: not set"
        fi
    done

    # Check API connectivity (if authenticated)
    if claude auth status &> /dev/null; then
        echo
        echo -e "${BLUE}API Connectivity Test:${NC}"
        echo -e "Testing API connection..."
        if claude -p "test connection" --max-budget-usd 0.01 &> /dev/null; then
            echo -e "${GREEN}✓ API connection successful${NC}"
        else
            echo -e "${RED}✗ API connection failed${NC}"
        fi
    fi

    return 0
}

# Show current configuration
show_config() {
    echo -e "${BLUE}=== Claude Code Configuration ===${NC}"
    echo

    # Show default values
    echo -e "${BLUE}Default Settings:${NC}"
    echo -e "  Timeout: ${CLAUDE_CODE_TIMEOUT:-300} seconds"
    echo -e "  Budget: $${CLAUDE_CODE_BUDGET:-10.00} USD"
    echo -e "  Model: ${CLAUDE_CODE_MODEL:-sonnet}"
    echo

    # Show environment variables
    echo -e "${BLUE}Environment Variables:${NC}"
    local env_vars=("CLAUDE_CODE_TIMEOUT" "CLAUDE_CODE_BUDGET" "CLAUDE_CODE_MODEL" "ANTHROPIC_API_KEY" "FORCE_COLOR" "CLAUDE_CODE_DISABLE_TELEMETRY")
    for var in "${env_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            echo -e "  $var=${!var}"
        else
            echo -e "  $var: (not set)"
        fi
    done
    echo

    # Show Claude Code config if available
    local config_file="$HOME/.config/claude/config.json"
    if [[ -f "$config_file" ]]; then
        echo -e "${BLUE}Claude Code Config File ($config_file):${NC}"
        if command -v jq &> /dev/null; then
            jq . "$config_file" 2>/dev/null || cat "$config_file"
        else
            cat "$config_file"
        fi
    else
        echo -e "${YELLOW}No Claude Code config file found${NC}"
    fi
    echo

    # Show available models
    echo -e "${BLUE}Available Models:${NC}"
    echo -e "  - sonnet (default): Balanced performance and speed"
    echo -e "  - opus: Most capable, higher cost"
    echo -e "  - haiku: Fastest, most cost-effective"
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
    if command -v script > /dev/null 2>&1 && [ -t 0 ]; then
        # Use script to ensure TTY
        echo -e "${BLUE}Using TTY wrapper for better compatibility...${NC}"
        if script -q /dev/null -c "claude $cmd $args"; then
            return 0
        else
            local exit_code=$?
            if [[ $exit_code -ne 0 ]] && [[ $exit_code -ne 130 ]]; then
                # Don't retry on Ctrl+C (exit code 130)
                echo -e "${YELLOW}Retrying without TTY wrapper...${NC}"
                claude $cmd $args
            fi
            return $exit_code
        fi
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
        echo -e "${YELLOW}Allowed tools: Read, Edit, Write, Bash, Glob, Grep${NC}"
    else
        flags="$flags --allowedTools \"Read,Bash(ls *),Bash(cat *),Grep,Glob\""
        echo -e "${BLUE}Running in read-only mode (use --write to allow file modifications)...${NC}"
        echo -e "${YELLOW}Allowed tools: Read, Bash (ls/cat only), Grep, Glob${NC}"
    fi

    echo -e "${GREEN}Executing Claude Code task...${NC}"
    echo -e "${YELLOW}Prompt:${NC} $prompt"
    echo -e "${YELLOW}Budget:${NC} \$$budget | ${YELLOW}Model:${NC} $model | ${YELLOW}Timeout:${NC} ${timeout}s"
    echo -e "${BLUE}Progress:${NC} Starting task execution..."
    echo ""

    # Execute with timeout
    local start_time=$(date +%s)
    local exit_code=0

    # Show progress indicator
    (
        local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        local i=0
        while kill -0 $! 2>/dev/null; do
            printf "\r${BLUE}Progress:${NC} %s Executing task..." "${spin:i++%${#spin}:1}"
            sleep 0.1
        done
        printf "\r${BLUE}Progress:${NC} Task execution completed.\n"
    ) &
    local spinner_pid=$!

    if timeout_cmd "$timeout" bash -c "claude $cmd $flags \"$prompt\"" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        echo ""
        echo -e "${GREEN}✓ Task completed successfully in ${duration}s${NC}"
        return 0
    else
        exit_code=$?
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        echo ""
        if [[ $exit_code -eq 124 ]] || [[ $exit_code -eq 137 ]]; then
            echo -e "${RED}✗ Error: Command timed out after ${timeout} seconds.${NC}"
        else
            echo -e "${RED}✗ Error: Command failed with exit code ${exit_code}${NC}"
            # Check if it's a common error
            if [[ $exit_code -eq 127 ]]; then
                echo -e "${YELLOW}Hint: Command not found. Is Claude Code installed?${NC}"
            elif [[ $exit_code -eq 126 ]]; then
                echo -e "${YELLOW}Hint: Command not executable. Check permissions.${NC}"
            fi
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

# Cleanup function
cleanup() {
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null
    wait
}
trap cleanup EXIT
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
            if ! build_task_command "$@"; then
                exit_code=$?
            fi
            ;;

        interactive|i)
            echo -e "${GREEN}Starting interactive Claude Code session...${NC}"
            echo -e "${YELLOW}Press Ctrl+D or type /exit to quit${NC}"
            echo -e "${BLUE}Initializing...${NC}"
            echo ""
            if ! execute_claude ""; then
                exit_code=$?
            fi
            ;;

        review)
            local path="${1:-.}"
            echo -e "${GREEN}Reviewing $path...${NC}"
            echo -e "${BLUE}Analyzing code quality, bugs, and best practices...${NC}"
            if ! build_task_command --write --budget 5.00 "Review the code in $path for quality, bugs, and best practices. Provide specific, actionable feedback."; then
                exit_code=$?
            fi
            ;;

        explain)
            local path="${1:-.}"
            echo -e "${GREEN}Explaining $path...${NC}"
            echo -e "${BLUE}Analyzing architecture and components...${NC}"
            if ! build_task_command "Explain the code in $path. Include architecture overview, key components, and how they interact."; then
                exit_code=$?
            fi
            ;;

        refactor)
            local prompt="$1"
            if [[ -z "$prompt" ]]; then
                echo -e "${RED}Error: Please provide refactoring instructions${NC}"
                echo "Usage: ./claude-wrapper.sh refactor \"optimize these functions\""
                exit 1
            fi
            echo -e "${GREEN}Refactoring: $prompt${NC}"
            if ! build_task_command --write --budget 10.00 "$prompt"; then
                exit_code=$?
            fi
            ;;

        session|s)
            local name="$1"
            if [[ -z "$name" ]]; then
                echo -e "${YELLOW}Available sessions:${NC}"
                if ! claude agents; then
                    exit_code=$?
                fi
                echo ""
                echo "To resume a session: ./claude-wrapper.sh session <name-or-id>"
            else
                echo -e "${GREEN}Resuming session: $name${NC}"
                if ! execute_claude "-r \"$name\""; then
                    exit_code=$?
                fi
            fi
            ;;

        agents|a)
            echo -e "${GREEN}Managing subagents...${NC}"
            if ! claude agents; then
                exit_code=$?
            fi
            ;;

        auth)
            echo -e "${GREEN}Checking authentication...${NC}"
            if ! claude auth status; then
                exit_code=$?
            fi
            ;;

        status)
            check_status
            ;;

        doctor)
            echo -e "${GREEN}Running diagnostics...${NC}"
            if ! claude /doctor; then
                exit_code=$?
            fi
            ;;

        help|--help|-h)
            show_help
            ;;

        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit_code=1
            ;;
    esac

    exit $exit_code
}

# Cleanup function
cleanup() {
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null
    wait
}
trap cleanup EXIT

# Run main function
main "$@"
