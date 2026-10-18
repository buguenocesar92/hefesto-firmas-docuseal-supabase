#!/bin/sh
set -eu
[ "$SUPABASE_DEDICATED_CONFIRMED" = true ] || { echo 'Confirme proyecto Supabase exclusivo'; exit 1; }
[ "$SUPABASE_DATA_API_DISABLED" = true ] || { echo 'Desactive Data API y confirme variable'; exit 1; }
# CA obligatoria solo con verify-full (default). Si el usuario fija
# DB_SSLMODE a otro modo (disable/require/prefer), puede omitir certs/ca.crt.
if [ "${PGSSLMODE:-verify-full}" = "verify-full" ]; then
    [ -s "$PGSSLROOTCERT" ] || { echo 'Falta certificado CA'; exit 1; }
fi
export PGCONNECT_TIMEOUT=15
psql --no-psqlrc -v ON_ERROR_STOP=1 -v app_role="${PGUSER:-docuseal_app}" -f /opt/hefesto/preflight.sql
