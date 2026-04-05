#!/usr/bin/env python3
"""Extract session topic from Claude Code transcript.

Standalone module — used by auto-topic-hook.sh and test_extract_topic.py.

Uses YAKE (Yet Another Keyword Extractor) for improved keyword extraction.
YAKE is a lightweight, unsupervised keyword extraction algorithm that provides
better results than simple bag-of-words approaches. Falls back to legacy
bag-of-words method if YAKE is unavailable or fails.

Usage:
    python extract_topic.py <transcript.jsonl>

Requirements:
    - Python 3.x
    - yake (optional but recommended): pip3 install yake
"""

import json
import re
import sys
import unicodedata

# Language detection for enforcing English-only topics
try:
    from langdetect import detect, DetectorFactory
    from langdetect.lang_detect_exception import LangDetectException
    # Set seed for reproducible results
    DetectorFactory.seed = 0
    LANGDETECT_AVAILABLE = True
except ImportError:
    LANGDETECT_AVAILABLE = False

# YAKE integration for improved keyword extraction
# YAKE (Yet Another Keyword Extractor) is a lightweight, unsupervised keyword extraction
# algorithm that provides better results than simple bag-of-words approaches
try:
    import yake
    YAKE_AVAILABLE = True
except ImportError:
    YAKE_AVAILABLE = False

VERSION = 9  # Bump when extraction logic changes → invalidates cached topics


def _strip_accents(s):
    return ''.join(
        c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn'
    )


# ── Word lists ──────────────────────────────────────────────────────────────

STOP_WORDS = {
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
    'nos', 'les', 'su', 'sus', 'mi', 'mis', 'tu', 'tus',     'y', 'o', 'ni',
    # Image/media references that should be ignored
    'image', 'images', 'imagen', 'imagenes', 'picture', 'pictures',
    'photo', 'photos', 'foto', 'fotos', 'screenshot', 'screenshots',
    'captura', 'capturas', 'png', 'jpg', 'jpeg', 'gif', 'svg',
}

ACTION_VERBS = {
    'fix', 'add', 'update', 'create', 'remove', 'delete', 'change',
    'modify', 'implement', 'build', 'write', 'refactor', 'debug',
    'check', 'review', 'test', 'help', 'configure', 'install',
    'move', 'rename', 'solve', 'resolve', 'handle', 'show', 'hide',
    'enable', 'disable', 'migrate', 'deploy', 'run', 'start', 'stop',
    'set', 'get', 'put', 'send', 'fetch', 'load', 'save', 'read',
    'find', 'replace', 'convert', 'merge', 'split', 'connect',
    'setup', 'init', 'initialize', 'open', 'close', 'look', 'adapt',
    'adjust', 'improve', 'enhance', 'optimize', 'polish', 'upgrade',
    'downgrade', 'revert', 'restore', 'backup', 'export', 'import',
    'sync', 'validate', 'verify', 'authenticate', 'authorize',
    'compress', 'minify', 'bundle', 'transpile', 'compile',
}

# Compound technical terms that should be kept together as n-grams
COMPOUND_TERMS = {
    # File extensions
    'json', 'yaml', 'yml', 'xml', 'csv', 'html', 'css', 'scss', 'sass',
    # UI Components
    'modal', 'dialog', 'popup', 'tooltip', 'dropdown', 'accordion',
    'carousel', 'slider', 'navbar', 'sidebar', 'footer', 'header',
    'button', 'input', 'field', 'form', 'card', 'panel', 'tab',
    # Layout terms  
    'layout', 'grid', 'flex', 'container', 'wrapper', 'section',
    'desktop', 'mobile', 'responsive', 'viewport', 'screen',
    # Data/State
    'state', 'props', 'context', 'store', 'cache', 'session',
    'database', 'table', 'column', 'record', 'query', 'migration',
    # API/Network
    'api', 'endpoint', 'route', 'request', 'response', 'handler',
    'middleware', 'controller', 'service', 'client', 'server',
    # Auth/Security
    'auth', 'login', 'logout', 'token', 'cookie', 'session',
    'certificate', 'permission', 'role', 'user', 'account',
    # Build/DevOps
    'build', 'deploy', 'pipeline', 'ci', 'cd', 'docker', 'kubernetes',
    'config', 'environment', 'production', 'staging', 'development',
}

