# Proposal: Improve Topic Extraction with YAKE

## Intent

Solve the generation of incoherent topic titles (e.g., "Image Entra Screen Club") from user messages by replacing the current heuristic approach with the YAKE keyword extraction library. This will improve semantic coherence while maintaining performance.

## Scope

### In Scope
- Integrate YAKE keyword extraction library
- Refactor `scripts/extract_topic.py` to use YAKE as the core engine
- Maintain the existing 2-4 word limit for topic length
- Preserve existing markdown and URL cleaning preprocessing
- Update `scripts/test_extract_topic.py` with new test cases for coherence validation

### Out of Scope
- Do not use LLM-based extraction (YAKE is sufficient)
- Do not change the script's public API interface
- Do not modify existing hooks or skills infrastructure

## Approach

Replace the current heuristic-based keyword extraction with YAKE, followed by light post-processing to enforce the 2-4 word limit and ensure coherence. YAKE will analyze the message and return ranked keywords, from which we'll select the most appropriate combination.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `scripts/extract_topic.py` | Modified | Replace extraction logic with YAKE integration |
| `scripts/test_extract_topic.py` | Modified | Add coherence test cases and update expectations |
| `package.json` | Modified | Add YAKE dependency |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| YAKE performance slower than current approach | Low | Benchmark extraction time; YAKE is designed for speed |
| YAKE installation issues | Low | Test in CI/CD pipeline before merging |
| Topic length enforcement conflicts with YAKE output | Medium | Implement post-processing to enforce 2-4 word limit |

## Rollback Plan

1. Revert changes to `scripts/extract_topic.py` using git
2. Remove YAKE dependency from `package.json`
3. Restore original test file from git history

## Dependencies

- `yake` library (Python)

## Success Criteria

- [ ] All existing and new tests pass, including coherence validation tests
- [ ] Generated topics are semantically coherent (human-evaluated)
- [ ] Extraction time remains under 500ms per message
- [ ] No changes to the script's external API
