#! /usr/bin/bash env

if [ -d "$HOME/.bashTaskMan" ]; then
    # Source task manager FIRST
    if [ -d "$HOME/.bashTaskMan/task_manager" ]; then
        . "$HOME/.bashTaskMan/task_manager/task_utils.bash"
        . "$HOME/.bashTaskMan/task_manager/task_manager.bash"
    fi

    # Source theme AFTER task manager
    if [ -f "$HOME/.bashTaskMan/theme.bash" ]; then
        . "$HOME/.bashTaskMan/theme.bash"
    fi

    if [ -f "$HOME/.bashTaskMan/aliases.bash" ]; then
        . "$HOME/.bashTaskMan/aliases.bash"
    fi
fi

# Initialize task system after loading everything
if command -v init_task_system &>/dev/null; then
    init_task_system
fi
