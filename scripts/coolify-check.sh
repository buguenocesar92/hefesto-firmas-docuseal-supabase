#!/usr/bin/env bash
# Verifica que los compose del repo cumplen el contrato de Coolify.
# Sale con código != 0 y mensaje 'servicio: motivo' si algo no cumple.
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

# .env temporal con valores ficticios no secretos.
ENV_FILE="$(mktemp -t coolify-check.XXXXXX.env)"
trap 'rm -f "$ENV_FILE"' EXIT

cat > "$ENV_FILE" <<'EOF'
DB_HOST=db.ejemplo.invalid
DB_PASSWORD=VALOR_FICTICIO_NO_SECRETO
PUBLIC_URL=https://ejemplo.invalid
SECRET_KEY_BASE=VALOR_FICTICIO_NO_SECRETO
ENCRYPTION_SECRET=VALOR_FICTICIO_NO_SECRETO
SUPABASE_DEDICATED_CONFIRMED=true
SUPABASE_DATA_API_DISABLED=true
INITIAL_SETUP_COMPLETE=true
SMTP_READY=true
SMTP_HOST=smtp.ejemplo.invalid
SMTP_USERNAME=VALOR_FICTICIO_NO_SECRETO
SMTP_PASSWORD=VALOR_FICTICIO_NO_SECRETO
SMTP_FROM=firmas@ejemplo.invalid
# Variables que el contrato exige parametrizar.
DB_SSLMODE=disable
DB_NAME=mvp_prueba
DB_ALLOW_INTERNAL_HOST=true
EOF

# Renderizar el compose con un --project-name explicito para poder detectar
# si el 'name:' viene del YAML (fijo) o lo pone Docker (Coolify lo asigna).
# stderr (WARNING de Docker) se descarta: no afecta el JSON.
PROJ_NAME="coolify_check_$$"
if ! RENDERED="$(docker compose --project-name "$PROJ_NAME" --project-directory "$ROOT" -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config --format json 2>/dev/null)"; then
    echo "FAIL: compose no renderiza" >&2
    exit 1
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

echo "OK: compose.yaml cumple el contrato de Coolify"