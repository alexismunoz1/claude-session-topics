#!/bin/bash
set -euo pipefail

# ── Stop hook: set session topic from first user message
# Receives Stop event JSON on stdin: {"session_id": "...", "transcript_path": "..."}

# ── Load common functions (with fallback)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  source "$SCRIPT_DIR/../lib/common.sh"
else
  # Fallback: define minimal required functions locally
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
fi

input=$(cat)

# ── Get HOOK_VERSION from extract_topic.py
HOOK_VERSION=$(python3 -c "
import sys; sys.path.insert(0, '$SCRIPT_DIR')
from extract_topic import VERSION; print(VERSION)
" 2>/dev/null || echo "0")

CLAUDE_PID=$(find_claude_pid)

# ── Parse JSON fields
read -r SESSION_ID TRANSCRIPT_PATH <<< "$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''), d.get('transcript_path', ''))
except:
    print(' ')
" 2>/dev/null || echo " ")"

# ── Validate session ID
if type sanitize_session_id &>/dev/null; then
  SESSION_ID=$(sanitize_session_id "$SESSION_ID")
else
  SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
fi
[ -z "$SESSION_ID" ] && exit 0

# ── Ensure topics directory + write active session marker
if type ensure_topics_dir &>/dev/null; then
  ensure_topics_dir
else
  mkdir -p "$HOME/.claude/session-topics"
fi
[ -n "$CLAUDE_PID" ] && echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID"

# ── Version-based cache invalidation: if hook version changed, wipe stale topics
VERSION_FILE="$HOME/.claude/session-topics/.hook-version"
if [ ! -f "$VERSION_FILE" ] || [ "$(cat "$VERSION_FILE" 2>/dev/null)" != "$HOOK_VERSION" ]; then
    find "$HOME/.claude/session-topics" -maxdepth 1 -type f ! -name '.*' ! -name '*.sh' ! -name '*.py' -delete 2>/dev/null || true
    echo "$HOOK_VERSION" > "$VERSION_FILE"
fi

# ── Fast path: topic already exists for this session
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
[ -f "$TOPIC_FILE" ] && [ -s "$TOPIC_FILE" ] && exit 0

# ── Extract topic from transcript
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

TOPIC=$(python3 "$SCRIPT_DIR/extract_topic.py" "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

# ── Write topic
if [ -n "$TOPIC" ]; then
    # Sanitize: keep letters (incl. accented), digits, spaces, basic punctuation
    TOPIC=$(printf '%s' "$TOPIC" | sed "s/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ .,:!?'-]//g" | cut -c1-50)
    [ -n "$TOPIC" ] && printf '%s\n' "$TOPIC" > "$TOPIC_FILE"
fi

exit 0
