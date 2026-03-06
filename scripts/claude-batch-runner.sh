#!/bin/bash
# Claude Code Batch Runner
# Runs multiple Claude Code tasks from a file

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_SCRIPT="$SCRIPT_DIR/claude-wrapper.sh"

# Default values
INPUT_FILE=""
OUTPUT_DIR="./claude-batch-results"
PARALLEL=false
MAX_PARALLEL=3
DELAY=0
CONTINUE_ON_ERROR=false
VERBOSE=false
DRY_RUN=false

# Progress tracking
TOTAL_TASKS=0
COMPLETED_TASKS=0
FAILED_TASKS=0

# Show help
show_help() {
    cat << EOF
Claude Code Batch Runner

Runs multiple Claude Code tasks from a file.

USAGE:
    ./claude-batch-runner.sh [OPTIONS] -f TASKS_FILE

OPTIONS:
    -f, --file FILE         Task file (required)
    -o, --output DIR        Output directory (default: ./claude-batch-results)
    -p, --parallel          Run tasks in parallel
    -j, --jobs N           Maximum parallel jobs (default: 3)
    -d, --delay SECONDS    Delay between tasks (default: 0)
    -c, --continue         Continue on error
    -v, --verbose          Verbose output
    -n, --dry-run          Show what would be run
    --help                  Show this help

TASK FILE FORMAT:
    Each line should contain a task in one of these formats:
    - task:"description"                    # Basic task
    - task:--write:"description"             # Task with write permission
    - task:--write --budget 5:"description"  # Task with options
    - review:path                            # Code review
    - explain:path                           # Code explanation
    - # Comment line                        # Ignored

EXAMPLES:
    ./claude-batch-runner.sh -f tasks.txt
    ./claude-batch-runner.sh -f tasks.txt -p -j 5
    ./claude-batch-runner.sh -f tasks.txt -o ./results -c

EOF
}

