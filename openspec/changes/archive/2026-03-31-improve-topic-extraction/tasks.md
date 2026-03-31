# Tasks: Improve Topic Extraction with YAKE

## Phase 1: Infrastructure

- [ ] 1.1 Add `yake` dependency to `requirements.txt` or install command
- [ ] 1.2 Verify YAKE installation and basic functionality

## Phase 2: Core Implementation

- [ ] 2.1 Import yake in `scripts/extract_topic.py`
- [ ] 2.2 Implement preprocessing function (preserve markdown/URL cleaning)
- [ ] 2.3 Implement YAKE extraction with params: n-gram 1-3, top 5 keywords
- [ ] 2.4 Implement post-processing: select candidates for 2-4 word topics
- [ ] 2.5 Add validation: ensure output is non-empty and coherent
- [ ] 2.6 Add fallback to heuristics if YAKE returns no valid results
- [ ] 2.7 Preserve final capitalization formatting

## Phase 3: Testing

- [ ] 3.1 Update `scripts/test_extract_topic.py` with YAKE-based test cases
- [ ] 3.2 Add semantic coherence tests (e.g., reject "Image Entra Screen Club")
- [ ] 3.3 Verify all tests pass including edge cases

## Phase 4: Integration & Verification

- [ ] 4.1 Test script maintains stdin/stdout interface compatibility
- [ ] 4.2 Run end-to-end test with real session messages
- [ ] 4.3 Verify bash scripts work without modifications
- [ ] 4.4 Benchmark extraction time (target: <500ms per message)

## Phase 5: Documentation

- [ ] 5.1 Update comments in `scripts/extract_topic.py` explaining YAKE integration
- [ ] 5.2 Document dependency in README if not already present

## Dependencies

- Refactorización (Phase 2) → Testing (Phase 3)
- Testing (Phase 3) → Integration (Phase 4)

## Priority

High: Infrastructure + Core Implementation + Testing
Medium: Integration + Documentation
