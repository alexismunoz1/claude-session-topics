# Contributing to Claude Session Topics

Thank you for your interest in contributing! This document provides guidelines for setting up the development environment and contributing to the project.

## Development Setup

### Prerequisites

- Node.js 18+ and npm
- Bash 4.0+
- jq

### Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install development tools (optional)
brew install shellcheck bats-core  # macOS
# or
sudo apt-get install shellcheck    # Ubuntu/Debian
npm install -g bats                # Bats testing framework
```

### Set Up Git Hooks

We use pre-commit hooks to ensure code quality:

```bash
# Option 1: Copy to .git/hooks
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Option 2: Configure git to use .githooks directory
git config core.hooksPath .githooks
```

## Running Tests

### All Tests

```bash
./test.sh
```

### Individual Test Suites

```bash
# Shell integration tests
bats tests/integration/

# Node.js tests
npm test

# With coverage
npm run test:ui
```

### Linting

```bash
# Shell scripts
shellcheck scripts/*.sh

# JavaScript
npx eslint bin/install.js

# All linting
npm run lint
```

### Diagnostics

Check your installation:

```bash
npm run diagnose
# or
./scripts/diagnose.sh
```

## Project Structure

```
.
├── bin/
│   └── install.js              # Main installer
├── scripts/
│   ├── lib/                    # Shared libraries
│   │   ├── common.sh           # Common functions
│   │   ├── config.sh           # Configuration constants
│   │   ├── logging.sh          # Logging utilities
│   │   └── validate-cmd.sh     # Command validation
│   ├── auto-topic-hook.sh      # Stop hook
│   ├── statusline.sh           # Statusline script
│   ├── extract_topic.sh        # Topic extraction
│   ├── diagnose.sh             # Diagnostic tool
│   ├── check-versions.sh       # Version checker
│   └── sync-versions.js        # Version sync
├── skills/
│   ├── auto-topic/             # Auto-topic skill
│   └── set-topic/              # Set-topic skill
├── tests/
│   ├── integration/            # Shell integration tests
│   ├── installer/              # Node.js installer tests
│   └── fixtures/               # Test fixtures
├── hooks/
│   └── hooks.json              # Claude plugin hooks
├── .github/
│   └── workflows/              # GitHub Actions
├── test.sh                     # Test runner
└── package.json
```

## Making Changes

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

### Commit Messages

Follow conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `style:` - Formatting, missing semi colons, etc
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

Examples:
```
feat: add verbose logging option
fix: handle edge case in topic extraction
docs: update troubleshooting guide
test: add tests for PID detection
```

### Version Management

Before releasing, ensure versions are synchronized:

```bash
# Check versions
npm run version:check

# Sync versions (updates skill versions to match package.json)
npm run version:sync
```

## Testing Your Changes

1. **Run the test suite**: `./test.sh`
2. **Run diagnostics**: `npm run diagnose`
3. **Test the installer locally**:
   ```bash
   npm pack
   npm install -g ./alexismunozdev-claude-session-topics-*.tgz
   ```
4. **Test in a clean environment** (if possible)

## Pull Request Process

1. Ensure all tests pass: `./test.sh`
2. Ensure linting passes: `npm run lint`
3. Update documentation if needed
4. Create a PR with clear description
5. Wait for CI to pass
6. Request review

## Release Process

Releases are automated via GitHub Actions when you push a tag:

```bash
# 1. Update version in package.json
npm version patch  # or minor, major

# 2. Sync skill versions
npm run version:sync

# 3. Commit and tag
git add .
git commit -m "chore: bump version to x.x.x"
git tag v$(node -p "require('./package.json').version")
git push && git push --tags
```

The CI will:
- Run all tests
- Publish to npm
- Create a GitHub release
- Update CHANGELOG.md

## Debugging

### Enable Debug Logging

```bash
export CLAUDE_SESSION_TOPICS_VERBOSE=1
export CLAUDE_SESSION_TOPICS_LOG_LEVEL=0  # DEBUG
```

### View Logs

```bash
cat ~/.claude/session-topics/debug.log
```

### Common Issues

See [README.md#troubleshooting](README.md#troubleshooting) for common issues and solutions.

## Code Style

### Shell Scripts

- Use `#!/bin/bash` with `set -euo pipefail`
- Quote all variables: `"$variable"`
- Use `[[ ]]` for conditionals
- Document functions with comments

### JavaScript

- Use ES6+ features
- Async/await preferred over callbacks
- Destructure when appropriate
- JSDoc for function documentation

## Questions?

- Open an issue on GitHub
- Check existing issues and PRs
- Review the troubleshooting guide in README.md

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
