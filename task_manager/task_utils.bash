#!/usr/bin/env bash

# SINGLE SOURCE OF TRUTH FOR TASK PATHS
export TASK_DIR="$HOME/Tasks/Daily"
export TASK_FILE="$TASK_DIR/today.json"
export TASK_ARCHIVE="$TASK_DIR/archive.json"

# Create task directory if needed
mkdir -p "$TASK_DIR"

# Initialize task system variables
export CURRENT_TASK_INDEX=0
export LAST_TASK_FILE_CHECK=0
export LAST_CYCLE_TIME=$(date +%s)
declare -gA TASK_NOTIFIED
export ACTIVE_TASKS=()

function get_active_tasks {
    [[ -f "$TASK_FILE" ]] || return
    command -v jq &>/dev/null || return
    # Sort tasks numerically by ID
    jq -r 'to_entries[] | select(.value.done == false) | .key' "$TASK_FILE" |
        sort -t_ -k2,2n
}

# Initialize task system
function init_task_system {
    ACTIVE_TASKS=($(get_active_tasks))
    LAST_CYCLE_TIME=$(date +%s)
    CURRENT_TASK_INDEX=0
    LAST_TASK_FILE_CHECK=0
    declare -gA TASK_NOTIFIED
}
