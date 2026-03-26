#!/usr/bin/env node

// claude-session-topics — npx installer
// Installs statusline script, skills, and configures settings.json
// Zero runtime dependency on npm after installation.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

// ─── ANSI helpers ────────────────────────────────────────────────────────────

const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const CYAN = '\x1b[36m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

const ok = (msg) => console.log(`  ${GREEN}\u2713${RESET} ${msg}`);
const warn = (msg) => console.log(`  ${YELLOW}\u26A0${RESET} ${msg}`);
const err = (msg) => console.error(`  ${RED}\u2717${RESET} ${msg}`);
const info = (msg) => console.log(`  ${DIM}${msg}${RESET}`);
const heading = (msg) => console.log(`\n${BOLD}${CYAN}${msg}${RESET}\n`);

// ─── Destination paths (fixed — never change) ───────────────────────────────

const HOME = os.homedir();
const TOPICS_DIR = path.join(HOME, '.claude', 'session-topics');
const DEST_STATUSLINE = path.join(TOPICS_DIR, 'statusline.sh');
const DEST_WRAPPER = path.join(TOPICS_DIR, 'wrapper-statusline.sh');
const DEST_HOOK_SCRIPT = path.join(TOPICS_DIR, 'auto-topic-hook.sh');
const ORIG_CMD_FILE = path.join(TOPICS_DIR, '.original-statusline-cmd');
const COLOR_CONFIG = path.join(TOPICS_DIR, '.color-config');
const SKILLS_DIR = path.join(HOME, '.claude', 'skills');
const SETTINGS_FILE = path.join(HOME, '.claude', 'settings.json');

// ─── Source paths (relative to this script) ──────────────────────────────────

const SRC_STATUSLINE = path.join(__dirname, '..', 'scripts', 'statusline.sh');
const SRC_HOOK_SCRIPT = path.join(__dirname, '..', 'scripts', 'auto-topic-hook.sh');
const SRC_SKILLS = path.join(__dirname, '..', 'skills');

// ─── The statusline command that settings.json will reference ────────────────

const STATUSLINE_CMD = `bash "$HOME/.claude/session-topics/statusline.sh"`;
const WRAPPER_CMD = `bash "$HOME/.claude/session-topics/wrapper-statusline.sh"`;
const STOP_HOOK_CMD = `bash "$HOME/.claude/session-topics/auto-topic-hook.sh" || true`;

// ─── Permission rule ─────────────────────────────────────────────────────────

const PERMISSION_RULE = 'Bash(*/.claude/session-topics/*)';

// ─── Wrapper script content ──────────────────────────────────────────────────

const WRAPPER_SCRIPT = `#!/bin/bash
input=$(cat)
TOPIC_OUTPUT=$(echo "$input" | bash "$HOME/.claude/session-topics/statusline.sh" 2>/dev/null || echo "")
ORIG_CMD=$(cat "$HOME/.claude/session-topics/.original-statusline-cmd" 2>/dev/null || echo "")
ORIG_OUTPUT=""

# Validate the original command before executing it
validate_cmd() {
    local cmd="\$1"
    # Reject dangerous patterns: command substitution, backticks, chaining,
    # process substitution, and /dev/tcp|udp redirection
    if echo "\$cmd" | grep -qF '\$(' ; then return 1; fi
    if echo "\$cmd" | grep -qF '\`' ; then return 1; fi
    if echo "\$cmd" | grep -q '[;&|]' ; then return 1; fi
    if echo "\$cmd" | grep -qE '>\\(' ; then return 1; fi
    if echo "\$cmd" | grep -qE '<\\(' ; then return 1; fi
    if echo "\$cmd" | grep -qE '/dev/(tcp|udp)' ; then return 1; fi
    # Must start with an allowed command pattern (bash <path> or absolute path)
    if ! echo "\$cmd" | grep -qE '^(bash |/[a-zA-Z0-9._/-]+)' ; then return 1; fi
    return 0
}

if [ -n "$ORIG_CMD" ] && validate_cmd "$ORIG_CMD"; then
    ORIG_OUTPUT=$(echo "$input" | bash -c "$ORIG_CMD" 2>/dev/null || echo "")
fi

if [ -n "$TOPIC_OUTPUT" ] && [ -n "$ORIG_OUTPUT" ]; then
    echo -e "\${TOPIC_OUTPUT} | \${ORIG_OUTPUT}"
elif [ -n "$TOPIC_OUTPUT" ]; then
    echo -e "\${TOPIC_OUTPUT}"
elif [ -n "$ORIG_OUTPUT" ]; then
    echo -e "\${ORIG_OUTPUT}"
fi
`;

