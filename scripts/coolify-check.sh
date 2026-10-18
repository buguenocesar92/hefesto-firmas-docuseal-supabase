#!/usr/bin/env bash
# Verifica que los compose del repo cumplen el contrato de Coolify.
# Sale con codigo != 0 y mensaje 'servicio: motivo' si algo no cumple.
# Invocacion: bash scripts/coolify-check.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Solo compose.yaml: compose.bootstrap.yaml queda fuera del contrato
# (ver punto 7 del contrato).
COMPOSE_FILE="$ROOT/compose.yaml"
if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo "Falta $COMPOSE_FILE" >&2
    exit 2
fi

# .env temporal con valores ficticios no secretos. Las variables se
# extraen dinamicamente del compose para no dejar ninguna sin
# ejercitar (Tarea 1.1 del plan).
ENV_FILE="$(mktemp -t coolify-check.XXXXXX.env)"
trap 'rm -f "$ENV_FILE"' EXIT
: > "$ENV_FILE"

VARS="$(grep -oE '\$\{[A-Z_][A-Z0-9_]*' "$COMPOSE_FILE" | sort -u | sed 's/^\${//')"
while IFS= read -r VAR; do
    [[ -z "$VAR" ]] && continue
    case "$VAR" in
        # Host o URL: dominio ficticio invalido.
        DB_HOST|PUBLIC_URL|SMTP_HOST|SMTP_FROM)
            echo "$VAR=https://ejemplo.invalid" >> "$ENV_FILE"
            ;;
        # Parametrizaciones que el contrato exige para supabase-pg.
        DB_NAME)
            echo "DB_NAME=mvp_prueba" >> "$ENV_FILE"
            ;;
        DB_SSLMODE)
            echo "DB_SSLMODE=disable" >> "$ENV_FILE"
            ;;
        # Resto: cadena no secreta.
        *)
            echo "$VAR=VALOR_FICTICIO_NO_SECRETO" >> "$ENV_FILE"
            ;;
    esac
done <<< "$VARS"

# Renderizar el compose con un --project-name explicito para poder detectar
# si el 'name:' viene del YAML (fijo) o lo pone Docker (Coolify lo asigna).
PROJ_NAME="coolify_check_$$"
RENDER_STDERR="$(mktemp -t coolify-check.stderr.XXXXXX)"
trap 'rm -f "$ENV_FILE" "$RENDER_STDERR"' EXIT
if ! RENDERED="$(docker compose --project-name "$PROJ_NAME" --project-directory "$ROOT" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config --format json 2>"$RENDER_STDERR")"; then
    echo "FAIL: compose no renderiza" >&2
    cat "$RENDER_STDERR" >&2
    exit 1
fi
if [[ -s "$RENDER_STDERR" ]]; then
    echo "---- stderr de docker compose config ----" >&2
    cat "$RENDER_STDERR" >&2
    echo "---- fin stderr ----" >&2
fi

if [[ -z "$RENDERED" ]]; then
    echo "FAIL: docker compose config devolvio vacio" >&2
    exit 1
fi

# Helper: ejecuta jq sobre RENDERED y devuelve su salida (string vacia si no hay resultados).
jq_render() { printf '%s' "$RENDERED" | jq -r "$@"; }

# Contrato punto 2: sin 'name:' fijo en la raiz (Coolify pone el nombre de proyecto).
# Si el render respeta --project-name, el YAML no lo fuerza.
RENDERED_NAME="$(printf '%s' "$RENDERED" | jq -r '.name // ""')"
if [[ "$RENDERED_NAME" != "$PROJ_NAME" ]]; then
    echo "FAIL raiz: 'name:' de proyecto fijo ($RENDERED_NAME) — Coolify debe poder asignarlo" >&2
    exit 1
fi

# Contrato punto 2: redes declaradas no pueden llevar 'name:' fijo sin variable.
# Una red declarada en el YAML con 'name:' explicito es fija; Coolify no puede
# prefijarla. Las redes auto-generadas por docker (formato '<proyecto>_<clave>')
# son validas porque Coolify asigna el nombre de proyecto.
BAD_NET="$(jq_render --arg proj "$PROJ_NAME" '
    .networks // {} | to_entries[] |
    select(.value.name != null) |
    select(.value.name != ($proj + "_" + .key)) |
    "\(.key):name=\(.value.name)"
')"
if [[ -n "$BAD_NET" ]]; then
    echo "FAIL red: $BAD_NET" >&2
    exit 1
fi

