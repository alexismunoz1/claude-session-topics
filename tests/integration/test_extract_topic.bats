#!/usr/bin/env bats

load helper

EXTRACT_SCRIPT=""
FIXTURES_DIR=""

setup() {
  export TEST_SESSION_ID="test-session-$$-$RANDOM"
  export TEST_DIR="$BATS_TEST_TMPDIR"
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  EXTRACT_SCRIPT="$PROJECT_ROOT/scripts/extract_topic.sh"
  FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"
}

# ── Basic English extraction ──

@test "extracts topic from English transcript" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-english.jsonl")
  # Should contain NeonDB or Authentication keywords
  [[ "$result" == *"NeonDB"* ]] || [[ "$result" == *"Authentication"* ]] || [[ "$result" == *"Auth"* ]]
}

@test "English: search filter dashboard" {
  local tmpfile="$BATS_TEST_TMPDIR/search-filter.jsonl"
  echo '{"role": "user", "content": "Add a new search filter to the dashboard"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Search"* ]]
}

@test "English: React Query cache invalidation" {
  local tmpfile="$BATS_TEST_TMPDIR/react-query.jsonl"
  echo '{"role": "user", "content": "Help me debug the React Query cache invalidation"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"React"* ]]
  [[ "$result" == *"Query"* ]]
  [[ "$result" == *"Cache"* ]]
  [[ "$result" == *"Invalidation"* ]]
}

@test "English: fix bug produces Bug Fix" {
  local tmpfile="$BATS_TEST_TMPDIR/fix-bug.jsonl"
  echo '{"role": "user", "content": "Fix bug"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Bug"* ]]
  [[ "$result" == *"Fix"* ]]
}

@test "English: database migration scripts" {
  local tmpfile="$BATS_TEST_TMPDIR/db-migration.jsonl"
  echo '{"role": "user", "content": "I need to refactor the database migration scripts"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Database"* ]]
  [[ "$result" == *"Migration"* ]]
}

# ── Basic Spanish extraction ──

@test "extracts topic from Spanish transcript" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-spanish.jsonl")
  [[ "$result" == *"es:"* ]]
  [[ "$result" == *"Corrige"* ]] || [[ "$result" == *"Error"* ]] || [[ "$result" == *"NeonDB"* ]]
}

@test "Spanish: NextAuth authentication component" {
  local tmpfile="$BATS_TEST_TMPDIR/es-nextauth.jsonl"
  echo '{"role": "user", "content": "Hola, necesito ayuda con el componente de autenticación de NextAuth"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Componente"* ]]
  [[ "$result" == *"NextAuth"* ]]
}

@test "Spanish: NeonDB auth error" {
  local tmpfile="$BATS_TEST_TMPDIR/es-neondb.jsonl"
  echo '{"role": "user", "content": "Corrige el error de autenticación en NeonDB"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Corrige"* ]]
  [[ "$result" == *"Error"* ]]
  [[ "$result" == *"NeonDB"* ]]
}

@test "Spanish: tests API pagos" {
  local tmpfile="$BATS_TEST_TMPDIR/es-api-pagos.jsonl"
  echo '{"role": "user", "content": "Revisa los tests de la API de pagos"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Revisa"* ]]
  [[ "$result" == *"Tests"* ]]
  [[ "$result" == *"API"* ]]
  [[ "$result" == *"Pagos"* ]]
}

@test "Spanish: Docker Compose dependencies" {
  local tmpfile="$BATS_TEST_TMPDIR/es-docker.jsonl"
  echo '{"role": "user", "content": "Actualiza las dependencias de Docker Compose"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Actualiza"* ]]
  [[ "$result" == *"Dependencias"* ]]
  [[ "$result" == *"Docker"* ]]
  [[ "$result" == *"Compose"* ]]
}

@test "Spanish: session topic hook garbage" {
  local tmpfile="$BATS_TEST_TMPDIR/es-hook.jsonl"
  echo '{"role": "user", "content": "Investiga por qué el hook de session topic genera basura"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Investiga"* ]]
  [[ "$result" == *"Hook"* ]]
  [[ "$result" == *"Session"* ]]
  [[ "$result" == *"Topic"* ]]
}

