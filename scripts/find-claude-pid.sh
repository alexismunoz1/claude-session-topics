#!/bin/bash
# Walks up the process tree to find the ancestor "claude" process PID.
# Prints the PID to stdout. Prints nothing if not found.
# Usage: CLAUDE_PID=$(bash /path/to/find-claude-pid.sh)

find_claude_pid() {
    local pid=$$
    # If our own process is "claude", return it
    local self_comm
    self_comm=$(ps -o comm= -p "$pid" 2>/dev/null)
    if [ "$self_comm" = "claude" ]; then
        echo "$pid"
        return 0
    fi
    # Walk up the process tree
    while [ "$pid" -ne 1 ] 2>/dev/null; do
        local parent
        parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -z "$parent" ] || [ "$parent" = "$pid" ]; then
            break
        fi
        local comm
        comm=$(ps -o comm= -p "$parent" 2>/dev/null)
        if [ "$comm" = "claude" ]; then
            echo "$parent"
            return 0
        fi
        pid=$parent
    done
    return 1
}

find_claude_pid
