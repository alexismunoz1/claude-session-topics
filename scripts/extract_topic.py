#!/usr/bin/env python3
"""Extract session topic from Claude Code transcript.

Standalone module — used by auto-topic-hook.sh and test_extract_topic.py.
"""

import json
import re
import sys
import unicodedata

VERSION = 4  # Bump when extraction logic changes → invalidates cached topics


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
    'nos', 'les', 'su', 'sus', 'mi', 'mis', 'tu', 'tus', 'y', 'o', 'ni',
}

ACTION_VERBS = {
    'fix', 'add', 'update', 'create', 'remove', 'delete', 'change',
    'modify', 'implement', 'build', 'write', 'refactor', 'debug',
    'check', 'review', 'test', 'help', 'configure', 'install',
    'move', 'rename', 'solve', 'resolve', 'handle', 'show', 'hide',
    'enable', 'disable', 'migrate', 'deploy', 'run', 'start', 'stop',
    'set', 'get', 'put', 'send', 'fetch', 'load', 'save', 'read',
    'find', 'replace', 'convert', 'merge', 'split', 'connect',
    'setup', 'init', 'initialize', 'open', 'close', 'look',
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
    'habilita', 'deshabilita', 'migra', 'despliega', 'ejecuta', 'inicia',
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


# ── Extraction ──────────────────────────────────────────────────────────────

def extract_user_text(transcript_path):
    """Read JSONL transcript and return the first user message text."""
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

    # ── 6. Tokenize → filter → classify
    domain = []
    verbs = []

    for w in text.split():
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

    # ── 7. Build topic: domain words first, verbs as filler
    words = domain[:4]
    if not words and verbs:
        words = verbs[:2]
    elif len(words) == 1 and verbs:
        words.append(verbs[0])

    if not words:
        return ''

    # Title-case, max 50 chars
    topic = ' '.join(w.capitalize() if not w[0].isupper() else w for w in words[:4])
    if len(topic) > 50:
        while len(topic) > 50 and len(words) > 2:
            words.pop()
            topic = ' '.join(
                w.capitalize() if not w[0].isupper() else w for w in words
            )
        if len(topic) > 50:
            topic = topic[:50].rstrip()

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