# Parse task line
parse_task() {
    local line="$1"
    local task_type=""
    local options=""
    local description=""

    # Remove leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
        return 1
    fi

    # Parse task type and options
    if [[ "$line" =~ ^([^:]+):(.*)$ ]]; then
        task_type="${BASH_REMATCH[1]}"
        remaining="${BASH_REMATCH[2]}"

        # Handle different formats
        if [[ "$remaining" =~ ^\"(.*)\"$ ]]; then
            # Simple quoted description
            description="${BASH_REMATCH[1]}"
        elif [[ "$remaining" =~ ^(--[^:]*):\"(.*)\"$ ]]; then
            # Options with description
            options="${BASH_REMATCH[1]}"
            description="${BASH_REMATCH[2]}"
        elif [[ "$remaining" =~ ^([^:]+):\"(.*)\"$ ]]; then
            # Path with description (review/explain)
            options="${BASH_REMATCH[1]}"
            description="${BASH_REMATCH[2]}"
        else
            # Fallback
            description="$remaining"
        fi
    else
        # Plain description
        task_type="task"
        description="$line"
    fi

    echo "$task_type|$options|$description"
}

# Execute single task
execute_task() {
    local task_id="$1"
    local task_line="$2"
    local output_file="$3"

    local parsed=$(parse_task "$task_line")
    if [[ -z "$parsed" ]]; then
        return 0  # Skip empty/comment lines
    fi

    IFS='|' read -r task_type options description <<< "$parsed"

    echo -e "${CYAN}[Task $task_id]${NC} $task_type: $description"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}Would run:${NC} $WRAPPER_SCRIPT $task_type $options \"$description\""
        return 0
    fi

    # Build command
    local cmd=()
    cmd+=("$WRAPPER_SCRIPT")
    cmd+=("$task_type")

    # Add options
    if [[ -n "$options" ]]; then
        cmd+=($options)
    fi

    # Add description for task commands
    if [[ "$task_type" == "task" ]]; then
        cmd+=("$description")
    fi

    # Execute and capture output
    local start_time=$(date +%s)
    local temp_output=$(mktemp)

    if "${cmd[@]}" > "$temp_output" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo -e "${GREEN}✓ Completed in ${duration}s${NC}"

        # Save output
        cat "$temp_output" >> "$output_file"
        echo -e "\n--- Task $task_id completed ---\n" >> "$output_file"

        rm "$temp_output"
        return 0
    else
        local exit_code=$?
        echo -e "${RED}✗ Failed with exit code $exit_code${NC}"

        # Save error output
        echo -e "\n--- Task $task_id FAILED ---\n" >> "$output_file"
        cat "$temp_output" >> "$output_file"

        rm "$temp_output"
        return $exit_code
    fi
}

# Process tasks sequentially
process_sequential() {
    local task_file="$1"
    local output_dir="$2"

    echo -e "${BLUE}Processing tasks sequentially...${NC}"

    local task_id=1
    while IFS= read -r line || [[ -n "$line" ]]; do
        local task_output="$output_dir/task_$(printf "%03d" $task_id).log"

        if execute_task "$task_id" "$line" "$task_output"; then
            ((COMPLETED_TASKS++))
        else
            ((FAILED_TASKS++))
            if [[ "$CONTINUE_ON_ERROR" != true ]]; then
                echo -e "${RED}Stopping on first error${NC}"
                break
            fi
        fi

        if [[ $DELAY -gt 0 ]]; then
            sleep "$DELAY"
        fi

        ((task_id++))
    done < "$task_file"
}

# Process tasks in parallel
process_parallel() {
    local task_file="$1"
    local output_dir="$2"

    echo -e "${BLUE}Processing tasks in parallel (max $MAX_PARALLEL jobs)...${NC}"

    # Create temporary directory for job control
    local temp_dir=$(mktemp -d)
    local pids_file="$temp_dir/pids"
    touch "$pids_file"

    local task_id=1
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Wait if we've reached max parallel jobs
        while [[ $(wc -l < "$pids_file") -ge $MAX_PARALLEL ]]; do
            sleep 0.1
            # Clean up completed jobs
            while read -r pid; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    grep -v "^$pid$" "$pids_file" > "$pids_file.tmp"
                    mv "$pids_file.tmp" "$pids_file"
                fi
            done < "$pids_file"
        done

        # Start new task
        local task_output="$output_dir/task_$(printf "%03d" $task_id).log"
        execute_task "$task_id" "$line" "$task_output" &
        local pid=$!
        echo "$pid" >> "$pids_file"

        ((task_id++))
    done < "$task_file"

    # Wait for all remaining jobs
    while read -r pid; do
        wait "$pid"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            ((COMPLETED_TASKS++))
        else
            ((FAILED_TASKS++))
        fi
    done < "$pids_file"

    rm -rf "$temp_dir"
}

# Generate summary report
generate_summary() {
    local output_dir="$1"
    local summary_file="$output_dir/summary.md"

    echo -e "${BLUE}Generating summary report...${NC}"

    cat > "$summary_file" << EOF
# Claude Code Batch Run Summary

**Date:** $(date)
**Total Tasks:** $TOTAL_TASKS
**Completed:** $COMPLETED_TASKS
**Failed:** $FAILED_TASKS
**Success Rate:** $((COMPLETED_TASKS * 100 / TOTAL_TASKS))%

## Task Results

EOF

    # Add individual task summaries
    for log_file in "$output_dir"/task_*.log; do
        if [[ -f "$log_file" ]]; then
            local task_name=$(basename "$log_file" .log)
            local status="✓ Completed"
            if grep -q "FAILED" "$log_file"; then
                status="✗ Failed"
            fi

            echo -e "### $task_name: $status" >> "$summary_file"
            echo -e "" >> "$summary_file"

            # Extract first few lines of output
            echo -e "\`\`\`" >> "$summary_file"
            head -n 20 "$log_file" >> "$summary_file"
            echo -e "\`\`\`" >> "$summary_file"
            echo -e "" >> "$summary_file"
        fi
    done

    echo -e "${GREEN}✓ Summary saved to: $summary_file${NC}"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -j|--jobs)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -d|--delay)
                DELAY="$2"
                shift 2
                ;;
            -c|--continue)
                CONTINUE_ON_ERROR=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
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

    # Validate required arguments
    if [[ -z "$INPUT_FILE" ]]; then
        echo -e "${RED}Error: Task file is required${NC}"
        show_help
        exit 1
    fi

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo -e "${RED}Error: Task file not found: $INPUT_FILE${NC}"
        exit 1
    fi

    # Count total tasks
    TOTAL_TASKS=$(grep -v '^#' "$INPUT_FILE" | grep -v '^[[:space:]]*$' | wc -l)

    echo -e "${PURPLE}=== Claude Code Batch Runner ===${NC}"
    echo -e "${BLUE}Input file:${NC} $INPUT_FILE"
    echo -e "${BLUE}Output directory:${NC} $OUTPUT_DIR"
    echo -e "${BLUE}Total tasks:${NC} $TOTAL_TASKS"
    echo -e "${BLUE}Parallel execution:${NC} $PARALLEL"
    if [[ "$PARALLEL" == true ]]; then
        echo -e "${BLUE}Max parallel jobs:${NC} $MAX_PARALLEL"
    fi
    if [[ $DELAY -gt 0 ]]; then
        echo -e "${BLUE}Delay between tasks:${NC} ${DELAY}s"
    fi
    echo

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Process tasks
    if [[ "$PARALLEL" == true ]]; then
        process_parallel "$INPUT_FILE" "$OUTPUT_DIR"
    else
        process_sequential "$INPUT_FILE" "$OUTPUT_DIR"
    fi

    # Generate summary
    generate_summary "$OUTPUT_DIR"

    # Final report
    echo
    echo -e "${PURPLE}=== Batch Run Complete ===${NC}"
    echo -e "${GREEN}✓ Completed: $COMPLETED_TASKS${NC}"
    if [[ $FAILED_TASKS -gt 0 ]]; then
        echo -e "${RED}✗ Failed: $FAILED_TASKS${NC}"
    fi
    echo -e "${BLUE}Results saved to: $OUTPUT_DIR${NC}"

    # Exit with error if any tasks failed
    if [[ $FAILED_TASKS -gt 0 ]]; then
        exit 1
    fi
}

# Run main function
main "$@"}