#!/bin/bash
# Diagnostic script for claude-session-topics
# Helps troubleshoot installation and runtime issues
# Usage: ./scripts/diagnose.sh [--verbose]

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || {
    # Fallback logging if library not available
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { :; }
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNINGS=0

# Check if a command exists
check_command() {
    local cmd="$1"
    local required="${2:-true}"
    
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$($cmd --version 2>&1 | head -n1) || version="unknown"
        echo -e "${GREEN}✓${NC} $cmd: $version"
        ((CHECKS_PASSED++))
        log_info "Found $cmd: $version"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $cmd: NOT FOUND (required)"
            ((CHECKS_FAILED++))
            log_error "Missing required command: $cmd"
        else
            echo -e "${YELLOW}⚠${NC} $cmd: NOT FOUND (optional)"
            ((CHECKS_WARNINGS++))
            log_warn "Missing optional command: $cmd"
        fi
        return 1
    fi
}

# Check if a file exists
check_file() {
    local file="$1"
    local desc="${2:-$file}"
    
    if [ -f "$file" ]; then
        local size
        size=$(du -h "$file" 2>/dev/null | cut -f1) || size="unknown"
        echo -e "${GREEN}✓${NC} $desc: $size"
        ((CHECKS_PASSED++))
        log_info "Found $desc ($size)"
        return 0
    else
        echo -e "${RED}✗${NC} $desc: NOT FOUND"
        ((CHECKS_FAILED++))
        log_error "Missing file: $file"
        return 1
    fi
}

# Check if a directory exists
check_dir() {
    local dir="$1"
    local desc="${2:-$dir}"
    
    if [ -d "$dir" ]; then
        local count
        count=$(find "$dir" -type f 2>/dev/null | wc -l) || count="unknown"
        echo -e "${GREEN}✓${NC} $desc: $count files"
        ((CHECKS_PASSED++))
        log_info "Found $desc ($count files)"
        return 0
    else
        echo -e "${RED}✗${NC} $desc: NOT FOUND"
        ((CHECKS_FAILED++))
        log_error "Missing directory: $dir"
        return 1
    fi
}

# Check Python module
check_python_module() {
    local module="$1"
    local required="${2:-true}"
    
    if python3 -c "import $module" 2>/dev/null; then
        local version
        version=$(python3 -c "import $module; print($module.__version__)" 2>/dev/null) || version="installed"
        echo -e "${GREEN}✓${NC} Python module $module: $version"
        ((CHECKS_PASSED++))
        log_info "Found Python module $module: $version"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} Python module $module: NOT FOUND (required)"
            ((CHECKS_FAILED++))
            log_error "Missing Python module: $module"
        else
            echo -e "${YELLOW}⚠${NC} Python module $module: NOT FOUND (optional)"
            ((CHECKS_WARNINGS++))
            log_warn "Missing optional Python module: $module"
        fi
        return 1
    fi
}

# Check JSON file validity
check_json() {
    local file="$1"
    local desc="${2:-$file}"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠${NC} $desc: does not exist (will be created)"
        ((CHECKS_WARNINGS++))
        log_warn "JSON file does not exist: $file"
        return 1
    fi
    
    if jq empty "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $desc: valid JSON"
        ((CHECKS_PASSED++))
        log_info "Valid JSON: $desc"
        return 0
    else
        echo -e "${RED}✗${NC} $desc: INVALID JSON"
        ((CHECKS_FAILED++))
        log_error "Invalid JSON: $file"
        return 1
    fi
}

# Main diagnostics
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Claude Session Topics - Diagnostics"
echo "═══════════════════════════════════════════════════════════"
echo ""

# System info
echo -e "${BLUE}System Information:${NC}"
echo "  Date: $(date)"
echo "  User: $(whoami)"
echo "  Home: $HOME"
echo "  Shell: $SHELL"
echo ""

# Required commands
echo -e "${BLUE}Required Commands:${NC}"
check_command "bash" true
check_command "jq" true
check_command "python3" true
check_command "ps" true
echo ""

# Optional commands
echo -e "${BLUE}Optional Commands:${NC}"
check_command "shellcheck" false
check_command "bats" false
echo ""

# Python modules
echo -e "${BLUE}Python Modules:${NC}"
check_python_module "yake" false
echo ""

# Installation files
echo -e "${BLUE}Installation Files:${NC}"
check_dir "$HOME/.claude/session-topics" "Topics directory"
check_file "$HOME/.claude/session-topics/statusline.sh" "Statusline script"
check_file "$HOME/.claude/session-topics/auto-topic-hook.sh" "Auto-topic hook"
check_file "$HOME/.claude/session-topics/extract_topic.py" "Topic extractor"
echo ""

