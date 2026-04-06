#!/usr/bin/env bats

load helper

VOICE_SCRIPT=""
ORIG_HOME=""
MOCK_BIN=""
MOCK_LOG=""

setup() {
  export TEST_SESSION_ID="test-session-$$-$RANDOM"
  export TEST_DIR="$BATS_TEST_TMPDIR"
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  VOICE_SCRIPT="$PROJECT_ROOT/scripts/voice-notify.sh"

  # Isolate HOME so .voice-config is sandboxed
  ORIG_HOME="$HOME"
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME/.claude/session-topics"

  # Mock bin directory for stub TTS commands
  MOCK_BIN="$BATS_TEST_TMPDIR/mockbin"
  MOCK_LOG="$BATS_TEST_TMPDIR/mock_tts.log"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  export HOME="$ORIG_HOME"
}

# Helper: write a .voice-config file
write_voice_config() {
  cat > "$HOME/.claude/session-topics/.voice-config" <<EOF
$1
EOF
}

# Helper: create a mock TTS command that logs its arguments
create_tts_mock() {
  local cmd_name="$1"
  cat > "$MOCK_BIN/$cmd_name" <<EOF
#!/bin/bash
echo "$cmd_name \$*" >> "$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/$cmd_name"
}

@test "exits 0 with no arguments" {
  run bash "$VOICE_SCRIPT"

  [ "$status" -eq 0 ]
}

@test "exits 0 when config file missing" {
  # Ensure no config file exists
  rm -f "$HOME/.claude/session-topics/.voice-config"

  run bash "$VOICE_SCRIPT" "some topic"

  [ "$status" -eq 0 ]
}

@test "exits 0 when VOICE_ENABLED=0" {
  write_voice_config 'VOICE_ENABLED=0'

  run bash "$VOICE_SCRIPT" "some topic"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 when VOICE_MUTED=1" {
  write_voice_config 'VOICE_ENABLED=1
VOICE_MUTED=1'

  run bash "$VOICE_SCRIPT" "some topic"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "template substitution works" {
  create_tts_mock "say"

  write_voice_config 'VOICE_ENABLED=1
VOICE_MUTED=0
VOICE_TEMPLATE="Session about {topic} finished"'

  run bash "$VOICE_SCRIPT" "Database Migration"

  [ "$status" -eq 0 ]
  # Wait briefly for backgrounded command to write log
  sleep 0.2
  [ -f "$MOCK_LOG" ]
  run cat "$MOCK_LOG"
  [[ "$output" == *"Session about Database Migration finished"* ]]
}

@test "detects macOS say command" {
  create_tts_mock "say"

  write_voice_config 'VOICE_ENABLED=1
VOICE_MUTED=0'

  run bash "$VOICE_SCRIPT" "Test Topic"

  [ "$status" -eq 0 ]
  sleep 0.2

  # On macOS (Darwin), the script should call say
  if [[ "$(uname -s)" == "Darwin" ]]; then
    [ -f "$MOCK_LOG" ]
    run cat "$MOCK_LOG"
    [[ "$output" == *"say"* ]]
    [[ "$output" == *"Test Topic"* ]]
  else
    skip "macOS-only test"
  fi
}

@test "uses detected language from second argument" {
  create_tts_mock "say"

  write_voice_config 'VOICE_ENABLED=1
VOICE_AUTO_LANG=1
VOICE_TEMPLATE='

  run bash "$VOICE_SCRIPT" "Deploy Config" "es"

  [ "$status" -eq 0 ]
  sleep 0.2
  [ -f "$MOCK_LOG" ]
  run cat "$MOCK_LOG"
  [[ "$output" == *"Tarea terminada"* ]]
}

@test "falls back to VOICE_LANG when auto-detect disabled" {
  create_tts_mock "say"

  write_voice_config 'VOICE_ENABLED=1
VOICE_AUTO_LANG=0
VOICE_LANG=en
VOICE_TEMPLATE='

  run bash "$VOICE_SCRIPT" "Deploy Config" "es"

  [ "$status" -eq 0 ]
  sleep 0.2
  [ -f "$MOCK_LOG" ]
  run cat "$MOCK_LOG"
  [[ "$output" == *"Done"* ]]
}

@test "uses custom VOICE_TEMPLATE over auto-detection" {
  create_tts_mock "say"

  write_voice_config 'VOICE_ENABLED=1
VOICE_AUTO_LANG=1
VOICE_TEMPLATE="Finished: {topic}"'

  run bash "$VOICE_SCRIPT" "My Task" "es"

  [ "$status" -eq 0 ]
  sleep 0.2
  [ -f "$MOCK_LOG" ]
  run cat "$MOCK_LOG"
  [[ "$output" == *"Finished: My Task"* ]]
}
