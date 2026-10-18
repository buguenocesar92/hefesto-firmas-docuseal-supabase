#!/bin/sh
set -eu
if [ "${BOOTSTRAP_MODE:-false}" != true ]; then
  [ "${INITIAL_SETUP_COMPLETE:-false}" = true ] || { echo 'Complete instalación privada'; exit 1; }
  case "$APP_URL" in https://*) ;; *) echo 'Se requiere HTTPS'; exit 1;; esac
fi
# Con SMTP_READY=false el correo queda desactivado: vaciamos los
# parametros SMTP para que DocuSeal use el delivery null por defecto
# y no aborte el arranque por falta de SMTP real.
if [ "${SMTP_READY:-false}" != true ]; then
  unset SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_FROM SMTP_ENABLE_STARTTLS SMTP_ENABLE_SSL SMTP_SSL_VERIFY
fi
cd /app
exec /app/bin/bundle exec puma -C /app/config/puma.rb --dir /app
