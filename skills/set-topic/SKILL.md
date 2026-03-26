---
name: set-topic
description: Set or change the session topic displayed in the statusline
argument-hint: <topic text>
allowed-tools: [Bash]
version: 1.1.0
---

# Set Topic

Set or change the topic displayed in the Claude Code statusline.

## Usage

`/set-topic <topic text>`

## Instructions

1. The topic text is: $ARGUMENTS
2. If the topic text is empty, inform the user they need to provide a topic (e.g., `/set-topic Auth Refactor`)
3. Run this bash command to discover the session ID and write the topic file:

```bash
SESSION_ID=$(cat /tmp/claude-pid-$PPID 2>/dev/null)
if [ -n "$SESSION_ID" ]; then
    mkdir -p "$HOME/.claude/session-topics"
    echo "$ARGUMENTS" > "$HOME/.claude/session-topics/${SESSION_ID}"
    echo "Topic set to: $ARGUMENTS"
else
    echo "$ARGUMENTS" > "/tmp/claude-pending-topic-$PPID"
    echo "Topic queued: $ARGUMENTS (will appear on next statusline refresh)"
fi
```

4. Confirm to the user that the topic has been set and will appear in the statusline.
