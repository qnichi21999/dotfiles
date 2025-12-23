#!/bin/sh

SESSION_NAME="nvim"
EDITOR_COMMAND="nvim" # Or specify a file: "nvim /path/to/your/file"

# Check if a tmux session with the specified name exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # If not, create a new session and run nvim
    tmux new-session -d -s "$SESSION_NAME" "$EDITOR_COMMAND"
fi

# Attach to the session
kitty -e tmux attach-session -t "$SESSION_NAME"
