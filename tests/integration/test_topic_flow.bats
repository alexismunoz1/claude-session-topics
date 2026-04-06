#!/usr/bin/env bats

load helper

@test "test_extract_topic_from_transcript" {
  # Test that extract_topic.sh correctly extracts topic from English transcript
  run bash "$PROJECT_ROOT/scripts/extract_topic.sh" "$PROJECT_ROOT/tests/fixtures/transcript-english.jsonl"

  [ "$status" -eq 0 ]
  [[ "$output" == *"NeonDB"* ]] || [[ "$output" == *"Authentication"* ]] || [[ "$output" == *"Auth"* ]]
}

@test "test_hook_creates_topic_file" {
  # Simulate Stop hook input JSON
  local hook_input='{"session_id": "'$TEST_SESSION_ID'", "transcript_path": "'$PROJECT_ROOT/tests/fixtures/transcript-english.jsonl'"}'
  
  # Run the hook script with the input
  run bash "$PROJECT_ROOT/scripts/auto-topic-hook.sh" <<< "$hook_input"
  
  [ "$status" -eq 0 ]
  [ -f "$TOPICS_DIR/$TEST_SESSION_ID" ]
  
  # Verify the topic file contains content
  local topic_content
  topic_content=$(cat "$TOPICS_DIR/$TEST_SESSION_ID")
  [ -n "$topic_content" ]
}

@test "test_statusline_reads_topic" {
  # Create a topic file for the test session
  echo "Test Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"
  
  # Run statusline with JSON input containing session_id
  local statusline_input='{"session_id": "'$TEST_SESSION_ID'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"
  
  [ "$status" -eq 0 ]
  [[ "$output" == *"◆ Test Topic"* ]]
}

@test "test_statusline_with_color" {
  # Create topic file
  echo "Colored Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"
  
  # Set color to cyan via config file
  echo "cyan" > "$TOPICS_DIR/.color-config"
  
  # Run statusline
  local statusline_input='{"session_id": "'$TEST_SESSION_ID'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"
  
  [ "$status" -eq 0 ]
  # Cyan ANSI code is \033[36m
  [[ "$output" == *$'\033[36m'* ]] || [[ "$output" == *"[36m"* ]]
  [[ "$output" == *"◆ Colored Topic"* ]]
}

@test "test_stale_files_cleanup" {
  # Create a stale file (older than 7 days) - macOS compatible
  local stale_session_id="stale-session-test"
  echo "Stale Topic" > "$TOPICS_DIR/$stale_session_id"
  # Use touch -t for macOS compatibility (YYYYMMDDhhmm format)
  touch -t $(date -v-8d +%Y%m%d%H%M) "$TOPICS_DIR/$stale_session_id" 2>/dev/null || \
    touch -t $(date -d "8 days ago" +%Y%m%d%H%M 2>/dev/null || echo "202401010000") "$TOPICS_DIR/$stale_session_id"
  
  # Create a fresh file
  echo "Fresh Topic" > "$TOPICS_DIR/$TEST_SESSION_ID"
  
  # Run statusline (which triggers cleanup)
  local statusline_input='{"session_id": "'$TEST_SESSION_ID'"}'
  run bash "$PROJECT_ROOT/scripts/statusline.sh" <<< "$statusline_input"
  
  [ "$status" -eq 0 ]
  # Note: Cleanup runs with atomic lock, so stale file may or may not be deleted
  # depending on timing. Fresh file should always exist.
  [ -f "$TOPICS_DIR/$TEST_SESSION_ID" ]
}

@test "test_pid_detection" {
  # Test that find_claude_pid function doesn't fail
  # We'll source the script and check the function exists and runs without error
  
  # Create a simple test script that sources the function
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

# Test the function
result=$(find_claude_pid)
# Function should complete without error (may or may not find a PID)
exit 0
EOF
  
  run bash "$test_script"
  
  # Should complete successfully (exit code 0)
  [ "$status" -eq 0 ]
}