// ─── Utility functions ───────────────────────────────────────────────────────

function readSettings() {
    try {
        const raw = fs.readFileSync(SETTINGS_FILE, 'utf8');
        return JSON.parse(raw);
    } catch {
        return {};
    }
}

function writeSettings(obj) {
    const dir = path.dirname(SETTINGS_FILE);
    fs.mkdirSync(dir, { recursive: true });
    // Atomic write: write to temp file then rename to avoid TOCTOU race condition
    const tmpFile = SETTINGS_FILE + '.tmp.' + process.pid;
    fs.writeFileSync(tmpFile, JSON.stringify(obj, null, 2) + '\n', { encoding: 'utf8', mode: 0o600 });
    fs.renameSync(tmpFile, SETTINGS_FILE);
}

function copyDirRecursive(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            copyDirRecursive(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

function hasJq() {
    try {
        execSync('which jq', { stdio: 'pipe' });
        return true;
    } catch {
        return false;
    }
}

// ─── CLI argument parsing ────────────────────────────────────────────────────

const VALID_NAMED_COLORS = ['green', 'blue', 'cyan', 'magenta', 'yellow', 'red', 'white', 'orange', 'grey'];
const VALID_ANSI_CODE_RE = /^[0-9;]{1,15}$/;

function validateColor(value) {
    if (VALID_NAMED_COLORS.includes(value.toLowerCase())) return true;
    if (VALID_ANSI_CODE_RE.test(value)) return true;
    return false;
}

function parseArgs(argv) {
    const args = argv.slice(2);
    const result = { action: 'install', color: null };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg === '--help' || arg === '-h') {
            result.action = 'help';
            return result;
        }
        if (arg === '--uninstall') {
            result.action = 'uninstall';
            return result;
        }
        if (arg === '--color') {
            if (i + 1 < args.length) {
                const colorValue = args[i + 1];
                if (!validateColor(colorValue)) {
                    err(`Invalid color: "${colorValue}". Use a named color (${VALID_NAMED_COLORS.join(', ')}) or a numeric ANSI code (max 15 chars).`);
                    process.exit(1);
                }
                result.color = colorValue;
                i++;
            } else {
                err('--color requires a value (e.g., --color cyan)');
                process.exit(1);
            }
        }
    }

    return result;
}

// ─── Help ────────────────────────────────────────────────────────────────────

function showHelp() {
    console.log(`
${BOLD}claude-session-topics${RESET} — session topics for Claude Code

${BOLD}Usage:${RESET}
  npx @alexismunozdev/claude-session-topics            Install
  npx @alexismunozdev/claude-session-topics --color cyan  Install with color
  npx @alexismunozdev/claude-session-topics --uninstall   Uninstall

${BOLD}Options:${RESET}
  --color <name>   Set topic color (red, green, yellow, blue, magenta,
                    cyan, white, orange, grey). Default: magenta
  --uninstall      Remove scripts, settings, and skills (preserves topic data)
  -h, --help       Show this help

${BOLD}What it does:${RESET}
  - Copies statusline.sh to ~/.claude/session-topics/
  - Configures statusLine in ~/.claude/settings.json
  - Adds Bash permission for session-topics commands
  - Registers Stop hook for automatic topic detection
  - Installs auto-topic and set-topic skills to ~/.claude/skills/

${BOLD}After install:${RESET}
  The statusline shows the current topic automatically.
  Use ${CYAN}/set-topic <text>${RESET} to change it manually.
`);
}

