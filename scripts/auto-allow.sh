#!/bin/bash
# Auto-approve Bash commands containing "session-topics" (PermissionRequest hook)
# Writes the allow rule to userSettings so future requests skip the prompt

input=$(cat)
CMD=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$CMD" | grep -q 'session-topics'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "permissionDecision": "allow",
    "updatedPermissions": [
      {
        "type": "addRules",
        "rules": [{"toolName": "Bash", "ruleContent": "*session-topics*"}],
        "behavior": "allow",
        "destination": "userSettings"
      }
    ]
  }
}
EOF
fi
