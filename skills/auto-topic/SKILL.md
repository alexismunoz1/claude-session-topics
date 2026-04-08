---
name: auto-topic
description: Use on EVERY user message to refine or update the session topic (2-4 words) when the conversation shifts to a different subject. The initial topic is read from Claude Code's internal custom-title — this skill handles ongoing topic evolution.
version: "4.0.0"
allowed-tools: [Bash]
---

# Auto Topic

Refine and update the session topic as the conversation evolves. The initial topic is read from Claude Code's internal `custom-title` by the Stop hook — this skill's role is to **set the topic early** (before the custom-title is available) and **update it when the conversation shifts**.

## When to Activate

This skill activates on **every user message**. Run it silently — do not mention to the user that you are setting or updating the topic.

## How It Works

1. **Initial topic**: The Stop hook reads Claude Code's `custom-title` from the transcript and converts it to Title Case. However, the custom-title may not be available on the first few turns. This skill fills that gap by inferring a topic from the conversation context.
2. **Ongoing updates**: This skill monitors the conversation and updates the topic when the user shifts to a different area of work.

## Session Resolution

The session ID is resolved via PID detection with fallback to the most recent session marker.

## Rules

1. After reading each user message, infer a topic of **2-5 words** (max 50 characters) that reflects what the user is currently working on
2. The topic should reflect the user's **current** focus. When in doubt, **update** the topic
3. Topics should be in the same language the user is speaking
4. Focus on the user's **intent**, not their exact words. Extract the core subject in 2-5 concise words
5. Examples: "NeonDB Auth Session", "React Query Cache", "Payment API Tests", "Docker Compose Setup", "Login Component Fix"
6. Run the topic check and update **silently** — do not tell the user you set or changed it
7. If `/set-topic` is used later by the user, that takes priority

## Manual Override

If the user explicitly sets a topic (via `/set-topic`, "set the topic to X", or "change the topic to X"):

1. Use their exact text as the topic (do not infer a different one)
2. Sanitize: keep only letters, numbers, spaces, accented characters, and basic punctuation (`.,-:!?'`), truncate to 50 characters
3. Write immediately using the Step 3 bash block below
4. Confirm to the user: "Topic set to: <topic>"
5. Do not override this topic with an inferred one on the same turn

## Word Prioritization

When generating a topic, prioritize words in this order:
1. **Domain/technology terms** (e.g., NeonDB, React, API, Auth, Docker) — always include these
2. **Specific nouns** (e.g., cache, session, endpoint, component, filter) — include when space allows
3. **Generic nouns** (e.g., error, bug, issue) — only include if no better terms are available
4. **Action verbs** (e.g., fix, add, update, refactor) — omit unless the topic would be unclear without one

## How to Check and Update the Topic

### Step 1: Read the current topic

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
    echo "No active session found. Skipping."
    exit 0
fi
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
CURRENT_TOPIC=$(cat "$TOPIC_FILE" 2>/dev/null || echo "")
echo "Current topic: '$CURRENT_TOPIC'"
```

### Step 2: Decide whether to update

Compare the inferred new topic with the current topic.

**Set a topic when:**
- The current topic is empty — **always** infer a topic from the conversation context
- The user has moved to a different area of work
- The current topic no longer describes what the conversation is about

**Do NOT update when:**
- Minor variations of the same topic (e.g., "Auth Tests" → "Auth Unit Tests")
- Rewording without a real subject change

### Step 3: Write the new topic (only if changed)

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
    exit 0
fi
mkdir -p "$HOME/.claude/session-topics"
printf '%s\n' "Your New Topic" > "$HOME/.claude/session-topics/${SESSION_ID}"
```

Replace `Your New Topic` with the inferred 2-5 word topic. The topic must contain only safe display text (letters, numbers, spaces, basic punctuation).

If the topic has NOT meaningfully changed, **do nothing** — skip the write entirely.

## Important

- The Stop hook reads Claude Code's `custom-title` — this skill complements it by covering early turns and topic evolution
- Run this on **every** user message, but only write when the topic has genuinely changed
- Do NOT mention the topic to the user — ever
- Keep topics short and descriptive (2-5 words, max 50 characters)
- If no session can be resolved (no PID and no session markers), skip silently
- If the current topic is empty, **always** infer and set a topic
