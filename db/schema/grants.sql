DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'inspector'
    ) THEN
        CREATE ROLE inspector
        WITH LOGIN PASSWORD 'NetoSQL2025';
    END IF;
END;
$$;

ALTER ROLE inspector
WITH LOGIN PASSWORD 'NetoSQL2025';

GRANT ALL PRIVILEGES ON SCHEMA sorokin_food TO inspector;

GRANT ALL PRIVILEGES ON ALL TABLES
IN SCHEMA sorokin_food TO inspector;

GRANT ALL PRIVILEGES ON ALL SEQUENCES
IN SCHEMA sorokin_food TO inspector;

GRANT EXECUTE ON ALL ROUTINES
IN SCHEMA sorokin_food TO inspector;

GRANT USAGE ON SCHEMA exts TO inspector;

GRANT USAGE ON SCHEMA information_schema TO inspector;

GRANT USAGE ON SCHEMA pg_catalog TO inspector;

GRANT EXECUTE ON FUNCTION exts.uuid_generate_v4()
TO inspector;

ALTER ROLE inspector
SET search_path TO sorokin_food, exts, public;