# Spanish morphological suffixes (unaccented — words normalized before match)
# 'sion' intentionally omitted: too many English false positives (session, version)
_ES_SUFFIX_RE = re.compile(
    r'(?:cion|mente|iendo|amiento|imiento|izacion'
    r'|anza|encia|oso|osa|osos|osas|ito|ita|itos|itas'
    r'|ando|endo|ado|ados|ida|idas)$', re.I,
)

_ES_WORDS = {
    # Common words that bypass stop_words / don't match suffixes
    'ahora', 'algo', 'antes', 'bien', 'cada', 'casi', 'cierto', 'creo',
    'cuando', 'debe', 'deben', 'desde', 'dia', 'donde', 'ejemplo', 'ella',
    'ellos', 'entonces', 'forma', 'fue', 'gran', 'grande', 'grandes',
    'hace', 'hacia', 'hasta', 'hay', 'hoy', 'igual', 'lado', 'lugar',
    'manera', 'mejor', 'menos', 'mientras', 'mismo', 'misma', 'momento',
    'mucho', 'mucha', 'muchos', 'muy', 'nada', 'necesitan', 'nunca',
    'otro', 'otra', 'otros', 'parece', 'poco', 'puede', 'pueden', 'punto',
    'queda', 'quien', 'sea', 'sido', 'siempre', 'sino', 'sobre', 'solo',
    'soy', 'tambien', 'tanto', 'tiempo', 'tiene', 'tienen', 'tipo',
    'todo', 'todos', 'verdad', 'vez', 'voy', 'hecho', 'dicho',
    # Tech-adjacent Spanish nouns
    'archivo', 'archivos', 'carpeta', 'pantalla', 'campo', 'tabla',
    'usuario', 'pagina', 'registro', 'mensaje', 'imagen', 'texto', 'lista',
    'esqueleto', 'esqueletos', 'perfil', 'perfiles', 'componente',
    'componentes', 'dependencia', 'dependencias', 'servicio', 'proyecto',
    'funcion', 'funciones', 'variable', 'directorio', 'paquete', 'metodo',
    'clase', 'modulo', 'recurso', 'valor', 'proceso', 'sistema',
    'servidor', 'cliente', 'clave', 'ruta', 'entorno', 'cambio', 'prueba',
    'desarrollo', 'permiso', 'acceso', 'seguridad', 'estructura', 'diseno',
    'estado', 'cuenta', 'evento', 'nivel', 'opcion', 'seccion', 'bloque',
    'fuente', 'carga', 'tarea', 'regla', 'error', 'errores', 'pagos',
    # -sión words (suffix 'sion' excluded from regex to avoid English false positives)
    'sesion', 'version', 'mision', 'extension', 'conexion', 'expresion',
    'revision', 'decision', 'dimension', 'produccion', 'aplicacion',
    # Conjugated verbs that don't match suffixes
    'corrige', 'arregla', 'agrega', 'elimina', 'cambia', 'modifica',
    'implementa', 'construye', 'escribe', 'crea', 'revisa', 'configura',
    'instala', 'mueve', 'renombra', 'resuelve', 'maneja', 'oculta',
    'habilita', 'deshabilita', 'migra', 'emigra', 'emigro', 'despliega', 'ejecuta', 'inicia',
    'detiene', 'reemplaza', 'convierte', 'analiza', 'investiga', 'verifica',
    'actualiza', 'refactoriza', 'genera', 'necesita', 'quita', 'muestra',
    'busca', 'abre', 'cierra', 'sube', 'baja', 'funciona', 'funcione',
    'adapta', 'toca', 'toques', 'realiza', 'hacen',
    # Misc
    'generar', 'reajustar', 'basura', 'usar', 'dentro', 'fuera',
    'rapido', 'lento', 'posible', 'necesario', 'anterior', 'completo',
    'actualmente', 'solamente', 'adecuadamente', 'busqueda', 'pestana',
    'contrasena', 'tamano', 'tamanos', 'flujo', 'flujos', 'inicio',
    'cuenta', 'cuentas', 'recupero', 'pantallas', 'elementos',
    'ventaja', 'ventajas', 'respecto', 'diferencia', 'diferencias',
    'comparar', 'compara', 'mejor', 'peor', 'manera', 'forma',
    'hablemos', 'vamos', 'quiero', 'necesito',
    'objetivo', 'objetivos', 'motivo', 'razon', 'causa',
    'problema', 'solucion', 'resultado', 'ejemplo', 'detalle', 'detalles',
    # Common short verbs/conjugations that don't match suffixes
    'tomar', 'toma', 'toman', 'tome', 'hablar', 'habla', 'dar', 'damos',
    'sacar', 'saca', 'ganar', 'gana', 'pagar', 'paga', 'dejar', 'deja',
    'pensar', 'piensa', 'seguir', 'sigue', 'siguen', 'volver', 'vuelve',
    'sentir', 'siente', 'pedir', 'pide', 'piden', 'salir', 'sale', 'salen',
    'traer', 'trae', 'perder', 'pierde', 'poner', 'pone', 'ponen',
    'decir', 'dice', 'dicen', 'saber', 'saben', 'querer', 'ver', 'veo',
    'llevar', 'lleva', 'llamar', 'llama', 'llaman', 'pasar', 'pasa',
    'quedar', 'queda', 'creer', 'cree', 'creen', 'conocer', 'conoce',
    # Montar and related
    'montar', 'monta', 'montan', 'monte', 'montando', 'montado',
    # Position/location words
    'alrededor', 'alrededores', 'encima', 'debajo', 'dentro', 'fuera',
    'detras', 'delante', 'entre', 'hacia', 'desde', 'hasta',
    # UI-related Spanish words
    'modales', 'ventana', 'ventanas', 'cuadro', 'cuadros', 'dialogo',
    'boton', 'botones', 'campo', 'campos', 'fila', 'filas', 'columna', 'columnas',
    # More common Spanish words that should be filtered
    'emigro', 'emigró', 'emigra', 'emigró', 'necesito', 'necesita', 'ayuda',
    'con', 'para', 'por', 'como', 'pero', 'mas', 'más', 'este', 'esta', 'esto',
    'ese', 'esa', 'eso', 'aqui', 'aquí', 'alli', 'allí', 'ahi', 'ahí',
    'arquitectura', 'arquitecturas', 'nueva', 'nuevo', 'nuevas', 'nuevos',
    'viejos', 'viejas', 'viejo', 'vieja', 'error', 'errores', 'correcto',
    # Size/dimension words
    'ancho', 'ancha', 'anchos', 'anchas', 'alto', 'alta', 'altos', 'altas',
    'largo', 'larga', 'largos', 'largas', 'pequeno', 'pequena', 'pequenos', 'pequenas',
    'grande', 'grandes', 'mediano', 'mediana', 'medianos', 'medianas',
    # More verbs
    'arreglar', 'arregla', 'arreglan', 'arreglo', 'arreglando',
    'hacer', 'hace', 'hacen', 'hago', 'hacia', 'hecho',
}


