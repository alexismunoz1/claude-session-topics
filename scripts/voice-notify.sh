#!/bin/bash

TOPIC="${1:-}"
DETECTED_LANG="${2:-}"
[[ -z "$TOPIC" ]] && exit 0

CONFIG_FILE="${HOME}/.claude/session-topics/.voice-config"
[[ ! -f "$CONFIG_FILE" ]] && exit 0

VOICE_ENABLED=0
VOICE_LANG="en"
VOICE_NAME=""
VOICE_TEMPLATE=""
VOICE_AUTO_LANG=1
VOICE_MUTED=0

# shellcheck source=/dev/null
source "$CONFIG_FILE"

[[ "$VOICE_ENABLED" != "1" ]] && exit 0
[[ "$VOICE_MUTED" == "1" ]] && exit 0

# Determine effective language
if [ "${VOICE_AUTO_LANG:-1}" = "1" ] && [ -n "$DETECTED_LANG" ]; then
    EFFECTIVE_LANG="$DETECTED_LANG"
else
    EFFECTIVE_LANG="${VOICE_LANG:-en}"
fi

# Build message: explicit template overrides, otherwise auto-select by language
if [ -n "$VOICE_TEMPLATE" ]; then
    MESSAGE="${VOICE_TEMPLATE//\{topic\}/$TOPIC}"
else
    case "$EFFECTIVE_LANG" in
        es*) MESSAGE="Tarea terminada: $TOPIC" ;;
        *)   MESSAGE="Done: $TOPIC" ;;
    esac
fi

speak_macos() {
  local voice_flag=""
  if [[ -n "$VOICE_NAME" ]]; then
    voice_flag="-v $VOICE_NAME"
  else
    case "$EFFECTIVE_LANG" in
      es*) voice_flag="-v Mónica" ;;
      *)   voice_flag="" ;;
    esac
  fi
  if [[ -n "$voice_flag" ]]; then
    # shellcheck disable=SC2086
    say $voice_flag "$MESSAGE" &
  else
    say "$MESSAGE" &
  fi
}

speak_linux() {
  if command -v espeak &>/dev/null; then
    espeak -v "$EFFECTIVE_LANG" "$MESSAGE" &
  elif command -v espeak-ng &>/dev/null; then
    espeak-ng -v "$EFFECTIVE_LANG" "$MESSAGE" &
  elif command -v spd-say &>/dev/null; then
    spd-say "$MESSAGE" &
  fi
}

speak_windows() {
  powershell.exe -Command "
    Add-Type -AssemblyName System.Speech;
    \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;
    \$s.Speak('$MESSAGE')
  " &
}

case "$(uname -s)" in
  Darwin)  speak_macos   ;;
  Linux)   speak_linux   ;;
  MINGW*|MSYS*|CYGWIN*) speak_windows ;;
esac

exit 0
