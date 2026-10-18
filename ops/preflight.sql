-- Acepta el rol esperado como variable psql (:'app_role') y lo expone
-- como GUC de sesion. Asi, dentro del bloque DO $$ se puede leer con
-- current_setting('hefesto.app_role') sin depender de psql variables.
SELECT set_config('hefesto.app_role', :'app_role', false);
DO $$
DECLARE v integer; r text; app_role text;
BEGIN
  v := current_setting('server_version_num')::int / 10000;
  IF v NOT IN (16,17) THEN RAISE EXCEPTION 'Validar version PostgreSQL: paquete admite16/17'; END IF;
  app_role := current_setting('hefesto.app_role');
  IF current_user <> app_role THEN RAISE EXCEPTION 'Usar rol % (conectado como %)', app_role, current_user; END IF;
  IF NOT has_schema_privilege(current_user,'public','USAGE') OR NOT has_schema_privilege(current_user,'public','CREATE') THEN
    RAISE EXCEPTION 'Faltan permisos del esquema';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='public' AND tableowner <> app_role) THEN
    RAISE EXCEPTION 'Hay tablas de otro propietario; usar proyecto exclusivo';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='public') AND
    (to_regclass('public.submissions') IS NULL OR to_regclass('public.users') IS NULL) THEN
    RAISE EXCEPTION 'Base no vacia sin marcadores DocuSeal; revisar antes de migrar';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='btree_gin') THEN RAISE EXCEPTION 'Falta btree_gin'; END IF;
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname=r) AND EXISTS(
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind IN ('r','p') AND has_table_privilege(r,c.oid,'SELECT,INSERT,UPDATE,DELETE')
    ) THEN RAISE EXCEPTION 'Tablas accesibles por rol API %',r; END IF;
  END LOOP;
END $$;
SELECT 'Preflight de permisos y base completado' AS resultado;
