#!/bin/bash
set -euo pipefail

# ── Stop hook: set session topic from first user message
# Receives Stop event JSON on stdin: {"session_id": "...", "transcript_path": "..."}

# ── Load common functions (with fallback)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  source "$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  source "$SCRIPT_DIR/lib/common.sh"
else
  # Fallback: define minimal required functions locally
  debug_log() { :; }
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

# ── Get HOOK_VERSION from extract_topic.sh
HOOK_VERSION=$(grep '^VERSION=' "$SCRIPT_DIR/extract_topic.sh" 2>/dev/null | head -1 | cut -d= -f2)
HOOK_VERSION="${HOOK_VERSION:-0}"

# ── Parse JSON fields (session_id is the primary identifier)
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // ""')

# ── Validate session ID
if type sanitize_session_id &>/dev/null; then
  SESSION_ID=$(sanitize_session_id "$SESSION_ID")
else
  SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
fi
if [ -z "$SESSION_ID" ]; then
  debug_log "hook: no session_id in input, exiting"
  exit 0
fi

debug_log "hook: session_id=$SESSION_ID"

# ── Ensure topics directory
if type ensure_topics_dir &>/dev/null; then
  ensure_topics_dir
else
  mkdir -p "$HOME/.claude/session-topics"
fi

# ── Write active session marker keyed by session_id (race-condition-safe)
# This is the primary mechanism — works regardless of PID detection.
echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-id-$SESSION_ID"
debug_log "hook: wrote .active-session-id-$SESSION_ID"

# ── Also write PID-based marker for backward compatibility (best-effort)
CLAUDE_PID=$(find_claude_pid)
if [ -n "$CLAUDE_PID" ]; then
  echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID"
  debug_log "hook: wrote .active-session-$CLAUDE_PID (compat)"
else
  debug_log "hook: PID detection failed, session_id marker is sufficient"
fi

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

RAW=$(bash "$SCRIPT_DIR/extract_topic.sh" "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

if [[ "$RAW" == *:* ]]; then
    DETECTED_LANG="${RAW%%:*}"
    TOPIC="${RAW#*:}"
else
    DETECTED_LANG="en"
    TOPIC="$RAW"
fi

# ── Write topic
if [ -n "$TOPIC" ]; then
    # Sanitize: keep letters (incl. accented), digits, spaces, basic punctuation
    TOPIC=$(printf '%s' "$TOPIC" | sed "s/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ .,:!?'-]//g" | cut -c1-50)
    if [ -n "$TOPIC" ]; then
      printf '%s\n' "$TOPIC" > "$TOPIC_FILE"
      debug_log "hook: wrote topic '$TOPIC' to $TOPIC_FILE"
      # Voice notification (opt-in, non-blocking)
      VOICE_SCRIPT="$SCRIPT_DIR/voice-notify.sh"
      [ -x "$VOICE_SCRIPT" ] && bash "$VOICE_SCRIPT" "$TOPIC" "$DETECTED_LANG" &>/dev/null &
    fi
fi

exit 0