# Contrato punto 2: volumenes sin 'name:' fijo. Si el compose usa
# ${VOLUME_PREFIX}-algo, se acepta porque Coolify puede prefijar el
# nombre; el valor inyectado es el que aparece en el render.
VOL_PREFIX="$(grep -E '^VOLUME_PREFIX=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
RENDERED_VOL="$(jq_render '.volumes // {} | to_entries[] | "\(.key)=\(.value.name // "")"')"
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    vol="${line%%=*}"
    name="${line#*=}"
    if [[ -z "$name" ]]; then
        echo "FAIL volumen: $vol sin nombre asignado" >&2
        exit 1
    fi
    # Si el nombre contiene el prefijo inyectado, Coolify puede
    # prefijarlo de forma compatible. Si es un literal sin variable
    # (no contiene el prefijo de prueba), es un 'name:' fijo.
    if [[ "$name" != *"$VOL_PREFIX"* ]]; then
        echo "FAIL volumen: $vol tiene 'name:' fijo sin variable ($name)" >&2
        exit 1
    fi
done <<< "$RENDERED_VOL"

# Contrato punto 1: servicios sin 'profiles' no deben colarse.
BAD="$(jq_render --arg root "$ROOT" '
    .services | to_entries[] |
    select(((.value.profiles // []) - ["default"]) | length == 0) |
    .key as $svc | .value |
    [
        (select(.ports != null)                      | "ports"),
        (select(.container_name != null)             | "container_name"),
        (select(.privileged == true)                 | "privileged"),
        (select((.cap_add // []) | length > 0)       | "cap_add"),
        (select((.devices // []) | length > 0)       | "devices"),
        (select(.network_mode == "host")             | "network_mode:host"),
        (select(.pid == "host")                      | "pid:host"),
        (select(.ipc == "host")                      | "ipc:host"),
        (select((.security_opt // []) | any(test("unconfined"))) | "security_opt:unconfined"),
        (select((.volumes // []) | map(select(type == "object") | .source // "") | any(test("(^|/)run/docker\\.sock$"))) | "docker.sock"),
        (select((.volumes // []) | map(select(type == "object") | .source // "") | any((startswith("/") and (startswith($root + "/") | not)) or test("/\\.\\./") or test("^\\.\\./"))) | "bind_fuera_repo")
    ] as $bad |
    if ($bad | length) > 0 then "\($svc):\($bad | join(","))" else empty end
')"
if [[ -n "$BAD" ]]; then
    echo "FAIL servicio: $BAD" >&2
    exit 1
fi

# supabase-pg: DB_NAME y DB_SSLMODE deben llegar al DSN/variables del servicio web.
APP_ENV="$(printf '%s' "$RENDERED" | jq -c '.services.app.environment // {}')"
HAS_NAME="$(printf '%s' "$APP_ENV" | jq -r 'to_entries[] | select(.key | test("DATABASE_URL|PGDATABASE")) | .value')"
HAS_MODE="$(printf '%s' "$APP_ENV" | jq -r 'to_entries[] | select(.key | test("DATABASE_URL|SSLMODE")) | .value')"

if ! grep -q "mvp_prueba" <<<"$HAS_NAME"; then
    echo "FAIL supabase-pg: DB_NAME=mvp_prueba no llega al servicio web" >&2
    exit 1
fi
if ! grep -q "disable" <<<"$HAS_MODE"; then
    echo "FAIL supabase-pg: DB_SSLMODE=disable no llega al servicio web" >&2
    exit 1
fi

# Regresion 1 (revision-1): con DB_SSLROOTCERT sin definir y DB_SSLMODE=verify-full
# el DATABASE_URL debe llevar sslrootcert=/certs/ca.crt para que libpq no
# busque ~/.postgresql/root.crt cuando sslmode es verify-full.
STRICT_ENV="$(mktemp -t coolify-check.strict.XXXXXX.env)"
trap 'rm -f "$ENV_FILE" "$RENDER_STDERR" "$STRICT_ENV"' EXIT
cp "$ENV_FILE" "$STRICT_ENV"
# Forzar verify-full y quitar DB_SSLROOTCERT del env ficticio.
sed -i 's/^DB_SSLMODE=.*/DB_SSLMODE=verify-full/' "$STRICT_ENV"
sed -i '/^DB_SSLROOTCERT=/d' "$STRICT_ENV"
if ! STRICT_RENDERED="$(docker compose --project-name "${PROJ_NAME}_strict" --project-directory "$ROOT" -f "$COMPOSE_FILE" --env-file "$STRICT_ENV" config --format json 2>"$RENDER_STDERR")"; then
    echo "FAIL: compose no renderiza con DB_SSLMODE=verify-full y DB_SSLROOTCERT vacia" >&2
    cat "$RENDER_STDERR" >&2
    exit 1
fi
STRICT_DSN="$(printf '%s' "$STRICT_RENDERED" | jq -r '.services.app.environment.DATABASE_URL // ""')"
if [[ "$STRICT_DSN" != *"sslrootcert=/certs/ca.crt"* ]]; then
    echo "FAIL supabase-pg: con DB_SSLMODE=verify-full y DB_SSLROOTCERT vacia el DATABASE_URL debe llevar 'sslrootcert=/certs/ca.crt' (libpq no debe depender de ~/.postgresql/root.crt)" >&2
    echo "      DATABASE_URL=$STRICT_DSN" >&2
    exit 1
fi

echo "OK: compose.yaml cumple el contrato de Coolify"