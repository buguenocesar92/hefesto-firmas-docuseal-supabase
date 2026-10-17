# Aceptación pendiente en servidor
- `docker compose config --quiet` con .env real; confirmar CA y conexión verify-full.
- Preflight: rechaza proyecto no confirmado, CA ausente y tablas de otra app.
- Crear propietario solo por túnel; comprobar acceso público después del alta.
- Migraciones PostgreSQL16/17 y extensión btree_gin sin privilegios de superusuario para la app.
- Dos firmantes completan PDF; descargar documentos y evidencia disponible.
- Correos primero Mailpit; luego destinatario real autorizado. Revisar fallos: upstream puede no elevar errores de entrega.
- Reinicio conserva documentos, claves y jobs; revisar permisos UID2000.
- Backup y restauración en proyecto/volumen nuevos: cuentas, plantillas y PDF se conservan; no se envían mensajes duplicados desde ensayo.
- Renovación TLS, espacio, latencia, tareas de correo, alertas y retención acordadas.

Pruebas locales del kit: parseo YAML/Python, shell syntax, generación exclusiva de secretos y validación del ZIP. No equivalen a ejecutar la aplicación.