# Skills
echo -e "${BLUE}Skills:${NC}"
check_dir "$HOME/.claude/skills/auto-topic" "auto-topic skill"
check_dir "$HOME/.claude/skills/set-topic" "set-topic skill"
echo ""

# Configuration
echo -e "${BLUE}Configuration:${NC}"
check_file "$HOME/.claude/settings.json" "Settings file"
check_json "$HOME/.claude/settings.json" "Settings JSON"
echo ""

# Session topics
echo -e "${BLUE}Session Topics:${NC}"
if [ -d "$HOME/.claude/session-topics" ]; then
    TOPIC_COUNT=$(find "$HOME/.claude/session-topics" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Active topics: $TOPIC_COUNT"
    log_info "Found $TOPIC_COUNT active topics"
    
    # Check for stale files
    STALE_COUNT=$(find "$HOME/.claude/session-topics" -maxdepth 1 -type f -mtime +7 ! -name '.*' 2>/dev/null | wc -l)
    if [ "$STALE_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Stale topic files (>7 days): $STALE_COUNT"
        ((CHECKS_WARNINGS++))
        log_warn "Found $STALE_COUNT stale topic files"
    fi
else
    echo -e "${RED}✗${NC} Topics directory not found"
    ((CHECKS_FAILED++))
fi
echo ""

# Log file
echo -e "${BLUE}Log File:${NC}"
if [ -f "$HOME/.claude/session-topics/debug.log" ]; then
    LOG_SIZE=$(du -h "$HOME/.claude/session-topics/debug.log" 2>/dev/null | cut -f1)
    LOG_LINES=$(wc -l < "$HOME/.claude/session-topics/debug.log" 2>/dev/null)
    echo -e "${GREEN}✓${NC} Debug log: $LOG_SIZE ($LOG_LINES lines)"
    log_info "Debug log exists: $LOG_SIZE"
else
    echo -e "${YELLOW}⚠${NC} Debug log: not created yet (normal)"
    log_info "Debug log not yet created"
fi
echo ""

# Test extraction
echo -e "${BLUE}Testing Topic Extraction:${NC}"
TEST_TRANSCRIPT=$(mktemp)
cat > "$TEST_TRANSCRIPT" << 'EOF'
{"role": "user", "content": "Test message for diagnostics"}
EOF

if [ -f "$HOME/.claude/session-topics/extract_topic.py" ]; then
    TOPIC_RESULT=$(python3 "$HOME/.claude/session-topics/extract_topic.py" "$TEST_TRANSCRIPT" 2>&1) || TOPIC_RESULT="ERROR"
    if [ -n "$TOPIC_RESULT" ] && [ "$TOPIC_RESULT" != "ERROR" ]; then
        echo -e "${GREEN}✓${NC} Topic extraction: working (result: '$TOPIC_RESULT')"
        ((CHECKS_PASSED++))
        log_info "Topic extraction working"
    else
        echo -e "${YELLOW}⚠${NC} Topic extraction: returned empty (may need dependencies)"
        ((CHECKS_WARNINGS++))
        log_warn "Topic extraction returned empty"
    fi
else
    echo -e "${RED}✗${NC} Topic extraction: script not found"
    ((CHECKS_FAILED++))
    log_error "Topic extractor not found"
fi
rm -f "$TEST_TRANSCRIPT"
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed: $CHECKS_PASSED${NC}"
echo -e "  ${YELLOW}Warnings: $CHECKS_WARNINGS${NC}"
echo -e "  ${RED}Failed: $CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "If you're still experiencing issues:"
    echo "  1. Check the debug log: ~/.claude/session-topics/debug.log"
    echo "  2. Re-run with verbose mode: CLAUDE_SESSION_TOPICS_VERBOSE=1"
    echo "  3. Reinstall: npx @alexismunozdev/claude-session-topics"
    exit 0
else
    echo -e "${RED}✗ Some critical checks failed.${NC}"
    echo ""
    echo "To fix:"
    
    if ! command -v jq &> /dev/null; then
        echo "  • Install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    fi
    
    if ! command -v python3 &> /dev/null; then
        echo "  • Install Python 3"
    fi
    
    if [ ! -d "$HOME/.claude/session-topics" ]; then
        echo "  • Run the installer: npx @alexismunozdev/claude-session-topics"
    fi
    
    echo ""
    echo "For more help:"
    echo "  • Debug log: ~/.claude/session-topics/debug.log"
    exit 1
fi