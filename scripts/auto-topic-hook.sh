#!/bin/bash
set -euo pipefail

# ── Stop hook: automatically set session topic from first user message
# Receives Stop event JSON on stdin: {"session_id": "...", "transcript_path": "..."}
# Fast-path: exits immediately if topic already exists for this session.

input=$(cat)

# ── Find the ancestor claude process PID (stable across all contexts)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_PID=$(bash "$SCRIPT_DIR/find-claude-pid.sh" 2>/dev/null || echo "")
if [ -z "$CLAUDE_PID" ]; then
    exit 0
fi

# ── Parse JSON fields
SESSION_ID=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('session_id', ''))
except:
    print('')
" 2>/dev/null || echo "")

TRANSCRIPT_PATH=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('transcript_path', ''))
except:
    print('')
" 2>/dev/null || echo "")

# ── Sanitize session ID (only allow alphanumeric, hyphens, underscores)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# ── Ensure topics directory exists and write active session (keyed by claude PID)
mkdir -p "$HOME/.claude/session-topics"
echo "$SESSION_ID" > "$HOME/.claude/session-topics/.active-session-$CLAUDE_PID"

# ── Fast path: topic already exists — nothing to do
TOPIC_FILE="$HOME/.claude/session-topics/${SESSION_ID}"
if [ -f "$TOPIC_FILE" ] && [ -s "$TOPIC_FILE" ]; then
    exit 0
fi

