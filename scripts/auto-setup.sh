#!/bin/bash
# Auto-configure statusline on first run (SessionStart hook)
# Handles two cases:
#   1. No statusline configured -> set plugin's statusline.sh directly
#   2. Existing custom statusline -> generate a wrapper that prepends topic to original output

SETTINGS="$HOME/.claude/settings.json"
TOPIC_DIR="$HOME/.claude/session-topics"
WRAPPER="$TOPIC_DIR/wrapper-statusline.sh"
STABLE_SL="$TOPIC_DIR/plugin-statusline.sh"
ORIG_CMD_FILE="$TOPIC_DIR/.original-statusline-cmd"

[ ! -f "$SETTINGS" ] && exit 0

# Find the plugin's statusline script via CLAUDE_PLUGIN_ROOT (set by hooks system)
PLUGIN_SL="${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
[ ! -f "$PLUGIN_SL" ] && exit 0

mkdir -p "$TOPIC_DIR"

# Always refresh the stable copy (keeps it up-to-date across plugin updates)
cp "$PLUGIN_SL" "$STABLE_SL"
chmod +x "$STABLE_SL"

CURRENT_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)

# Already integrated — skip (but the copy above still refreshes)
echo "$CURRENT_CMD" | grep -q 'session-topics' && exit 0

HAS_STATUSLINE=$(jq 'has("statusLine")' "$SETTINGS" 2>/dev/null)

if [ "$HAS_STATUSLINE" = "true" ] && [ -n "$CURRENT_CMD" ]; then
    # Case 2: User has a custom statusline — generate wrapper
    echo "$CURRENT_CMD" > "$ORIG_CMD_FILE"

    cat > "$WRAPPER" << 'WRAPPER_EOF'
#!/bin/bash
input=$(cat)

# Run the plugin's topic statusline (stable copy refreshed each session)
TOPIC_OUTPUT=""
if [ -f "$HOME/.claude/session-topics/plugin-statusline.sh" ]; then
    TOPIC_OUTPUT=$(echo "$input" | bash "$HOME/.claude/session-topics/plugin-statusline.sh" 2>/dev/null || echo "")
fi

# Run the user's original statusline command
ORIG_CMD=$(cat "$HOME/.claude/session-topics/.original-statusline-cmd" 2>/dev/null || echo "")
ORIG_OUTPUT=""
if [ -n "$ORIG_CMD" ]; then
    ORIG_OUTPUT=$(echo "$input" | bash -c "$ORIG_CMD" 2>/dev/null || echo "")
fi

# Combine: topic | original
if [ -n "$TOPIC_OUTPUT" ] && [ -n "$ORIG_OUTPUT" ]; then
    echo -e "${TOPIC_OUTPUT} | ${ORIG_OUTPUT}"
elif [ -n "$TOPIC_OUTPUT" ]; then
    echo -e "${TOPIC_OUTPUT}"
elif [ -n "$ORIG_OUTPUT" ]; then
    echo -e "${ORIG_OUTPUT}"
fi
WRAPPER_EOF
    chmod +x "$WRAPPER"

    jq --arg cmd "bash \"$WRAPPER\"" '.statusLine.command = $cmd' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
else
    # Case 1: No statusline at all — use stable copy directly
    jq --arg cmd "bash \"$STABLE_SL\"" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
fi

# ── Cleanup stale files (once per session start)
find "$HOME/.claude/session-topics" -type f -mtime +7 -not -name '.*' -delete 2>/dev/null || true
find "$HOME/.claude/session-topics" -type f -name '.active-session-*' -mtime +7 -delete 2>/dev/null || true
