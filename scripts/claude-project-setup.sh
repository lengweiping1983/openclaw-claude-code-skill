#!/bin/bash
# Claude Code Project Setup Script
# Sets up Claude Code for new projects with best practices

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
PROJECT_NAME=""
PROJECT_TYPE="auto"
LANGUAGE="auto"
FRAMEWORK="none"
INCLUDE_DOCS=true
INCLUDE_TESTS=true
INCLUDE_CI=true
SETUP_MCP=false

# Detect project type
detect_project_type() {
    local project_dir="${1:-.}"

    # Check for common project files
    if [ -f "$project_dir/package.json" ]; then
        echo "nodejs"
    elif [ -f "$project_dir/requirements.txt" ] || [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ]; then
        echo "python"
    elif [ -f "$project_dir/pom.xml" ] || [ -f "$project_dir/build.gradle" ]; then
        echo "java"
    elif [ -f "$project_dir/go.mod" ]; then
        echo "go"
    elif [ -f "$project_dir/Cargo.toml" ]; then
        echo "rust"
    elif [ -f "$project_dir/composer.json" ]; then
        echo "php"
    else
        echo "generic"
    fi
}

# Detect programming language
detect_language() {
    local project_dir="${1:-.}"
    local lang_count=$(find "$project_dir" -type f -name "*.py" 2>/dev/null | wc -l)
    local js_count=$(find "$project_dir" -type f -name "*.js" -o -name "*.ts" 2>/dev/null | wc -l)
    local java_count=$(find "$project_dir" -type f -name "*.java" 2>/dev/null | wc -l)
    local go_count=$(find "$project_dir" -type f -name "*.go" 2>/dev/null | wc -l)
    local rust_count=$(find "$project_dir" -type f -name "*.rs" 2>/dev/null | wc -l)

    local max_count=0
    local detected_lang="generic"

    if [ $lang_count -gt $max_count ]; then
        max_count=$lang_count
        detected_lang="python"
    fi

    if [ $js_count -gt $max_count ]; then
        max_count=$js_count
        detected_lang="javascript"
    fi

    if [ $java_count -gt $max_count ]; then
        max_count=$java_count
        detected_lang="java"
    fi

    if [ $go_count -gt $max_count ]; then
        max_count=$go_count
        detected_lang="go"
    fi

    if [ $rust_count -gt $max_count ]; then
        detected_lang="rust"
    fi

    echo "$detected_lang"
}

# Create Claude Code configuration
create_claude_config() {
    local project_dir="$1"
    local project_type="$2"
    local language="$3"

    echo -e "${BLUE}Creating Claude Code configuration...${NC}"

    mkdir -p "$project_dir/.claude"

    # Create project-specific instructions
    cat > "$project_dir/.claude/instructions.md" << EOF
# Claude Code Instructions for $PROJECT_NAME

## Project Overview
- Type: $project_type
- Language: $language
- Framework: $FRAMEWORK

## Code Style Guidelines
$(get_style_guidelines "$language")

## Testing Requirements
$(get_testing_guidelines "$project_type")

## Build and Run Commands
$(get_build_commands "$project_type" "$language")

## Project Structure
$(get_project_structure "$project_type")

## Common Tasks
$(get_common_tasks "$project_type")

EOF

    echo -e "${GREEN}✓ Created instructions.md${NC}"
}

# Get style guidelines based on language
get_style_guidelines() {
    local lang="$1"
    case "$lang" in
        python)
            echo "- Follow PEP 8 style guide"
            echo "- Use type hints where appropriate"
            echo "- Maximum line length: 88 characters (Black formatter)"
            echo "- Use docstrings for all public functions"
            ;;
        javascript|typescript)
            echo "- Use ESLint configuration"
            echo "- Prefer const/let over var"
            echo "- Use async/await over callbacks"
            echo "- Follow functional programming patterns"
            ;;
        java)
            echo "- Follow Google Java Style Guide"
            echo "- Use meaningful variable names"
            echo "- Proper indentation: 2 spaces"
            echo "- Add Javadoc comments for public methods"
            ;;
        go)
            echo "- Follow gofmt formatting"
            echo "- Use go vet for static analysis"
            echo "- Keep functions small and focused"
            echo "- Handle errors explicitly"
            ;;
        *)
            echo "- Follow language-specific best practices"
            echo "- Maintain consistent indentation"
            echo "- Use meaningful variable names"
            echo "- Add comments for complex logic"
            ;;
    esac
}

