: ${BATS_TEST_FILENAME:?BATS_TEST_FILENAME not set}

# Helper functions for Bats integration tests

# Setup function called before each test
setup() {
  export TEST_SESSION_ID="test-session-$$-$RANDOM"
  export TEST_DIR="$BATS_TEST_TMPDIR"
  export TOPICS_DIR="$HOME/.claude/session-topics"
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  
  # Ensure topics directory exists
  mkdir -p "$TOPICS_DIR"
  
  # Clean up any leftover test files from previous runs
  rm -f "$TOPICS_DIR/test-session-"*
}

# Teardown function called after each test
teardown() {
  # Clean up test files
  rm -f "$TOPICS_DIR/${TEST_SESSION_ID}" 2>/dev/null || true
  rm -f "$TOPICS_DIR/.active-session-"* 2>/dev/null || true
  rm -f "$TOPICS_DIR/.color-config" 2>/dev/null || true
}

# Helper: Create a topic file for testing
create_topic_file() {
  local session_id="${1:-$TEST_SESSION_ID}"
  local topic="${2:-Test Topic}"
  echo "$topic" > "$TOPICS_DIR/${session_id}"
}

# Helper: Remove a topic file
remove_topic_file() {
  local session_id="${1:-$TEST_SESSION_ID}"
  rm -f "$TOPICS_DIR/${session_id}"
}

# Helper: Check if output contains string (case insensitive)
output_contains() {
  [[ "$output" == *"$1"* ]]
}

# Helper: Check if output matches pattern
output_matches() {
  [[ "$output" =~ $1 ]]
}
