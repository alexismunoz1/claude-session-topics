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

# ── Topic file and voice marker
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
VOICE_ANNOUNCED="$HOME/.claude/session-topics/.voice-announced-${SESSION_ID}"

# ── If topic already exists (set by skill or previous hook run)
if [ -f "$TOPIC_FILE" ] && [ -s "$TOPIC_FILE" ]; then
    # Voice announcement on first stop
    if [ ! -f "$VOICE_ANNOUNCED" ]; then
        TOPIC=$(cat "$TOPIC_FILE")
        VOICE_SCRIPT="$SCRIPT_DIR/voice-notify.sh"
        if [ -x "$VOICE_SCRIPT" ]; then
            bash "$VOICE_SCRIPT" "$TOPIC" "" &>/dev/null &
            touch "$VOICE_ANNOUNCED"
        fi
    fi
    exit 0
fi

# ── Extract topic from Claude Code's internal custom-title
[ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ] && exit 0

CUSTOM_TITLE=$(grep '"custom-title"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 | jq -r '.customTitle // ""' 2>/dev/null || echo "")

if [ -n "$CUSTOM_TITLE" ]; then
    # Convert kebab-case to Title Case: "fix-signin-mobile" → "Fix Signin Mobile"
    TOPIC=$(echo "$CUSTOM_TITLE" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
    TOPIC=$(echo "$TOPIC" | cut -c1-50)

    if [ -n "$TOPIC" ]; then
        printf '%s\n' "$TOPIC" > "$TOPIC_FILE"
        debug_log "hook: wrote topic '$TOPIC' from custom-title"

        # Voice notification (opt-in, non-blocking)
        VOICE_SCRIPT="$SCRIPT_DIR/voice-notify.sh"
        if [ -x "$VOICE_SCRIPT" ]; then
            bash "$VOICE_SCRIPT" "$TOPIC" "" &>/dev/null &
            touch "$VOICE_ANNOUNCED"
        fi
    fi
fi

exit 0
