#!/bin/bash
# Test runner for claude-session-topics
# Runs all test suites: Shell integration and linting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0
PASSED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════════════"
echo "  Claude Session Topics - Test Suite"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Function to run tests and track results
run_test_suite() {
    local name="$1"
    local cmd="$2"
    
    echo "📦 Running: $name"
    echo "────────────────────────────────────────────────────────────"
    
    if eval "$cmd"; then
        echo -e "${GREEN}✓ $name PASSED${NC}"
        ((PASSED++)) || true
    else
        echo -e "${RED}✗ $name FAILED${NC}"
        ((FAILED++)) || true
    fi
    echo ""
}

# 1. Bats integration tests
if [ -f "$SCRIPT_DIR/tests/bats/bin/bats" ] && [ -d "$SCRIPT_DIR/tests/integration" ]; then
    run_test_suite "Shell Integration Tests (Bats)" \
        "cd '$SCRIPT_DIR' && ./tests/bats/bin/bats tests/integration/"
elif command -v bats &> /dev/null && [ -d "$SCRIPT_DIR/tests/integration" ]; then
    run_test_suite "Shell Integration Tests (system Bats)" \
        "cd '$SCRIPT_DIR' && bats tests/integration/"
fi

# 3. Shellcheck (if available)
if command -v shellcheck &> /dev/null; then
    run_test_suite "Shellcheck (static analysis)" \
        "cd '$SCRIPT_DIR' && shellcheck scripts/*.sh --severity=warning"
else
    echo -e "${YELLOW}⚠ Shellcheck not installed, skipping static analysis${NC}"
    echo "   Install: brew install shellcheck (macOS)"
    echo "            apt-get install shellcheck (Ubuntu/Debian)"
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  Test Summary"
echo "═══════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAILED${NC}"
fi
echo "═══════════════════════════════════════════════════════════"

# Exit with failure count
exit $FAILED
