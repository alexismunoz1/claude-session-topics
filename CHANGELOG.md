# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