// ─── Install ─────────────────────────────────────────────────────────────────

function install(color) {
    heading('Installing claude-session-topics');

    // ── Step 1: Check deps ───────────────────────────────────────────────

    if (!hasJq()) {
        err('jq is required but not found in PATH.');
        console.log(`\n  Install it:  ${BOLD}brew install jq${RESET}  (macOS)`);
        console.log(`               ${BOLD}sudo apt install jq${RESET}  (Ubuntu/Debian)\n`);
        process.exit(1);
    }
    ok('jq found');

    // ── Step 2: Create dir ───────────────────────────────────────────────

    fs.mkdirSync(TOPICS_DIR, { recursive: true });
    ok(`Created ${DIM}~/.claude/session-topics/${RESET}`);

    // ── Step 3: Copy statusline ──────────────────────────────────────────

    if (!fs.existsSync(SRC_STATUSLINE)) {
        err(`Source statusline not found: ${SRC_STATUSLINE}`);
        process.exit(1);
    }
    fs.copyFileSync(SRC_STATUSLINE, DEST_STATUSLINE);
    fs.chmodSync(DEST_STATUSLINE, 0o755);
    ok('Copied statusline.sh');

    // ── Step 4: Copy auto-topic hook script ─────────────────────────────

    if (!fs.existsSync(SRC_HOOK_SCRIPT)) {
        err(`Source hook script not found: ${SRC_HOOK_SCRIPT}`);
        process.exit(1);
    }
    fs.copyFileSync(SRC_HOOK_SCRIPT, DEST_HOOK_SCRIPT);
    fs.chmodSync(DEST_HOOK_SCRIPT, 0o755);
    ok('Copied auto-topic-hook.sh');

    // ── Step 5: Configure statusline in settings.json ────────────────────

    const settings = readSettings();
    const statusLineCase = determineStatusLineCase(settings);

    switch (statusLineCase) {
        case 'A': {
            // No statusLine — create fresh
            settings.statusLine = {
                type: 'command',
                command: STATUSLINE_CMD,
            };
            writeSettings(settings);
            ok('Configured statusLine in settings.json');
            break;
        }
        case 'B': {
            // Already ours — just update the script (already copied above)
            ok('statusLine already configured for session-topics (updated script)');
            break;
        }
        case 'C': {
            // Another command exists — create wrapper
            const origCmd = settings.statusLine.command;

            // Backup original command (read-only: 0400 to prevent tampering)
            fs.writeFileSync(ORIG_CMD_FILE, origCmd, { encoding: 'utf8', mode: 0o400 });
            info(`Backed up original statusLine command to .original-statusline-cmd`);

            // Write wrapper
            fs.writeFileSync(DEST_WRAPPER, WRAPPER_SCRIPT, { encoding: 'utf8', mode: 0o600 });
            fs.chmodSync(DEST_WRAPPER, 0o755);
            info('Created wrapper-statusline.sh');

            // Update settings to use wrapper
            settings.statusLine.command = WRAPPER_CMD;
            writeSettings(settings);
            ok('Configured statusLine wrapper (preserves your existing statusline)');
            break;
        }
        case 'D': {
            // statusLine exists but no valid command — treat as case A
            settings.statusLine = {
                type: 'command',
                command: STATUSLINE_CMD,
            };
            writeSettings(settings);
            ok('Configured statusLine in settings.json (replaced invalid entry)');
            break;
        }
    }

    // ── Step 6: Add permission ───────────────────────────────────────────

    if (!settings.permissions || typeof settings.permissions !== 'object' || Array.isArray(settings.permissions)) {
        settings.permissions = {};
    }
    if (!Array.isArray(settings.permissions.allow)) {
        settings.permissions.allow = [];
    }
    if (!settings.permissions.allow.includes(PERMISSION_RULE)) {
        settings.permissions.allow.push(PERMISSION_RULE);
        writeSettings(settings);
        ok(`Added permission: ${DIM}${PERMISSION_RULE}${RESET}`);
    } else {
        ok('Permission already present');
    }

    // ── Step 7: Register Stop hook ──────────────────────────────────────

    if (!settings.hooks || typeof settings.hooks !== 'object' || Array.isArray(settings.hooks)) {
        settings.hooks = {};
    }
    if (!Array.isArray(settings.hooks.Stop)) {
        settings.hooks.Stop = [];
    }

    // Find existing session-topics hook entry
    let hookFound = false;
    for (const entry of settings.hooks.Stop) {
        if (entry && Array.isArray(entry.hooks)) {
            for (const h of entry.hooks) {
                if (h && typeof h.command === 'string' && h.command.includes('session-topics')) {
                    h.command = STOP_HOOK_CMD;
                    hookFound = true;
                }
            }
        }
    }

    if (!hookFound) {
        settings.hooks.Stop.push({
            hooks: [
                {
                    type: 'command',
                    command: STOP_HOOK_CMD,
                },
            ],
        });
    }
    writeSettings(settings);
    if (hookFound) {
        ok('Updated Stop hook for auto-topic detection');
    } else {
        ok('Registered Stop hook for auto-topic detection');
    }

    // ── Step 8: Copy skills ──────────────────────────────────────────────

    const skillsToCopy = ['auto-topic', 'set-topic'];
    for (const skill of skillsToCopy) {
        const srcSkill = path.join(SRC_SKILLS, skill);
        const destSkill = path.join(SKILLS_DIR, skill);
        if (fs.existsSync(srcSkill)) {
            copyDirRecursive(srcSkill, destSkill);
            ok(`Installed skill: ${BOLD}${skill}${RESET}`);
        } else {
            warn(`Skill source not found: ${skill}`);
        }
    }

    // ── Step 9: Configure color ──────────────────────────────────────────

    if (color) {
        fs.writeFileSync(COLOR_CONFIG, color, { encoding: 'utf8', mode: 0o600 });
        ok(`Topic color set to: ${BOLD}${color}${RESET}`);
    }

    // ── Step 10: Summary ─────────────────────────────────────────────────

    console.log('');
    heading('Installation complete');
    console.log(`  ${DIM}Statusline:${RESET}  ~/.claude/session-topics/statusline.sh`);
    console.log(`  ${DIM}Skills:${RESET}      ~/.claude/skills/auto-topic/`);
    console.log(`                ~/.claude/skills/set-topic/`);
    console.log(`  ${DIM}Hook:${RESET}        Stop → auto-topic-hook.sh`);
    console.log(`  ${DIM}Settings:${RESET}    ~/.claude/settings.json`);
    if (color) {
        console.log(`  ${DIM}Color:${RESET}       ${color}`);
    }
    console.log('');
    console.log(`  Topics are set automatically. Use ${CYAN}/set-topic <text>${RESET} to override.`);
    console.log('');
}

