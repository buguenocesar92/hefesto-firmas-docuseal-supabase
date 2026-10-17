#!/bin/sh
set -eu
if [ "${BOOTSTRAP_MODE:-false}" != true ]; then
  [ "${INITIAL_SETUP_COMPLETE:-false}" = true ] || { echo 'Complete instalación privada'; exit 1; }
  [ "${SMTP_READY:-false}" = true ] || { echo 'Configure SMTP y pruebe entrega'; exit 1; }
  case "$APP_URL" in https://*) ;; *) echo 'Se requiere HTTPS'; exit 1;; esac
fi
cd /app
exec /app/bin/bundle exec puma -C /app/config/puma.rb --dir /app
