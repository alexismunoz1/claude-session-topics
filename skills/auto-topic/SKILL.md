---
name: auto-topic
description: Use on EVERY user message to refine or update the session topic (2-4 words) when the conversation shifts to a different subject. The initial topic is set automatically by the Stop hook — this skill handles ongoing topic evolution.
version: 2.0.0
allowed-tools: [Bash]
---

# Auto Topic

Refine and update the session topic as the conversation evolves. The initial topic is set automatically by a Stop hook after the first response — this skill's role is to **update the topic when the conversation shifts** to a different subject.

## When to Activate

This skill activates on **every user message**. Run it silently — do not mention to the user that you are setting or updating the topic.

## How It Works

1. **Initial topic**: Handled automatically by the Stop hook (`auto-topic-hook.sh`). It extracts a 2-4 word topic from the first user message using heuristics. No action needed from this skill for the first message.
2. **Ongoing updates**: This skill monitors the conversation and updates the topic when the user shifts to a genuinely different area of work.

## Rules

1. After reading each user message, infer a topic of **2-4 words** (max 20 characters) that reflects what the user is currently working on
2. The topic should summarize the current focus of the conversation
3. Use the project's domain language (e.g., Spanish is fine if the user writes in Spanish)
4. Examples: "Auth Refactor", "FAQ Bug", "Search Filters", "DB Migration", "API Tests"
5. Run the topic check and update **silently** — do not tell the user you set or changed it
6. If `/set-topic` is used later by the user, that takes priority

## How to Check and Update the Topic

### Step 1: Read the current topic

```bash
SESSION_ID=$(cat "$HOME/.claude/session-topics/.active-session" 2>/dev/null)
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
- Minor variations of the same topic (e.g., "Auth Refactor" → "Refactor Auth")
- Subtasks within the same broader topic (e.g., "Auth Refactor" → "Auth Tests" if still working on auth)
- Rewording without a real subject change
- The first message (the Stop hook already handles initial topic setting)

DO update when:
- The user has moved to a genuinely different area of work (e.g., "Auth Refactor" → "DB Migration")
- The original topic no longer describes what the conversation is about
- The hook-generated topic is too generic and you can infer a better one from context

### Step 3: Write the new topic (only if changed)

If the topic has meaningfully changed, run:

```bash
SESSION_ID=$(cat "$HOME/.claude/session-topics/.active-session" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    exit 0
fi
mkdir -p "$HOME/.claude/session-topics"
printf '%s\n' "Your New Topic" > "$HOME/.claude/session-topics/${SESSION_ID}"
```

Replace `Your New Topic` with the inferred 2-4 word topic. The topic must contain only safe display text (letters, numbers, spaces, basic punctuation).

If the topic has NOT meaningfully changed, **do nothing** — skip the write entirely.

## Important

- The Stop hook sets the initial topic automatically — this skill complements it by handling topic evolution
- Run this on **every** user message, but only write when the topic has genuinely changed
- Do NOT mention the topic to the user — ever
- Keep topics short and descriptive (2-4 words, max 20 characters)
- If the statusline hasn't run yet (no `.active-session` file), skip silently
- A high bar for "meaningfully changed" prevents unnecessary churn — when in doubt, keep the current topic