def _is_spanish(word):
    """Heuristic: is this word likely Spanish?"""
    wl = word.lower()
    # ñ is exclusively Spanish
    if 'ñ' in wl:
        return True
    wn = _strip_accents(wl)
    if wn in _ES_WORDS:
        return True
    if _ES_SUFFIX_RE.search(wn):
        return True
    return False


def _is_primarily_spanish(text):
    """Detect if text contains significant Spanish words.
    
    Uses a simple heuristic: if >40% of content words are Spanish,
    consider the text Spanish. This is more reliable than langdetect
    for short technical texts.
    """
    if not text:
        return False
    
    # Extract words
    words = re.findall(r'[a-zA-Z\u00C0-\u024F]+', text.lower())
    if not words:
        return False
    
    # Count Spanish words
    spanish_count = sum(1 for w in words if _is_spanish(w))
    
    # If more than 25% are Spanish, consider it Spanish text
    # Lower threshold to catch short phrases with Spanish verbs
    return spanish_count / len(words) > 0.25


# ── Extraction ──────────────────────────────────────────────────────────────


def extract_user_text(transcript_path):
    """Read JSONL transcript and return the first non-empty user message text.

    Skips messages that become empty after XML tag stripping (e.g.,
    messages containing only <local-command-caveat> wrappers).
    """
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

                text = _get_user_text(obj)
                if text and text.strip():
                    # Strip XML/HTML tags to check if meaningful content remains
                    stripped = re.sub(r'<(\w[\w-]*)(?:\s[^>]*)?>.*?</\1>', '', text, flags=re.DOTALL)
                    stripped = re.sub(r'<[^>]*>', '', stripped).strip()
                    if stripped:
                        return text.strip()
    except Exception:
        pass
    return ''


def _get_user_text(obj):
    """Extract text from a single transcript entry."""
    content = None

    if obj.get('role') == 'user':
        content = obj.get('content', '')
    elif obj.get('type') in ('human', 'user'):
        msg = obj.get('message', {})
        if isinstance(msg, dict):
            content = msg.get('content', '')

    if content is None:
        return None

    if isinstance(content, str):
        return content

    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'text':
                return item.get('text', '')

    return None


