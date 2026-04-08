# claude-session-topics

Session topics for Claude Code. Auto-detect and display a topic in the statusline, change anytime with `/set-topic`.

![Session topics demo](./assets/session-topics-demo.jpg)

## Install

```bash
npx @alexismunozdev/claude-session-topics
```

## With color

```bash
npx @alexismunozdev/claude-session-topics --color cyan
```

Supported colors: `red`, `green`, `yellow`, `blue`, `magenta` (default), `cyan`, `white`, `orange`, `grey`/`gray`. Raw ANSI codes are also accepted (e.g., `38;5;208`).

## Voice notifications

Get spoken alerts when Claude detects a new session topic — useful when multitasking across terminals.

```bash
npx @alexismunozdev/claude-session-topics --voice       # English default
npx @alexismunozdev/claude-session-topics --voice es    # Spanish fallback
```

The voice **automatically matches your conversation language**. If you write in Spanish, you'll hear *"Tarea terminada: Deploy Config"*. In English: *"Done: Deploy Config"*.

**Platforms supported:**

| Platform | Engine | Install needed? |
|----------|--------|----------------|
| macOS | `say` (native) | No |
| Linux | `espeak` / `espeak-ng` | `sudo apt install espeak` |
| Windows | PowerShell SAPI | No |

**Disable voice:**

```bash
npx @alexismunozdev/claude-session-topics --no-voice
```

**Customize** by editing `~/.claude/session-topics/.voice-config`:

| Variable | Default | Description |
|----------|---------|-------------|
| `VOICE_ENABLED` | `1` | Master on/off |
| `VOICE_AUTO_LANG` | `1` | Auto-detect language from conversation |
| `VOICE_LANG` | `en` | Fallback language when auto-detect is off |
| `VOICE_NAME` | *(empty)* | Specific voice (e.g., `Mónica`, `Jorge` on macOS) |
| `VOICE_TEMPLATE` | *(empty)* | Custom message template with `{topic}` placeholder |
| `VOICE_MUTED` | `0` | Temporary mute without disabling |

## What it does

- After Claude's first response, a Stop hook extracts a 2-5 word topic from your first message using lightweight keyword extraction (no model tokens spent)
- The auto-topic skill refines the topic when the conversation shifts
- Shows the topic in the Claude Code statusline (`◆ Topic`)
- Change the topic anytime with `/set-topic`
- Composes with existing statusline plugins (doesn't overwrite)

## What the installer configures

1. Copies the statusline script to `~/.claude/session-topics/`
2. Installs the Stop hook (`auto-topic-hook.sh`) that sets the initial topic
3. Configures `statusLine` in `~/.claude/settings.json`
4. Adds bash permission for the script
5. Installs `auto-topic` and `set-topic` skills to `~/.claude/skills/`
6. If you already have a statusline, creates a wrapper that shows both
7. Copies `voice-notify.sh` for optional voice alerts

## Requirements

- `jq`
- `bash`
- POSIX-compatible system (macOS, Linux)
- `espeak` (Linux only, for voice notifications)

## Customization

The default topic color is bold magenta. Three ways to change it:

- Re-run with `--color <name>`:
  ```bash
  npx @alexismunozdev/claude-session-topics --color cyan
  ```
- Edit the config file directly:
  ```bash
  echo "cyan" > ~/.claude/session-topics/.color-config
  ```
- Set the `CLAUDE_TOPIC_COLOR` environment variable:
  ```bash
  export CLAUDE_TOPIC_COLOR="cyan"
  ```

## Token usage

This package installs two skills to `~/.claude/skills/`:

- **auto-topic** — loaded on every conversation (needed to track topic changes as you work). This is the core skill that keeps the statusline topic up to date.
- **set-topic** — a minimal stub (~15 lines) that enables the `/set-topic` command. It delegates all logic to auto-topic, so its token footprint is negligible.

The initial topic extraction runs entirely via a Stop hook using `jq` + `awk` — no model tokens spent. Only the auto-topic skill uses model tokens, and only when it detects that the conversation has shifted to a different subject.

## Usage

### Auto-topic (automatic)

After Claude's first response, a Stop hook extracts a 2-5 word topic from your first message using lightweight keyword extraction (no model tokens spent). The auto-topic skill then monitors the conversation and updates the topic when you shift to a different subject.

### /set-topic (manual)

Change the topic at any time:

```
/set-topic Fix Login Bug
/set-topic API Redesign
```

## How it works

```
Session starts
    |
Claude sends first response
    |
Stop hook (auto-topic-hook.sh) extracts topic from first user message
    |
Writes topic to ~/.claude/session-topics/${SESSION_ID}
    |
auto-topic skill monitors for conversation shifts and updates topic
    |
Statusline script reads the topic file → displays: ◆ Topic
```

The Stop hook runs after each model response and uses lightweight keyword extraction (jq + awk) to extract the initial topic from the transcript. No model tokens are spent — the extraction is purely heuristic. On subsequent messages, the auto-topic skill handles topic updates when the conversation shifts. The statusline script receives the session ID via stdin JSON, reads the corresponding topic file, and renders it with ANSI color codes.

## Troubleshooting

### Run Diagnostics

Check your installation:

```bash
~/.claude/session-topics/diagnose.sh
```

Or from the project directory:
```bash
./scripts/diagnose.sh
```

### Enable Debug Logging

Set the verbose environment variable:

```bash
export CLAUDE_SESSION_TOPICS_VERBOSE=1
# Then run your claude commands
```

Or use the --verbose flag with the installer:

```bash
npx @alexismunozdev/claude-session-topics --verbose
```

### View Debug Logs

Debug logs are stored in:

```bash
cat ~/.claude/session-topics/debug.log
```

Log levels (set via `CLAUDE_SESSION_TOPICS_LOG_LEVEL`):
- `0` = DEBUG (most verbose)
- `1` = INFO (default)
- `2` = WARN
- `3` = ERROR (least verbose)

### Common Issues

**Topic not appearing in statusline:**
1. Check that the hook is registered: `cat ~/.claude/settings.json | jq '.hooks'`
2. Verify permissions: `cat ~/.claude/settings.json | jq '.permissions'`
3. Check debug logs for errors

**Permission denied errors:**
1. Ensure scripts are executable: `chmod +x ~/.claude/session-topics/*.sh`
2. Check that Bash permission is in settings.json

## Uninstall

```bash
npx @alexismunozdev/claude-session-topics --uninstall
```

This also removes voice configuration (`~/.claude/session-topics/.voice-config`).

## License

MIT
