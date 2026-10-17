# Restauración y traspaso
1. Preparar destino aislado con la misma versión 3.3.2, un proyecto Supabase nuevo y VOLUME_PREFIX nuevo. No apuntar al origen.
2. Recuperar .env del respaldo por canal seguro: conservar exactamente SECRET_KEY_BASE y ENCRYPTION_SECRET. Cambiar solo conexión a base, dominio y volumen según destino. Nunca regenerar claves: protegen configuración cifrada y sesiones.
3. Preparar SQL y CA en destino. Mantener app detenida. `docker compose run --rm preflight`.
4. `python3 scripts/restore_db.py /ruta/respaldo`. Exige public vacío; no borra tablas existentes. btree_gin debe estar preinstalada en extensions. El respaldo cubre public, no configuración administrada de Supabase.
5. `python3 scripts/restore_files.py /ruta/respaldo`. Exige volumen vacío, valida SHA256/rutas y ajusta propietario2000. Incluye adjuntos y dump Redis nativo. No restaurar una cola antigua en producción sin revisar posibles notificaciones pendientes.
6. Primer arranque aislado con compose.bootstrap.yaml: fuerza Mailpit en lugar de SMTP externo. No adjuntar el proxy público. Examinar documentos, cuentas, trabajos pendientes y errores. No efectuar pruebas que modifiquen el original.
7. Detener bootstrap; configurar dominio final y SMTP. Realizar prueba autorizada, cambiar DNS durante ventana de mantenimiento, comprobar enlaces y retirar origen solo tras aceptación. Las solicitudes antiguas necesitan conservar el dominio o una redirección compatible; no asumir migración automática de enlaces.

Un backup fallido no lleva manifest completed; no restaurarlo. Si falla una restauración a medias, usar un destino nuevo, no relanzar sobre datos parciales. Los hashes detectan corrupción, no autentican un respaldo de origen desconocido.

Odoo: integración futura por API/webhooks y/o adjuntos. Mapear cliente, documento, referencia comercial, ID de solicitud, estado y PDF final. Usar credenciales exclusivamente en backend, validar eventos y consultar estado por API antes de marcar completado, deduplicar por ID y reintentar con registro. Este kit no instala un módulo Odoo ni replica sus permisos. La entrega manual de PDF y evidencia es la vía inicial disponible.
