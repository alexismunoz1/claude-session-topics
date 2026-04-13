#!/bin/bash
set -euo pipefail

# ── Stop hook: set session topic from Claude Code's internal custom-title
# Receives Stop event JSON on stdin: {"session_id": "...", "transcript_path": "..."}

# ── Load common functions (with fallback)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  source "$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
  source "$SCRIPT_DIR/lib/common.sh"
else
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

# ── Parse JSON fields
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
echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-id-$SESSION_ID"
debug_log "hook: wrote .active-session-id-$SESSION_ID"

# ── Also write PID-based marker for backward compatibility (best-effort)
CLAUDE_PID=$(find_claude_pid)
if [ -n "$CLAUDE_PID" ]; then
  echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID"
  debug_log "hook: wrote .active-session-$CLAUDE_PID (compat)"
fi

# ── Cleanup old markers
find "$HOME/.claude/session-topics" -maxdepth 1 -name '.voice-announced-*' -mmin +1440 -delete 2>/dev/null || true
find "$HOME/.claude/session-topics" -maxdepth 1 -name '.stop-count-*' -mmin +1440 -delete 2>/dev/null || true

# ── Topic file, source marker, voice marker
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
SOURCE_FILE="$HOME/.claude/session-topics/.source-${SESSION_ID}"
MANUAL_MARKER="$HOME/.claude/session-topics/.manual-set-${SESSION_ID}"
VOICE_ANNOUNCED="$HOME/.claude/session-topics/.voice-announced-${SESSION_ID}"

# Helper: voice announce once per session
announce_topic() {
    local topic="$1"
    [ -f "$VOICE_ANNOUNCED" ] && return 0
    local voice_script="$SCRIPT_DIR/voice-notify.sh"
    if [ -x "$voice_script" ]; then
        bash "$voice_script" "$topic" "" &>/dev/null &
        touch "$VOICE_ANNOUNCED"
    fi
}

CURRENT_SOURCE=""
[ -f "$SOURCE_FILE" ] && CURRENT_SOURCE=$(cat "$SOURCE_FILE" 2>/dev/null || echo "")

# ── Manual override always wins
if [ -f "$MANUAL_MARKER" ] || [ "$CURRENT_SOURCE" = "manual" ]; then
    if [ -f "$TOPIC_FILE" ] && [ -s "$TOPIC_FILE" ]; then
        announce_topic "$(cat "$TOPIC_FILE")"
    fi
    exit 0
fi

# ── Try to upgrade topic from Claude Code's internal custom-title
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    CUSTOM_TITLE=$(grep '"custom-title"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | jq -r '.customTitle // ""' 2>/dev/null || echo "")

    if [ -n "$CUSTOM_TITLE" ]; then
        # Convert kebab-case to Title Case: "fix-signin-mobile" → "Fix Signin Mobile"
        TOPIC=$(echo "$CUSTOM_TITLE" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
        TOPIC=$(echo "$TOPIC" | cut -c1-50)

        if [ -n "$TOPIC" ]; then
            tmp="${TOPIC_FILE}.tmp.$$"
            printf '%s\n' "$TOPIC" > "$tmp" && mv "$tmp" "$TOPIC_FILE"
            printf '%s' "custom-title" > "$SOURCE_FILE"
            debug_log "hook: wrote topic '$TOPIC' from custom-title (source=$CURRENT_SOURCE → custom-title)"
            announce_topic "$TOPIC"
            exit 0
        fi
    fi
fi

# ── No custom-title available — keep whatever the UserPromptSubmit hook wrote
if [ -f "$TOPIC_FILE" ] && [ -s "$TOPIC_FILE" ]; then
    announce_topic "$(cat "$TOPIC_FILE")"
fi

exit 0