def _detect_language(text):
    """Detect if text is primarily English or Spanish based on word frequency."""
    if not text:
        return "en"
    
    words = text.lower().split()
    spanish_indicators = 0
    english_indicators = 0
    
    for word in words:
        clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', word)
        if not clean:
            continue
        if _is_spanish(clean):
            spanish_indicators += 1
        elif clean in STOP_WORDS:
            english_indicators += 1
    
    return "es" if spanish_indicators > english_indicators else "en"


def _legacy_extract_topic(cleaned_text):
    """
    Legacy bag-of-words extraction method.
    Used as fallback when YAKE is not available or fails.
    """
    # Tokenize → filter → classify
    domain = []
    verbs = []

    for w in cleaned_text.split():
        # Skip command tokens (--flag, -f, /command)
        if w.startswith('-') or w.startswith('/'):
            continue
        clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', w)
        if not clean or len(clean) < 2:
            continue
        cl = _strip_accents(clean.lower())
        if cl in STOP_WORDS:
            continue
        if _is_spanish(clean):
            continue
        if cl in ACTION_VERBS:
            verbs.append(clean)
        else:
            domain.append(clean)

    # Build topic: domain words first, verbs as filler
    words = domain[:4]
    if not words and verbs:
        words = verbs[:2]
    elif len(words) == 1 and verbs:
        words.append(verbs[0])

    if not words:
        return ''

    return words