# ── No topic yet — extract one from the transcript
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# ── Use python3 for robust JSON + text processing
TOPIC=$(python3 -c "
import sys, json, re

def extract_user_text(transcript_path):
    \"\"\"Read JSONL transcript and return the first user/human message text.\"\"\"
    try:
        with open(transcript_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                text = None

                # Format 1: {\"role\": \"user\", \"content\": \"message text\"}
                if obj.get('role') == 'user':
                    content = obj.get('content', '')
                    if isinstance(content, str):
                        text = content
                    elif isinstance(content, list):
                        # Format 2: {\"role\": \"user\", \"content\": [{\"type\": \"text\", \"text\": \"...\"}]}
                        for item in content:
                            if isinstance(item, dict) and item.get('type') == 'text':
                                text = item.get('text', '')
                                break

                # Format 3: {\"type\": \"human\", \"message\": {\"role\": \"user\", \"content\": \"text\"}}
                elif obj.get('type') == 'human':
                    msg = obj.get('message', {})
                    if isinstance(msg, dict):
                        content = msg.get('content', '')
                        if isinstance(content, str):
                            text = content
                        elif isinstance(content, list):
                            for item in content:
                                if isinstance(item, dict) and item.get('type') == 'text':
                                    text = item.get('text', '')
                                    break

                if text and text.strip():
                    return text.strip()
    except Exception:
        pass
    return ''

def extract_topic(text):
    \"\"\"Extract a concise 2-4 word topic from user text.\"\"\"
    if not text:
        return ''

    # Remove markdown formatting
    text = re.sub(r'\`\`\`[\s\S]*?\`\`\`', '', text)  # code blocks
    text = re.sub(r'\`[^\`]+\`', '', text)              # inline code
    text = re.sub(r'[#*_~>\[\]()!]', '', text)          # markdown chars
    text = re.sub(r'https?://\S+', '', text)             # URLs
    text = re.sub(r'\s+', ' ', text).strip()

    # Take only the first sentence/line for topic extraction
    first_line = text.split('\n')[0].strip()
    first_sentence = re.split(r'[.!?]', first_line)[0].strip()
    if first_sentence:
        text = first_sentence

    # Strip common prefixes (English and Spanish)
    prefixes = [
        # Greetings first (often followed by other prefixes)
        r'^hey\b',
        r'^hi\b',
        r'^hello\b',
        r'^hola\b',
        # Polite qualifiers
        r'^please\b',
        r'^por favor\b',
        # English request patterns (longer patterns first)
        r'^i would like to\b',
        r'^i\'d like to\b',
        r'^i need to\b',
        r'^i want to\b',
        r'^i need\b',
        r'^i want\b',
        r'^can you\b',
        r'^could you\b',
        r'^would you\b',
        r'^help me\b',
        r'^we need to\b',
        r'^we should\b',
        r'^let\'s\b',
        # Spanish request patterns
        r'^me gustaria\b',
        r'^ayudame a\b',
        r'^ayudame\b',
        r'^necesito\b',
        r'^quiero\b',
        r'^puedes\b',
        r'^podrias\b',
        r'^podr.as\b',
        r'^vamos a\b',
    ]
    # Multi-pass: keep stripping until no more prefixes match
    changed = True
    while changed:
        changed = False
        for prefix in prefixes:
            old = text
            text = re.sub(prefix, '', text, flags=re.IGNORECASE).strip()
            text = re.sub(r'^[,;:\s]+', '', text).strip()
            if text != old:
                changed = True

    # Stop words (English + Spanish)
    stop_words = {
        # English
        'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
        'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
        'should', 'may', 'might', 'shall', 'can', 'to', 'of', 'in', 'for',
        'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
        'before', 'after', 'above', 'below', 'between', 'out', 'off', 'over',
        'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when',
        'where', 'why', 'how', 'all', 'each', 'every', 'both', 'few', 'more',
        'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
        'same', 'so', 'than', 'too', 'very', 'just', 'about', 'up', 'it',
        'its', 'this', 'that', 'these', 'those', 'my', 'your', 'his', 'her',
        'our', 'their', 'me', 'him', 'us', 'them', 'what', 'which', 'who',
        'whom', 'and', 'but', 'or', 'if', 'while', 'because', 'until',
        'also', 'still', 'get', 'got', 'make', 'made',
        # Spanish
        'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del',
        'en', 'con', 'por', 'para', 'al', 'es', 'son', 'ser', 'estar',
        'este', 'esta', 'estos', 'estas', 'ese', 'esa', 'esos', 'esas',
        'que', 'como', 'mas', 'pero', 'si', 'ya', 'se', 'le', 'lo',
        'nos', 'les', 'su', 'sus', 'mi', 'mis', 'tu', 'tus',
    }

    words = text.split()
    # Filter stop words but keep words that look important (capitalized, technical)
    meaningful = []
    for w in words:
        clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', w)
        if not clean:
            continue
        if clean.lower() in stop_words and not clean[0].isupper():
            continue
        meaningful.append(clean)

    if not meaningful:
        # Fallback: just take first few words if all were stop words
        meaningful = [re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', w) for w in words[:4]]
        meaningful = [w for w in meaningful if w]

    # Take 2-4 words
    topic_words = meaningful[:4]
    if not topic_words:
        return ''

    # Title-case each word
    topic = ' '.join(w.capitalize() if not w[0].isupper() else w for w in topic_words)

    # Truncate to max 40 chars
    if len(topic) > 40:
        # Try to fit within 40 chars by reducing words
        while len(topic) > 40 and len(topic_words) > 2:
            topic_words.pop()
            topic = ' '.join(w.capitalize() if not w[0].isupper() else w for w in topic_words)
        if len(topic) > 40:
            topic = topic[:40].rstrip()

    return topic

transcript_path = sys.argv[1]
text = extract_user_text(transcript_path)
topic = extract_topic(text)
print(topic)
" "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

# ── Write topic if we got one
if [ -n "$TOPIC" ]; then
    # Sanitize topic: remove shell metacharacters and non-printable chars, keep letters (incl. accented), digits, spaces, basic punctuation
    TOPIC=$(printf '%s' "$TOPIC" | sed 's/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ .,:!?'"'"'-]//g' | cut -c1-40)
    if [ -n "$TOPIC" ]; then
        printf '%s\n' "$TOPIC" > "$TOPIC_FILE"
    fi
fi

exit 0
