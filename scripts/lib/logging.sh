#!/bin/bash
# Logging library for claude-session-topics
# Usage: source scripts/lib/logging.sh
#        log_info "Message"
#        log_error "Message" 2
#
# Log levels: DEBUG=0, INFO=1, WARN=2, ERROR=3
# Control via CLAUDE_SESSION_TOPICS_LOG_LEVEL (default: INFO)
# Output to: ~/.claude/session-topics/debug.log (if DEBUG enabled)

# Initialize logging
_init_logging() {
    # Default log level: INFO (1)
    : "${CLAUDE_SESSION_TOPICS_LOG_LEVEL:=1}"
    
    # Log file location
    LOG_FILE="${HOME}/.claude/session-topics/debug.log"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log levels as numeric values for comparison
    readonly LOG_LEVEL_DEBUG=0
    readonly LOG_LEVEL_INFO=1
    readonly LOG_LEVEL_WARN=2
    readonly LOG_LEVEL_ERROR=3
}

# Internal: Write to log file
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Internal: Check if level should be logged
_should_log() {
    local level="$1"
    [ "$level" -ge "$CLAUDE_SESSION_TOPICS_LOG_LEVEL" ]
}

# Log debug message (level 0)
log_debug() {
    if _should_log "$LOG_LEVEL_DEBUG"; then
        local message="$1"
        _log_to_file "DEBUG" "$message"
        # Only print to stderr if verbose mode enabled
        if [ "${CLAUDE_SESSION_TOPICS_VERBOSE:-}" = "1" ]; then
            echo "[DEBUG] $message" >&2
        fi
    fi
}

# Log info message (level 1)
log_info() {
    if _should_log "$LOG_LEVEL_INFO"; then
        local message="$1"
        _log_to_file "INFO" "$message"
    fi
}

# Log warning message (level 2)
log_warn() {
    if _should_log "$LOG_LEVEL_WARN"; then
        local message="$1"
        _log_to_file "WARN" "$message"
        echo "[WARN] $message" >&2
    fi
}

# Log error message (level 3)
log_error() {
    if _should_log "$LOG_LEVEL_ERROR"; then
        local message="$1"
        local exit_code="${2:-}"
        _log_to_file "ERROR" "$message"
        echo "[ERROR] $message" >&2
        if [ -n "$exit_code" ]; then
            exit "$exit_code"
        fi
    fi
}

# Log command execution with error handling
# Usage: log_exec "description" command [args...]
log_exec() {
    local desc="$1"
    shift
    
    log_debug "Executing: $desc"
    log_debug "Command: $*"
    
    if "$@"; then
        log_debug "Success: $desc"
        return 0
    else
        local exit_code=$?
        log_error "Failed ($exit_code): $desc"
        return $exit_code
    fi
}

# Log with fallback: try command, log error but don't fail
# Usage: log_try "description" command [args...]
log_try() {
    local desc="$1"
    shift
    
    log_debug "Trying: $desc"
    
    if "$@" 2>/dev/null; then
        log_debug "Success: $desc"
        return 0
    else
        local exit_code=$?
        log_warn "Failed ($exit_code): $desc"
        return $exit_code
    fi
}

# Initialize on source
_init_logging

# Export functions for use in other scripts
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_exec
export -f log_try
