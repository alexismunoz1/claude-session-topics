---
name: set-topic
description: Set or change the session topic displayed in the statusline
argument-hint: <topic text>
allowed-tools: [Bash]
version: "3.3.0"
---

# Set Topic

Set or change the topic displayed in the Claude Code statusline.

## Usage

`/set-topic <topic text>`

## Instructions

1. The topic text is: $ARGUMENTS
2. If the topic text is empty, inform the user they need to provide a topic (e.g., `/set-topic Auth Refactor`)
3. **Sanitize the arguments:** Before writing, the topic must be cleaned to contain only safe display text — letters, numbers, spaces, and basic punctuation (`.,-:!?'`). Strip any shell metacharacters or non-printable characters, and truncate to a maximum of 50 characters.
4. Run this bash command to discover the Claude process PID, find the session ID, sanitize inputs, and write the topic file:

```bash
resolve_session_id() {
  local pid=$$
  while [ "$pid" != "1" ] && [ -n "$pid" ]; do
    local parent
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$parent" ] && break
    local comm
    comm=$(ps -o comm= -p "$parent" 2>/dev/null)
    case "$comm" in
      *claude*|*Claude*)
        local sid
        sid=$(cat "$HOME/.claude/session-topics/.active-session-$parent" 2>/dev/null)
        sid=$(echo "$sid" | tr -cd 'a-zA-Z0-9_-')
        [ -n "$sid" ] && echo "$sid" && return 0
        break ;;
    esac
    pid=$parent
  done
  local latest
  latest=$(ls -t "$HOME/.claude/session-topics"/.active-session-id-* 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    local sid
    sid=$(basename "$latest" | sed 's/^\.active-session-id-//')
    sid=$(echo "$sid" | tr -cd 'a-zA-Z0-9_-')
    [ -n "$sid" ] && echo "$sid" && return 0
  fi
  echo ""
}
SESSION_ID=$(resolve_session_id)
if [ -z "$SESSION_ID" ]; then
    echo "Error: No active session found. The statusline must run at least once before setting a topic."
    exit 1
fi
TOPIC=$(printf '%s' "$ARGUMENTS" | sed "s/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ .,:!?'-]//g" | cut -c1-50)
if [ -z "$TOPIC" ]; then
    echo "Error: Topic text is empty after sanitization."
    exit 1
fi
mkdir -p "$HOME/.claude/session-topics"
printf '%s\n' "$TOPIC" > "$HOME/.claude/session-topics/${SESSION_ID}"
echo "Topic set to: $TOPIC"
```

5. Confirm to the user that the topic has been set and will appear in the statusline.
