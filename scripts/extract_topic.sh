#!/usr/bin/env bash
# Extract session topic from Claude Code transcript (pure bash + jq).
# Usage: bash extract_topic.sh <transcript.jsonl>
# Output: lang:Topic Words Here | Always exits 0.
set -euo pipefail
# shellcheck disable=SC2034
VERSION=13
trap 'echo ""; exit 0' ERR

STOP_WORDS=" a an the and or but if in on at to for of is it be as do by we he she no so up my me am i not all can has its may new now old see way who how did get let say too use her him his our own any few got had man run set try two big end far put ask ago came done give goes gone into just keep know last like long look made make many much must name next only open over part real same show side some sure take tell than them then they this that used want well went what when also back been call come each even find first from good here high home kind left life line live more most move need once play read right seem self shall should since still such test text time turn very will with word work year about through during before after above below between under again further nor out off are was were being have has had does did would could should might being while where which there those these every other another some any thing things really just already always never using properly currently actually basically de el la los las un una unos unas del al en por para con sin sobre entre es son ser estar fue como mas pero esta este estos estas ese esa esos esas tiene puede hacer donde cuando ya hay todo otra otro si lo le se su sus nos les me te mi mis tu tus que y o ni e u eso esto algo solo muy aqui asi ahora despues antes cada sido quiero necesito puedes estaba estoy estan era eran fueron hice hizo tengo tienen tenia quiere quieren habia habian podria deberia viene vienen van iba paso pasa dice decir dicho hecho puedo dijo sabe saben creo cree siendo estando parece parecia queda quedan sigue siguen lleva llevan deja dejan pone ponen sale salen caso cosa cosas forma manera parte tipo tipos veces vez dia dias momento lado ejemplo dato datos cuenta problema bien mal mejor peor mayor menor nuevo nueva nuevos nuevas viejo gran grande pequeno poco poca pocos pocas mucho mucha muchos muchas tanto tanta tantos tantas varios varias cierto cierta propio propia mismo misma cual cuales quien quienes algun alguno alguna algunos algunas ningun ninguno ninguna ambos demas cuanto cuanta tal tales bastante bastantes demasiado demasiada primer primero primera segundo segunda ultimo ultima unico unica medio media recien ahi alla aca adonde abajo arriba afuera adentro adelante atras cerca lejos dentro fuera junto menos mientras entonces pues porque aunque sino tampoco ademas quiza quizas todavia aun tambien siempre nunca jamas apenas casi realmente basicamente solamente simplemente actualmente normalmente generalmente practicamente finalmente incluso segun hasta desde hacia mediante durante contra tras ante excepto salvo dado bueno buena buenos buenas malo mala malos malas claro verdad obvio posible necesario importante diferente siguiente anterior actual otro otra otros otras saber tener poder hacer decir querer poner salir venir dar ver ir oir caer traer creer leer parecer conocer saber sentir pensar vivir morir dormir pedir seguir servir llamar pasar hablar dejar contar tocar perder encontrar esperar mirar resultar tratar punto puntos cosa cosas lado cosas parte partes veces momento manera forma lugar muestra muestran funciona funcionan aparece aparecen permite permiten necesita necesitan intenta intentan mueve mueven abre abren cierra cierran cambia cambian agrega agregan quita quitan usa usan utiliza utilizan recibe reciben incluye incluyen muestra muestran genera generan requiere requieren devuelve devuelven pueda puedan tenga tengan haga hagan vaya vayan sepa sepan diga digan quiera quieran haya hayan sea sean este esten fuera fuese pudiera pudieron tuviera tuvieron hiciera hicieron fuera fueron diera dieron dijera dijeron color negro blanco rojo azul verde amarillo gris rosa naranja morado oscuro claro image images imagen imagenes picture pictures photo photos foto fotos screenshot screenshots captura capturas png jpg jpeg gif svg "
ES_MARKERS=" el la los las un una de del en con por para al es son que como pero ya se este esta su sus mi tu y o ni nos "
EN_MARKERS=" the is are was were have has had do does did will would could should can with from this that these those and but or if not just "
ACTION_VERBS=" fix add update create remove delete change modify implement build write refactor debug check review test help configure install move rename solve resolve handle show hide enable disable migrate deploy run start stop set get put send fetch load save read find replace convert merge split connect setup init initialize open close look adapt adjust improve enhance optimize polish upgrade downgrade revert restore backup export import sync validate verify authenticate authorize compress minify bundle transpile compile arreglar agregar crear actualizar eliminar cambiar modificar implementar construir configurar habilitar mover copiar revisar probar correr instalar reemplazar convertir migrar optimizar depurar generar exportar importar enviar cargar guardar limpiar iniciar detener aplicar buscar filtrar ordenar seleccionar mostrar ocultar abrir cerrar subir bajar descargar publicar compartir conectar desconectar verificar validar autenticar registrar ingresar acceder navegar redirigir continuar pasar cambiar poner sacar meter llevar traer mandar llamar quedar seguir volver salir entrar lograr obtener mantener preparar terminar completar comenzar empezar ayudar corregir solucionar reparar ajustar mejorar analizar investigar explorar explicar entender comprender revisar comprobar asegurar necesitar intentar "
COMPOUND_TERMS=" json yaml yml xml csv html css scss sass modal dialog popup tooltip dropdown accordion carousel slider navbar sidebar footer header button input field form card panel tab layout grid flex container wrapper section desktop mobile responsive viewport screen state props context store cache session database table column record query migration api endpoint route request response handler middleware controller service client server auth login logout token cookie certificate permission role user account build deploy pipeline ci cd docker kubernetes config environment production staging development boton formulario campo entrada pagina pantalla inicio sesion registro usuario contrasena clave correo mensaje error aviso notificacion lista tabla menu barra busqueda filtro selector pestana ventana archivo carpeta icono enlace vinculo componente estilo tema fuente margen borde fondo ancho alto texto titulo parrafo celda fila columna permiso ruta servidor base datos modelo vista controlador servicio "

