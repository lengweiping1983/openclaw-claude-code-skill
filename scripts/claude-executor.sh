#!/bin/bash

# Claude Executor - Simple task execution script for Claude Code
# Usage: ./claude-executor.sh "your task description"

set -e

# Check if claude command exists
if ! command -v claude &> /dev/null; then
    echo "Error: claude command not found. Please install Claude Code first."
    exit 1
fi

# Check if a task description is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"your task description\""
    echo "Example: $0 \"create a simple todo list app\""
    exit 1
fi

# Combine all arguments as the task description
TASK="$*"

echo "Executing task: $TASK"
echo "----------------------------------------"

# Execute the task with claude
claude "$TASK"

echo "----------------------------------------"
echo "Task execution complete."