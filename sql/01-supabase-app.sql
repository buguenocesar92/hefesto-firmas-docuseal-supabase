-- SOLO en proyecto Supabase nuevo dedicado a datos de DocuSeal.
-- Ejecutar con postgres en SQL Editor. No borra datos.
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='public') THEN
  RAISE EXCEPTION 'public debe estar vacio';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='docuseal_app') THEN
  CREATE ROLE docuseal_app LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
 END IF;
END $$;
GRANT CONNECT ON DATABASE postgres TO docuseal_app;
GRANT USAGE, CREATE ON SCHEMA public TO docuseal_app;
ALTER ROLE docuseal_app IN DATABASE postgres SET search_path=public,extensions;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE docuseal_app IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE docuseal_app IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE docuseal_app IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
-- Asignar la clave generada en .env mediante psql administrativo: \password docuseal_app

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO docuseal_app;
