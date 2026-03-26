# claude-session-topics

Session topics for Claude Code. Auto-detect and display a topic in the statusline, change anytime with `/set-topic`.

![Session topics demo](https://github.com/user-attachments/assets/3698013f-123c-4d7e-8511-44718da5c3a4)

## Install

```bash
npx @alexismunozdev/claude-session-topics
```

## With color

```bash
npx @alexismunozdev/claude-session-topics --color cyan
```

Supported colors: `red`, `green`, `yellow`, `blue`, `magenta` (default), `cyan`, `white`, `orange`, `grey`/`gray`. Raw ANSI codes are also accepted (e.g., `38;5;208`).

## What it does

- Auto-detects a session topic from context on the first prompt
- Shows the topic in the Claude Code statusline (`◆ Topic`)
- Change the topic anytime with `/set-topic`
- Composes with existing statusline plugins (doesn't overwrite)

## What the installer configures

1. Copies the statusline script to `~/.claude/session-topics/`
2. Configures `statusLine` in `~/.claude/settings.json`
3. Adds bash permission for the script
4. Installs `auto-topic` and `set-topic` skills to `~/.claude/skills/`
5. If you already have a statusline, creates a wrapper that shows both

## Requirements

- `jq`
- `bash`
- POSIX-compatible system (macOS, Linux)

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

## Usage

### Auto-topic (automatic)

Starts automatically on session start. Claude reads your first message and sets a short topic (2-4 words) summarizing the task.

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
auto-topic skill fires on first message
    |
Claude writes topic to ~/.claude/session-topics/${SESSION_ID}
    |
Statusline script reads the topic file
    |
Displays: ◆ Topic
```

The statusline script receives the session ID via stdin JSON, reads the corresponding topic file, and renders it with ANSI color codes.

## Uninstall

```bash
npx @alexismunozdev/claude-session-topics --uninstall
```

## License

MIT
