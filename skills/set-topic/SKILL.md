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
3. **Sanitize the arguments:** Before writing, the topic must be cleaned to contain only safe display text — letters, numbers, spaces, and basic punctuation (`.,-:!?'`). Strip any shell metacharacters or non-printable characters, and truncate to a maximum of 100 characters.
4. Run this bash command to discover the session ID, sanitize inputs, and write the topic file:

```bash
SESSION_ID=$(cat "$HOME/.claude/session-topics/.active-session" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    echo "Error: No active session found. The statusline must run at least once before setting a topic."
    exit 1
fi
TOPIC=$(printf '%s' "$ARGUMENTS" | sed "s/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ .,:!?'-]//g" | cut -c1-100)
if [ -z "$TOPIC" ]; then
    echo "Error: Topic text is empty after sanitization."
    exit 1
fi
mkdir -p "$HOME/.claude/session-topics"
printf '%s\n' "$TOPIC" > "$HOME/.claude/session-topics/${SESSION_ID}"
echo "Topic set to: $TOPIC"
```

5. Confirm to the user that the topic has been set and will appear in the statusline.