def extract_topic(text):
    """Extract a concise 2-4 word English topic from user text."""
    if not text:
        return ''

    # ── 1. Strip ALL XML/HTML tagged blocks (handles every tag format at once)
    text = re.sub(r'<(\w[\w-]*)(?:\s[^>]*)?>.*?</\1>', '', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]*>', '', text)  # orphan/self-closing tags

    # ── 2. Strip markdown
    text = re.sub(r'```[\s\S]*?```', '', text)             # code blocks
    text = re.sub(r'`[^`]+`', '', text)                    # inline code
    text = re.sub(r'!\[[^\]]*\]\([^)]*\)', '', text)       # images
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)   # links → keep text
    text = re.sub(r'[#*_~<>\[\]()!]', '', text)            # remaining markers

    # ── 3. Strip URLs
    text = re.sub(r'(?:https?|file)://\S+', '', text)

    # ── 4. Normalize whitespace, take first sentence
    text = re.sub(r'\s+', ' ', text).strip()
    text = re.split(r'[.!?\n]', text)[0].strip()

    # ── 5. Strip conversational prefixes
    _prefixes = [
        r'^(?:hey|hi|hello|hola)\b',
        r'^please\b', r'^por favor\b',
        r'^(?:i (?:would like to|\'d like to|need to|want to|need|want))\b',
        r'^(?:can you|could you|would you|help me|we need to|let\'s)\b',
        r'^(?:necesito(?: ayuda(?: con)?)?|quiero|puedes|ayudame(?: a)?)\b',
    ]
    for p in _prefixes:
        text = re.sub(p, '', text, flags=re.IGNORECASE).strip()
        text = re.sub(r'^[,;:\s]+', '', text).strip()

    # ── 6. Language detection: select YAKE language parameter
    # Detect if text is primarily Spanish to configure YAKE accordingly.
    # Spanish text uses lan="es" for better keyword extraction.
    yake_lang = "es" if _is_primarily_spanish(text) else "en"

    # ── 7. Smart topic extraction with structured composition
    # Goal: Create topics like "Fix Certificate Modal Desktop Layout"
    # Structure: [ACTION VERB] + [MAIN OBJECT] + [CONTEXT/DETAIL]
    words = []

    if YAKE_AVAILABLE and len(text.split()) >= 3:
        try:
            kw_extractor = yake.KeywordExtractor(
                lan=yake_lang,
                n=3,
                dedupLim=0.9,
                top=10,
            )
            
            keywords = kw_extractor.extract_keywords(text)
            
            # Extract all candidate words from YAKE results
            candidate_words = []
            for score, keyword in keywords:
                for word in keyword.split():
                    clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', word)
                    if not clean or len(clean) < 2:
                        continue
                    cl = _strip_accents(clean.lower())
                    if cl in STOP_WORDS or _is_spanish(clean):
                        continue
                    if clean.lower() not in [w.lower() for w in candidate_words]:
                        candidate_words.append(clean)
            
            # Build structured topic: [VERB] + [OBJECT] + [CONTEXT]
            action_verb = None
            main_object = None
            context_words = []
            
            # First pass: Look for action verb at the beginning of the text
            text_words = text.split()
            for i, w in enumerate(text_words[:5]):  # Check first 5 words
                clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', w)
                cl = _strip_accents(clean.lower())
                if cl in ACTION_VERBS:
                    action_verb = clean
                    break
            
            # Second pass: Find main object and context from candidates
            for word in candidate_words:
                word_lower = word.lower()
                
                # Skip if it's the same as the action verb
                if action_verb and word_lower == action_verb.lower():
                    continue
                
                # Identify compound terms and tech keywords
                if word_lower in COMPOUND_TERMS or len(word) >= 4:
                    if main_object is None:
                        main_object = word
                    elif len(context_words) < 2:
                        context_words.append(word)
                
                if main_object and len(context_words) >= 2:
                    break
            
            # Compose final topic with structure: VERB + OBJECT + CONTEXT
            if action_verb:
                words.append(action_verb)
            if main_object:
                words.append(main_object)
            words.extend(context_words[:3])  # Add up to 3 context words
            
            # Fallback: if structured approach didn't work, use best YAKE candidates
            if len(words) < 2:
                words = candidate_words[:4]
                
        except Exception:
            # If YAKE fails, fall through to legacy method
            words = []
    
    # ── 7. Fallback to legacy extraction if YAKE didn't produce results
    if not words:
        words = _legacy_extract_topic(text)
        if not words:
            return ''

    # ── 8. Post-process: limit to 2-4 words, capitalize, max 50 chars
    # Ensure we have at least 2 words for better context
    if len(words) == 1:
        # Check if we already have an English technical term
        has_english_tech_term = (
            len(words) >= 1 and 
            not _is_spanish(words[0]) and
            (_strip_accents(words[0].lower()) in ACTION_VERBS or
             _strip_accents(words[0].lower()) in COMPOUND_TERMS or
             len(words[0]) >= 4)
        )
        
        # Only add additional words if they are English technical terms
        for w in text.split():
            if len(words) >= 2:
                break
            
            # Handle file names with extensions (e.g., "package.json")
            if '.' in w and not w.startswith('.') and not w.endswith('.'):
                parts = w.lower().split('.')
                for part in parts:
                    if len(part) < 2:
                        continue
                    # Skip Spanish words when we already have English terms
                    if has_english_tech_term and _is_spanish(part):
                        continue
                    if part not in [x.lower() for x in words]:
                        words.append(part.capitalize())
                        break
            else:
                clean = re.sub(r'[^a-zA-Z0-9\u00C0-\u024F-]', '', w)
                if not clean or len(clean) < 2:
                    continue
                
                # Skip Spanish words entirely - only accept English technical terms
                if _is_spanish(clean):
                    continue
                    
                cl = _strip_accents(clean.lower())
                if cl in STOP_WORDS:
                    continue
                if clean.lower() != words[0].lower():
                    # Only add if it's a technical term (action verb or compound term)
                    if cl in ACTION_VERBS or cl in COMPOUND_TERMS:
                        words.append(clean)
    
    # Limit to 1-4 words (allow single word if it's a strong tech term)
    words = words[:4]
    if not words:
        return ''
    # Allow single word only if it's a meaningful tech term (>= 4 chars)
    if len(words) == 1 and len(words[0]) < 4:
        return ''
    
    # Capitalize correctly: capitalize each word
    topic = ' '.join(w.capitalize() if not w[0].isupper() else w for w in words)
    
    # Apply 50 character limit
    if len(topic) > 50:
        while len(topic) > 50 and len(words) > 2:
            words.pop()
            topic = ' '.join(
                w.capitalize() if not w[0].isupper() else w for w in words
            )
        if len(topic) > 50:
            topic = topic[:50].rstrip()
    
    # ── Final validation: reject topics containing Spanish words
    # This enforces the English-only policy strictly
    topic_words = topic.split()
    spanish_count = sum(1 for w in topic_words if _is_spanish(w))
    if spanish_count > 0:
        # Contains Spanish words - return empty to trigger fallback behavior
        return ''

    return topic


def validate_topic(topic):
    """Return True if topic is meaningful enough to display."""
    if not topic:
        return False
    return any(len(w) >= 4 for w in topic.split())


# ── CLI ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print('')
        sys.exit(0)
    try:
        text = extract_user_text(sys.argv[1])
        topic = extract_topic(text)
        print(topic if validate_topic(topic) else '')
    except Exception:
        print('')


if __name__ == '__main__':
    main()
