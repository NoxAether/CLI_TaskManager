#!/usr/bin/env bash

function task_prompt {
    # Check if jq exists
    if ! command -v jq &>/dev/null; then
        echo -n "[${TECH_YELLOW}JOB-ERR${RESET}] [${NEON_RED}INSTALL jq${RESET}]"
        return
    fi

    # Check if task file exists
    if [[ ! -f "$TASK_FILE" ]]; then
        echo -n "[${TECH_YELLOW}JOB-0${RESET}] [${NEON_PINK}NO TASKS${RESET}]"
        return
    fi

    local current_time=$(date +%s)
    local file_mtime=$(stat -c %Y "$TASK_FILE" 2>/dev/null || stat -f %m "$TASK_FILE" 2>/dev/null)

    # Refresh task list if file modified or every 10s
    if ((current_time - LAST_TASK_FILE_CHECK > 10)) || [[ "$file_mtime" -gt "$LAST_TASK_FILE_CHECK" ]]; then
        ACTIVE_TASKS=($(get_active_tasks))
        LAST_TASK_FILE_CHECK=$current_time
    fi

    # Handle no active tasks
    if [[ ${#ACTIVE_TASKS[@]} -eq 0 ]]; then
        echo -n "[${TECH_YELLOW}JOB-0${RESET}] [${NEON_PINK}NO TASKS${RESET}]"
        return
    fi

    # Handle task cycling
    if [[ ${#ACTIVE_TASKS[@]} -gt 1 ]]; then
        # Cycle tasks every 30 seconds
        if ((current_time - LAST_CYCLE_TIME >= 30)); then
            CURRENT_TASK_INDEX=$(((CURRENT_TASK_INDEX + 1) % ${#ACTIVE_TASKS[@]}))
            LAST_CYCLE_TIME=$current_time

            # Force prompt refresh by clearing PS1
            PS1=""
        fi
        task_key="${ACTIVE_TASKS[$CURRENT_TASK_INDEX]}"
    else
        task_key="${ACTIVE_TASKS[0]}"
    fi

    # Get task details
    local task_name=$(jq -r ".[\"$task_key\"].name" "$TASK_FILE")
    local due_epoch=$(jq -r ".[\"$task_key\"].due_epoch" "$TASK_FILE")
    local duration=$(jq -r ".[\"$task_key\"].duration" "$TASK_FILE")

    # Extract just the numeric ID
    local job_id="${task_key#task_}"

    # Check notification timing
    if [[ -z "${TASK_NOTIFIED[$task_key]}" ]] && ((current_time >= due_epoch)); then
        dunstify "TASK OVERDUE!" "$task_name was due $duration ago" -u critical
        TASK_NOTIFIED[$task_key]=1
    fi

    # Time calculation - use AEST timezone
    if ((due_epoch <= current_time)); then
        echo -n "[${TECH_YELLOW}JOB-$job_id${RESET}] [${NEON_RED}$task_name${RESET}] [${ARASAKA_RED}OVERDUE${RESET}]"
    else
        local time_left=$((due_epoch - current_time))
        local hours=$((time_left / 3600))
        local mins=$(((time_left % 3600) / 60))
        printf "[${TECH_YELLOW}JOB-%s${RESET}] [${CORPO_BLUE}%s${RESET}] [${RIPPER_TEAL}%02d:%02d${RESET}]" \
            "$job_id" "$task_name" "$hours" "$mins"
    fi
}

function showdone {
    if [[ -f "$TASK_ARCHIVE" ]]; then
        echo -e "${TECH_YELLOW_RAW}Completed Tasks:${RESET_RAW}"
        # Sort tasks by numeric ID
        jq -r 'to_entries | sort_by(.key | split("_")[1] | tonumber) | .[] |
            "\(.key)\t\(.value.name)\t\(.value.completed_epoch)"' "$TASK_ARCHIVE" |
            while IFS=$'\t' read -r key name completed_epoch; do
                local job_id="${key#task_}"
                local completed_time=""

                if [[ -n "$completed_epoch" && "$completed_epoch" != "null" ]]; then
                    # Use AEST timezone
                    completed_time=$(TZ="Australia/Sydney" date -d "@$completed_epoch" +"%Y-%m-%d %H:%M" 2>/dev/null)
                fi

                if [[ -z "$completed_time" ]]; then
                    completed_time="Unknown"
                fi

                echo -e "  ${RIPPER_TEAL_RAW}JOB-$job_id:${RESET_RAW} $name [Completed: $completed_time]"
            done
    else
        echo -e "${NEON_RED_RAW}No archived tasks found${RESET_RAW}"
    fi
}

function addtask {
    if ! command -v jq &>/dev/null; then
        echo -e "${NEON_RED_RAW}Error: jq is required but not installed. Install with: sudo apt install jq${RESET_RAW}"
        return 1
    fi

    # Create task file if it doesn't exist
    if [[ ! -f "$TASK_FILE" ]]; then
        echo "{}" >"$TASK_FILE"
    fi

    # Get task name
    echo -ne "${TECH_YELLOW_RAW}» Task name: ${RESET_RAW}"
    read -r task_name
    if [[ -z "$task_name" ]]; then
        echo -e "${NEON_RED_RAW}Error: Task name cannot be empty${RESET_RAW}"
        return 1
    fi

    # Get duration in HH:MM format
    while true; do
        echo -ne "${TECH_YELLOW_RAW}» Duration (HH:MM): ${RESET_RAW}"
        read -r duration
        if [[ "$duration" =~ ^([0-9]+):([0-5][0-9])$ ]]; then
            hours=${BASH_REMATCH[1]}
            minutes=${BASH_REMATCH[2]}
            break
        else
            echo -e "${ARASAKA_RED_RAW}Invalid format. Use HH:MM (e.g. 3:20 for 3 hours 20 minutes)${RESET_RAW}"
        fi
    done

    local tz="Australia/Sydney"
    if date --version &>/dev/null; then # Linux
        local due_time=$(TZ="$tz" date -d "now + $hours hours $minutes minutes" +"%H:%M")
        local due_epoch=$(TZ="$tz" date -d "now + $hours hours $minutes minutes" +%s)
    else # macOS
        # Convert to UTC offset for macOS
        local utc_offset=$(TZ="$tz" date +%z)
        local due_time=$(TZ="$tz" date -v +${hours}H -v +${minutes}M +"%H:%M")
        local due_epoch=$(TZ="UTC" date -v +${hours}H -v +${minutes}M -v ${utc_offset:0:3}H -v ${utc_offset:3:2}M +%s)
    fi

    if [[ -z "$due_time" || -z "$due_epoch" ]]; then
        echo -e "${ARASAKA_RED_RAW}Error: Failed to calculate due time${RESET_RAW}"
        return 1
    fi

    # Find next available task ID (reuse gaps)
    local next_id=1
    while jq -e ".[\"task_$next_id\"]" "$TASK_FILE" &>/dev/null ||
        jq -e ".[\"task_$next_id\"]" "$TASK_ARCHIVE" &>/dev/null; do
        ((next_id++))
    done

    local task_id="task_$next_id"

    # Add the new task
    jq --arg name "$task_name" \
        --arg duration "$duration" \
        --arg due "$due_time" \
        --argjson due_epoch "$due_epoch" \
        ". + {\"$task_id\": {name: \$name, duration: \$duration, due: \$due, due_epoch: \$due_epoch, done: false}}" \
        "$TASK_FILE" >"${TASK_FILE}.tmp" && mv "${TASK_FILE}.tmp" "$TASK_FILE"

    echo -e "${NETWATCH_GREEN_RAW}✓ Created new task: ${TECH_YELLOW_RAW}JOB-$next_id${RESET_RAW}"
    echo -e "  ${NEON_PINK_RAW}Name:${RESET_RAW} $task_name"
    echo -e "  ${RIPPER_TEAL_RAW}Duration:${RESET_RAW} $duration (Due: $due_time AEST)"

    # Update task system
    ACTIVE_TASKS=($(get_active_tasks))
    CURRENT_TASK_INDEX=0
    LAST_CYCLE_TIME=$(date +%s) # Reset cycle timer
}

function complete_task {
    local task_id="$1"
    [[ -z "$task_id" ]] && {
        echo -e "${NEON_RED_RAW}Usage: ct <task_id>${RESET_RAW}"
        echo -e "Example: ${TECH_YELLOW_RAW}ct 1${RESET_RAW} or ${TECH_YELLOW_RAW}ct JOB-1${RESET_RAW}"
        return 1
    }

    # Handle both formats: 1, JOB-1, task_1
    if [[ "$task_id" =~ ^[0-9]+$ ]]; then
        task_id="task_$task_id"
    elif [[ "$task_id" =~ ^JOB- ]]; then
        task_id="task_${task_id#JOB-}"
    fi

    if jq -e ".[\"$task_id\"]" "$TASK_FILE" &>/dev/null; then
        # Get current timestamp
        local completed_epoch=$(date +%s)

        # Archive the task
        if [[ ! -f "$TASK_ARCHIVE" ]]; then
            echo "{}" >"$TASK_ARCHIVE"
        fi

        # Add completion timestamp and move to archive
        jq --arg id "$task_id" --argjson completed "$completed_epoch" \
            '.[$id] as $task |
            $task + {completed_epoch: $completed} |
            {($id): .}' "$TASK_FILE" >archive_entry.json

        jq -s '.[0] * .[1]' "$TASK_ARCHIVE" archive_entry.json >"${TASK_ARCHIVE}.tmp" &&
            mv "${TASK_ARCHIVE}.tmp" "$TASK_ARCHIVE"

        # Remove from active tasks
        jq "del(.[\"$task_id\"])" "$TASK_FILE" >"${TASK_FILE}.tmp" &&
            mv "${TASK_FILE}.tmp" "$TASK_FILE"

        # Cleanup
        rm archive_entry.json

        # Get numeric ID for display
        local job_id="${task_id#task_}"

        echo -e "${RIPPER_TEAL_RAW}✓ Task JOB-$job_id archived${RESET_RAW}"
        ACTIVE_TASKS=($(get_active_tasks))
        CURRENT_TASK_INDEX=0
        LAST_CYCLE_TIME=$(date +%s)

        # Force prompt update
        PS1=""
    else
        echo -e "${NEON_RED_RAW}Error: Task '$task_id' not found${RESET_RAW}"
        return 1
    fi
}

function delete_task {
    local archive_mode=0
    local task_id=""

    # Check for archive flag
    if [[ "$1" == "-a" || "$1" == "--archive" ]]; then
        archive_mode=1
        shift
    fi

    task_id="$1"
    [[ -z "$task_id" ]] && {
        echo -e "${NEON_RED_RAW}Usage: deltask [-a|--archive] <task_id>${RESET_RAW}"
        echo -e "  Without -a: Delete active task"
        echo -e "  With -a: Delete archived task"
        echo -e "Example: ${TECH_YELLOW_RAW}deltask 1${RESET_RAW} or ${TECH_YELLOW_RAW}deltask -a JOB-1${RESET_RAW}"
        return 1
    }

    # Handle both formats: 1, JOB-1, task_1
    if [[ "$task_id" =~ ^[0-9]+$ ]]; then
        task_id="task_$task_id"
    elif [[ "$task_id" =~ ^JOB- ]]; then
        task_id="task_${task_id#JOB-}"
    fi

    if ((archive_mode == 1)); then
        # Delete from archive
        if [[ -f "$TASK_ARCHIVE" ]]; then
            if jq -e ".[\"$task_id\"]" "$TASK_ARCHIVE" &>/dev/null; then
                jq "del(.[\"$task_id\"])" "$TASK_ARCHIVE" >"${TASK_ARCHIVE}.tmp" &&
                    mv "${TASK_ARCHIVE}.tmp" "$TASK_ARCHIVE"
                local job_id="${task_id#task_}"
                echo -e "${RIPPER_TEAL_RAW}✓ Deleted archived task: JOB-$job_id${RESET_RAW}"
            else
                echo -e "${NEON_RED_RAW}Error: Archived task '$task_id' not found${RESET_RAW}"
                return 1
            fi
        else
            echo -e "${NEON_RED_RAW}Error: Archive file not found${RESET_RAW}"
            return 1
        fi
    else
        # Delete from active tasks
        if [[ -f "$TASK_FILE" ]] && jq -e ".[\"$task_id\"]" "$TASK_FILE" &>/dev/null; then
            jq "del(.[\"$task_id\"])" "$TASK_FILE" >"${TASK_FILE}.tmp" &&
                mv "${TASK_FILE}.tmp" "$TASK_FILE"
            local job_id="${task_id#task_}"
            echo -e "${RIPPER_TEAL_RAW}✓ Deleted active task: JOB-$job_id${RESET_RAW}"
            ACTIVE_TASKS=($(get_active_tasks))
            CURRENT_TASK_INDEX=0
            LAST_CYCLE_TIME=$(date +%s)
        else
            echo -e "${NEON_RED_RAW}Error: Active task '$task_id' not found${RESET_RAW}"
            return 1
        fi
    fi
}

function showtasks {
    if [[ -f "$TASK_FILE" ]]; then
        echo -e "${TECH_YELLOW_RAW}Active Tasks (Times in AEST):${RESET_RAW}"
        # Sort tasks by numeric ID
        jq -r 'to_entries | sort_by(.key | split("_")[1] | tonumber) | .[] |
            "\(.key)\t\(.value.name)\t\(.value.due)\t\(.value.duration)"' \
            "$TASK_FILE" | while IFS=$'\t' read -r key name due duration; do

            # Convert to JOB-X format
            local job_id="${key#task_}"

            echo -e "  ${CORPO_BLUE_RAW}JOB-$job_id:${RESET_RAW} $name [Due: $due AEST] [Duration: $duration]"
        done
    else
        echo -e "${NEON_RED_RAW}No tasks found${RESET_RAW}"
    fi
}

function edittasks {
    if [[ -n "$EDITOR" ]]; then
        "$EDITOR" "$TASK_FILE"
        # Refresh tasks after editing
        ACTIVE_TASKS=($(get_active_tasks))
        CURRENT_TASK_INDEX=0
        LAST_CYCLE_TIME=$(date +%s)
        echo -e "${RIPPER_TEAL_RAW}✓ Task file updated. Refreshed task list.${RESET_RAW}"
    else
        echo -e "${NEON_RED_RAW}Error: EDITOR environment variable not set${RESET_RAW}"
        return 1
    fi
}

function taskinfo {
    echo -e "\n${TECH_YELLOW_RAW}=== TASK COMMANDS ==="
    echo -e "${CORPO_BLUE_RAW}addtask${RESET_RAW}    - Create new task"
    echo -e "${CORPO_BLUE_RAW}ct <id>${RESET_RAW}    - Complete task (use number or JOB-X)"
    echo -e "${CORPO_BLUE_RAW}deltask [-a] <id>${RESET_RAW} - Delete task (active by default, use -a for archive)"
    echo -e "${CORPO_BLUE_RAW}showtasks${RESET_RAW}  - List active tasks"
    echo -e "${CORPO_BLUE_RAW}showdone${RESET_RAW}   - List completed tasks"
    echo -e "${CORPO_BLUE_RAW}edittasks (et)${RESET_RAW} - Edit task file"
    echo -e "${CORPO_BLUE_RAW}taskinfo${RESET_RAW}   - Show this help"
    echo -e "\n${TECH_YELLOW_RAW}Examples:"
    echo -e "  ${CORPO_BLUE_RAW}addtask${RESET_RAW}           # Create new task"
    echo -e "  ${CORPO_BLUE_RAW}ct 1${RESET_RAW}             # Complete task 1"
    echo -e "  ${CORPO_BLUE_RAW}deltask 2${RESET_RAW}        # Delete active task 2"
    echo -e "  ${CORPO_BLUE_RAW}deltask -a JOB-3${RESET_RAW} # Delete archived task 3"
    echo -e "  ${CORPO_BLUE_RAW}et${RESET_RAW}               # Edit task file"
    echo -e "  ${CORPO_BLUE_RAW}showdone${RESET_RAW}          # Show completed tasks"
}
