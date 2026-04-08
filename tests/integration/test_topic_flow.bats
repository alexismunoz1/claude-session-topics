#!/usr/bin/env bats

load helper

@test "test_hook_writes_session_markers" {
  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "/nonexistent"}'

  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]
  [ -f "$TOPICS_DIR/.active-session-id-$TEST_SESSION_ID" ]
}

@test "test_hook_reads_custom_title_from_transcript" {
  # Create a transcript with a custom-title entry
  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "user", "message": {"content": "Fix the login"}}' > "$tmpfile"
  echo '{"type": "assistant", "message": {"content": "Sure"}}' >> "$tmpfile"
  echo '{"type": "custom-title", "customTitle": "fix-login-redirect-bug", "sessionId": "'$TEST_SESSION_ID'"}' >> "$tmpfile"

  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]
  [ -f "$TOPICS_DIR/$TEST_SESSION_ID" ]

  local topic_content
  topic_content=$(cat "$TOPICS_DIR/$TEST_SESSION_ID")
  [[ "$topic_content" == "Fix Login Redirect Bug" ]]
}

@test "test_hook_uses_latest_custom_title" {
  # Transcript with multiple custom-title entries (title gets updated)
  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "custom-title", "customTitle": "initial-topic", "sessionId": "'$TEST_SESSION_ID'"}' > "$tmpfile"
  echo '{"type": "user", "message": {"content": "Actually, fix the auth"}}' >> "$tmpfile"
  echo '{"type": "custom-title", "customTitle": "fix-auth-token-refresh", "sessionId": "'$TEST_SESSION_ID'"}' >> "$tmpfile"

  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]

  local topic_content
  topic_content=$(cat "$TOPICS_DIR/$TEST_SESSION_ID")
  [[ "$topic_content" == "Fix Auth Token Refresh" ]]
}

@test "test_hook_no_topic_without_custom_title" {
  # Transcript without custom-title — no topic should be written
  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "user", "message": {"content": "Hello"}}' > "$tmpfile"
  echo '{"type": "assistant", "message": {"content": "Hi"}}' >> "$tmpfile"

  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]
  [ ! -f "$TOPICS_DIR/$TEST_SESSION_ID" ]
}

@test "test_hook_preserves_existing_topic" {
  # If topic already exists (set by skill), hook should not overwrite it
  echo "Skill Generated Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"

  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "custom-title", "customTitle": "different-hook-title", "sessionId": "'$TEST_SESSION_ID'"}' > "$tmpfile"

  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]

  local topic_content
  topic_content=$(cat "$TOPICS_DIR/$TEST_SESSION_ID")
  [[ "$topic_content" == "Skill Generated Topic" ]]
}

@test "test_hook_truncates_long_titles" {
  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "custom-title", "customTitle": "this-is-a-very-long-title-that-should-be-truncated-to-fifty-characters-maximum", "sessionId": "'$TEST_SESSION_ID'"}' > "$tmpfile"

  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]

  local topic_content
  topic_content=$(cat "$TOPICS_DIR/$TEST_SESSION_ID")
  [ ${#topic_content} -le 50 ]
}

@test "test_statusline_reads_topic" {
  echo "Test Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"

  local statusline_input='{"session_id": "'$TEST_SESSION_ID'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"◆ Test Topic"* ]]
}

@test "test_statusline_reads_custom_title_fallback" {
  # No topic file exists, but transcript has custom-title
  local tmpfile="$BATS_TEST_TMPDIR/transcript.jsonl"
  echo '{"type": "custom-title", "customTitle": "add-search-filter", "sessionId": "'$TEST_SESSION_ID'"}' > "$tmpfile"

  local statusline_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$tmpfile'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Add Search Filter"* ]]
}

@test "test_statusline_with_color" {
  echo "Colored Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"
  echo "cyan" > "$TOPICS_DIR/.color-config"

  local statusline_input='{"session_id": "'$TEST_SESSION_ID'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[36m'* ]] || [[ "$output" == *"[36m"* ]]
  [[ "$output" == *"◆ Colored Topic"* ]]
}

@test "test_hook_no_session_id_exits_cleanly" {
  local hook_input='{"session_id": "", "transcript_path": "/nonexistent"}'

  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"

  [ "$status" -eq 0 ]
}

@test "test_pid_detection" {
  local test_script="$TEST_DIR/test_pid.sh"
  cat > "$test_script" << 'EOF'
find_claude_pid() {
  local pid=$$
  while [ "$pid" != "1" ] && [ -n "$pid" ]; do
    local parent
    parent=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$parent" ] && break
    local comm
    comm=$(ps -o comm= -p "$parent" 2>/dev/null)
    case "$comm" in
      *claude*|*Claude*) echo "$parent"; return 0 ;;
    esac
    pid=$parent
  done
  echo ""
}
result=$(find_claude_pid)
exit 0
EOF

  run bash "$test_script"
  [ "$status" -eq 0 ]
}
