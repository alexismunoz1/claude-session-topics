#!/bin/bash
# Common utility functions for claude-session-topics scripts

# ── Find the ancestor claude process PID (stable across all contexts)
find_claude_pid() {
  local pid=$$
  while [ "$pid" != "1" ] && [ -n "$pid" ]; do
    local parent
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$parent" ] && break
    local comm
    comm=$(ps -o comm= -p "$parent" 2>/dev/null)
    case "$comm" in
      *claude*|*Claude*) echo "$parent"; return 0 ;;
    esac
    pid=$parent
  done
  echo ""
}

# ── Sanitize session ID (keep only alphanumeric, underscore, hyphen)
sanitize_session_id() {
  echo "$1" | tr -cd 'a-zA-Z0-9_-' 2>/dev/null || echo ""
}

# ── Ensure topics directory exists
ensure_topics_dir() {
  mkdir -p "$HOME/.claude/session-topics"
}

# ── Get path to session topic file
get_session_file() {
  local session_id="$1"
  echo "$HOME/.claude/session-topics/${session_id}"
}
