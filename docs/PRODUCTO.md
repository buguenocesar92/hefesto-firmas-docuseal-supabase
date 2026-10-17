# Oferta Hefesto
Servicio sugerido: implementación por cliente + mensualidad de hosting, soporte, respaldos y actualizaciones. Cotizar según usuarios, almacenamiento, solicitudes y SLA; no se incluyen precios de licencias ni correo. Una instancia por cliente simplifica aislamiento y traspaso.

Incluido por el producto abierto: edición visual de PDFs/campos, varios firmantes, plantillas, API y webhooks según upstream. El kit configura infraestructura, no crea plantillas comerciales ni firma documentos reales.

Pro según upstream: marca propia/white-label, roles avanzados, recordatorios automáticos, SMS, condiciones/fórmulas, carga masiva, SSO y ciertos flujos embebidos/de generación. Validar licencia vigente antes de vender esas funciones. No se eliminó atribución DocuSeal: AGPLv3 con términos adicionales Section7(b). Distribuir modificaciones del producto requeriría cumplir sus obligaciones; este kit conserva imagen oficial.

La entrega no certifica firma avanzada, identidad de firmantes ni validez jurídica de un contrato. Definir con el cliente qué documentos y nivel de identidad requiere su proceso.

Supabase es PostgreSQL remoto. El diseño no transforma DocuSeal en aplicación Supabase ni usa su Auth; no aplicar RLS genérico a tablas Rails. Data API desactivada y rol exclusivo restringen acceso desde APIs públicas.