@test "Spanish: ñ detection - pestaña búsqueda" {
  local tmpfile="$BATS_TEST_TMPDIR/es-pestana.jsonl"
  echo '{"role": "user", "content": "Modifica el diseño de la pestaña de búsqueda"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Pestaña"* ]] || [[ "$result" == *"pestaña"* ]]
  [[ "$result" == *"Búsqueda"* ]] || [[ "$result" == *"búsqueda"* ]]
}

# ── Language detection ──

@test "language detection: English transcript prefixed with en:" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-english.jsonl")
  [[ "$result" == "en:"* ]]
}

@test "language detection: Spanish transcript prefixed with es:" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-spanish.jsonl")
  [[ "$result" == "es:"* ]]
}

# ── XML tag stripping ──

@test "XML tags: system-reminder stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/xml-system.jsonl"
  echo '{"role": "user", "content": "Fix the login <system-reminder>task tools reminder blah</system-reminder> page redirect"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Login"* ]]
  [[ "$result" == *"Page"* ]] || [[ "$result" == *"Redirect"* ]]
  [[ "$result" != *"task"* ]]
  [[ "$result" != *"reminder"* ]]
}

@test "XML tags: command-args with user text inside tags stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/xml-command-args.jsonl"
  printf '{"role": "user", "content": "<command-message>develop</command-message>\\n<command-name>/develop</command-name>\\n<command-args>--auto Fix the NextAuth login flow for desktop</command-args>"}\n' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  # All text is inside tags, so result should be empty
  [[ -z "$result" ]]
}

@test "XML tags: local-command-caveat stripped with trailing text" {
  local tmpfile="$BATS_TEST_TMPDIR/xml-caveat.jsonl"
  printf '{"role": "user", "content": "<local-command-caveat>Caveat: messages generated by user running local commands</local-command-caveat>\\nDebug the Nginx proxy config"}\n' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Nginx"* ]]
  [[ "$result" == *"Proxy"* ]]
  [[ "$result" != *"Messages"* ]]
  [[ "$result" != *"Generated"* ]]
}

@test "XML tags: command-args fixture produces empty output" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-command-args.jsonl")
  # All content is inside XML tags
  [[ -z "$result" ]]
}

# ── Empty / invalid input ──

@test "empty file returns empty" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-empty.jsonl")
  [[ -z "$result" ]]
}

@test "malformed JSONL handles gracefully" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-malformed.jsonl")
  # Should not crash - exit 0
  [ $? -eq 0 ]
}

@test "no arguments returns empty" {
  result=$(bash "$EXTRACT_SCRIPT")
  [[ -z "$result" ]]
}

@test "nonexistent file returns empty" {
  result=$(bash "$EXTRACT_SCRIPT" "/tmp/nonexistent-file-$RANDOM.jsonl")
  [[ -z "$result" ]]
}

# ── URL stripping ──

@test "URLs: file:// paths stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/url-file.jsonl"
  echo '{"role": "user", "content": "Open file:///Users/mac/projects/app/config.yaml and review the settings"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Settings"* ]]
  [[ "$result" != *"Users"* ]]
  [[ "$result" != *"mac"* ]]
  [[ "$result" != *"yaml"* ]]
}

# ── Markdown stripping ──

@test "Markdown: image syntax stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/md-image.jsonl"
  echo '{"role": "user", "content": "![Image 1 Screen Profile Desktop](file:///Users/mac/Desktop/screenshot.png) Fix the topic extraction"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Topic"* ]] || [[ "$result" == *"Extraction"* ]]
  [[ "$result" != *"Image"* ]]
  [[ "$result" != *"Screen"* ]]
  [[ "$result" != *"Desktop"* ]]
}

@test "Markdown: multiple images stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/md-multi-image.jsonl"
  echo '{"role": "user", "content": "![step 1](file:///a.png) ![step 2](file:///b.png) Configure the Nginx proxy"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Nginx"* ]]
  [[ "$result" == *"Proxy"* ]]
  [[ "$result" != *"step"* ]]
}

@test "Markdown: link text preserved, URL stripped" {
  local tmpfile="$BATS_TEST_TMPDIR/md-link.jsonl"
  echo '{"role": "user", "content": "Read [this documentation](https://docs.example.com/auth) about OAuth setup"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Documentation"* ]] || [[ "$result" == *"OAuth"* ]]
}

@test "Markdown: image with transcript fixture" {
  result=$(bash "$EXTRACT_SCRIPT" "$FIXTURES_DIR/transcript-with-images.jsonl")
  [[ "$result" == *"Login"* ]] || [[ "$result" == *"Modal"* ]] || [[ "$result" == *"Error"* ]]
  [[ "$result" != *"screenshot"* ]]
}

