#!/bin/bash

echo "This will currently overite your custom colors for bash prompt and the design of the prompt."
read -r -p "Will you continue [y/N]: " ANS

if [ ! "$ANS" == "y" ]; then
    echo "Nothing will be done"
    exit 0
fi

echo "Checking for needed dependencies..."
if ! command -v jq &>/dev/null; then
    echo "jq needed to be installed"
    exit 0
fi

TARGET_DIR="$HOME/.bashTaskMan"
BASHRC="$HOME/.bashrc"
TASKS_DIR="$HOME/Tasks/Daily/"

echo "Starting installation"

if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
else
    echo "Directory exists: $TARGET_DIR."
fi

if [ ! -d "$TASKS_DIR" ]; then
    mkdir -p "$TASKS_DIR"
else
    echo "Directory exists: $TASKS_DIR"
fi

OBJECTS_TO_MOVE=(task_manager/ aliases.bash theme.bash tskManLoader.bash remove.bash)
echo "Moving files to $TARGET_DIR..."

for item in "${OBJECTS_TO_MOVE[@]}"; do
    cp -fr "$item" "$TARGET_DIR/" || {
        echo "Error: Could not move $item. Ensure it's in the current directory."
        exit 1
    }
done

echo "Files moved."

LOAD_LINE="source $TARGET_DIR/tskManLoader.bash"
if ! grep -qxF "$LOAD_LINE" "$BASHRC"; then
    echo "Appending load line to $BASHRC..."
    echo "$LOAD_LINE" >>"$BASHRC"
else
    echo "Load line already in $BASHRC."
fi

ARCHIVE_JSON="$TASKS_DIR/archive.json"
TODAY_JSON="$TASKS_DIR/today.json"

if [ ! -f "$ARCHIVE_JSON" ]; then
    echo "{}" >"$ARCHIVE_JSON"
else
    echo "$ARCHIVE_JSON exists."
fi

if [ ! -f "$TODAY_JSON" ]; then
    echo "{}" >"$TODAY_JSON"
else
    echo "$TODAY_JSON exists."
fi

echo "Installation complete! Run 'source $HOME/.bashrc' or restart terminal."
