#!/bin/bash
# Validation library for shell commands
# Usage: source scripts/lib/validate-cmd.sh
#        validate_cmd "$command" || echo "Invalid command"

# Validates a command string for safe execution
# Returns 0 if valid, 1 if invalid
validate_cmd() {
    local cmd="$1"
    
    # Reject empty commands
    if [ -z "$cmd" ]; then
        return 1
    fi
    
    # Reject command substitution: $(...) or `...`
    if echo "$cmd" | grep -qF '$(' ; then return 1; fi
    if echo "$cmd" | grep -qF '\`' ; then return 1; fi
    
    # Reject chaining: ; && ||
    if echo "$cmd" | grep -q '[;&|]' ; then return 1; fi
    
    # Reject process substitution: <( ) or >( )
    if echo "$cmd" | grep -qE '>\\(' ; then return 1; fi
    if echo "$cmd" | grep -qE '<\\(' ; then return 1; fi
    
    # Reject /dev/tcp|udp redirection
    if echo "$cmd" | grep -qE '/dev/(tcp|udp)' ; then return 1; fi
    
    # Reject path traversal
    if echo "$cmd" | grep -qF '..' ; then return 1; fi
    
    # Reject tilde expansion (potential injection)
    if echo "$cmd" | grep -q '~' ; then return 1; fi
    
    # Must start with an allowed command pattern:
    # - bash <path>
    # - /absolute/path
    # - command (no arguments with special chars)
    if ! echo "$cmd" | grep -qE '^(bash[[:space:]]+|/[a-zA-Z0-9._/-]+|[a-zA-Z0-9_-]+)$' ; then
        return 1
    fi
    
    return 0
}

# Export for use in other scripts
export -f validate_cmd
