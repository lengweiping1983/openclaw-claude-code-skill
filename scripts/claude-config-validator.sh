#!/bin/bash
# Claude Code Configuration Validator
# Validates Claude Code installation and configuration

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Validation functions
validate_claude_installed() {
    echo -e "${BLUE}Checking Claude Code installation...${NC}"

    if command -v claude &> /dev/null; then
        VERSION=$(claude --version 2>/dev/null || echo "Unknown")
        echo -e "${GREEN}✓ Claude Code installed${NC}"
        echo -e "  Version: $VERSION"
        return 0
    else
        echo -e "${RED}✗ Claude Code not found${NC}"
        echo -e "  Install with: curl -fsSL https://claude.ai/install.sh | bash"
        return 1
    fi
}

validate_authentication() {
    echo -e "${BLUE}Checking authentication...${NC}"

    if claude auth status &> /dev/null; then
        echo -e "${GREEN}✓ Authenticated${NC}"
        return 0
    else
        echo -e "${RED}✗ Not authenticated${NC}"
        echo -e "  Run: claude auth login"
        return 1
    fi
}

validate_environment() {
    echo -e "${BLUE}Checking environment...${NC}"

    # Check TTY
    if [ -t 0 ] && [ -t 1 ]; then
        echo -e "${GREEN}✓ TTY available${NC}"
    else
        echo -e "${YELLOW}! No TTY available${NC}"
        echo -e "  Consider using wrapper scripts for automation"
    fi

    # Check required tools
    local missing_tools=()

    if ! command -v script &> /dev/null; then
        missing_tools+=("script")
    fi

    if ! command -v timeout &> /dev/null && ! command -v gtimeout &> /dev/null; then
        missing_tools+=("timeout/gtimeout")
    fi

    if [ ${#missing_tools[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All required tools available${NC}"
    else
        echo -e "${YELLOW}! Missing tools: ${missing_tools[*]}${NC}"
        echo -e "  Install with package manager"
    fi
}

validate_configuration() {
    echo -e "${BLUE}Checking configuration...${NC}"

    # Check config directory
    if [ -d "$HOME/.claude" ]; then
        echo -e "${GREEN}✓ Config directory exists${NC}"

        # Check permissions
        if [ -r "$HOME/.claude" ] && [ -w "$HOME/.claude" ]; then
            echo -e "${GREEN}✓ Config directory permissions OK${NC}"
        else
            echo -e "${RED}✗ Config directory permissions issue${NC}"
            chmod 700 "$HOME/.claude"
        fi
    else
        echo -e "${YELLOW}! Config directory not found${NC}"
        echo -e "  Will be created on first run"
    fi

    # Check environment variables
    echo -e "${BLUE}Environment variables:${NC}"

    if [ -n "${CLAUDE_CODE_TIMEOUT:-}" ]; then
        echo -e "  CLAUDE_CODE_TIMEOUT=$CLAUDE_CODE_TIMEOUT"
    else
        echo -e "  CLAUDE_CODE_TIMEOUT=300 (default)"
    fi

    if [ -n "${CLAUDE_CODE_BUDGET:-}" ]; then
        echo -e "  CLAUDE_CODE_BUDGET=$CLAUDE_CODE_BUDGET"
    else
        echo -e "  CLAUDE_CODE_BUDGET=10.00 (default)"
    fi

    if [ -n "${CLAUDE_CODE_MODEL:-}" ]; then
        echo -e "  CLAUDE_CODE_MODEL=$CLAUDE_CODE_MODEL"
    else
        echo -e "  CLAUDE_CODE_MODEL=sonnet (default)"
    fi
}

validate_mcp_config() {
    echo -e "${BLUE}Checking MCP configuration...${NC}"

    local mcp_configs=(
        "$HOME/.claude/mcp.json"
        "$HOME/.claude/mcp.config.json"
        "./mcp.json"
        "./.claude/mcp.json"
    )

    local found_config=false
    for config in "${mcp_configs[@]}"; do
        if [ -f "$config" ]; then
            echo -e "${GREEN}✓ MCP config found: $config${NC}"
            # Basic JSON validation
            if command -v jq &> /dev/null; then
                if jq empty "$config" 2>/dev/null; then
                    echo -e "${GREEN}✓ Valid JSON${NC}"
                else
                    echo -e "${RED}✗ Invalid JSON${NC}"
                fi
            fi
            found_config=true
            break
        fi
    done

    if [ "$found_config" = false ]; then
        echo -e "${YELLOW}! No MCP configuration found${NC}"
        echo -e "  Create one at ~/.claude/mcp.json"
    fi
}

validate_examples() {
    echo -e "${BLUE}Checking example agents...${NC}"

    local examples_dir="$SKILL_DIR/examples/agents"
    if [ -d "$examples_dir" ]; then
        local agent_count=0
        for agent in "$examples_dir"/*.md; do
            if [ -f "$agent" ]; then
                agent_name=$(basename "$agent" .md)
                echo -e "${GREEN}✓ $agent_name${NC}"
                ((agent_count++))
            fi
        done
        echo -e "${GREEN}✓ Found $agent_count example agents${NC}"
    else
        echo -e "${YELLOW}! Examples directory not found${NC}"
    fi
}

run_diagnostics() {
    echo -e "${BLUE}Running Claude Code diagnostics...${NC}"

    # Try to run a simple command
    if claude -p "echo 'diagnostic test'" &> /dev/null; then
        echo -e "${GREEN}✓ Claude Code is working correctly${NC}"
        return 0
    else
        echo -e "${RED}✗ Claude Code test failed${NC}"
        return 1
    fi
}

show_help() {
    cat << EOF
Claude Code Configuration Validator

USAGE:
    ./claude-config-validator.sh [OPTIONS]

OPTIONS:
    --diagnose              Run full diagnostics
    --fix                   Attempt to fix issues
    --quiet                 Minimal output
    --json                  Output in JSON format
    --help                  Show this help

EXAMPLES:
    ./claude-config-validator.sh
    ./claude-config-validator.sh --diagnose
    ./claude-config-validator.sh --fix

EOF
}

# Main function
main() {
    local run_diagnostics=false
    local fix_issues=false
    local quiet=false
    local json_output=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --diagnose)
                run_diagnostics=true
                shift
                ;;
            --fix)
                fix_issues=true
                shift
                ;;
            --quiet)
                quiet=true
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    echo -e "${PURPLE}=== Claude Code Configuration Validator ===${NC}"
    echo

    local issues=0

    # Run validations
    validate_claude_installed || ((issues++))
    echo

    validate_authentication || ((issues++))
    echo

    validate_environment
    echo

    validate_configuration
    echo

    validate_mcp_config
    echo

    validate_examples
    echo

    if [ "$run_diagnostics" = true ]; then
        run_diagnostics || ((issues++))
        echo
    fi

    # Summary
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}✓ All validations passed!${NC}"
        exit 0
    else
        echo -e "${YELLOW}! Found $issues issue(s)${NC}"
        exit 1
    fi
}

# Run main function
main "$@"