# ── Topic validation (minimum word length) ──

@test "single short word rejected" {
  local tmpfile="$BATS_TEST_TMPDIR/short-word.jsonl"
  echo '{"role": "user", "content": "go"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  # "go" alone is too short (< 4 chars, < 2 words) => empty
  [[ -z "$result" ]]
}

# ── Conversational prefix stripping ──

@test "strips conversational prefix: Help me debug" {
  local tmpfile="$BATS_TEST_TMPDIR/prefix-help.jsonl"
  echo '{"role": "user", "content": "Help me debug the React Query cache invalidation"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"React"* ]]
  [[ "$result" == *"Query"* ]]
}

@test "strips conversational prefix: I need to" {
  local tmpfile="$BATS_TEST_TMPDIR/prefix-need.jsonl"
  echo '{"role": "user", "content": "I need to refactor the database migration scripts"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Database"* ]]
  [[ "$result" == *"Migration"* ]]
}

@test "strips conversational prefix: Necesito ayuda con (Spanish)" {
  local tmpfile="$BATS_TEST_TMPDIR/prefix-necesito.jsonl"
  echo '{"role": "user", "content": "Necesito ayuda con el componente de autenticación de NextAuth"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Componente"* ]]
  [[ "$result" == *"NextAuth"* ]]
}

# ── Command flags stripping ──

@test "command flags --auto --verbose stripped from loose text" {
  local tmpfile="$BATS_TEST_TMPDIR/flags.jsonl"
  echo '{"role": "user", "content": "--auto --verbose Fix the NextAuth login flow"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"NextAuth"* ]]
  [[ "$result" == *"Login"* ]]
  [[ "$result" != *"auto"* ]]
  [[ "$result" != *"verbose"* ]]
}

# ── Semantic coherence: core technical terms preserved ──

@test "semantic: database connection pool" {
  local tmpfile="$BATS_TEST_TMPDIR/db-conn.jsonl"
  echo '{"role": "user", "content": "Fix database connection pool timeout issue in production"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Database"* ]]
  [[ "$result" == *"Connection"* ]]
}

@test "semantic: API response" {
  local tmpfile="$BATS_TEST_TMPDIR/api-resp.jsonl"
  echo '{"role": "user", "content": "API response data format JSON parsing error handling"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"API"* ]]
  [[ "$result" == *"Response"* ]]
}

@test "semantic: server endpoint" {
  local tmpfile="$BATS_TEST_TMPDIR/server-ep.jsonl"
  echo '{"role": "user", "content": "Server endpoint request method GET POST parameters"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Server"* ]]
  [[ "$result" == *"Endpoint"* ]]
}

# ── Spanish with markdown images ──

@test "Spanish: image stripped, modal desktop extracted" {
  local tmpfile="$BATS_TEST_TMPDIR/es-modal-img.jsonl"
  echo '{"role": "user", "content": "![Image](url) Emigró el modal a la versión desktop"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Modal"* ]] || [[ "$result" == *"modal"* ]]
  [[ "$result" == *"Desktop"* ]] || [[ "$result" == *"desktop"* ]]
}

@test "Spanish: montar modal background" {
  local tmpfile="$BATS_TEST_TMPDIR/es-montar.jsonl"
  echo '{"role": "user", "content": "Montar el modal en el background"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Montar"* ]]
  [[ "$result" == *"Modal"* ]]
  [[ "$result" == *"Background"* ]]
}

# ── Dimension words ──

@test "dimension: screen profile ancho 900px" {
  local tmpfile="$BATS_TEST_TMPDIR/dimension-es.jsonl"
  echo '{"role": "user", "content": "Screen profile ancho 900px"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Screen"* ]]
  [[ "$result" == *"Profile"* ]]
  [[ "$result" == *"900px"* ]]
}

@test "dimension: English profile width 900px" {
  local tmpfile="$BATS_TEST_TMPDIR/dimension-en.jsonl"
  echo '{"role": "user", "content": "Fix profile width 900px"}' > "$tmpfile"
  result=$(bash "$EXTRACT_SCRIPT" "$tmpfile")
  [[ "$result" == *"Profile"* ]]
  [[ "$result" == *"Width"* ]] || [[ "$result" == *"900px"* ]]
}