# Get testing guidelines
get_testing_guidelines() {
    local type="$1"
    case "$type" in
        nodejs)
            echo "- Use Jest or Mocha for testing"
            echo "- Aim for 80% code coverage"
            echo "- Write unit tests for all functions"
            echo "- Include integration tests for APIs"
            ;;
        python)
            echo "- Use pytest for testing"
            echo "- Aim for 80% code coverage"
            echo "- Write unit tests for all functions"
            echo "- Include integration tests for APIs"
            ;;
        java)
            echo "- Use JUnit for testing"
            echo "- Aim for 80% code coverage"
            echo "- Write unit tests for all public methods"
            echo "- Include integration tests for APIs"
            ;;
        *)
            echo "- Write comprehensive tests"
            echo "- Aim for good code coverage"
            echo "- Include both unit and integration tests"
            ;;
    esac
}

# Get build commands
get_build_commands() {
    local type="$1"
    local lang="$2"
    case "$type" in
        nodejs)
            echo "- Install: npm install"
            echo "- Build: npm run build"
            echo "- Test: npm test"
            echo "- Run: npm start"
            ;;
        python)
            echo "- Install: pip install -r requirements.txt"
            echo "- Build: python setup.py build"
            echo "- Test: pytest"
            echo "- Run: python main.py"
            ;;
        java)
            echo "- Build: mvn compile"
            echo "- Test: mvn test"
            echo "- Package: mvn package"
            echo "- Run: java -jar target/app.jar"
            ;;
        go)
            echo "- Build: go build"
            echo "- Test: go test"
            echo "- Run: go run main.go"
            ;;
        *)
            echo "- Follow project-specific build instructions"
            ;;
    esac
}

# Get project structure
get_project_structure() {
    local type="$1"
    case "$type" in
        nodejs)
            echo "- src/: Source code"
            echo "- test/: Test files"
            echo "- public/: Static assets"
            echo "- package.json: Dependencies and scripts"
            ;;
        python)
            echo "- src/: Source code"
            echo "- tests/: Test files"
            echo "- requirements.txt: Dependencies"
            echo "- setup.py: Package configuration"
            ;;
        java)
            echo "- src/main/java/: Source code"
            echo "- src/test/java/: Test files"
            echo "- pom.xml: Maven configuration"
            ;;
        *)
            echo "- src/: Source code"
            echo "- tests/: Test files"
            echo "- docs/: Documentation"
            ;;
    esac
}

# Get common tasks
get_common_tasks() {
    local type="$1"
    case "$type" in
        nodejs)
            echo "- Run development server: npm run dev"
            echo "- Run tests: npm test"
            echo "- Build for production: npm run build"
            echo "- Lint code: npm run lint"
            ;;
        python)
            echo "- Run tests: pytest"
            echo "- Format code: black ."
            echo "- Type check: mypy ."
            echo "- Run linter: flake8"
            ;;
        java)
            echo "- Run tests: mvn test"
            echo "- Build: mvn compile"
            echo "- Package: mvn package"
            echo "- Run: mvn exec:java"
            ;;
        *)
            echo "- Run tests"
            echo "- Build project"
            echo "- Check code quality"
            ;;
    esac
}

# Create custom agents
create_custom_agents() {
    local project_dir="$1"
    local project_type="$2"

    echo -e "${BLUE}Creating custom agents...${NC}"

    mkdir -p "$project_dir/.claude/agents"

    # Code Reviewer Agent
    cat > "$project_dir/.claude/agents/code-reviewer.md" << EOF
---
name: code-reviewer
description: Specialized code reviewer for $PROJECT_NAME
model: sonnet
tools: Read, Grep, Glob, Bash
---

You are a code reviewer for $PROJECT_NAME, a $project_type project.

Review Focus:
- Code quality and best practices for $project_type
- Security vulnerabilities
- Performance issues
- Maintainability and readability
- Test coverage

Always provide:
1. Summary of findings
2. Specific issues with file:line references
3. Actionable recommendations
4. Priority level (High/Medium/Low)

EOF

    # Security Auditor Agent
    cat > "$project_dir/.claude/agents/security-auditor.md" << EOF
---
name: security-auditor
description: Security-focused reviewer for $PROJECT_NAME
model: sonnet
tools: Read, Grep, Glob, Bash
---

You are a security auditor for $PROJECT_NAME.

Security Focus:
- OWASP Top 10 vulnerabilities
- Input validation and sanitization
- Authentication and authorization
- Data encryption and protection
- Dependency vulnerabilities
- API security

Provide:
1. Severity level (Critical/High/Medium/Low)
2. Specific vulnerability details
3. Exploitation scenario
4. Recommended fixes with code examples

EOF

    echo -e "${GREEN}✓ Created custom agents${NC}"
}

# Create MCP configuration
create_mcp_config() {
    local project_dir="$1"

    if [ "$SETUP_MCP" = true ]; then
        echo -e "${BLUE}Creating MCP configuration...${NC}"

        cat > "$project_dir/.claude/mcp.json" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$project_dir"],
      "env": {}
    }
  }
}
EOF

        echo -e "${GREEN}✓ Created MCP configuration${NC}"
    fi
}

