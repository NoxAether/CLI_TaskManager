#!/bin/bash

TARGET_DIR="$HOME/.bashTaskMan"
BASHRC="$HOME/.bashrc"
TASKS_DIR="$HOME/Tasks/"

echo "This script will remove the Bash Task Manager installation."
echo "It will delete the following directories and their contents:"
echo " - $TARGET_DIR"
echo " - $TASKS_DIR"
echo "It will also remove the load line from your $BASHRC file."
echo ""
read -r -p "Are you sure you want to continue? [y/N] " ANS

if [ ! "$ANS" == "y" ]; then
    echo "Removal cancelled."
    exit 0
fi

echo "Starting removal..."

LOAD_LINE="source $TARGET_DIR/tskManLoader.bash"
if grep -qxF "$LOAD_LINE" "$BASHRC"; then
    echo "Removing load line from $BASHRC..."
    ESCAPED_LOAD_LINE=$(echo "$LOAD_LINE" | sed 's/\//\\\//g')
    sed -i "/^$ESCAPED_LOAD_LINE$/d" "$BASHRC"
    echo "Load line removed."
else
    echo "Load line not found in $BASHRC, skipping."
fi

if [ -d "$TARGET_DIR" ]; then
    echo "Removing directory: $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
    echo "Directory removed."
else
    echo "Directory not found: $TARGET_DIR, skipping."
fi

if [ -d "$TASKS_DIR" ]; then
    echo "Removing directory: $TASKS_DIR..."
    rm -rf "$TASKS_DIR"
    echo "Directory removed."
else
    echo "Directory not found: $TASKS_DIR, skipping."
fi

if command -v jq &>/dev/null; then
    ART="jq"
    echo "Removal complete. Possible artifact: $ART"
    exit 0;
fi

echo "Removal complete. Possible artifact: NONE"
