#!/bin/bash
set -euo pipefail

input=$(cat)

# ── Parse JSON
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    # No valid session ID — skip session-dependent logic, just run original statusline
    exit 0
fi

# ── Write active session file
if [ -n "$SESSION_ID" ]; then
    mkdir -p "$HOME/.claude/session-topics"
    echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session"
fi

# ── Topic
TOPIC=""
if [ -n "$SESSION_ID" ]; then
    TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
    if [ -f "$TOPIC_FILE" ]; then
        TOPIC=$(cat "$TOPIC_FILE" 2>/dev/null || echo "")
    fi
fi
if [ -z "$TOPIC" ] && [ -n "${CLAUDE_SESSION_TOPICS_TOPIC:-}" ]; then
    TOPIC="$CLAUDE_SESSION_TOPICS_TOPIC"
    if [ -n "$SESSION_ID" ]; then
        mkdir -p "$HOME/.claude/session-topics"
        echo "$TOPIC" > "$HOME/.claude/session-topics/${SESSION_ID}"
    fi
fi

# ── Resolve topic color
resolve_color() {
    case "$1" in
        red)       echo '\033[31m' ;;
        green)     echo '\033[32m' ;;
        yellow)    echo '\033[33m' ;;
        blue)      echo '\033[34m' ;;
        magenta)   echo '\033[35m' ;;
        cyan)      echo '\033[36m' ;;
        white)     echo '\033[37m' ;;
        orange)    echo '\033[38;5;208m' ;;
        grey|gray) echo '\033[90m' ;;
        "")        echo '\033[35m' ;;  # default: magenta
        *)
            if echo "$1" | grep -qE '^[0-9;]+$'; then
                echo "\033[${1}m"
            else
                echo '\033[35m'
            fi
            ;;
    esac
}
# Color priority: env var > config file > default (magenta)
_color="${CLAUDE_SESSION_TOPICS_COLOR:-}"
if [ -z "$_color" ] && [ -f "$HOME/.claude/session-topics/.color-config" ]; then
    _color=$(cat "$HOME/.claude/session-topics/.color-config" 2>/dev/null || echo "")
fi
C_TOPIC=$(resolve_color "$_color")
C_BOLD='\033[1m'
C_RESET='\033[0m'

# ── Cleanup stale files (atomic lock)
CLEANUP_LOCK="/tmp/.claude-topic-cleanup-lock"
if mkdir "$CLEANUP_LOCK" 2>/dev/null; then
    trap "rmdir '$CLEANUP_LOCK' 2>/dev/null || true" EXIT
    find "$HOME/.claude/session-topics" -type f -mtime +7 -not -name '.*' -delete 2>/dev/null || true
    rmdir "$CLEANUP_LOCK" 2>/dev/null
fi

# ── Output
if [ -n "$TOPIC" ]; then
    echo -e "${C_BOLD}${C_TOPIC}◆ ${TOPIC}${C_RESET}"
fi