function determineStatusLineCase(settings) {
    // Case B or C: statusLine exists
    if (settings.statusLine && typeof settings.statusLine === 'object') {
        const cmd = settings.statusLine.command;
        if (typeof cmd === 'string' && cmd.length > 0) {
            // Case B: already ours
            if (cmd.includes('session-topics')) {
                return 'B';
            }
            // Case C: another command
            return 'C';
        }
        // statusLine exists but no valid command
        return 'D';
    }
    // No statusLine at all
    return 'A';
}

// ─── Uninstall ───────────────────────────────────────────────────────────────

function uninstall() {
    heading('Uninstalling claude-session-topics');

    const settings = readSettings();

    // ── Step 1: Restore statusline ───────────────────────────────────────

    if (fs.existsSync(ORIG_CMD_FILE)) {
        // Had a previous command — restore it
        const origCmd = fs.readFileSync(ORIG_CMD_FILE, 'utf8').trim();
        if (origCmd && settings.statusLine) {
            settings.statusLine.command = origCmd;
            writeSettings(settings);
            ok(`Restored original statusLine command`);
            info(`  ${origCmd}`);
        }
    } else {
        // No backup — remove statusLine entirely if it's ours
        if (
            settings.statusLine &&
            typeof settings.statusLine.command === 'string' &&
            settings.statusLine.command.includes('session-topics')
        ) {
            delete settings.statusLine;
            writeSettings(settings);
            ok('Removed statusLine from settings.json');
        } else if (settings.statusLine) {
            info('statusLine does not reference session-topics — left untouched');
        } else {
            info('No statusLine to remove');
        }
    }

    // ── Step 2: Delete scripts ───────────────────────────────────────────

    const filesToDelete = [DEST_STATUSLINE, DEST_WRAPPER, DEST_HOOK_SCRIPT, ORIG_CMD_FILE];
    for (const file of filesToDelete) {
        if (fs.existsSync(file)) {
            fs.unlinkSync(file);
            ok(`Deleted ${path.basename(file)}`);
        }
    }

    // ── Step 3: Remove permission ────────────────────────────────────────

    if (
        settings.permissions &&
        typeof settings.permissions === 'object' &&
        Array.isArray(settings.permissions.allow)
    ) {
        const before = settings.permissions.allow.length;
        const OLD_PERMISSION_RULE = 'Bash(*session-topics*)';
        settings.permissions.allow = settings.permissions.allow.filter(
            (rule) => rule !== PERMISSION_RULE && rule !== OLD_PERMISSION_RULE
        );
        if (settings.permissions.allow.length < before) {
            writeSettings(settings);
            ok(`Removed permission: ${PERMISSION_RULE}`);
        }
    }

    // ── Step 4: Remove Stop hook ───────────────────────────────────────

    if (
        settings.hooks &&
        typeof settings.hooks === 'object' &&
        Array.isArray(settings.hooks.Stop)
    ) {
        const beforeLen = settings.hooks.Stop.length;
        settings.hooks.Stop = settings.hooks.Stop.filter((entry) => {
            if (entry && Array.isArray(entry.hooks)) {
                return !entry.hooks.some(
                    (h) => h && typeof h.command === 'string' && h.command.includes('session-topics')
                );
            }
            return true;
        });
        if (settings.hooks.Stop.length < beforeLen) {
            if (settings.hooks.Stop.length === 0) {
                delete settings.hooks.Stop;
            }
            if (Object.keys(settings.hooks).length === 0) {
                delete settings.hooks;
            }
            writeSettings(settings);
            ok('Removed Stop hook');
        }
    }

    // ── Step 5: Delete skills ────────────────────────────────────────────

    const skillsToDelete = ['auto-topic', 'set-topic'];
    for (const skill of skillsToDelete) {
        const skillDir = path.join(SKILLS_DIR, skill);
        if (fs.existsSync(skillDir)) {
            fs.rmSync(skillDir, { recursive: true, force: true });
            ok(`Removed skill: ${skill}`);
        }
    }

    // ── Step 6: Preserve data ────────────────────────────────────────────

    info('Preserved topic data in ~/.claude/session-topics/ (topic files + color config)');

    // ── Summary ──────────────────────────────────────────────────────────

    console.log('');
    heading('Uninstall complete');
    console.log(`  Scripts and skills removed. Topic data preserved.`);
    console.log(`  To fully remove all data: ${DIM}rm -rf ~/.claude/session-topics/${RESET}`);
    console.log('');
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
    const { action, color } = parseArgs(process.argv);

    switch (action) {
        case 'help':
            showHelp();
            break;
        case 'install':
            install(color);
            break;
        case 'uninstall':
            uninstall();
            break;
        default:
            showHelp();
            break;
    }
}

main();
