# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.9.2] - 2025-04-03

### Added
- ESLint v9 configuration with flat config (`eslint.config.js`)
- ESLint dependency for code quality enforcement

### Changed
- Cleaned up orphaned files and directories from repository
- Improved `.gitignore` to exclude build artifacts (*.tgz)

## [2.8.0] - 2025-03-30
  - 41 Python tests for topic extraction
  - 6 shell integration tests (Bats)
  - 35 Node.js installer tests (Vitest)
- Security hardening for installer
  - Command validation to prevent injection attacks
  - Validates backup commands before storing
  - Rejects dangerous patterns: `$(...)`, `` `...` ``, chaining, path traversal
- Observability and logging
  - Structured logging library with levels (DEBUG/INFO/WARN/ERROR)
  - Diagnostic script for troubleshooting
  - Verbose mode (`--verbose` flag)
  - Debug logs at `~/.claude/session-topics/debug.log`
- CI/CD automation
  - GitHub Actions workflow for testing (Python, Shell, Node.js)
  - Automatic npm publishing on tags
  - Shellcheck and ESLint integration
  - macOS integration testing
- Developer tooling
  - Pre-commit hooks for code quality
  - Version synchronization between package.json and skills
  - Contributing guidelines

### Changed
- Refactored code to eliminate duplication
  - Extracted common functions to `scripts/lib/common.sh`
  - Centralized configuration in `scripts/lib/config.sh`
- Improved error handling
  - Replaced silent failures with explicit logging
  - Better validation of user inputs

### Fixed
- Shellcheck warnings in all shell scripts
- Version extraction in version checker
- macOS compatibility in tests (date command)

## [2.8.1] - 2024-04-01

### Fixed
- Various bug fixes and improvements

## [2.8.0] - 2024-03-31

### Previous Releases

For changes prior to 2.8.1, please refer to the git history.