in_list() { [[ "$2" == *" $1 "* ]]; }

strip_accents() {
  if command -v perl >/dev/null 2>&1; then
    echo "$1" | perl -CS -MUnicode::Normalize -ne 'print NFD($_) =~ s/\pM//gr'
  else
    echo "$1" | sed 'y/áéíóúñàèìòùâêîôûäëïöüÁÉÍÓÚÑÀÈÌÒÙÂÊÎÔÛÄËÏÖÜ/aeiounaeioaeiouaeiouAEIOUNAEIOUAEIOUAEIOU/'
  fi
}

capitalize() {
  local w="$1"; [[ -z "$w" ]] && return
  echo "$(echo "${w:0:1}" | tr '[:lower:]' '[:upper:]')${w:1}"
}

is_spanish_filtered_form() {
  local w="$1"
  [[ ${#w} -lt 5 ]] && return 1
  # Adverbs ending in -mente (correctamente, rápidamente, etc.)
  [[ "$w" =~ mente$ ]] && [[ ${#w} -ge 7 ]] && return 0
  # Gerunds: -ando, -endo, -iendo
  [[ "$w" =~ (ando|endo|iendo)$ ]] && return 0
  # Past participles: -ado, -ido
  [[ "$w" =~ (ado|ido)$ ]] && return 0
  # Imperfect: -aba, -aban, -abas, -abamos
  [[ "$w" =~ (aba|aban|abas|abamos)$ ]] && return 0
  # Imperfect -ía: -ia, -ian, -ias, -iamos (accent-stripped)
  [[ "$w" =~ (ia|ian|ias|iamos)$ ]] && [[ ${#w} -ge 5 ]] && return 0
  # Conditional: -aria, -eria, -iria and plurals
  [[ "$w" =~ (aria|eria|iria|arian|erian|irian)$ ]] && return 0
  # Subjunctive: -ase, -iese
  [[ "$w" =~ (ase|ases|iese|iesen)$ ]] && return 0
  return 1
}

extract_user_text() {
  local file="$1"; [[ ! -f "$file" ]] && return
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local role text content_type
    role=$(echo "$line" | jq -r '.role // empty' 2>/dev/null) || continue
    if [[ "$role" == "user" ]]; then
      content_type=$(echo "$line" | jq -r '.content | type' 2>/dev/null) || continue
      if [[ "$content_type" == "string" ]]; then
        text=$(echo "$line" | jq -r '.content' 2>/dev/null)
      elif [[ "$content_type" == "array" ]]; then
        text=$(echo "$line" | jq -r '[.content[] | select(.type=="text") | .text] | first // empty' 2>/dev/null)
      else continue; fi
    else
      local msg_type
      msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null) || continue
      if [[ "$msg_type" == "human" || "$msg_type" == "user" ]]; then
        content_type=$(echo "$line" | jq -r '.message.content | type' 2>/dev/null) || continue
        if [[ "$content_type" == "string" ]]; then
          text=$(echo "$line" | jq -r '.message.content' 2>/dev/null)
        elif [[ "$content_type" == "array" ]]; then
          text=$(echo "$line" | jq -r '[.message.content[] | select(.type=="text") | .text] | first // empty' 2>/dev/null)
        else continue; fi
      else continue; fi
    fi
    [[ -z "$text" ]] && continue
    local stripped
    stripped=$(echo "$text" | perl -0pe 's/<(\w[\w-]*)(?:\s[^>]*)?>[\s\S]*?<\/\1>//g' 2>/dev/null || echo "$text")
    stripped=$(echo "$stripped" | sed 's/<[^>]*>//g' | tr -s '[:space:]' ' ')
    stripped="${stripped## }"; stripped="${stripped%% }"
    [[ -n "$stripped" ]] && echo "$text" && return
  done < "$file"
}

detect_language() {
  local lower es=0 en=0
  lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for w in $lower; do
    in_list "$w" "$ES_MARKERS" && (( es++ )) || true
    in_list "$w" "$EN_MARKERS" && (( en++ )) || true
  done
  (( es >= 2 && es > en )) && echo "es" || echo "en"
}

clean_text() {
  local text="$1"
  text=$(echo "$text" | perl -0pe 's/<(\w[\w-]*)(?:\s[^>]*)?>[\s\S]*?<\/\1>//g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed 's/<[^>]*>//g')
  text=$(echo "$text" | perl -0pe 's/```[\s\S]*?```//g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed 's/`[^`]*`//g')
  text=$(echo "$text" | sed -E 's/!\[[^]]*\]\([^)]*\)//g')
  text=$(echo "$text" | sed -E 's/\[([^]]*)\]\([^)]*\)/\1/g')
  text=$(echo "$text" | sed 's/[#*_~<>[\]()!]//g')
  text=$(echo "$text" | sed -E 's|https?://[^ ]*||g; s|file://[^ ]*||g')
  text=$(echo "$text" | tr -s '[:space:]' ' ')
  text="${text## }"; text="${text%% }"
  local again=true
  while $again; do
    again=false; local before="$text"
    text=$(echo "$text" | sed -E 's/^[Hh][Ee][Yy][,;]? //;s/^[Hh][Ii][,;]? //;s/^[Hh][Ee][Ll][Ll][Oo][,;]? //;s/^[Hh][Oo][Ll][Aa][,;]? //')
    text=$(echo "$text" | sed -E -e "s/^[Pp]lease //i" -e "s/^[Pp]or favor //i")
    text=$(echo "$text" | sed -E -e "s/^[Ii] would like to //i" -e "s/^[Ii]'d like to //i" -e "s/^[Ii] need to //i" -e "s/^[Ii] want to //i" -e "s/^[Ii] need //i" -e "s/^[Ii] want //i")
    text=$(echo "$text" | sed -E -e "s/^[Cc]an you //i" -e "s/^[Cc]ould you //i" -e "s/^[Ww]ould you //i" -e "s/^[Hh]elp me //i" -e "s/^[Ww]e need to //i" -e "s/^[Ll]et's //i")
    text=$(echo "$text" | sed -E -e "s/^[Nn]ecesito ayuda con //i" -e "s/^[Nn]ecesito ayuda //i" -e "s/^[Nn]ecesito //i" -e "s/^[Qq]uiero //i" -e "s/^[Pp]uedes //i" -e "s/^[Aa]yudame a //i" -e "s/^[Aa]yudame //i")
    text=$(echo "$text" | sed -E 's/^[,;: ]+//')
    text="${text## }"; text="${text%% }"
    [[ "$text" != "$before" ]] && again=true
  done
  text=$(echo "$text" | sed -E 's/[.!?;]( |$).*//')
  text="${text## }"; text="${text%% }"
  echo "$text"
}

_clean_token() {
  echo "$1" | sed 's/[^a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÑÇ-]//g'
}

extract_topic() {
  local text="$1"; [[ -z "$text" ]] && return
  local cleaned; cleaned=$(clean_text "$text"); [[ -z "$cleaned" ]] && return
  local -a compound_words=() other_words=() verb_words=()
  local seen=" "
  for w in $cleaned; do
    [[ "$w" == -* || "$w" == /* ]] && continue
    local clean; clean=$(_clean_token "$w")
    [[ -z "$clean" || ${#clean} -lt 2 ]] && continue
    local cl; cl=$(strip_accents "$(echo "$clean" | tr '[:upper:]' '[:lower:]')")
    # Deduplicate
    [[ "$seen" == *" $cl "* ]] && continue
    seen+="$cl "
    in_list "$cl" "$STOP_WORDS" && continue
    if in_list "$cl" "$ACTION_VERBS"; then verb_words+=("$clean")
    elif is_spanish_filtered_form "$cl"; then verb_words+=("$clean")
    elif in_list "$cl" "$COMPOUND_TERMS"; then compound_words+=("$clean")
    else other_words+=("$clean"); fi
  done
  # Prioritize compound/technical terms; only add other words if needed
  local -a domain_words=()
  if [[ ${#compound_words[@]} -ge 3 ]]; then
    domain_words=("${compound_words[@]}")
  else
    domain_words=(${compound_words[@]+"${compound_words[@]}"} ${other_words[@]+"${other_words[@]}"})
  fi
  local -a words=(${domain_words[@]+"${domain_words[@]:0:4}"})
  if [[ ${#words[@]} -eq 0 ]] && [[ ${#verb_words[@]} -gt 0 ]]; then
    words=(${verb_words[@]+"${verb_words[@]:0:2}"})
  elif [[ ${#words[@]} -eq 1 ]] && [[ ${#verb_words[@]} -gt 0 ]]; then
    words+=("${verb_words[0]}")
  fi
  [[ ${#words[@]} -eq 0 ]] && return
  if [[ ${#words[@]} -eq 1 && ${#words[0]} -lt 4 ]]; then
    for w in $cleaned; do
      [[ ${#words[@]} -ge 2 ]] && break
      local clean; clean=$(_clean_token "$w")
      [[ -z "$clean" || ${#clean} -lt 2 ]] && continue
      local cl; cl=$(strip_accents "$(echo "$clean" | tr '[:upper:]' '[:lower:]')")
      in_list "$cl" "$STOP_WORDS" && continue
      local wl; wl=$(echo "${words[0]}" | tr '[:upper:]' '[:lower:]')
      [[ "$cl" == "$wl" ]] && continue
      (in_list "$cl" "$ACTION_VERBS" || in_list "$cl" "$COMPOUND_TERMS") && words+=("$clean")
    done
  fi
  words=("${words[@]:0:4}"); [[ ${#words[@]} -eq 0 ]] && return
  [[ ${#words[@]} -eq 1 && ${#words[0]} -lt 4 ]] && return
  local topic=""
  for w in "${words[@]}"; do
    local cap; cap=$(capitalize "$w")
    [[ -z "$topic" ]] && topic="$cap" || topic="$topic $cap"
  done
  if [[ ${#topic} -gt 50 ]]; then
    local n=${#words[@]}
    while [[ ${#topic} -gt 50 && $n -gt 2 ]]; do
      (( n-- )); topic=""
      for (( i=0; i<n; i++ )); do
        local cap; cap=$(capitalize "${words[$i]}")
        [[ -z "$topic" ]] && topic="$cap" || topic="$topic $cap"
      done
    done
    [[ ${#topic} -gt 50 ]] && topic="${topic:0:50}" && topic="${topic%% }"
  fi
  local wcount=0 valid=false
  for w in $topic; do (( wcount++ )); [[ ${#w} -ge 4 ]] && valid=true; done
  ! $valid && [[ $wcount -lt 2 ]] && return
  echo "$topic"
}

main() {
  [[ $# -lt 1 ]] && echo "" && exit 0
  local text lang topic
  text=$(extract_user_text "$1") || text=""
  [[ -z "$text" ]] && echo "" && exit 0
  lang=$(detect_language "$text")
  topic=$(extract_topic "$text") || topic=""
  [[ -n "$topic" ]] && echo "${lang}:${topic}" || echo ""
  exit 0
}
main "$@"
