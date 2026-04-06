---
name: auto-topic
description: Use on EVERY user message to refine or update the session topic (2-4 words) when the conversation shifts to a different subject. The initial topic is set automatically by the Stop hook — this skill handles ongoing topic evolution.
version: 2.1.1
allowed-tools: [Bash]
---

# Auto Topic

Refine and update the session topic as the conversation evolves. The initial topic is set automatically by a Stop hook after the first response — this skill's role is to **update the topic when the conversation shifts** to a different subject.

## When to Activate

This skill activates on **every user message**. Run it silently — do not mention to the user that you are setting or updating the topic.

## How It Works

1. **Initial topic**: Handled automatically by the Stop hook (`auto-topic-hook.sh`). It extracts a 2-4 word topic from the first user message using heuristics. No action needed from this skill for the first message.
2. **Ongoing updates**: This skill monitors the conversation and updates the topic when needed — either because the hook produced a poor/missing topic, or because the user shifted to a different area of work.

## Finding the Claude Process

Before reading or writing the topic, you must locate the Claude process PID to find the correct session file. The session file is stored at `$HOME/.claude/session-topics/.active-session-$CLAUDE_PID`.

Use this function to traverse up the process tree and find the Claude process:

```bash
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
CLAUDE_PID=$(find_claude_pid)
```

If `CLAUDE_PID` is empty, skip the topic update silently.

## Rules

1. After reading each user message, infer a topic of **2-5 words** (max 50 characters) that reflects what the user is currently working on
2. The topic should reflect the user's **current** focus, not the overall session theme. When in doubt, **update** the topic
3. Topics should be in the same language the user is speaking. If the user writes in Spanish, the topic should be in Spanish; if in English, in English
4. Focus on the user's **intent**, not their exact words. Extract the core subject being discussed in 2-5 concise words
5. Examples: "NeonDB Auth Session", "React Query Cache", "Payment API Tests", "Docker Compose Setup", "Login Component Fix"
6. Run the topic check and update **silently** — do not tell the user you set or changed it
7. If `/set-topic` is used later by the user, that takes priority

## Word Prioritization

When generating a topic, prioritize words in this order:
1. **Domain/technology terms** (e.g., NeonDB, React, API, Auth, Docker) — always include these
2. **Specific nouns** (e.g., cache, session, endpoint, component, filter) — include when space allows
3. **Generic nouns** (e.g., error, bug, issue) — only include if no better terms are available
4. **Action verbs** (e.g., fix, add, update, refactor) — omit unless the topic would be unclear without one

## How to Check and Update the Topic

### Step 1: Read the current topic

```bash
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
CLAUDE_PID=$(find_claude_pid)
if [ -z "$CLAUDE_PID" ]; then
    echo "No active session found. Skipping."
    exit 0
fi
SESSION_ID=$(cat "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    echo "No active session found. Skipping."
    exit 0
fi
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
CURRENT_TOPIC=$(cat "$TOPIC_FILE" 2>/dev/null || echo "")
echo "Current topic: '$CURRENT_TOPIC'"
```

### Step 2: Decide whether to update

Compare the inferred new topic with the current topic. **Only write a new topic if the conversation has clearly shifted to a different subject.** Do NOT update for:
- Minor variations of the same topic (e.g., "Auth Tests" → "Auth Unit Tests")
- Minor rewording of the same specific task (e.g., "Auth Refactor" → "Refactor Auth")
- Rewording without a real subject change
- The first message IF the Stop hook has already set a topic (check if current topic is non-empty)

DO update when:
- The current topic is empty or was not set by the hook — **always** infer a topic from the conversation context
- The current topic doesn't clearly describe what the user is working on (e.g., "Home Desktop Buscard" is not a meaningful topic)
- The user has moved to a different file, directory, or area of work (e.g., "Components Analysis" → "TSConfig Analysis")
- The user's current request focuses on something different from what the current topic describes
- The original topic no longer describes what the conversation is about
- The hook-generated topic is too generic and you can infer a better one from context
- The current topic is dominated by action verbs or generic terms (e.g., "Fix Error", "Corrige Bug", "Add New") — replace with domain-specific terms from the user's message
- The current topic is in a different language than the user is currently speaking

### Step 3: Write the new topic (only if changed)

If the topic has meaningfully changed, run:

```bash
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
CLAUDE_PID=$(find_claude_pid)
if [ -z "$CLAUDE_PID" ]; then
    exit 0
fi
SESSION_ID=$(cat "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    exit 0
fi
mkdir -p "$HOME/.claude/session-topics"
printf '%s\n' "Your New Topic" > "$HOME/.claude/session-topics/${SESSION_ID}"
```

Replace `Your New Topic` with the inferred 2-5 word topic. The topic must contain only safe display text (letters, numbers, spaces, basic punctuation).

If the topic has NOT meaningfully changed, **do nothing** — skip the write entirely.

## Important

- The Stop hook sets the initial topic automatically — this skill complements it by handling topic evolution
- Run this on **every** user message, but only write when the topic has genuinely changed
- Do NOT mention the topic to the user — ever
- Keep topics short and descriptive (2-5 words, max 50 characters)
- If the statusline hasn't run yet (no `.active-session-<claude-pid>` file), skip silently
- A low bar for "changed" keeps the topic fresh — when in doubt, update
- If the current topic is empty, **always** infer and set a topic — do not wait for the Stop hook
