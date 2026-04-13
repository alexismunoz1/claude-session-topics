# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] — 2026-04-13

### Added
- `UserPromptSubmit` hook (`scripts/user-prompt-hook.sh`) for deterministic topic generation on every user message — no longer dependent on the model invoking a skill
- Synchronous bash heuristic writes a topic in <200 ms; asynchronous `claude -p --model haiku` refines it in the background
- Explicit source tracking via `.source-${SESSION_ID}` marker (values: `manual`, `custom-title`, `refined`, `heuristic`)
- Manual override marker `.manual-set-${SESSION_ID}` — set by `/set-topic`, protects the topic from hook overwrites for the rest of the session
- Recursion guard `CLAUDE_SESSION_TOPICS_SKIP=1` so the background `claude -p` call does not re-trigger the hook

### Changed
- Stop hook (`auto-topic-hook.sh`) now upgrades existing topics when Claude Code's `custom-title` becomes available (previously it exited early if a topic already existed)
- Source precedence is now explicit: `manual > custom-title > refined > heuristic > empty`
- `set-topic` skill is self-contained (no longer delegates to `auto-topic`); sets the manual marker atomically
- Installer copies `scripts/lib/` and registers the new `UserPromptSubmit` hook; uninstall cleans both hooks
- README rewritten to describe the two-hook flow and precedence

### Removed
- `auto-topic` skill — its role is fully subsumed by the deterministic `UserPromptSubmit` hook, removing a source of non-determinism and race conditions. Installer removes the obsolete skill on upgrade.

### Breaking
- Installations that depended on the `auto-topic` skill being present should reinstall with `npx @alexismunozdev/claude-session-topics` to pick up the new hook registration.

## [4.0.0] — 2026-04-08

### Changed
- Topic extraction now reads Claude Code's internal `custom-title` from the transcript instead of using custom heuristics
- Simplified auto-topic skill — removed hook override logic, streamlined rules
- Simplified statusline fallback to use `custom-title` instead of bash heuristics

### Removed
- Removed `scripts/extract_topic.sh` (~320 lines of bash NLP heuristics)
- Removed `tests/integration/test_extract_topic.bats` and all transcript fixtures
- Removed topic extraction dependencies from installer (`extract_topic.sh` copy step)

## [3.4.0]

For previous changes, refer to the [git history](https://github.com/alexismunoz1/claude-session-topics/commits/main).