# Create documentation
create_documentation() {
    local project_dir="$1"

    if [ "$INCLUDE_DOCS" = true ]; then
        echo -e "${BLUE}Creating Claude Code documentation...${NC}"

        mkdir -p "$project_dir/docs/claude"

        cat > "$project_dir/docs/claude/README.md" << EOF
# Claude Code Integration

This project uses Claude Code for AI-assisted development.

## Quick Start

\`\`\`bash
# Review your code
claude -p "review the authentication module"

# Generate tests
claude -p "create unit tests for src/auth.js"

# Debug issues
claude -p "why are the tests failing?"
\`\`\`

## Using the Wrapper Script

\`\`\`bash
# From project root
./scripts/claude-wrapper.sh review src/
./scripts/claude-wrapper.sh task --write "implement new feature"
\`\`\`

## Custom Agents

This project includes custom Claude Code agents:

- \`code-reviewer\`: Specialized code reviewer
- \`security-auditor\`: Security-focused auditor

Use them with:
\`\`\`bash
claude --agents .claude/agents/code-reviewer.md "review src/"
\`\`\`

EOF

        echo -e "${GREEN}✓ Created documentation${NC}"
    fi
}

# Create example usage scripts
create_example_scripts() {
    local project_dir="$1"

    echo -e "${BLUE}Creating example scripts...${NC}"

    mkdir -p "$project_dir/scripts/claude"

    # Review script
    cat > "$project_dir/scripts/claude/review.sh" << 'EOF'
#!/bin/bash
# Code review script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CLADE_WRAPPER="$PROJECT_ROOT/scripts/claude-wrapper.sh"

if [ $# -eq 0 ]; then
    path="src/"
else
    path="$1"
fi

"$CLADE_WRAPPER" review "$path"
EOF

    # Test script
    cat > "$project_dir/scripts/claude/test.sh" << 'EOF'
#!/bin/bash
# Test runner script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CLADE_WRAPPER="$PROJECT_ROOT/scripts/claude-wrapper.sh"

"$CLADE_WRAPPER" test "${1:-.}"
EOF

    # Make scripts executable
    chmod +x "$project_dir/scripts/claude/"*.sh

    echo -e "${GREEN}✓ Created example scripts${NC}"
}

# Show help
show_help() {
    cat << EOF
Claude Code Project Setup

USAGE:
    ./claude-project-setup.sh [OPTIONS]

OPTIONS:
    --name NAME             Project name (default: directory name)
    --type TYPE             Project type: nodejs, python, java, go, rust, generic (default: auto-detect)
    --language LANG         Primary language (default: auto-detect)
    --framework FRAMEWORK   Framework name (optional)
    --no-docs               Skip documentation creation
    --no-tests              Skip test setup
    --no-ci                 Skip CI configuration
    --with-mcp              Setup MCP servers
    --help                  Show this help

EXAMPLES:
    ./claude-project-setup.sh
    ./claude-project-setup.sh --name myapp --type nodejs
    ./claude-project-setup.sh --type python --with-mcp

EOF
}

# Main function
main() {
    local project_dir="."

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --type)
                PROJECT_TYPE="$2"
                shift 2
                ;;
            --language)
                LANGUAGE="$2"
                shift 2
                ;;
            --framework)
                FRAMEWORK="$2"
                shift 2
                ;;
            --no-docs)
                INCLUDE_DOCS=false
                shift
                ;;
            --no-tests)
                INCLUDE_TESTS=false
                shift
                ;;
            --no-ci)
                INCLUDE_CI=false
                shift
                ;;
            --with-mcp)
                SETUP_MCP=true
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

    # Auto-detect if not specified
    if [ "$PROJECT_TYPE" = "auto" ]; then
        PROJECT_TYPE=$(detect_project_type "$project_dir")
        echo -e "${BLUE}Detected project type: $PROJECT_TYPE${NC}"
    fi

    if [ "$LANGUAGE" = "auto" ]; then
        LANGUAGE=$(detect_language "$project_dir")
        echo -e "${BLUE}Detected language: $LANGUAGE${NC}"
    fi

    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$PWD")
    fi

    echo -e "${PURPLE}=== Setting up Claude Code for $PROJECT_NAME ===${NC}"
    echo

    # Create configurations
    create_claude_config "$project_dir" "$PROJECT_TYPE" "$LANGUAGE"
    create_custom_agents "$project_dir" "$PROJECT_TYPE"
    create_mcp_config "$project_dir"
    create_documentation "$project_dir"
    create_example_scripts "$project_dir"

    echo
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "1. Review .claude/instructions.md"
    echo -e "2. Try: ./scripts/claude/review.sh"
    echo -e "3. Read docs: docs/claude/README.md"
    echo
}

# Run main function
main "$@"