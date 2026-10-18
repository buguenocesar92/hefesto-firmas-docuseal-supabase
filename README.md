# Hefesto Firmas · DocuSeal 3.3.2 + Supabase

Kit de despliegue nativo, sin modificar DocuSeal. Para crear plantillas PDF, colocar campos, solicitar firmas a varios participantes y descargar documentos completados. No incluye un servicio desplegado ni licencias Pro.

## Arquitectura
DocuSeal/Puma con Sidekiq y Redis local integrados por el propio upstream. Una instancia, sin escalado horizontal. Supabase aporta PostgreSQL; no se usan Supabase Auth, Storage ni Data API. Archivos, certificados y persistencia Redis quedan en el volumen /data/docuseal. La base sola no constituye respaldo completo.

## Instalación privada
Requisitos: Docker Engine + Compose v2, Python 3.11+, proyecto Supabase nuevo y exclusivo, PostgreSQL16/17, DNS y proxy TLS para producción. Dimensionamiento inicial orientativo: 2 CPU, 4GB RAM y almacenamiento según documentos; medir carga real.

1. Ejecutar `python3 scripts/configure.py`. Editar .env sin publicarlo. Usar DB_PASSWORD hexadecimal generado (no caracteres reservados de URL).
2. Ejecutar sql/01-supabase-app.sql como postgres en SQL Editor. Asignar al rol docuseal_app la clave DB_PASSWORD mediante `\password docuseal_app` en psql administrativo.
3. Desactivar Data API del proyecto. Completar DB_HOST con conexión directa puerto5432. Si requiere IPv4, usar Session Pooler5432 y DB_USER=docuseal_app.REFERENCIA. No usar Transaction Pooler6543. Descargar CA oficial a certs/ca.crt. Confirmar las dos variables SUPABASE_* solo tras realizar estas tareas.
4. `docker compose -f compose.yaml -f compose.bootstrap.yaml up -d`. El preflight verifica permisos; DocuSeal aplica migraciones nativas al iniciar.
5. Abrir http://localhost:8101. Desde otro equipo usar túnel SSH: `ssh -L 8101:127.0.0.1:8101 -L 8028:127.0.0.1:8028 usuario@servidor`. Crear el propietario y activar segundo factor si está disponible en su edición. Nunca publicar el asistente inicial.
6. Crear una plantilla PDF de prueba sin datos reales, agregar dos firmantes y revisar los enlaces capturados en http://localhost:8028 (Mailpit). Completar y descargar el PDF. Mailpit no entrega correo externo. Mantener ambos accesos privados.
7. Detener: `docker compose -f compose.yaml -f compose.bootstrap.yaml down`. No agregar -v: conserva datos.
8. Configurar PUBLIC_URL HTTPS y SMTP real, puerto465 con TLS implícito y remitente autorizado. Las variables SMTP del entorno tienen precedencia sobre la configuración en interfaz. Completar INITIAL_SETUP_COMPLETE y SMTP_READY tras verificar configuración; la prueba real de entrega forma parte de aceptación.
9. `docker compose up -d`. En Coolify importar compose.yaml, archivos ops y certs, y variables .env; conectar el dominio a app:3000. No añadir compose.bootstrap.yaml en producción. Conservar VOLUME_PREFIX si se reutilizan volúmenes; en migración usar uno nuevo.
10. Verificar login, crear solicitud a un destinatario de prueba autorizado, completar firma y descargar documento. Confirmar URL pública en todos los enlaces, TLS, correo y persistencia después del reinicio.

No ejecutar migraciones desde dos instancias. Los flags son confirmaciones operativas, no una auditoría del propietario ni del SMTP. No se han realizado envíos de correo desde este kit.

## Operación y respaldo
`python3 scripts/backup.py` detiene la app (incluidos workers/Redis), copia esquema public, volumen completo, configuración y secretos, y reinicia si estaba ejecutándose. Ejecutar después de terminar trabajos activos, sin documentos en procesamiento. Usar en modo producción compose.yaml; no durante bootstrap. Verificar salida, manifest y espacio libre. Los respaldos contienen datos privados y secretos: cifrarlos fuera del servidor, restringir acceso y aplicar retención acordada.

Restauración y traspaso: docs/RESTORE.md. Validación pendiente: docs/ACCEPTANCE.md. Oferta comercial y límites: docs/PRODUCTO.md. Base y volumen deben pertenecer al mismo respaldo.

Estado: código/configuración revisados estáticamente. No se ejecutó Docker, migraciones, firma, correo ni restauración real en este entorno. Requiere aceptación en infraestructura de Hefesto antes de ofrecerlo en producción.

## Despliegue en Coolify (MVP Hefesto)

Coolify enruta el dominio a `app:3000` y Traefik gestiona TLS, por lo que el compose no publica puertos propios ni fija `name:` de proyecto. Variables nuevas o con valores por defecto nuevos respecto a la instalación privada:

- `DB_NAME` — base dentro del Postgres compartido de Supabase. Por defecto `postgres` (uso original). Para Coolify usar `mvp_hefesto` u otro esquema dedicado por app.
- `DB_SSLMODE` — modo SSL. Por defecto `verify-full` (uso original). Coolify puede fijar `disable` cuando el Postgres va por red interna de Docker sin TLS.
- `DB_SSLROOTCERT` — ruta de la CA. Por defecto `/certs/ca.crt`. Con `DB_SSLMODE=verify-full` (o `verify-ca`) libpq exige la CA; sin definir, el `DATABASE_URL` usa la ruta por defecto. Con `DB_SSLMODE` distinto de `verify-ca`/`verify-full`, el valor se ignora.
- `DB_USER` — rol del Postgres. Por defecto `docuseal_app`. El preflight compara contra este valor (antes estaba hardcodeado).
- `BOOTSTRAP_MODE` — habilita el setup privado (primer usuario crea la cuenta admin). Por defecto `false`. **Primer arranque en Coolify:** definir `INITIAL_SETUP_COMPLETE=false`, `BOOTSTRAP_MODE=true` y entrar por la UI para crear el admin; luego pasar `BOOTSTRAP_MODE=false` e `INITIAL_SETUP_COMPLETE=true`. `start.sh` sigue exigiendo HTTPS fuera de bootstrap.
- `SMTP_READY` — por defecto `false` para no abortar el arranque. Si se pone `true`, se exigen las variables SMTP reales (el `start.sh` original bloqueaba sin esto). El correo puede quedar desactivado: con `SMTP_READY=false` los parámetros SMTP se vacían al arrancar y DocuSeal usa el delivery null.
- `SMTP_ENABLE_STARTTLS` — por defecto `false` (uso original SMTP 465 implícito).
- `SMTP_ENABLE_SSL` — por defecto `true` (uso original SMTP 465 implícito).
- `VOLUME_PREFIX` — prefijo del volumen. Coolify lo asigna; conservar valor anterior sólo para reusar volumen existente.

El healthcheck del servicio `app` usa `wget` para consultar `http://127.0.0.1:3000/up` enviando `X-Forwarded-Proto: https` para evitar la redirección 301 que `FORCE_SSL: "true"` impone a las peticiones HTTP planas (no hay TLS en ese puerto, sólo lo pone Traefik fuera del contenedor). El binario `wget` y la ruta `/up` se asumen presentes en la imagen `docuseal/docuseal:3.3.2` según la convención upstream; si en otra versión la imagen no los trae, ajustar `compose.yaml` (sustituir por `curl` u otro binario disponible).

El script `scripts/coolify-check.sh` verifica que `compose.yaml` cumple el contrato y que `DB_NAME`/`DB_SSLMODE` llegan al servicio web.
