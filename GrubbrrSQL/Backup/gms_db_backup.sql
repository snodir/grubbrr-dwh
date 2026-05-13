--
-- PostgreSQL database dump
--

\restrict qEtCU8c5oLyFw4Sin4Qi4H8NRJBR7Px27gWeKbXLrqgwpSUaKKwo5Atoe1i7Xw9

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.2

-- Started on 2026-05-13 15:53:53

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 44 (class 2615 OID 19570)
-- Name: partman; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA partman;


ALTER SCHEMA partman OWNER TO postgres;

--
-- TOC entry 51 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 6017 (class 0 OID 0)
-- Dependencies: 51
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 1279 (class 1255 OID 320242)
-- Name: audit_changes(); Type: FUNCTION; Schema: public; Owner: citus
--

CREATE FUNCTION public.audit_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- For UPDATE operations, capture both OLD and NEW values in separate JSONB columns
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO audit (
            record_id,
            operation_type,
            operation_timestamp,
            user_name,
            old_data,
            new_data
        ) VALUES (
            OLD.id,
            'UPDATE',
            CURRENT_TIMESTAMP,
            COALESCE(NEW.modified_by, 'system'),
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb
        );
        
        RETURN NEW;
    END IF;
    
    -- For DELETE operations, capture only OLD values
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit (
            record_id,
            operation_type,
            operation_timestamp,
            user_name,
            old_data,
            new_data
        ) VALUES (
            OLD.id,
            'DELETE',
            CURRENT_TIMESTAMP,
            COALESCE(OLD.modified_by, 'system'),
            row_to_json(OLD)::jsonb,
            NULL
        );
        
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.audit_changes() OWNER TO citus;

--
-- TOC entry 1096 (class 1255 OID 71431)
-- Name: convert_discount_type_to_json(); Type: FUNCTION; Schema: public; Owner: citus
--

CREATE FUNCTION public.convert_discount_type_to_json() RETURNS json
    LANGUAGE sql IMMUTABLE
    AS $_$
                      SELECT ('{"$type":"DiscountFixedAmount","Amount":0,"Kind":"DiscountFixedAmount"}')::json
                    $_$;


ALTER FUNCTION public.convert_discount_type_to_json() OWNER TO citus;

--
-- TOC entry 985 (class 1255 OID 19719)
-- Name: create_extension(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_extension(extname text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN
DISCARD TEMP;
IF extname NOT IN (
'address_standardizer',
'amcheck',
'autoinc',
'azure_storage',
'bloom',
'dict_int',
'dict_xsyn',
'insert_username',
'intagg',
'isn',
'lo',
'moddatetime',
'orafce',
'pageinspect',
'pgaudit',
'pgcrypto',
'pgrowlocks',
'pg_trgm',
'pg_visibility',
'postgis',
'postgis_raster',
'postgis_sfcgal',
'postgis_topology',
'postgres_fdw',
'refint',
'seg',
'semver',
'tcn',
'tsm_system_rows',
'tsm_system_time',
'uuid-ossp',
'vector') THEN raise 'not allowed to create this extension';
END IF;
IF extname IN ('azure_storage', 'postgis_topology') THEN
    EXECUTE pg_catalog.format('CREATE EXTENSION %I', extname);
ELSE
    EXECUTE pg_catalog.format('CREATE EXTENSION %I WITH SCHEMA public', extname);
END IF;
IF extname IN ('postgres_fdw') THEN EXECUTE pg_catalog.format('GRANT USAGE ON FOREIGN DATA WRAPPER %I TO citus WITH GRANT OPTION', extname);
END IF;
IF extname IN ('azure_storage') THEN
    GRANT azure_storage_admin TO citus WITH ADMIN OPTION;
    PERFORM azure_storage.citus_cluster_initialize();
END IF;
IF extname IN ('orafce') THEN
    REVOKE ALL ON SCHEMA utl_file FROM PUBLIC;
    REVOKE ALL ON SCHEMA utl_file FROM citus;
END IF;
END; $$;


ALTER FUNCTION public.create_extension(extname text) OWNER TO postgres;

--
-- TOC entry 821 (class 1255 OID 19720)
-- Name: drop_extension(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.drop_extension(extname text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN
DISCARD TEMP;
IF extname NOT IN (
'address_standardizer',
'amcheck',
'autoinc',
'azure_storage',
'bloom',
'dict_int',
'dict_xsyn',
'insert_username',
'intagg',
'isn',
'lo',
'moddatetime',
'mysql_fdw',
'orafce',
'pageinspect',
'pgaudit',
'pgcrypto',
'pgrowlocks',
'pg_trgm',
'pg_visibility',
'postgis',
'postgis_raster',
'postgis_sfcgal',
'postgis_tiger_geocoder',
'postgis_topology',
'postgres_fdw',
'refint',
'seg',
'semver',
'tcn',
'tsm_system_rows',
'tsm_system_time',
'uuid-ossp',
'vector') THEN raise 'not allowed to drop this extension';
END IF;
EXECUTE pg_catalog.format('DROP EXTENSION %I;', extname);
END; $$;


ALTER FUNCTION public.drop_extension(extname text) OWNER TO postgres;

--
-- TOC entry 1194 (class 1255 OID 19516)
-- Name: pg_replication_origin_create(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_create(text) RETURNS oid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_create($1) $_$;


ALTER FUNCTION public.pg_replication_origin_create(text) OWNER TO postgres;

--
-- TOC entry 1149 (class 1255 OID 19519)
-- Name: pg_replication_origin_drop(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_drop(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_drop($1) $_$;


ALTER FUNCTION public.pg_replication_origin_drop(text) OWNER TO postgres;

--
-- TOC entry 611 (class 1255 OID 19518)
-- Name: pg_replication_origin_progress(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_progress(text, boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_progress($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_progress(text, boolean) OWNER TO postgres;

--
-- TOC entry 1374 (class 1255 OID 19517)
-- Name: pg_replication_origin_session_progress(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_progress(boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_progress($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_progress(boolean) OWNER TO postgres;

--
-- TOC entry 477 (class 1255 OID 19521)
-- Name: pg_replication_origin_session_setup(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_setup(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_setup($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_setup(text) OWNER TO postgres;

--
-- TOC entry 1180 (class 1255 OID 19520)
-- Name: pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_xact_setup($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) OWNER TO postgres;

--
-- TOC entry 1195 (class 1255 OID 3663820)
-- Name: usp_prod_to_stage_migration_audit(); Type: PROCEDURE; Schema: public; Owner: citus
--

CREATE PROCEDURE public.usp_prod_to_stage_migration_audit()
    LANGUAGE plpgsql
    AS $$


BEGIN

DROP TABLE IF EXISTS temp_prod_to_stage_migration_audit;

CREATE TEMP TABLE IF NOT EXISTS temp_prod_to_stage_migration_audit(
    table_schema text COLLATE pg_catalog."default",
    table_name text COLLATE pg_catalog."default",
    key_columns jsonb,
    key_type text COLLATE pg_catalog."default",
    key_column_data_types jsonb,
    dependency_level INTEGER,
    dependency_count INTEGER,
    depends_on jsonb,
    referenced_by jsonb,  -- NEW COLUMN
    insert_watermark text COLLATE pg_catalog."default",
    insert_watermark_data_type text COLLATE pg_catalog."default",
    update_watermark text COLLATE pg_catalog."default",
    update_watermark_data_type text COLLATE pg_catalog."default",
    sql_aggregate text COLLATE pg_catalog."default"
);

WITH RECURSIVE watermark_columns AS (
    SELECT DISTINCT
        COALESCE(it.table_schema, ut.table_schema) as table_schema, 
        COALESCE(it.table_name, ut.table_name) as table_name, 
        it.column_name as insert_watermark, 
        it.data_type as insert_watermark_type,
        ut.column_name as update_watermark, 
        ut.data_type as update_watermark_type
    FROM
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('public')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'create%date%' OR a.attname LIKE 'sys%inserttime' OR a.attname LIKE 'created%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as it
    FULL OUTER JOIN  
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('public')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'update%date%' OR a.attname LIKE 'sys%updatetime' OR a.attname LIKE 'modified%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as ut
        ON it.table_schema = ut.table_schema
       AND it.table_name = ut.table_name
),
table_dependencies AS (
    -- Get all base tables in the schema
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' -- regular tables only
        AND n.nspname IN ('public')
        AND n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
),
foreign_keys AS (
    -- Extract all foreign key relationships using pg_constraint (including cross-schema)
    SELECT DISTINCT
        n1.nspname::text AS referencing_schema,
        c1.relname::text AS referencing_table,
        n2.nspname::text AS referenced_schema,
        c2.relname::text AS referenced_table,
        -- Create a combined identifier for matching
        n1.nspname::text || '.' || c1.relname::text AS referencing_full,
        n2.nspname::text || '.' || c2.relname::text AS referenced_full
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c1 ON con.conrelid = c1.oid
    JOIN pg_catalog.pg_namespace n1 ON c1.relnamespace = n1.oid
    JOIN pg_catalog.pg_class c2 ON con.confrelid = c2.oid
    JOIN pg_catalog.pg_namespace n2 ON c2.relnamespace = n2.oid
    WHERE con.contype = 'f' -- foreign key constraints
        AND n1.nspname IN ('public')
),
dependency_graph AS (
    -- Build the complete dependency graph (including cross-schema dependencies)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referenced_full) 
            FILTER (WHERE fk.referenced_full IS NOT NULL), ARRAY[]::text[]) AS depends_on
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referencing_full
    GROUP BY td.table_schema, td.table_name
),
reverse_dependency_graph AS (
    -- NEW CTE: Build reverse dependencies (which tables reference this table)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referencing_full) 
            FILTER (WHERE fk.referencing_full IS NOT NULL), ARRAY[]::text[]) AS referenced_by
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referenced_full
    GROUP BY td.table_schema, td.table_name
),
table_keys AS (
    -- Get Primary Key or Unique Key columns using pg_constraint
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name,
        CASE 
            WHEN con.contype = 'p' THEN 'PRIMARY KEY'
            WHEN con.contype = 'u' THEN 'UNIQUE'
        END AS constraint_type,
        to_jsonb(array_agg(a.attname::text ORDER BY array_position(con.conkey, a.attnum))) AS key_columns,
        -- Build JSON object of column:type pairs
        jsonb_object_agg(
            a.attname::text,
            format_type(a.atttypid, a.atttypmod)
        ) AS key_data_types,
        CASE 
            WHEN con.contype = 'p' THEN 1
            WHEN con.contype = 'u' THEN 2
        END AS key_priority
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(con.conkey)
    WHERE con.contype IN ('p', 'u') -- primary key or unique
        AND n.nspname IN ('public')
    GROUP BY n.nspname, c.relname, con.contype, con.conname
),
best_keys AS (
    -- Select the best key for each table (PK preferred over UNIQUE)
    SELECT DISTINCT ON (table_schema, table_name)
        table_schema,
        table_name,
        constraint_type,
        key_columns,
        key_data_types
    FROM table_keys
    ORDER BY table_schema, table_name, key_priority
),
dependency_levels AS (
    -- Level 0: Tables with no dependencies
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        0 AS dependency_level,
        dg.depends_on,
        ARRAY[dg.full_table_name] AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE cardinality(dg.depends_on) = 0
    
    UNION ALL
    
    -- Recursive: Calculate levels for dependent tables
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        dl.dependency_level + 1 AS dependency_level,
        dg.depends_on,
        dl.dependency_chain || dg.full_table_name AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    JOIN dependency_levels dl 
        ON dl.full_table_name = ANY(dg.depends_on)
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE NOT dg.full_table_name = ANY(dl.dependency_chain) -- Prevent circular dependencies
)

INSERT INTO temp_prod_to_stage_migration_audit
SELECT DISTINCT
    dl.table_schema,
    dl.table_name,
    dl.key_columns,
    dl.key_type,
    dl.key_data_types,
    dl.dependency_level,
    COALESCE(array_length(dl.depends_on, 1), 0) AS dependency_count,
    to_jsonb(dl.depends_on) as depends_on,
    to_jsonb(rdg.referenced_by) as referenced_by,  -- NEW COLUMN
    wc.insert_watermark,
    wc.insert_watermark_type,
    wc.update_watermark,
    wc.update_watermark_type,
    CASE WHEN (dl.key_data_types :: text LIKE '%bigint"}' OR dl.key_data_types :: text LIKE '%integer"}') AND jsonb_array_length(dl.key_columns) = 1
         THEN concat('max(', dl.key_columns ->> 0, ') as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
         ELSE concat('NULL as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
    END as sql_aggregate
FROM dependency_levels dl
LEFT JOIN watermark_columns wc
    ON dl.table_schema = wc.table_schema
    AND dl.table_name = wc.table_name
LEFT JOIN reverse_dependency_graph rdg  -- NEW JOIN
    ON dl.table_schema = rdg.table_schema
    AND dl.table_name = rdg.table_name
WHERE dl.dependency_level = (
    -- Get the maximum level for each table (in case of multiple paths)
    SELECT MAX(dl2.dependency_level)
    FROM dependency_levels dl2
    WHERE dl2.table_name = dl.table_name
        AND dl2.table_schema = dl.table_schema
);

INSERT INTO public.prod_to_stage_migration_audit (
    table_schema,
    table_name,
    key_columns,
    key_type,
    key_column_data_types,
    dependency_level,
    dependency_count,
    depends_on,
    referenced_by,  -- NEW COLUMN
    insert_watermark,
    insert_watermark_data_type,
    update_watermark,
    update_watermark_data_type,
    sql_aggregate
)
SELECT * FROM temp_prod_to_stage_migration_audit as tau
WHERE NOT EXISTS (SELECT 1 FROM public.prod_to_stage_migration_audit as pau 
                  WHERE pau.table_schema = tau.table_schema
                    AND pau.table_name = tau.table_name);

UPDATE public.prod_to_stage_migration_audit
SET table_schema = tau.table_schema,
    table_name = tau.table_name,
    key_columns = tau.key_columns,
    key_type = tau.key_type,
    key_column_data_types = tau.key_column_data_types,
    dependency_level = tau.dependency_level,
    dependency_count = tau.dependency_count,
    depends_on = tau.depends_on,
    referenced_by = tau.referenced_by,  -- NEW COLUMN
    insert_watermark = tau.insert_watermark,
    insert_watermark_data_type = tau.insert_watermark_data_type,
    update_watermark = tau.update_watermark,
    update_watermark_data_type = tau.update_watermark_data_type,
    sql_aggregate = tau.sql_aggregate
FROM temp_prod_to_stage_migration_audit as tau
WHERE prod_to_stage_migration_audit.table_schema = tau.table_schema
  AND prod_to_stage_migration_audit.table_name = tau.table_name;

UPDATE public.prod_to_stage_migration_audit
SET sql_source_query = CASE WHEN (referenced_by :: text LIKE '[]' OR referenced_by IS NULL) AND record_count < 10000000
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND record_count <= 100000
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN jsonb_array_length(key_columns) = 1 AND (key_column_data_types :: text LIKE '%bigint"}' OR key_column_data_types :: text LIKE '%integer"}')
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', key_columns ->> 0, ' >= ', COALESCE(watermark_integer_value, 0) :: text)
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' >= ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' >= ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')                            
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NULL AND record_count < 10000000 AND (referenced_by :: text LIKE '[]' OR referenced_by IS NULL)
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            ELSE concat('SELECT * FROM ', table_schema, '.', table_name)
                        END;

DROP TABLE IF EXISTS temp_prod_to_stage_migration_audit;

END;
$$;


ALTER PROCEDURE public.usp_prod_to_stage_migration_audit() OWNER TO citus;

--
-- TOC entry 2454 (class 1255 OID 19515)
-- Name: sum(public.hll); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.sum(public.hll) (
    SFUNC = public.hll_union_trans,
    STYPE = internal,
    FINALFUNC = public.hll_pack
);


ALTER AGGREGATE public.sum(public.hll) OWNER TO postgres;

--
-- TOC entry 2453 (class 1255 OID 19514)
-- Name: sum(public.hll_hashval); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.sum(public.hll_hashval) (
    SFUNC = public.hll_add_trans0,
    STYPE = internal,
    FINALFUNC = public.hll_pack
);


ALTER AGGREGATE public.sum(public.hll_hashval) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 392 (class 1259 OID 320227)
-- Name: audit; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.audit (
    audit_id bigint NOT NULL,
    record_id character varying(50) NOT NULL,
    operation_type character varying(10) NOT NULL,
    operation_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    user_name character varying(255),
    old_data jsonb NOT NULL,
    new_data jsonb,
    CONSTRAINT audit_operation_type_check CHECK (((operation_type)::text = ANY ((ARRAY['UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE public.audit OWNER TO citus;

--
-- TOC entry 391 (class 1259 OID 320226)
-- Name: audit_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: citus
--

CREATE SEQUENCE public.audit_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_audit_id_seq OWNER TO citus;

--
-- TOC entry 6027 (class 0 OID 0)
-- Dependencies: 391
-- Name: audit_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.audit_audit_id_seq OWNED BY public.audit.audit_id;


--
-- TOC entry 334 (class 1259 OID 26033)
-- Name: catalog; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.catalog (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    organization_id character varying(40) NOT NULL,
    pos_sync_settings jsonb,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    gem_company_id character varying(255),
    gem_location_id character varying(255),
    sync_in_progress boolean DEFAULT false NOT NULL,
    is_standalone boolean DEFAULT false NOT NULL,
    is_master boolean DEFAULT false NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    is_ecm_enabled boolean DEFAULT false NOT NULL
);


ALTER TABLE public.catalog OWNER TO citus;

--
-- TOC entry 366 (class 1259 OID 28232)
-- Name: catalog_entity_pos_connector_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.catalog_entity_pos_connector_glue (
    catalog_entity_id character varying(50) NOT NULL,
    pos_connector_configuration_id character varying(50) NOT NULL,
    last_synced_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_deleted boolean NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.catalog_entity_pos_connector_glue OWNER TO citus;

--
-- TOC entry 367 (class 1259 OID 28238)
-- Name: catalog_pos_connector_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.catalog_pos_connector_glue (
    catalog_id character varying(50) NOT NULL,
    pos_connector_configuration_id character varying(50) NOT NULL,
    is_master boolean NOT NULL,
    is_active boolean NOT NULL,
    sync_in_progress boolean DEFAULT false NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    pos_mapping_name character varying(100),
    pos_integration_name character varying(100),
    entity86_reset_setting smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.catalog_pos_connector_glue OWNER TO citus;

--
-- TOC entry 331 (class 1259 OID 26017)
-- Name: catalog_sync_history; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.catalog_sync_history (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    started_on timestamp without time zone NOT NULL,
    finished_on timestamp without time zone,
    error_message text,
    change_set text,
    status integer NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_snapshot_group_id character varying(255),
    created_by character varying(255),
    modified_by character varying(255),
    sync_type character varying(100) DEFAULT 'SYNC'::character varying NOT NULL,
    pos_snapshot_type character varying(100),
    pos_connector_config_id character varying(255)
);


ALTER TABLE public.catalog_sync_history OWNER TO citus;

--
-- TOC entry 335 (class 1259 OID 26042)
-- Name: category_displayable_item; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.category_displayable_item (
    id character varying(50) NOT NULL,
    category_master_id character varying(50),
    item_master_id character varying(50),
    item_variation_id character varying(50),
    pre_selected_combo_id character varying(50),
    sub_category_id character varying(50),
    combo_id character varying(50),
    display_order integer,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    combo_family_id character varying(50),
    catalog_id character varying(50),
    pos_linked_entity_id character varying(50),
    pos_sync_enable boolean DEFAULT false,
    pos_overrided_fields character varying[],
    created_by character varying(255),
    modified_by character varying(255),
    source jsonb
);


ALTER TABLE public.category_displayable_item OWNER TO citus;

--
-- TOC entry 338 (class 1259 OID 26064)
-- Name: category_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.category_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    catalog_id character varying(50) NOT NULL,
    description text NOT NULL,
    description_localized jsonb,
    media jsonb,
    pos_linked_entity_id character varying(50),
    pos_overrided_fields character varying[],
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    number_of_items integer DEFAULT 0 NOT NULL,
    number_of_sub_categories integer DEFAULT 0 NOT NULL,
    number_of_item_variations integer DEFAULT 0 NOT NULL,
    number_of_combos integer DEFAULT 0 NOT NULL,
    number_of_combo_families integer DEFAULT 0 NOT NULL,
    availability_schedule jsonb,
    display_metadata jsonb,
    is_alcoholic boolean,
    created_by character varying(255),
    modified_by character varying(255),
    show_categoryname_in_header boolean,
    channels character varying[],
    source jsonb,
    multi_media jsonb,
    item_level_smart_upsell_enabled boolean DEFAULT false NOT NULL,
    is_pinned boolean DEFAULT false NOT NULL
);


ALTER TABLE public.category_master OWNER TO citus;

--
-- TOC entry 381 (class 1259 OID 177975)
-- Name: category_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.category_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT category_parent_child_mapping_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.category_parent_child_mapping OWNER TO citus;

--
-- TOC entry 340 (class 1259 OID 26080)
-- Name: combo_component; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_component (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    type character varying(50),
    pos_linked_entity_id character varying(50),
    min_selection integer,
    max_selection integer,
    is_active boolean NOT NULL,
    is_default boolean,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    media jsonb,
    pos_overrided_fields character varying[],
    clone_from_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255),
    source jsonb,
    multi_media jsonb,
    display_order integer DEFAULT 0
);


ALTER TABLE public.combo_component OWNER TO citus;

--
-- TOC entry 339 (class 1259 OID 26073)
-- Name: combo_component_item_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_component_item_glue (
    id character varying(50) NOT NULL,
    combo_component_id character varying(50),
    item_master_id character varying(50) NOT NULL,
    display_order integer,
    pos_linked_entity_id character varying(50),
    combo_component_item_glue_grouping_id character varying(50),
    is_default boolean,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    group_index integer,
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[] DEFAULT ARRAY[]::character varying[],
    source jsonb
);


ALTER TABLE public.combo_component_item_glue OWNER TO citus;

--
-- TOC entry 369 (class 1259 OID 34375)
-- Name: combo_component_item_glue_group; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_component_item_glue_group (
    id character varying(50) NOT NULL,
    combo_component_id character varying(50),
    name character varying(50),
    display_order integer,
    pos_linked_entity_id character varying(50),
    catalog_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    is_default boolean,
    pos_overrided_fields character varying[] DEFAULT ARRAY[]::character varying[],
    source jsonb,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb
);


ALTER TABLE public.combo_component_item_glue_group OWNER TO citus;

--
-- TOC entry 342 (class 1259 OID 26096)
-- Name: combo_family; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_family (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    catalog_id character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    media jsonb,
    pos_linked_entity_id character varying(50),
    name_localized jsonb,
    display_name text,
    promotional_details jsonb,
    availability_schedule jsonb,
    calories text,
    display_name_localized jsonb,
    created_by character varying(255),
    modified_by character varying(255),
    family_type smallint DEFAULT 0 NOT NULL,
    channels character varying[] DEFAULT '{}'::character varying[],
    description text,
    description_localized jsonb,
    multi_media jsonb
);


ALTER TABLE public.combo_family OWNER TO citus;

--
-- TOC entry 341 (class 1259 OID 26089)
-- Name: combo_family_member; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_family_member (
    id character varying(50) NOT NULL,
    combo_family_id character varying(50),
    combo_master_id character varying(50),
    display_order integer,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    item_master_id character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    display_name text,
    is_default boolean,
    catalog_id character varying(50),
    display_name_prefix_text_localized jsonb
);


ALTER TABLE public.combo_family_member OWNER TO citus;

--
-- TOC entry 377 (class 1259 OID 69842)
-- Name: combo_item_modifier_group_override; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_item_modifier_group_override (
    id character varying(50) NOT NULL,
    catalog_id character varying(255) NOT NULL,
    combo_id character varying(50) NOT NULL,
    item_id character varying(50) NOT NULL,
    modifier_group_id character varying(50) NOT NULL,
    is_invisible boolean NOT NULL,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    free_count numeric,
    combo_component_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[],
    free_modifier_swaps integer
);


ALTER TABLE public.combo_item_modifier_group_override OWNER TO citus;

--
-- TOC entry 378 (class 1259 OID 69851)
-- Name: combo_item_modifier_override; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_item_modifier_override (
    id character varying(50) NOT NULL,
    catalog_id character varying(255),
    combo_id character varying(50) NOT NULL,
    item_id character varying(50) NOT NULL,
    modifier_id character varying(50) NOT NULL,
    is_default boolean NOT NULL,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    is_invisible boolean DEFAULT false NOT NULL,
    pos_overrided_fields character varying[],
    display_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.combo_item_modifier_override OWNER TO citus;

--
-- TOC entry 344 (class 1259 OID 26112)
-- Name: combo_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    catalog_id character varying(50) NOT NULL,
    description text NOT NULL,
    description_localized jsonb,
    pos_linked_entity_id character varying(50),
    media jsonb NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    calories text,
    promotional_details jsonb,
    size_label character varying(255),
    size_label_localized jsonb,
    availability_schedule jsonb,
    pos_overrided_fields character varying[],
    clone_from_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255),
    channels character varying[],
    avg_rating integer,
    feedback_count integer DEFAULT 0,
    pct_response jsonb,
    display_info jsonb,
    source jsonb,
    hide_price boolean DEFAULT false,
    multi_media jsonb,
    pull_subgroups_from_categories boolean DEFAULT false NOT NULL,
    linked_category_ids text[]
);


ALTER TABLE public.combo_master OWNER TO citus;

--
-- TOC entry 343 (class 1259 OID 26105)
-- Name: combo_master_component_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_master_component_glue (
    id character varying(50) NOT NULL,
    combo_master_id character varying(50),
    combo_component_id character varying(50),
    is_default boolean NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    is_hidden boolean,
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[],
    source jsonb
);


ALTER TABLE public.combo_master_component_glue OWNER TO citus;

--
-- TOC entry 383 (class 1259 OID 178110)
-- Name: combo_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.combo_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT combo_parent_child_mapping_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.combo_parent_child_mapping OWNER TO citus;

--
-- TOC entry 380 (class 1259 OID 160740)
-- Name: concessionaire_config; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.concessionaire_config (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    mode character varying(50),
    multiple_concessionaire_per_order boolean NOT NULL,
    show_landing_grid boolean NOT NULL,
    display_type character varying(50),
    show_location_header boolean NOT NULL
);


ALTER TABLE public.concessionaire_config OWNER TO citus;

--
-- TOC entry 399 (class 1259 OID 3623813)
-- Name: dietary_tag_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.dietary_tag_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    display_order integer,
    catalog_id character varying(50) NOT NULL,
    multi_media jsonb,
    is_active boolean DEFAULT true NOT NULL,
    pos_linked_entity_id character varying(50),
    is_deleted boolean DEFAULT false NOT NULL,
    source jsonb,
    pos_overrided_fields character varying[],
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.dietary_tag_master OWNER TO citus;

--
-- TOC entry 375 (class 1259 OID 63416)
-- Name: discount; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.discount (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    menu_dataset_id character varying(50),
    name character varying(255) NOT NULL,
    display_name character varying(255),
    short_description character varying(255),
    discount_type json,
    pos_linked_entity_id character varying(50),
    pos_discount_type character varying(50),
    reward_reference_id character varying(255),
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    mode character varying(50),
    media jsonb,
    conditions json,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scope json,
    max_applications_per_order double precision DEFAULT 0,
    pos_discount_id character varying(100),
    pos_metadata jsonb,
    rule_type character varying(50) DEFAULT 'Discount'::character varying NOT NULL,
    pos_overrided_fields character varying[],
    created_by character varying(255),
    modified_by character varying(255),
    custom_rule_prompt_header character varying(255),
    bar_code character varying(255),
    is_code_required boolean DEFAULT false NOT NULL,
    require_single_use_code boolean DEFAULT false NOT NULL,
    discount_codes jsonb,
    code character varying(255),
    min_spend_discount_basis jsonb,
    max_discounted_units integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.discount OWNER TO citus;

--
-- TOC entry 396 (class 1259 OID 3476462)
-- Name: human_in_the_loop_interaction; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.human_in_the_loop_interaction (
    id character varying(255) NOT NULL,
    organization_id character varying(255) NOT NULL,
    location_id character varying(255) NOT NULL,
    ai_classification character varying(50) NOT NULL,
    human_classification character varying(50) NOT NULL,
    confidence character varying(50) NOT NULL,
    reason character varying(2024) NOT NULL,
    human_reviewed boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    entity_type character varying(50) DEFAULT 'Item'::character varying NOT NULL
);


ALTER TABLE public.human_in_the_loop_interaction OWNER TO citus;

--
-- TOC entry 371 (class 1259 OID 59404)
-- Name: item_86; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_86 (
    id character varying(50) NOT NULL,
    item_master_id character varying(255),
    modifier_master_id character varying(255),
    combo_master_id character varying(255),
    pos_connector_config_id character varying(255) NOT NULL,
    pos_snapshot_group_id character varying(255),
    catalog_id character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_entity_external_id character varying(255),
    created_by character varying(255),
    modified_by character varying(255),
    reset_setting smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.item_86 OWNER TO citus;

--
-- TOC entry 400 (class 1259 OID 3625161)
-- Name: item_dietary_tags_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_dietary_tags_glue (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    item_master_id character varying(50) NOT NULL,
    dietary_tag_master_id character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    pos_overrided_fields character varying[],
    source jsonb,
    created_by character varying(255),
    modified_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.item_dietary_tags_glue OWNER TO citus;

--
-- TOC entry 345 (class 1259 OID 26121)
-- Name: item_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    catalog_id character varying(50) NOT NULL,
    short_description text NOT NULL,
    short_description_localized jsonb,
    description text NOT NULL,
    description_localized jsonb,
    calories text NOT NULL,
    upc text,
    sku text,
    is_alcoholic boolean,
    concrete_model_id character varying(50),
    taxgroup_master_id character varying(50),
    media jsonb NOT NULL,
    pos_linked_entity_id character varying(50),
    pos_overrided_fields character varying[],
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    transform_rules_metadata text,
    kiosk_display_metadata jsonb,
    display_info jsonb,
    availability_schedule jsonb,
    promotional_details jsonb,
    domain_specific_attributes json,
    created_by character varying(255),
    modified_by character varying(255),
    channels character varying[],
    clone_from_id character varying(50),
    avg_rating integer,
    feedback_count integer DEFAULT 0,
    pct_response jsonb,
    is_quick_modifier_mode boolean DEFAULT false,
    bar_codes character varying[],
    has_upsell boolean DEFAULT false,
    custom_bar_codes character varying[],
    source jsonb,
    max_qty_per_cart integer,
    hide_price boolean DEFAULT false,
    multi_media jsonb,
    item_class_type integer DEFAULT 0 NOT NULL,
    enable_modifier_upsell boolean DEFAULT false NOT NULL,
    tags character varying[],
    allergen_info text,
    allergen_info_localized jsonb,
    is_pinned boolean DEFAULT false NOT NULL,
    additional_info text,
    additional_info_localized jsonb
);


ALTER TABLE public.item_master OWNER TO citus;

--
-- TOC entry 336 (class 1259 OID 26049)
-- Name: item_modifier_group_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_modifier_group_glue (
    id character varying(50) NOT NULL,
    min_selection integer,
    max_selection integer,
    free_count integer,
    item_variation_master_id character varying(50),
    item_master_id character varying(50),
    modifier_group_master_id character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    catalog_id character varying(50),
    is_invisible boolean DEFAULT false NOT NULL,
    pos_sync_enable boolean DEFAULT false NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    primary_modifier_group boolean DEFAULT false NOT NULL,
    channels character varying[],
    pos_overrided_fields character varying[],
    source jsonb,
    CONSTRAINT chk_item_item_variation_id CHECK ((((item_variation_master_id IS NULL) AND (item_master_id IS NOT NULL)) OR ((item_variation_master_id IS NOT NULL) AND (item_master_id IS NULL))))
);


ALTER TABLE public.item_modifier_group_glue OWNER TO citus;

--
-- TOC entry 337 (class 1259 OID 26057)
-- Name: item_modifier_group_modifier_config; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_modifier_group_modifier_config (
    id character varying(50) NOT NULL,
    hidden boolean,
    max_quantity integer,
    increment_step integer,
    hide_nested_modifiers boolean,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active boolean,
    item_master_id character varying(50) NOT NULL,
    modifier_master_id character varying(50) NOT NULL,
    modifier_group_master_id character varying(50),
    catalog_id character varying(50) NOT NULL,
    pos_linked_entity_id character varying(50),
    is_default boolean,
    is_included_in_item_price boolean,
    is_invisible boolean DEFAULT false NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    min_quantity integer,
    pos_overrided_fields character varying[]
);


ALTER TABLE public.item_modifier_group_modifier_config OWNER TO citus;

--
-- TOC entry 379 (class 1259 OID 128679)
-- Name: item_modifier_group_overrides; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_modifier_group_overrides (
    id character varying(50) NOT NULL,
    item_master_id character varying(50) NOT NULL,
    parent_modifier_master_id character varying(50),
    modifier_group_master_id character varying(50),
    pos_linked_entity_id character varying(50),
    catalog_id character varying(255),
    is_active boolean,
    is_invisible boolean DEFAULT false NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    max_selection_count integer,
    free_modifier_count integer,
    free_modifier_amount integer,
    min_selection_count integer,
    max_aggregate_count integer,
    min_aggregate_count integer,
    free_modifier_swaps integer
);


ALTER TABLE public.item_modifier_group_overrides OWNER TO citus;

--
-- TOC entry 389 (class 1259 OID 307412)
-- Name: item_modifier_group_overrides_backup_20250806; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_modifier_group_overrides_backup_20250806 (
    id character varying(50),
    item_master_id character varying(50),
    parent_modifier_master_id character varying(50),
    modifier_group_master_id character varying(50),
    pos_linked_entity_id character varying(50),
    catalog_id character varying(255),
    is_active boolean,
    is_invisible boolean,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    max_selection_count integer,
    free_modifier_count integer,
    free_modifier_amount integer,
    min_selection_count integer,
    max_aggregate_count integer,
    min_aggregate_count integer
);


ALTER TABLE public.item_modifier_group_overrides_backup_20250806 OWNER TO citus;

--
-- TOC entry 382 (class 1259 OID 177988)
-- Name: item_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT item_parent_child_mapping_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.item_parent_child_mapping OWNER TO citus;

--
-- TOC entry 346 (class 1259 OID 26130)
-- Name: item_variation_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.item_variation_master (
    id character varying(50) NOT NULL,
    item_master_id character varying(50),
    name text,
    name_localized jsonb,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50) NOT NULL,
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.item_variation_master OWNER TO citus;

--
-- TOC entry 348 (class 1259 OID 26148)
-- Name: menu_category; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_category (
    id character varying(50) NOT NULL,
    menu_id character varying(50) NOT NULL,
    availability_schedule jsonb,
    category_id character varying(50) NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    display_metadata jsonb,
    pos_linked_entity_id character varying(50),
    catalog_id character varying(50),
    pos_overrided_fields character varying[],
    created_by character varying(255),
    modified_by character varying(255),
    is_alcoholic boolean,
    source jsonb
);


ALTER TABLE public.menu_category OWNER TO citus;

--
-- TOC entry 347 (class 1259 OID 26139)
-- Name: menu_category_displayable_item_override; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_category_displayable_item_override (
    id character varying(50) NOT NULL,
    category_displayable_item_id character varying(50) NOT NULL,
    menu_category_id character varying(50) NOT NULL,
    availability_schedule jsonb,
    hidden boolean NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.menu_category_displayable_item_override OWNER TO citus;

--
-- TOC entry 365 (class 1259 OID 27459)
-- Name: menu_dataset; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_dataset (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    organization_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    created_by character varying(50) NOT NULL,
    modified_by character varying(50),
    published_by character varying(50),
    archived_by character varying(50),
    published_on timestamp without time zone,
    archived_on timestamp without time zone,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_entity_ids text,
    snapshot text,
    parent_id character varying(50),
    snapshot_blob_name character varying(255)
);


ALTER TABLE public.menu_dataset OWNER TO citus;

--
-- TOC entry 393 (class 1259 OID 2274687)
-- Name: menu_dataset_overrides; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_dataset_overrides (
    id character varying(50) NOT NULL,
    item_master_id character varying(255),
    modifier_master_id character varying(255),
    combo_master_id character varying(255),
    menu_dataset_id character varying(255),
    pos_connector_config_id character varying(255),
    location_id character varying(255),
    catalog_id character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.menu_dataset_overrides OWNER TO citus;

--
-- TOC entry 388 (class 1259 OID 234263)
-- Name: menu_dataset_snapshot; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_dataset_snapshot (
    id integer NOT NULL,
    snapshot_id character varying(50) NOT NULL,
    snapshot_section character varying(50) NOT NULL,
    snapshot_section_data jsonb NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50)
);


ALTER TABLE public.menu_dataset_snapshot OWNER TO citus;

--
-- TOC entry 6057 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE menu_dataset_snapshot; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON TABLE public.menu_dataset_snapshot IS 'Stores snapshot sections with JSON body data for a published dataset';


--
-- TOC entry 6058 (class 0 OID 0)
-- Dependencies: 388
-- Name: COLUMN menu_dataset_snapshot.id; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON COLUMN public.menu_dataset_snapshot.id IS 'Auto-incrementing primary key';


--
-- TOC entry 6059 (class 0 OID 0)
-- Dependencies: 388
-- Name: COLUMN menu_dataset_snapshot.snapshot_id; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON COLUMN public.menu_dataset_snapshot.snapshot_id IS 'Identifier for the snapshot';


--
-- TOC entry 6060 (class 0 OID 0)
-- Dependencies: 388
-- Name: COLUMN menu_dataset_snapshot.snapshot_section; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON COLUMN public.menu_dataset_snapshot.snapshot_section IS 'Section identifier within the snapshot';


--
-- TOC entry 6061 (class 0 OID 0)
-- Dependencies: 388
-- Name: COLUMN menu_dataset_snapshot.snapshot_section_data; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON COLUMN public.menu_dataset_snapshot.snapshot_section_data IS 'JSON body content for the section';


--
-- TOC entry 6062 (class 0 OID 0)
-- Dependencies: 388
-- Name: COLUMN menu_dataset_snapshot.created_on; Type: COMMENT; Schema: public; Owner: citus
--

COMMENT ON COLUMN public.menu_dataset_snapshot.created_on IS 'Timestamp when the record was created';


--
-- TOC entry 387 (class 1259 OID 234262)
-- Name: menu_dataset_snapshot_id_seq; Type: SEQUENCE; Schema: public; Owner: citus
--

CREATE SEQUENCE public.menu_dataset_snapshot_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.menu_dataset_snapshot_id_seq OWNER TO citus;

--
-- TOC entry 6063 (class 0 OID 0)
-- Dependencies: 387
-- Name: menu_dataset_snapshot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.menu_dataset_snapshot_id_seq OWNED BY public.menu_dataset_snapshot.id;


--
-- TOC entry 349 (class 1259 OID 26157)
-- Name: menu_item_modifier_group_modifier_override; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_item_modifier_group_modifier_override (
    id character varying(50) NOT NULL,
    menu_category_id character varying(50) NOT NULL,
    category_displayable_item_id character varying(50) NOT NULL,
    item_modifier_group_glue_id character varying(50) NOT NULL,
    modifier_id character varying(50) NOT NULL,
    hidden boolean NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.menu_item_modifier_group_modifier_override OWNER TO citus;

--
-- TOC entry 350 (class 1259 OID 26164)
-- Name: menu_item_modifier_group_override; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_item_modifier_group_override (
    id character varying(50) NOT NULL,
    menu_category_id character varying(50) NOT NULL,
    category_displayable_item_id character varying(50) NOT NULL,
    item_modifier_group_glue_id character varying(50) NOT NULL,
    hidden boolean NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.menu_item_modifier_group_override OWNER TO citus;

--
-- TOC entry 351 (class 1259 OID 26171)
-- Name: menu_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.menu_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    catalog_id character varying(50) NOT NULL,
    pos_linked_entity_id character varying(50),
    cached_resolved_menu jsonb,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    reset_entity_settings jsonb
);


ALTER TABLE public.menu_master OWNER TO citus;

--
-- TOC entry 352 (class 1259 OID 26180)
-- Name: modifier_code_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_code_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255),
    catalog_id character varying(50) NOT NULL,
    media jsonb NOT NULL,
    is_active boolean NOT NULL,
    pos_linked_entity_id character varying(50),
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    behavior integer,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    display_order integer DEFAULT 0 NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    source jsonb,
    pos_overrided_fields character varying[],
    multi_media jsonb
);


ALTER TABLE public.modifier_code_master OWNER TO citus;

--
-- TOC entry 384 (class 1259 OID 184053)
-- Name: modifier_code_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_code_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT modifier_code_parent_child_mappi_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.modifier_code_parent_child_mapping OWNER TO citus;

--
-- TOC entry 401 (class 1259 OID 3625172)
-- Name: modifier_dietary_tags_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_dietary_tags_glue (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    modifier_master_id character varying(50) NOT NULL,
    dietary_tag_master_id character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    pos_overrided_fields character varying[],
    source jsonb,
    created_by character varying(255),
    modified_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.modifier_dietary_tags_glue OWNER TO citus;

--
-- TOC entry 353 (class 1259 OID 26189)
-- Name: modifier_group_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_master (
    id character varying(50) NOT NULL,
    name character varying(510) NOT NULL,
    name_localized jsonb,
    display_name character varying(510),
    display_name_localized jsonb,
    catalog_id character varying(50) NOT NULL,
    media jsonb NOT NULL,
    pos_overrided_fields character varying[],
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    negative_modifier_behavior integer,
    clone_from_id character varying(50),
    domain_specific_attributes json,
    shortcut_name character varying(510),
    shortcut_name_localized jsonb,
    created_by character varying(255),
    modified_by character varying(255),
    parent_shortcut_modifier_id character varying(250),
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer DEFAULT 1,
    slider_mode boolean DEFAULT false NOT NULL,
    slider_mode_modifier boolean DEFAULT false NOT NULL,
    source jsonb,
    disable_flattning boolean DEFAULT false NOT NULL,
    show_nested_modifier_inside_modifier_card boolean DEFAULT false NOT NULL,
    multi_media jsonb,
    type integer,
    default_display_state integer DEFAULT 1 NOT NULL,
    free_modifier_swaps integer
);


ALTER TABLE public.modifier_group_master OWNER TO citus;

--
-- TOC entry 390 (class 1259 OID 307417)
-- Name: modifier_group_master_backup_20250806; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_master_backup_20250806 (
    id character varying(50),
    name character varying(510),
    name_localized jsonb,
    display_name character varying(510),
    display_name_localized jsonb,
    catalog_id character varying(50),
    media jsonb,
    pos_overrided_fields character varying[],
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50),
    is_active boolean,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    clone_from_id character varying(50),
    domain_specific_attributes json,
    shortcut_name character varying(510),
    shortcut_name_localized jsonb,
    created_by character varying(255),
    modified_by character varying(255),
    parent_shortcut_modifier_id character varying(250),
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean,
    slider_mode_modifier boolean,
    source jsonb
);


ALTER TABLE public.modifier_group_master_backup_20250806 OWNER TO citus;

--
-- TOC entry 358 (class 1259 OID 26230)
-- Name: modifier_group_modifier_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_modifier_glue (
    id character varying(50) NOT NULL,
    modifier_master_id character varying(50) NOT NULL,
    modifier_group_master_id character varying(50) NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    max_quantity integer,
    increment_step integer,
    allow_quantity_increment boolean,
    default_quantity integer,
    calories_text text,
    is_invisible boolean,
    is_default boolean,
    catalog_id character varying(50),
    has_shortcut_name boolean,
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[],
    min_quantity integer,
    source jsonb,
    modifier_group_subgroup_id character varying(50)
);


ALTER TABLE public.modifier_group_modifier_glue OWNER TO citus;

--
-- TOC entry 359 (class 1259 OID 26237)
-- Name: modifier_group_modifier_modifier_code_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_modifier_modifier_code_glue (
    id character varying(50) NOT NULL,
    modifier_group_modifier_glue_id character varying(50),
    modifier_code_master_id character varying(50),
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_default boolean,
    catalog_id character varying(50),
    display_order integer DEFAULT 0 NOT NULL,
    modifier_group_id character varying(50) NOT NULL,
    modifier_id character varying(50) NOT NULL,
    pos_overrided_fields character varying[],
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.modifier_group_modifier_modifier_code_glue OWNER TO citus;

--
-- TOC entry 385 (class 1259 OID 184063)
-- Name: modifier_group_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT modifier_group_parent_child_mapp_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.modifier_group_parent_child_mapping OWNER TO citus;

--
-- TOC entry 394 (class 1259 OID 2797731)
-- Name: modifier_group_subgroup; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_group_subgroup (
    id character varying(50) NOT NULL,
    modifier_group_master_id character varying(50),
    name character varying(255) NOT NULL,
    display_order integer NOT NULL,
    pos_linked_entity_id character varying(50),
    catalog_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    source jsonb,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_default boolean DEFAULT false NOT NULL
);


ALTER TABLE public.modifier_group_subgroup OWNER TO citus;

--
-- TOC entry 354 (class 1259 OID 26198)
-- Name: modifier_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_master (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    name_localized jsonb,
    display_name character varying(255),
    display_name_localized jsonb,
    media jsonb NOT NULL,
    pos_linked_entity_id text,
    pos_overrided_fields character varying[],
    max_quantity integer,
    increment_step integer,
    calories text NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    allow_quantity_increment boolean DEFAULT true NOT NULL,
    default_quantity integer,
    calories_text text,
    is_invisible boolean DEFAULT false NOT NULL,
    transform_rules_metadata text,
    kiosk_display_metadata jsonb,
    selected_display_name character varying(255),
    selected_display_name_localized character varying(255),
    display_info jsonb,
    domain_specific_attributes json,
    created_by character varying(255),
    modified_by character varying(255),
    min_quantity integer,
    availability_schedule jsonb,
    source jsonb,
    inverse_modifier_id character varying(50),
    multi_media jsonb,
    short_description text,
    short_description_localized jsonb,
    description text,
    description_localized jsonb,
    bar_codes character varying[],
    custom_bar_codes character varying[],
    classification integer DEFAULT 0 NOT NULL,
    mutually_exclusive_modifier_ids character varying[],
    tags character varying[],
    allergen_info text,
    allergen_info_localized jsonb
);


ALTER TABLE public.modifier_master OWNER TO citus;

--
-- TOC entry 360 (class 1259 OID 26244)
-- Name: modifier_modifier_code_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_modifier_code_glue (
    id character varying(50) NOT NULL,
    modifier_master_id character varying(50) NOT NULL,
    modifier_code_master_id character varying(50) NOT NULL,
    item_master_id character varying(50),
    display_order integer NOT NULL,
    is_default boolean NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.modifier_modifier_code_glue OWNER TO citus;

--
-- TOC entry 361 (class 1259 OID 26266)
-- Name: modifier_nested_modifier_group_glue; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_nested_modifier_group_glue (
    id character varying(50) NOT NULL,
    modifier_master_id character varying(50) NOT NULL,
    modifier_group_master_id character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    display_order integer DEFAULT 0 NOT NULL,
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[] DEFAULT ARRAY[]::character varying[],
    pos_sync_enable boolean DEFAULT true NOT NULL,
    is_invisible boolean DEFAULT false
);


ALTER TABLE public.modifier_nested_modifier_group_glue OWNER TO citus;

--
-- TOC entry 386 (class 1259 OID 184072)
-- Name: modifier_parent_child_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifier_parent_child_mapping (
    child_id character varying(50) NOT NULL,
    parent_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(50) NOT NULL,
    pos_metadata jsonb,
    pos_mapping_name character varying(100) NOT NULL,
    mapping_confidence_score numeric(3,2) NOT NULL,
    mapped_by_user_id character varying(255) NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT modifier_parent_child_mapping_mapping_confidence_score_check CHECK (((mapping_confidence_score >= (0)::numeric) AND (mapping_confidence_score <= (1)::numeric)))
);


ALTER TABLE public.modifier_parent_child_mapping OWNER TO citus;

--
-- TOC entry 368 (class 1259 OID 28503)
-- Name: modifierglueid; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.modifierglueid (
    id character varying
);


ALTER TABLE public.modifierglueid OWNER TO citus;

--
-- TOC entry 395 (class 1259 OID 3087274)
-- Name: pos_deleted_records; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pos_deleted_records (
    id character varying(50) NOT NULL,
    catalog_entity_id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    entity_type character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    external_pos_entity_id character varying(255),
    price integer,
    media jsonb,
    deletion_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_connector_configuration_id character varying(50),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.pos_deleted_records OWNER TO citus;

--
-- TOC entry 362 (class 1259 OID 26273)
-- Name: pos_linked_entity; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pos_linked_entity (
    id character varying(50) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    pos_entity_external_id character varying(250) NOT NULL,
    pos_entity_type character varying(100) NOT NULL,
    pos_metadata jsonb,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_service_id text,
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.pos_linked_entity OWNER TO citus;

--
-- TOC entry 355 (class 1259 OID 26207)
-- Name: pre_selected_combo_item; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pre_selected_combo_item (
    id character varying(50) NOT NULL,
    combo_component_item_glue_id character varying(50),
    combo_component_id character varying(50),
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.pre_selected_combo_item OWNER TO citus;

--
-- TOC entry 356 (class 1259 OID 26214)
-- Name: pre_selected_combo_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pre_selected_combo_master (
    id character varying(50) NOT NULL,
    display_name character varying(255) NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    catalog_id character varying(50),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.pre_selected_combo_master OWNER TO citus;

--
-- TOC entry 370 (class 1259 OID 34382)
-- Name: pricebook; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pricebook (
    id character varying(50) NOT NULL,
    price integer NOT NULL,
    catalog_id character varying(255) NOT NULL,
    pos_connector_configuration_id character varying(255) NOT NULL,
    pos_linked_entity_id character varying(50),
    menu_id character varying(255),
    category_id character varying(255),
    item_id character varying(255),
    item_variation_id character varying(255),
    modifier_group_id character varying(255),
    modifier_id character varying(255),
    combo_master_id character varying(255),
    combo_family_id character varying(255),
    combo_component_id character varying(255),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_snapshot_group_id character varying(255) DEFAULT 'unknown'::character varying NOT NULL,
    price_amended boolean DEFAULT false NOT NULL,
    price_amended_by character varying(255),
    created_by character varying(255),
    modified_by character varying(255),
    pos_overrided_fields character varying[],
    base_price integer,
    CONSTRAINT pricebook_check CHECK (((item_id IS NOT NULL) OR (item_variation_id IS NOT NULL) OR (modifier_group_id IS NOT NULL) OR (modifier_id IS NOT NULL) OR (combo_component_id IS NOT NULL) OR (combo_family_id IS NOT NULL) OR (combo_master_id IS NOT NULL)))
);


ALTER TABLE public.pricebook OWNER TO citus;

--
-- TOC entry 357 (class 1259 OID 26221)
-- Name: pricebook_item; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.pricebook_item (
    id character varying(50) NOT NULL,
    price numeric(10,2),
    catalog_id character varying(255) NOT NULL,
    menu_id character varying(255),
    category_id character varying(255),
    item_id character varying(255),
    item_variation_id character varying(255),
    modifier_group_id character varying(255),
    modifier_id character varying(255),
    combo_master_id character varying(255),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    pos_linked_entity_id character varying(50),
    combo_component_id character varying(255),
    combo_family_id character varying(255),
    price_amended boolean DEFAULT false NOT NULL,
    price_amended_by character varying(255),
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.pricebook_item OWNER TO citus;

--
-- TOC entry 402 (class 1259 OID 3663815)
-- Name: prod_to_stage_migration_audit; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.prod_to_stage_migration_audit (
    table_schema text,
    table_name text,
    key_columns jsonb,
    key_type text,
    key_column_data_types jsonb,
    dependency_level integer,
    dependency_count integer,
    depends_on jsonb,
    referenced_by jsonb,
    insert_watermark text,
    insert_watermark_data_type text,
    update_watermark text,
    update_watermark_data_type text,
    insert_watermark_value timestamp without time zone,
    update_watermark_value timestamp without time zone,
    watermark_integer_value bigint,
    record_count bigint,
    sql_aggregate text,
    sysupdatetime timestamp without time zone,
    post_sync_insert_watermark_value timestamp without time zone,
    post_sync_update_watermark_value timestamp without time zone,
    post_sync_watermark_integer_value bigint,
    post_sync_record_count bigint,
    sysupdatetime_after_migration timestamp without time zone,
    sql_source_query text
);


ALTER TABLE public.prod_to_stage_migration_audit OWNER TO citus;

--
-- TOC entry 333 (class 1259 OID 26027)
-- Name: schemaversions; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.schemaversions (
    schemaversionsid integer NOT NULL,
    scriptname character varying(255) NOT NULL,
    applied timestamp without time zone NOT NULL
);


ALTER TABLE public.schemaversions OWNER TO citus;

--
-- TOC entry 332 (class 1259 OID 26026)
-- Name: schemaversions_schemaversionsid_seq; Type: SEQUENCE; Schema: public; Owner: citus
--

CREATE SEQUENCE public.schemaversions_schemaversionsid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schemaversions_schemaversionsid_seq OWNER TO citus;

--
-- TOC entry 6084 (class 0 OID 0)
-- Dependencies: 332
-- Name: schemaversions_schemaversionsid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.schemaversions_schemaversionsid_seq OWNED BY public.schemaversions.schemaversionsid;


--
-- TOC entry 363 (class 1259 OID 26284)
-- Name: tax_group_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.tax_group_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    applicable_order_types character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.tax_group_master OWNER TO citus;

--
-- TOC entry 364 (class 1259 OID 26291)
-- Name: tax_master; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.tax_master (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    catalog_id character varying(50) NOT NULL,
    tax_group_id character varying(50) NOT NULL,
    tax jsonb NOT NULL,
    inclusive character varying(50) NOT NULL,
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_by character varying(255)
);


ALTER TABLE public.tax_master OWNER TO citus;

--
-- TOC entry 374 (class 1259 OID 63208)
-- Name: upsell; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.upsell (
    id character varying(255) NOT NULL,
    organization_id character varying(255) NOT NULL,
    catalog_id character varying(255) NOT NULL,
    menu_dataset_id character varying(255),
    upsell_type character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    pos_linked_entity_id character varying(50),
    item_upsell_type character varying(50),
    replacement_display_name character varying(255)
);


ALTER TABLE public.upsell OWNER TO citus;

--
-- TOC entry 373 (class 1259 OID 63199)
-- Name: upsell_group; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.upsell_group (
    id character varying(255) NOT NULL,
    upsell_id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    upsell_conditions jsonb,
    is_active boolean DEFAULT true NOT NULL,
    created_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    pos_linked_entity_id character varying(50),
    item_upsell_type character varying(50),
    replacement_display_name character varying(255),
    is_deleted boolean DEFAULT false NOT NULL,
    catalog_id character varying(50)
);


ALTER TABLE public.upsell_group OWNER TO citus;

--
-- TOC entry 376 (class 1259 OID 66867)
-- Name: upsell_group_mapping; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.upsell_group_mapping (
    id character varying(255) NOT NULL,
    upsell_group_id character varying(255) NOT NULL,
    item_id character varying(255),
    category_id character varying(255),
    created_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    combo_id character varying(255),
    pos_linked_entity_id character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    modifier_master_id character varying(255),
    display_order bigint DEFAULT 0,
    catalog_id character varying(50),
    CONSTRAINT check_one_of_two CHECK ((((category_id IS NULL) AND ((item_id IS NOT NULL) OR (combo_id IS NOT NULL))) OR ((category_id IS NOT NULL) AND (item_id IS NULL) AND (combo_id IS NULL))))
);


ALTER TABLE public.upsell_group_mapping OWNER TO citus;

--
-- TOC entry 372 (class 1259 OID 63190)
-- Name: upsell_group_offer; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.upsell_group_offer (
    id character varying(255) NOT NULL,
    upsell_group_id character varying(255) NOT NULL,
    item_id character varying(255),
    category_id character varying(255),
    created_by character varying(255),
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    modified_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    combo_id character varying(255),
    pos_linked_entity_id character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    modifier_master_id character varying(50),
    display_order bigint DEFAULT 0,
    catalog_id character varying(50),
    remove_upsell_on_trigger_deletion boolean DEFAULT false NOT NULL,
    CONSTRAINT check_one_of_two CHECK ((((category_id IS NULL) AND ((item_id IS NOT NULL) OR (combo_id IS NOT NULL) OR (modifier_master_id IS NOT NULL))) OR ((category_id IS NOT NULL) AND (item_id IS NULL) AND (combo_id IS NULL) AND (modifier_master_id IS NULL)))),
    CONSTRAINT one_of_two_constraint CHECK ((((category_id IS NULL) AND ((item_id IS NOT NULL) OR (combo_id IS NOT NULL) OR (modifier_master_id IS NOT NULL))) OR ((category_id IS NOT NULL) AND (item_id IS NULL) AND (combo_id IS NULL) AND (modifier_master_id IS NULL))))
);


ALTER TABLE public.upsell_group_offer OWNER TO citus;

--
-- TOC entry 398 (class 1259 OID 3552359)
-- Name: upsell_test; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.upsell_test (
    id integer NOT NULL,
    product_name character varying(100),
    category character varying(50),
    price numeric(10,2),
    is_active boolean,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.upsell_test OWNER TO citus;

--
-- TOC entry 397 (class 1259 OID 3552358)
-- Name: upsell_test_id_seq; Type: SEQUENCE; Schema: public; Owner: citus
--

CREATE SEQUENCE public.upsell_test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.upsell_test_id_seq OWNER TO citus;

--
-- TOC entry 6091 (class 0 OID 0)
-- Dependencies: 397
-- Name: upsell_test_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.upsell_test_id_seq OWNED BY public.upsell_test.id;


--
-- TOC entry 5310 (class 2604 OID 320230)
-- Name: audit audit_id; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.audit ALTER COLUMN audit_id SET DEFAULT nextval('public.audit_audit_id_seq'::regclass);


--
-- TOC entry 5308 (class 2604 OID 234266)
-- Name: menu_dataset_snapshot id; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_snapshot ALTER COLUMN id SET DEFAULT nextval('public.menu_dataset_snapshot_id_seq'::regclass);


--
-- TOC entry 5139 (class 2604 OID 26030)
-- Name: schemaversions schemaversionsid; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions ALTER COLUMN schemaversionsid SET DEFAULT nextval('public.schemaversions_schemaversionsid_seq'::regclass);


--
-- TOC entry 5323 (class 2604 OID 3552362)
-- Name: upsell_test id; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_test ALTER COLUMN id SET DEFAULT nextval('public.upsell_test_id_seq'::regclass);


--
-- TOC entry 5370 (class 2606 OID 26032)
-- Name: schemaversions PK_schemaversions_Id; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions
    ADD CONSTRAINT "PK_schemaversions_Id" PRIMARY KEY (schemaversionsid);


--
-- TOC entry 5643 (class 2606 OID 320236)
-- Name: audit audit_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.audit
    ADD CONSTRAINT audit_pkey PRIMARY KEY (audit_id);


--
-- TOC entry 5528 (class 2606 OID 28237)
-- Name: catalog_entity_pos_connector_glue catalog_entity_pos_connector_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_entity_pos_connector_glue
    ADD CONSTRAINT catalog_entity_pos_connector_glue_pkey PRIMARY KEY (catalog_entity_id, pos_connector_configuration_id);


--
-- TOC entry 5372 (class 2606 OID 26041)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (id);


--
-- TOC entry 5534 (class 2606 OID 28242)
-- Name: catalog_pos_connector_glue catalog_pos_connector_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_pos_connector_glue
    ADD CONSTRAINT catalog_pos_connector_glue_pkey PRIMARY KEY (catalog_id, pos_connector_configuration_id);


--
-- TOC entry 5536 (class 2606 OID 61177)
-- Name: catalog_pos_connector_glue catalog_pos_connector_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_pos_connector_glue
    ADD CONSTRAINT catalog_pos_connector_glue_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, pos_connector_configuration_id);


--
-- TOC entry 5367 (class 2606 OID 26025)
-- Name: catalog_sync_history catalog_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_sync_history
    ADD CONSTRAINT catalog_sync_history_pkey PRIMARY KEY (id);


--
-- TOC entry 5374 (class 2606 OID 26048)
-- Name: category_displayable_item category_displayable_item_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT category_displayable_item_pkey PRIMARY KEY (id);


--
-- TOC entry 5377 (class 2606 OID 3522566)
-- Name: category_displayable_item category_displayable_item_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT category_displayable_item_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, item_master_id, combo_family_id, combo_id, category_master_id, sub_category_id, item_variation_id, pre_selected_combo_id);


--
-- TOC entry 5395 (class 2606 OID 26072)
-- Name: category_master category_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_master
    ADD CONSTRAINT category_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5615 (class 2606 OID 177983)
-- Name: category_parent_child_mapping category_parent_child_mapping_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_parent_child_mapping
    ADD CONSTRAINT category_parent_child_mapping_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5540 (class 2606 OID 34381)
-- Name: combo_component_item_glue_group combo_component_item_glue_group_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue_group
    ADD CONSTRAINT combo_component_item_glue_group_pkey PRIMARY KEY (id);


--
-- TOC entry 5400 (class 2606 OID 26079)
-- Name: combo_component_item_glue combo_component_item_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue
    ADD CONSTRAINT combo_component_item_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5402 (class 2606 OID 61173)
-- Name: combo_component_item_glue combo_component_item_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue
    ADD CONSTRAINT combo_component_item_glue_unique_key UNIQUE NULLS NOT DISTINCT (combo_component_id, item_master_id, catalog_id);


--
-- TOC entry 5409 (class 2606 OID 26088)
-- Name: combo_component combo_component_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component
    ADD CONSTRAINT combo_component_pkey PRIMARY KEY (id);


--
-- TOC entry 5414 (class 2606 OID 26095)
-- Name: combo_family_member combo_family_member_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family_member
    ADD CONSTRAINT combo_family_member_pkey PRIMARY KEY (id);


--
-- TOC entry 5417 (class 2606 OID 26104)
-- Name: combo_family combo_family_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family
    ADD CONSTRAINT combo_family_pkey PRIMARY KEY (id);


--
-- TOC entry 5593 (class 2606 OID 69850)
-- Name: combo_item_modifier_group_override combo_item_modifier_group_override_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT combo_item_modifier_group_override_pkey PRIMARY KEY (id);


--
-- TOC entry 5595 (class 2606 OID 73683)
-- Name: combo_item_modifier_group_override combo_item_modifier_group_override_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT combo_item_modifier_group_override_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, combo_id, item_id, modifier_group_id, combo_component_id);


--
-- TOC entry 5601 (class 2606 OID 69859)
-- Name: combo_item_modifier_override combo_item_modifier_override_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT combo_item_modifier_override_pkey PRIMARY KEY (id);


--
-- TOC entry 5603 (class 2606 OID 69903)
-- Name: combo_item_modifier_override combo_item_modifier_override_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT combo_item_modifier_override_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, combo_id, item_id, modifier_id);


--
-- TOC entry 5422 (class 2606 OID 26111)
-- Name: combo_master_component_glue combo_master_component_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master_component_glue
    ADD CONSTRAINT combo_master_component_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5425 (class 2606 OID 26120)
-- Name: combo_master combo_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master
    ADD CONSTRAINT combo_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5624 (class 2606 OID 178118)
-- Name: combo_parent_child_mapping combo_parent_child_mapping_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_parent_child_mapping
    ADD CONSTRAINT combo_parent_child_mapping_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5611 (class 2606 OID 160744)
-- Name: concessionaire_config concessionaire_config_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.concessionaire_config
    ADD CONSTRAINT concessionaire_config_pkey PRIMARY KEY (id);


--
-- TOC entry 5665 (class 2606 OID 3623823)
-- Name: dietary_tag_master dietary_tag_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.dietary_tag_master
    ADD CONSTRAINT dietary_tag_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5585 (class 2606 OID 63424)
-- Name: discount discount_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.discount
    ADD CONSTRAINT discount_pkey PRIMARY KEY (id);


--
-- TOC entry 5660 (class 2606 OID 3476470)
-- Name: human_in_the_loop_interaction human_in_the_loop_interaction_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.human_in_the_loop_interaction
    ADD CONSTRAINT human_in_the_loop_interaction_pkey PRIMARY KEY (id);


--
-- TOC entry 5561 (class 2606 OID 59412)
-- Name: item_86 item_86_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_86
    ADD CONSTRAINT item_86_pkey PRIMARY KEY (id);


--
-- TOC entry 5563 (class 2606 OID 66897)
-- Name: item_86 item_86_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_86
    ADD CONSTRAINT item_86_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, pos_connector_config_id, item_master_id, modifier_master_id, combo_master_id);


--
-- TOC entry 5669 (class 2606 OID 3625171)
-- Name: item_dietary_tags_glue item_dietary_tags_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT item_dietary_tags_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5435 (class 2606 OID 26129)
-- Name: item_master item_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_master
    ADD CONSTRAINT item_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5384 (class 2606 OID 2908400)
-- Name: item_modifier_group_glue item_modifier_group_glue_item_mod_group_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_glue
    ADD CONSTRAINT item_modifier_group_glue_item_mod_group_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, item_master_id, modifier_group_master_id);


--
-- TOC entry 5386 (class 2606 OID 26056)
-- Name: item_modifier_group_glue item_modifier_group_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_glue
    ADD CONSTRAINT item_modifier_group_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5389 (class 2606 OID 26063)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_config_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_config_pkey PRIMARY KEY (id);


--
-- TOC entry 5391 (class 2606 OID 61194)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_config_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_config_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, item_master_id, modifier_group_master_id, modifier_master_id);


--
-- TOC entry 5607 (class 2606 OID 128688)
-- Name: item_modifier_group_overrides item_modifier_group_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_overrides
    ADD CONSTRAINT item_modifier_group_overrides_pkey PRIMARY KEY (id);


--
-- TOC entry 5622 (class 2606 OID 177996)
-- Name: item_parent_child_mapping item_parent_child_mapping_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_parent_child_mapping
    ADD CONSTRAINT item_parent_child_mapping_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5441 (class 2606 OID 26138)
-- Name: item_variation_master item_variation_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_variation_master
    ADD CONSTRAINT item_variation_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5445 (class 2606 OID 26147)
-- Name: menu_category_displayable_item_override menu_category_displayable_item_override_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category_displayable_item_override
    ADD CONSTRAINT menu_category_displayable_item_override_pkey PRIMARY KEY (id);


--
-- TOC entry 5450 (class 2606 OID 26156)
-- Name: menu_category menu_category_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category
    ADD CONSTRAINT menu_category_pkey PRIMARY KEY (id);


--
-- TOC entry 5650 (class 2606 OID 2274695)
-- Name: menu_dataset_overrides menu_dataset_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_overrides
    ADD CONSTRAINT menu_dataset_overrides_pkey PRIMARY KEY (id);


--
-- TOC entry 5526 (class 2606 OID 27467)
-- Name: menu_dataset menu_dataset_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset
    ADD CONSTRAINT menu_dataset_pkey PRIMARY KEY (id);


--
-- TOC entry 5639 (class 2606 OID 234271)
-- Name: menu_dataset_snapshot menu_dataset_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_snapshot
    ADD CONSTRAINT menu_dataset_snapshot_pkey PRIMARY KEY (id);


--
-- TOC entry 5453 (class 2606 OID 26163)
-- Name: menu_item_modifier_group_modifier_override menu_item_modifier_group_modifier_override_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_modifier_override
    ADD CONSTRAINT menu_item_modifier_group_modifier_override_pkey PRIMARY KEY (id);


--
-- TOC entry 5456 (class 2606 OID 26170)
-- Name: menu_item_modifier_group_override menu_item_modifier_group_override_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_override
    ADD CONSTRAINT menu_item_modifier_group_override_pkey PRIMARY KEY (id);


--
-- TOC entry 5460 (class 2606 OID 26179)
-- Name: menu_master menu_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_master
    ADD CONSTRAINT menu_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5464 (class 2606 OID 26188)
-- Name: modifier_code_master modifier_code_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_master
    ADD CONSTRAINT modifier_code_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5628 (class 2606 OID 184061)
-- Name: modifier_code_parent_child_mapping modifier_code_parent_child_ma_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_parent_child_mapping
    ADD CONSTRAINT modifier_code_parent_child_ma_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5678 (class 2606 OID 3625182)
-- Name: modifier_dietary_tags_glue modifier_dietary_tags_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT modifier_dietary_tags_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5469 (class 2606 OID 26197)
-- Name: modifier_group_master modifier_group_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_master
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5487 (class 2606 OID 26236)
-- Name: modifier_group_modifier_glue modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_glue
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5489 (class 2606 OID 61198)
-- Name: modifier_group_modifier_glue modifier_group_modifier_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_glue
    ADD CONSTRAINT modifier_group_modifier_glue_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, modifier_group_master_id, modifier_master_id);


--
-- TOC entry 5492 (class 2606 OID 28467)
-- Name: modifier_group_modifier_modifier_code_glue modifier_group_modifier_modifier_code_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT modifier_group_modifier_modifier_code_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5494 (class 2606 OID 68922)
-- Name: modifier_group_modifier_modifier_code_glue modifier_group_modifier_modifier_code_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT modifier_group_modifier_modifier_code_glue_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, modifier_code_master_id, modifier_group_id, modifier_id);


--
-- TOC entry 5630 (class 2606 OID 184071)
-- Name: modifier_group_parent_child_mapping modifier_group_parent_child_m_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_parent_child_mapping
    ADD CONSTRAINT modifier_group_parent_child_m_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5654 (class 2606 OID 2797739)
-- Name: modifier_group_subgroup modifier_group_subgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_subgroup
    ADD CONSTRAINT modifier_group_subgroup_pkey PRIMARY KEY (id);


--
-- TOC entry 5474 (class 2606 OID 26206)
-- Name: modifier_master modifier_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_master
    ADD CONSTRAINT modifier_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5497 (class 2606 OID 26250)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5499 (class 2606 OID 61206)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, modifier_master_id, modifier_code_master_id);


--
-- TOC entry 5502 (class 2606 OID 26272)
-- Name: modifier_nested_modifier_group_glue modifier_nested_modifier_group_glue_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_nested_modifier_group_glue
    ADD CONSTRAINT modifier_nested_modifier_group_glue_pkey PRIMARY KEY (id);


--
-- TOC entry 5504 (class 2606 OID 61210)
-- Name: modifier_nested_modifier_group_glue modifier_nested_modifier_group_glue_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_nested_modifier_group_glue
    ADD CONSTRAINT modifier_nested_modifier_group_glue_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, modifier_master_id, modifier_group_master_id);


--
-- TOC entry 5632 (class 2606 OID 184080)
-- Name: modifier_parent_child_mapping modifier_parent_child_mapping_child_id_parent_id_catalog_id_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_parent_child_mapping
    ADD CONSTRAINT modifier_parent_child_mapping_child_id_parent_id_catalog_id_key UNIQUE (child_id, parent_id, catalog_id);


--
-- TOC entry 5656 (class 2606 OID 3087285)
-- Name: pos_deleted_records pos_deleted_records_catalog_entity_id_pos_connector_configu_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pos_deleted_records
    ADD CONSTRAINT pos_deleted_records_catalog_entity_id_pos_connector_configu_key UNIQUE (catalog_entity_id, pos_connector_configuration_id);


--
-- TOC entry 5658 (class 2606 OID 3087283)
-- Name: pos_deleted_records pos_deleted_records_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pos_deleted_records
    ADD CONSTRAINT pos_deleted_records_pkey PRIMARY KEY (id);


--
-- TOC entry 5508 (class 2606 OID 277940)
-- Name: pos_linked_entity pos_linked_entity_catalog_id_pos_entity_type_pos_entity_ext_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pos_linked_entity
    ADD CONSTRAINT pos_linked_entity_catalog_id_pos_entity_type_pos_entity_ext_key UNIQUE (catalog_id, pos_entity_type, pos_entity_external_id);


--
-- TOC entry 5511 (class 2606 OID 26281)
-- Name: pos_linked_entity pos_linked_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pos_linked_entity
    ADD CONSTRAINT pos_linked_entity_pkey PRIMARY KEY (id);


--
-- TOC entry 5513 (class 2606 OID 277942)
-- Name: pos_linked_entity pos_linked_entity_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pos_linked_entity
    ADD CONSTRAINT pos_linked_entity_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, pos_entity_external_id, pos_entity_type);


--
-- TOC entry 5477 (class 2606 OID 26213)
-- Name: pre_selected_combo_item pre_selected_combo_item_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_item
    ADD CONSTRAINT pre_selected_combo_item_pkey PRIMARY KEY (id);


--
-- TOC entry 5480 (class 2606 OID 26220)
-- Name: pre_selected_combo_master pre_selected_combo_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_master
    ADD CONSTRAINT pre_selected_combo_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5482 (class 2606 OID 26229)
-- Name: pricebook_item pricebook_item_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT pricebook_item_pkey PRIMARY KEY (id);


--
-- TOC entry 5556 (class 2606 OID 34391)
-- Name: pricebook pricebook_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT pricebook_pkey PRIMARY KEY (id);


--
-- TOC entry 5558 (class 2606 OID 59888)
-- Name: pricebook pricebook_unique_key; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT pricebook_unique_key UNIQUE NULLS NOT DISTINCT (catalog_id, pos_connector_configuration_id, menu_id, item_id, item_variation_id, modifier_group_id, modifier_id, combo_component_id, combo_family_id, combo_master_id);


--
-- TOC entry 5516 (class 2606 OID 26290)
-- Name: tax_group_master tax_group_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.tax_group_master
    ADD CONSTRAINT tax_group_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5519 (class 2606 OID 26299)
-- Name: tax_master tax_master_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.tax_master
    ADD CONSTRAINT tax_master_pkey PRIMARY KEY (id);


--
-- TOC entry 5641 (class 2606 OID 234273)
-- Name: menu_dataset_snapshot unique_snapshot_section; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_snapshot
    ADD CONSTRAINT unique_snapshot_section UNIQUE (snapshot_id, snapshot_section);


--
-- TOC entry 5591 (class 2606 OID 66876)
-- Name: upsell_group_mapping upsell_group_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT upsell_group_mapping_pkey PRIMARY KEY (id);


--
-- TOC entry 5570 (class 2606 OID 63197)
-- Name: upsell_group_offer upsell_group_offer_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT upsell_group_offer_pkey PRIMARY KEY (id);


--
-- TOC entry 5575 (class 2606 OID 63206)
-- Name: upsell_group upsell_group_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group
    ADD CONSTRAINT upsell_group_pkey PRIMARY KEY (id);


--
-- TOC entry 5583 (class 2606 OID 63218)
-- Name: upsell upsell_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell
    ADD CONSTRAINT upsell_pkey PRIMARY KEY (id);


--
-- TOC entry 5663 (class 2606 OID 3552365)
-- Name: upsell_test upsell_test_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_test
    ADD CONSTRAINT upsell_test_pkey PRIMARY KEY (id);


--
-- TOC entry 5652 (class 2606 OID 2277477)
-- Name: menu_dataset_overrides uq_menu_dataset_overrides; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_overrides
    ADD CONSTRAINT uq_menu_dataset_overrides UNIQUE NULLS NOT DISTINCT (item_master_id, combo_master_id, modifier_master_id, menu_dataset_id, location_id, catalog_id);


--
-- TOC entry 5382 (class 1259 OID 37009)
-- Name: IX_modifier_group_master_id_item_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX "IX_modifier_group_master_id_item_master_id" ON public.item_modifier_group_glue USING btree (modifier_group_master_id, item_master_id) INCLUDE (is_deleted, is_active) WITH (deduplicate_items='true');


--
-- TOC entry 5375 (class 1259 OID 3522564)
-- Name: category_displayable_item_pos_linked_entity_unique_idx; Type: INDEX; Schema: public; Owner: citus
--

CREATE UNIQUE INDEX category_displayable_item_pos_linked_entity_unique_idx ON public.category_displayable_item USING btree (catalog_id, item_master_id, combo_family_id, combo_id, category_master_id, sub_category_id, item_variation_id, pre_selected_combo_id) WHERE (pos_linked_entity_id IS NOT NULL);


--
-- TOC entry 5644 (class 1259 OID 320241)
-- Name: idx_audit_new_data_gin; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_audit_new_data_gin ON public.audit USING gin (new_data);


--
-- TOC entry 5645 (class 1259 OID 320240)
-- Name: idx_audit_old_data_gin; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_audit_old_data_gin ON public.audit USING gin (old_data);


--
-- TOC entry 5646 (class 1259 OID 320239)
-- Name: idx_audit_operation_type; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_audit_operation_type ON public.audit USING btree (operation_type);


--
-- TOC entry 5647 (class 1259 OID 320237)
-- Name: idx_audit_record_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_audit_record_id ON public.audit USING btree (record_id);


--
-- TOC entry 5648 (class 1259 OID 320238)
-- Name: idx_audit_timestamp; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_audit_timestamp ON public.audit USING btree (operation_timestamp);


--
-- TOC entry 5529 (class 1259 OID 3522609)
-- Name: idx_catalog_entity_pos_connector_glue_entity_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_catalog_entity_pos_connector_glue_entity_lookup ON public.catalog_entity_pos_connector_glue USING btree (catalog_entity_id, catalog_id, is_deleted) WHERE (is_deleted = false);


--
-- TOC entry 5530 (class 1259 OID 3522608)
-- Name: idx_catalog_entity_pos_connector_glue_join_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_catalog_entity_pos_connector_glue_join_lookup ON public.catalog_entity_pos_connector_glue USING btree (catalog_id, pos_connector_configuration_id, is_deleted) INCLUDE (catalog_entity_id) WHERE (is_deleted = false);


--
-- TOC entry 5616 (class 1259 OID 177986)
-- Name: idx_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_catalog_id ON public.category_parent_child_mapping USING btree (catalog_id);


--
-- TOC entry 5537 (class 1259 OID 3522607)
-- Name: idx_catalog_pos_connector_glue_catalog_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_catalog_pos_connector_glue_catalog_active ON public.catalog_pos_connector_glue USING btree (catalog_id, is_active) INCLUDE (pos_connector_configuration_id, is_master) WHERE (is_active = true);


--
-- TOC entry 5378 (class 1259 OID 1973630)
-- Name: idx_category_displayable_item_sub_category_deleted; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_category_displayable_item_sub_category_deleted ON public.category_displayable_item USING btree (sub_category_id, is_deleted) WHERE (is_deleted = false);


--
-- TOC entry 5617 (class 1259 OID 177984)
-- Name: idx_category_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_category_id ON public.category_parent_child_mapping USING btree (child_id);


--
-- TOC entry 5396 (class 1259 OID 1973632)
-- Name: idx_category_master_id_deleted; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_category_master_id_deleted ON public.category_master USING btree (id, is_deleted) WHERE (is_deleted = false);


--
-- TOC entry 5626 (class 1259 OID 184062)
-- Name: idx_child_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_child_id ON public.modifier_code_parent_child_mapping USING btree (child_id);


--
-- TOC entry 5403 (class 1259 OID 1627051)
-- Name: idx_combo_component_item_glue_item_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_component_item_glue_item_master_id ON public.combo_component_item_glue USING btree (item_master_id);


--
-- TOC entry 5404 (class 1259 OID 736469)
-- Name: idx_combo_component_item_glue_query_optimization; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_component_item_glue_query_optimization ON public.combo_component_item_glue USING btree (catalog_id, combo_component_id, is_deleted, is_active, is_default) INCLUDE (item_master_id, id);


--
-- TOC entry 5410 (class 1259 OID 736565)
-- Name: idx_combo_component_min_selection; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_component_min_selection ON public.combo_component USING btree (catalog_id, id) INCLUDE (min_selection);


--
-- TOC entry 5426 (class 1259 OID 1975269)
-- Name: idx_combo_master_catalog_deleted_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_master_catalog_deleted_active ON public.combo_master USING btree (catalog_id, is_deleted, is_active) INCLUDE (name, display_name, pos_linked_entity_id) WHERE (is_deleted = false);


--
-- TOC entry 5427 (class 1259 OID 1975271)
-- Name: idx_combo_master_catalog_display_name; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_master_catalog_display_name ON public.combo_master USING btree (catalog_id, display_name) WHERE (is_deleted = false);


--
-- TOC entry 5428 (class 1259 OID 1975272)
-- Name: idx_combo_master_catalog_is_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_master_catalog_is_active ON public.combo_master USING btree (catalog_id, is_active) WHERE (is_deleted = false);


--
-- TOC entry 5429 (class 1259 OID 1975270)
-- Name: idx_combo_master_catalog_name; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_master_catalog_name ON public.combo_master USING btree (catalog_id, name) WHERE (is_deleted = false);


--
-- TOC entry 5423 (class 1259 OID 1975273)
-- Name: idx_combo_master_component_glue_combo_catalog; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_master_component_glue_combo_catalog ON public.combo_master_component_glue USING btree (combo_master_id, catalog_id) INCLUDE (combo_component_id, display_order) WHERE (combo_master_id IS NOT NULL);


--
-- TOC entry 5625 (class 1259 OID 1975268)
-- Name: idx_combo_parent_child_child_catalog; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_combo_parent_child_child_catalog ON public.combo_parent_child_mapping USING btree (child_id, catalog_id) WHERE (catalog_id IS NOT NULL);


--
-- TOC entry 5661 (class 1259 OID 3488722)
-- Name: idx_hitl_id_org_entity_type; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_hitl_id_org_entity_type ON public.human_in_the_loop_interaction USING btree (id, organization_id, entity_type);

ALTER TABLE public.human_in_the_loop_interaction CLUSTER ON idx_hitl_id_org_entity_type;


--
-- TOC entry 5559 (class 1259 OID 1975274)
-- Name: idx_item_86_combo_connector_deleted; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_item_86_combo_connector_deleted ON public.item_86 USING btree (combo_master_id, pos_connector_config_id, is_deleted) INCLUDE (is_active, modified_on) WHERE ((is_deleted = false) AND (combo_master_id IS NOT NULL));


--
-- TOC entry 5620 (class 1259 OID 177997)
-- Name: idx_item_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_item_id ON public.item_parent_child_mapping USING btree (child_id);


--
-- TOC entry 5433 (class 1259 OID 736566)
-- Name: idx_item_master_active_catalog; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_item_master_active_catalog ON public.item_master USING btree (catalog_id, is_active, id) INCLUDE (pos_linked_entity_id);


--
-- TOC entry 5446 (class 1259 OID 1973631)
-- Name: idx_menu_category_menu_deleted_display; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_menu_category_menu_deleted_display ON public.menu_category USING btree (menu_id, is_deleted, display_order) WHERE (is_deleted = false);


--
-- TOC entry 5520 (class 1259 OID 2358558)
-- Name: idx_menu_dataset_org_parent_null_status; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_menu_dataset_org_parent_null_status ON public.menu_dataset USING btree (organization_id, status) INCLUDE (id, name, catalog_id, created_on, modified_on, published_on) WHERE (parent_id IS NULL);


--
-- TOC entry 5521 (class 1259 OID 2358556)
-- Name: idx_menu_dataset_org_parent_status; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_menu_dataset_org_parent_status ON public.menu_dataset USING btree (organization_id, parent_id, status) INCLUDE (id, name, published_on, archived_on, published_by, archived_by, created_on) WHERE (parent_id IS NOT NULL);


--
-- TOC entry 5522 (class 1259 OID 2358557)
-- Name: idx_menu_dataset_parent_status_published; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_menu_dataset_parent_status_published ON public.menu_dataset USING btree (parent_id, status, published_on DESC) INCLUDE (id, name, published_by, archived_by, archived_on, created_on) WHERE (parent_id IS NOT NULL);


--
-- TOC entry 5465 (class 1259 OID 128693)
-- Name: idx_modifier_group_master_catalog_id_is_deleted; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_modifier_group_master_catalog_id_is_deleted ON public.modifier_group_master USING btree (catalog_id, is_deleted);


--
-- TOC entry 5618 (class 1259 OID 177985)
-- Name: idx_parent_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_parent_id ON public.category_parent_child_mapping USING btree (parent_id);


--
-- TOC entry 5505 (class 1259 OID 277943)
-- Name: idx_pos_linked_entity_conflict; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pos_linked_entity_conflict ON public.pos_linked_entity USING btree (catalog_id, pos_entity_type, pos_entity_external_id) WITH (deduplicate_items='true');


--
-- TOC entry 5619 (class 1259 OID 177987)
-- Name: idx_pos_mapping_name_group; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pos_mapping_name_group ON public.category_parent_child_mapping USING btree (pos_mapping_name) INCLUDE (modified_on);


--
-- TOC entry 5543 (class 1259 OID 310041)
-- Name: idx_pricebook_catalog_pos_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pricebook_catalog_pos_active ON public.pricebook USING btree (catalog_id, pos_connector_configuration_id, is_active, is_deleted);


--
-- TOC entry 5544 (class 1259 OID 736564)
-- Name: idx_pricebook_combo_component_optimization; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pricebook_combo_component_optimization ON public.pricebook USING btree (catalog_id, combo_component_id, item_id, pos_connector_configuration_id, modifier_id, is_active, is_deleted) INCLUDE (price, id);


--
-- TOC entry 5545 (class 1259 OID 310043)
-- Name: idx_pricebook_ids; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pricebook_ids ON public.pricebook USING btree (item_id, combo_master_id, modifier_id, modifier_group_id);


--
-- TOC entry 5546 (class 1259 OID 409574)
-- Name: idx_pricebook_ids_with_catalog; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pricebook_ids_with_catalog ON public.pricebook USING btree (catalog_id, modifier_id, modifier_group_id);


--
-- TOC entry 5547 (class 1259 OID 3612965)
-- Name: idx_pricebook_inactives_by_type; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_pricebook_inactives_by_type ON public.pricebook USING btree (catalog_id, pos_connector_configuration_id, item_id, combo_master_id, modifier_id, modifier_group_id) WHERE ((is_active = false) AND (is_deleted = false) AND (menu_id IS NULL) AND (category_id IS NULL) AND (item_variation_id IS NULL) AND (combo_family_id IS NULL) AND (combo_component_id IS NULL));


--
-- TOC entry 5633 (class 1259 OID 234277)
-- Name: idx_snapshots_body_gin; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_snapshots_body_gin ON public.menu_dataset_snapshot USING gin (snapshot_section_data);


--
-- TOC entry 5634 (class 1259 OID 234278)
-- Name: idx_snapshots_body_path_gin; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_snapshots_body_path_gin ON public.menu_dataset_snapshot USING gin (snapshot_section_data jsonb_path_ops);


--
-- TOC entry 5635 (class 1259 OID 234276)
-- Name: idx_snapshots_id_section; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_snapshots_id_section ON public.menu_dataset_snapshot USING btree (snapshot_id, snapshot_section);


--
-- TOC entry 5636 (class 1259 OID 234275)
-- Name: idx_snapshots_section; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_snapshots_section ON public.menu_dataset_snapshot USING btree (snapshot_section);


--
-- TOC entry 5637 (class 1259 OID 234274)
-- Name: idx_snapshots_snapshot_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_snapshots_snapshot_id ON public.menu_dataset_snapshot USING btree (snapshot_id);


--
-- TOC entry 5576 (class 1259 OID 3310005)
-- Name: idx_upsell_catalog_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_catalog_lookup ON public.upsell USING btree (catalog_id, is_deleted, upsell_type) WHERE (menu_dataset_id IS NULL);


--
-- TOC entry 5577 (class 1259 OID 3310006)
-- Name: idx_upsell_dataset_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_dataset_lookup ON public.upsell USING btree (catalog_id, menu_dataset_id, is_deleted, upsell_type);


--
-- TOC entry 5571 (class 1259 OID 3310009)
-- Name: idx_upsell_group_catalog_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_group_catalog_lookup ON public.upsell_group USING btree (catalog_id, upsell_id);


--
-- TOC entry 5588 (class 1259 OID 3310055)
-- Name: idx_upsell_group_mapping_catalog_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_group_mapping_catalog_lookup ON public.upsell_group_mapping USING btree (catalog_id, upsell_group_id);


--
-- TOC entry 5566 (class 1259 OID 3310010)
-- Name: idx_upsell_group_offer_catalog_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_group_offer_catalog_lookup ON public.upsell_group_offer USING btree (catalog_id, upsell_group_id);


--
-- TOC entry 5578 (class 1259 OID 3310007)
-- Name: idx_upsell_organization_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_organization_lookup ON public.upsell USING btree (organization_id, is_deleted, upsell_type);


--
-- TOC entry 5579 (class 1259 OID 3310008)
-- Name: idx_upsell_pos_linked_entity; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX idx_upsell_pos_linked_entity ON public.upsell USING btree (pos_linked_entity_id) WHERE (pos_linked_entity_id IS NOT NULL);


--
-- TOC entry 5531 (class 1259 OID 195258)
-- Name: ix_catalog_entity_pos_connector_glue_by_catalog_id_pos_connecto; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_entity_pos_connector_glue_by_catalog_id_pos_connecto ON public.catalog_entity_pos_connector_glue USING btree (catalog_id, pos_connector_configuration_id, catalog_entity_id) INCLUDE (is_deleted);


--
-- TOC entry 5612 (class 1259 OID 196410)
-- Name: ix_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id ON public.concessionaire_config USING btree (catalog_id);


--
-- TOC entry 5405 (class 1259 OID 63256)
-- Name: ix_catalog_id_combo_component_id_item_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_combo_component_id_item_id ON public.combo_component_item_glue USING btree (catalog_id, combo_component_id, item_master_id) INCLUDE (is_active, is_deleted);


--
-- TOC entry 5483 (class 1259 OID 62264)
-- Name: ix_catalog_id_modifier_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_modifier_master_id ON public.modifier_group_modifier_glue USING btree (catalog_id, modifier_master_id, modifier_group_master_id);


--
-- TOC entry 5532 (class 1259 OID 197328)
-- Name: ix_catalog_id_on_catalog_entity_pos_connector_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_catalog_entity_pos_connector_glue ON public.catalog_entity_pos_connector_glue USING btree (catalog_id);


--
-- TOC entry 5538 (class 1259 OID 197332)
-- Name: ix_catalog_id_on_catalog_pos_connector_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_catalog_pos_connector_glue ON public.catalog_pos_connector_glue USING btree (catalog_id);


--
-- TOC entry 5368 (class 1259 OID 197337)
-- Name: ix_catalog_id_on_catalog_sync_history; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_catalog_sync_history ON public.catalog_sync_history USING btree (catalog_id);


--
-- TOC entry 5379 (class 1259 OID 197315)
-- Name: ix_catalog_id_on_category_displayable_item; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_category_displayable_item ON public.category_displayable_item USING btree (catalog_id);


--
-- TOC entry 5397 (class 1259 OID 197231)
-- Name: ix_catalog_id_on_category_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_category_master ON public.category_master USING btree (catalog_id);


--
-- TOC entry 5411 (class 1259 OID 197353)
-- Name: ix_catalog_id_on_combo_component; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_component ON public.combo_component USING btree (catalog_id);


--
-- TOC entry 5406 (class 1259 OID 197345)
-- Name: ix_catalog_id_on_combo_component_item_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_component_item_glue ON public.combo_component_item_glue USING btree (catalog_id);


--
-- TOC entry 5541 (class 1259 OID 197342)
-- Name: ix_catalog_id_on_combo_component_item_glue_group; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_component_item_glue_group ON public.combo_component_item_glue_group USING btree (catalog_id);


--
-- TOC entry 5418 (class 1259 OID 197370)
-- Name: ix_catalog_id_on_combo_family; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_family ON public.combo_family USING btree (catalog_id);


--
-- TOC entry 5415 (class 1259 OID 197363)
-- Name: ix_catalog_id_on_combo_family_member; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_family_member ON public.combo_family_member USING btree (catalog_id);


--
-- TOC entry 5596 (class 1259 OID 197375)
-- Name: ix_catalog_id_on_combo_item_modifier_group_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_item_modifier_group_override ON public.combo_item_modifier_group_override USING btree (catalog_id);


--
-- TOC entry 5604 (class 1259 OID 197387)
-- Name: ix_catalog_id_on_combo_item_modifier_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_item_modifier_override ON public.combo_item_modifier_override USING btree (catalog_id);


--
-- TOC entry 5430 (class 1259 OID 197248)
-- Name: ix_catalog_id_on_combo_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_combo_master ON public.combo_master USING btree (catalog_id);


--
-- TOC entry 5613 (class 1259 OID 197218)
-- Name: ix_catalog_id_on_concessionaire_config; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_concessionaire_config ON public.concessionaire_config USING btree (catalog_id);


--
-- TOC entry 5564 (class 1259 OID 197219)
-- Name: ix_catalog_id_on_item_86; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_86 ON public.item_86 USING btree (catalog_id);


--
-- TOC entry 5436 (class 1259 OID 197260)
-- Name: ix_catalog_id_on_item_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_master ON public.item_master USING btree (catalog_id);


--
-- TOC entry 5387 (class 1259 OID 197397)
-- Name: ix_catalog_id_on_item_modifier_group_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_modifier_group_glue ON public.item_modifier_group_glue USING btree (catalog_id);


--
-- TOC entry 5392 (class 1259 OID 197406)
-- Name: ix_catalog_id_on_item_modifier_group_modifier_config; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_modifier_group_modifier_config ON public.item_modifier_group_modifier_config USING btree (catalog_id);


--
-- TOC entry 5608 (class 1259 OID 197419)
-- Name: ix_catalog_id_on_item_modifier_group_overrides; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_modifier_group_overrides ON public.item_modifier_group_overrides USING btree (catalog_id);


--
-- TOC entry 5442 (class 1259 OID 197275)
-- Name: ix_catalog_id_on_item_variation_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_item_variation_master ON public.item_variation_master USING btree (catalog_id);


--
-- TOC entry 5447 (class 1259 OID 197430)
-- Name: ix_catalog_id_on_menu_category; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_category ON public.menu_category USING btree (catalog_id);


--
-- TOC entry 5443 (class 1259 OID 197429)
-- Name: ix_catalog_id_on_menu_category_displayable_item_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_category_displayable_item_override ON public.menu_category_displayable_item_override USING btree (catalog_id);


--
-- TOC entry 5523 (class 1259 OID 197440)
-- Name: ix_catalog_id_on_menu_dataset; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_dataset ON public.menu_dataset USING btree (catalog_id);


--
-- TOC entry 5451 (class 1259 OID 197448)
-- Name: ix_catalog_id_on_menu_item_modifier_group_modifier_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_item_modifier_group_modifier_override ON public.menu_item_modifier_group_modifier_override USING btree (catalog_id);


--
-- TOC entry 5454 (class 1259 OID 197449)
-- Name: ix_catalog_id_on_menu_item_modifier_group_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_item_modifier_group_override ON public.menu_item_modifier_group_override USING btree (catalog_id);


--
-- TOC entry 5457 (class 1259 OID 197276)
-- Name: ix_catalog_id_on_menu_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_menu_master ON public.menu_master USING btree (catalog_id);


--
-- TOC entry 5461 (class 1259 OID 197281)
-- Name: ix_catalog_id_on_modifier_code_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_code_master ON public.modifier_code_master USING btree (catalog_id);


--
-- TOC entry 5466 (class 1259 OID 197288)
-- Name: ix_catalog_id_on_modifier_group_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_group_master ON public.modifier_group_master USING btree (catalog_id);


--
-- TOC entry 5484 (class 1259 OID 197450)
-- Name: ix_catalog_id_on_modifier_group_modifier_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_group_modifier_glue ON public.modifier_group_modifier_glue USING btree (catalog_id);


--
-- TOC entry 5490 (class 1259 OID 197458)
-- Name: ix_catalog_id_on_modifier_group_modifier_modifier_code_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_group_modifier_modifier_code_glue ON public.modifier_group_modifier_modifier_code_glue USING btree (catalog_id);


--
-- TOC entry 5470 (class 1259 OID 197301)
-- Name: ix_catalog_id_on_modifier_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_master ON public.modifier_master USING btree (catalog_id);


--
-- TOC entry 5495 (class 1259 OID 197468)
-- Name: ix_catalog_id_on_modifier_modifier_code_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_modifier_code_glue ON public.modifier_modifier_code_glue USING btree (catalog_id);


--
-- TOC entry 5500 (class 1259 OID 197469)
-- Name: ix_catalog_id_on_modifier_nested_modifier_group_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_modifier_nested_modifier_group_glue ON public.modifier_nested_modifier_group_glue USING btree (catalog_id);


--
-- TOC entry 5506 (class 1259 OID 197478)
-- Name: ix_catalog_id_on_pos_linked_entity; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_pos_linked_entity ON public.pos_linked_entity USING btree (catalog_id);


--
-- TOC entry 5475 (class 1259 OID 197485)
-- Name: ix_catalog_id_on_pre_selected_combo_item; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_pre_selected_combo_item ON public.pre_selected_combo_item USING btree (catalog_id);


--
-- TOC entry 5478 (class 1259 OID 197312)
-- Name: ix_catalog_id_on_pre_selected_combo_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_pre_selected_combo_master ON public.pre_selected_combo_master USING btree (catalog_id);


--
-- TOC entry 5548 (class 1259 OID 197486)
-- Name: ix_catalog_id_on_pricebook; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_pricebook ON public.pricebook USING btree (catalog_id);


--
-- TOC entry 5514 (class 1259 OID 197313)
-- Name: ix_catalog_id_on_tax_group_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_tax_group_master ON public.tax_group_master USING btree (catalog_id);


--
-- TOC entry 5517 (class 1259 OID 197314)
-- Name: ix_catalog_id_on_tax_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_on_tax_master ON public.tax_master USING btree (catalog_id);


--
-- TOC entry 5580 (class 1259 OID 63219)
-- Name: ix_catalog_id_organization_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_catalog_id_organization_id ON public.upsell USING btree (catalog_id, organization_id);


--
-- TOC entry 5380 (class 1259 OID 292659)
-- Name: ix_category_displayable_item_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_category_displayable_item_optimized ON public.category_displayable_item USING btree (catalog_id, category_master_id, is_active, is_deleted, display_order);


--
-- TOC entry 5419 (class 1259 OID 292667)
-- Name: ix_combo_family_join_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_combo_family_join_optimized ON public.combo_family USING btree (id, catalog_id, is_deleted, is_active, created_on, modified_on);


--
-- TOC entry 5597 (class 1259 OID 195263)
-- Name: ix_combo_item_modifier_group_override_by_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_combo_item_modifier_group_override_by_catalog_id ON public.combo_item_modifier_group_override USING btree (catalog_id, id) INCLUDE (is_deleted);


--
-- TOC entry 5598 (class 1259 OID 318028)
-- Name: ix_combo_item_modifier_group_override_catalog_pos_entity; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_combo_item_modifier_group_override_catalog_pos_entity ON public.combo_item_modifier_group_override USING btree (catalog_id, pos_linked_entity_id) INCLUDE (combo_id, item_id, modifier_group_id, is_invisible, combo_component_id, is_active, is_deleted);


--
-- TOC entry 5431 (class 1259 OID 292666)
-- Name: ix_combo_master_join_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_combo_master_join_optimized ON public.combo_master USING btree (id, catalog_id, is_deleted, is_active, created_on, modified_on);


--
-- TOC entry 5666 (class 1259 OID 3623845)
-- Name: ix_dietary_tag_master_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_dietary_tag_master_catalog_id ON public.dietary_tag_master USING btree (catalog_id);


--
-- TOC entry 5586 (class 1259 OID 63425)
-- Name: ix_discount_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_discount_catalog_id ON public.discount USING btree (catalog_id, menu_dataset_id);


--
-- TOC entry 5565 (class 1259 OID 292663)
-- Name: ix_item_86_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_86_optimized ON public.item_86 USING btree (catalog_id, pos_connector_config_id, is_active, is_deleted) INCLUDE (item_master_id, combo_master_id);


--
-- TOC entry 5670 (class 1259 OID 3625231)
-- Name: ix_item_dietary_tags_glue_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_dietary_tags_glue_catalog_id ON public.item_dietary_tags_glue USING btree (catalog_id);


--
-- TOC entry 5671 (class 1259 OID 3625230)
-- Name: ix_item_dietary_tags_glue_dietary_tag_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_dietary_tags_glue_dietary_tag_master_id ON public.item_dietary_tags_glue USING btree (dietary_tag_master_id);


--
-- TOC entry 5672 (class 1259 OID 3625229)
-- Name: ix_item_dietary_tags_glue_item_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_dietary_tags_glue_item_master_id ON public.item_dietary_tags_glue USING btree (item_master_id);


--
-- TOC entry 5437 (class 1259 OID 42375)
-- Name: ix_item_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_master ON public.item_master USING btree (catalog_id);


--
-- TOC entry 5438 (class 1259 OID 292665)
-- Name: ix_item_master_join_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_item_master_join_optimized ON public.item_master USING btree (id, catalog_id, is_deleted, is_active, created_on, modified_on);


--
-- TOC entry 5524 (class 1259 OID 292664)
-- Name: ix_menu_dataset_optimized; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_menu_dataset_optimized ON public.menu_dataset USING btree (catalog_id, id);


--
-- TOC entry 5674 (class 1259 OID 3625250)
-- Name: ix_modifier_dietary_tags_glue_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_modifier_dietary_tags_glue_catalog_id ON public.modifier_dietary_tags_glue USING btree (catalog_id);


--
-- TOC entry 5675 (class 1259 OID 3625249)
-- Name: ix_modifier_dietary_tags_glue_dietary_tag_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_modifier_dietary_tags_glue_dietary_tag_master_id ON public.modifier_dietary_tags_glue USING btree (dietary_tag_master_id);


--
-- TOC entry 5676 (class 1259 OID 3625248)
-- Name: ix_modifier_dietary_tags_glue_modifier_master_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_modifier_dietary_tags_glue_modifier_master_id ON public.modifier_dietary_tags_glue USING btree (modifier_master_id);


--
-- TOC entry 5485 (class 1259 OID 42374)
-- Name: ix_modifier_group_modifier_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_modifier_group_modifier_glue ON public.modifier_group_modifier_glue USING btree (modifier_master_id, modifier_group_master_id, is_deleted);


--
-- TOC entry 5471 (class 1259 OID 42373)
-- Name: ix_modifier_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_modifier_master ON public.modifier_master USING btree (id, catalog_id, pos_linked_entity_id);


--
-- TOC entry 5381 (class 1259 OID 199506)
-- Name: ix_ple_id_on_category_displayable_item; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_category_displayable_item ON public.category_displayable_item USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5398 (class 1259 OID 199518)
-- Name: ix_ple_id_on_category_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_category_master ON public.category_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5412 (class 1259 OID 199535)
-- Name: ix_ple_id_on_combo_component; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_component ON public.combo_component USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5407 (class 1259 OID 199546)
-- Name: ix_ple_id_on_combo_component_item_glue; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_component_item_glue ON public.combo_component_item_glue USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5542 (class 1259 OID 199554)
-- Name: ix_ple_id_on_combo_component_item_glue_group; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_component_item_glue_group ON public.combo_component_item_glue_group USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5420 (class 1259 OID 199557)
-- Name: ix_ple_id_on_combo_family; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_family ON public.combo_family USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5599 (class 1259 OID 199563)
-- Name: ix_ple_id_on_combo_item_modifier_group_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_item_modifier_group_override ON public.combo_item_modifier_group_override USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5605 (class 1259 OID 199575)
-- Name: ix_ple_id_on_combo_item_modifier_override; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_item_modifier_override ON public.combo_item_modifier_override USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5432 (class 1259 OID 199585)
-- Name: ix_ple_id_on_combo_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_combo_master ON public.combo_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5587 (class 1259 OID 199597)
-- Name: ix_ple_id_on_discount; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_discount ON public.discount USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5439 (class 1259 OID 199608)
-- Name: ix_ple_id_on_item_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_item_master ON public.item_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5393 (class 1259 OID 199624)
-- Name: ix_ple_id_on_item_modifier_group_modifier_config; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_item_modifier_group_modifier_config ON public.item_modifier_group_modifier_config USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5609 (class 1259 OID 199637)
-- Name: ix_ple_id_on_item_modifier_group_overrides; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_item_modifier_group_overrides ON public.item_modifier_group_overrides USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5448 (class 1259 OID 199647)
-- Name: ix_ple_id_on_menu_category; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_menu_category ON public.menu_category USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5458 (class 1259 OID 199657)
-- Name: ix_ple_id_on_menu_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_menu_master ON public.menu_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5462 (class 1259 OID 199662)
-- Name: ix_ple_id_on_modifier_code_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_modifier_code_master ON public.modifier_code_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5467 (class 1259 OID 199669)
-- Name: ix_ple_id_on_modifier_group_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_modifier_group_master ON public.modifier_group_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5472 (class 1259 OID 199681)
-- Name: ix_ple_id_on_modifier_master; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_modifier_master ON public.modifier_master USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5549 (class 1259 OID 199692)
-- Name: ix_ple_id_on_pricebook; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_pricebook ON public.pricebook USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5581 (class 1259 OID 199706)
-- Name: ix_ple_id_on_upsell; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_upsell ON public.upsell USING btree (catalog_id, pos_linked_entity_id);


--
-- TOC entry 5572 (class 1259 OID 199711)
-- Name: ix_ple_id_on_upsell_group; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_upsell_group ON public.upsell_group USING btree (pos_linked_entity_id);


--
-- TOC entry 5589 (class 1259 OID 199715)
-- Name: ix_ple_id_on_upsell_group_mapping; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_upsell_group_mapping ON public.upsell_group_mapping USING btree (pos_linked_entity_id);


--
-- TOC entry 5567 (class 1259 OID 199721)
-- Name: ix_ple_id_on_upsell_group_offer; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_ple_id_on_upsell_group_offer ON public.upsell_group_offer USING btree (pos_linked_entity_id);


--
-- TOC entry 5550 (class 1259 OID 42376)
-- Name: ix_pricebook; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_pricebook ON public.pricebook USING btree (catalog_id);


--
-- TOC entry 5551 (class 1259 OID 196951)
-- Name: ix_pricebook_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_pricebook_catalog_id ON public.pricebook USING btree (catalog_id);


--
-- TOC entry 5552 (class 1259 OID 292662)
-- Name: ix_pricebook_combo_family_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_pricebook_combo_family_lookup ON public.pricebook USING btree (catalog_id, combo_family_id, pos_connector_configuration_id);


--
-- TOC entry 5553 (class 1259 OID 292661)
-- Name: ix_pricebook_combo_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_pricebook_combo_lookup ON public.pricebook USING btree (catalog_id, combo_master_id, pos_connector_configuration_id) WHERE ((combo_component_id IS NULL) AND (modifier_id IS NULL) AND (item_id IS NULL));


--
-- TOC entry 5554 (class 1259 OID 292660)
-- Name: ix_pricebook_item_lookup; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_pricebook_item_lookup ON public.pricebook USING btree (catalog_id, item_id, pos_connector_configuration_id) WHERE ((combo_component_id IS NULL) AND (modifier_id IS NULL) AND (combo_master_id IS NULL));


--
-- TOC entry 5568 (class 1259 OID 63198)
-- Name: ix_upsell_group_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_upsell_group_id ON public.upsell_group_offer USING btree (upsell_group_id);


--
-- TOC entry 5573 (class 1259 OID 63207)
-- Name: ix_upsell_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE INDEX ix_upsell_id ON public.upsell_group USING btree (upsell_id);


--
-- TOC entry 5509 (class 1259 OID 318021)
-- Name: pos_linked_entity_id_catalog_id; Type: INDEX; Schema: public; Owner: citus
--

CREATE UNIQUE INDEX pos_linked_entity_id_catalog_id ON public.pos_linked_entity USING btree (catalog_id, id);


--
-- TOC entry 5667 (class 1259 OID 3623844)
-- Name: uq_dietary_tag_master_catalog_name; Type: INDEX; Schema: public; Owner: citus
--

CREATE UNIQUE INDEX uq_dietary_tag_master_catalog_name ON public.dietary_tag_master USING btree (catalog_id, lower((name)::text)) WHERE (is_deleted = false);


--
-- TOC entry 5673 (class 1259 OID 3625228)
-- Name: uq_item_dietary_tags_glue_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE UNIQUE INDEX uq_item_dietary_tags_glue_active ON public.item_dietary_tags_glue USING btree (catalog_id, item_master_id, dietary_tag_master_id) WHERE (is_deleted = false);


--
-- TOC entry 5679 (class 1259 OID 3625247)
-- Name: uq_modifier_dietary_tags_glue_active; Type: INDEX; Schema: public; Owner: citus
--

CREATE UNIQUE INDEX uq_modifier_dietary_tags_glue_active ON public.modifier_dietary_tags_glue USING btree (catalog_id, modifier_master_id, dietary_tag_master_id) WHERE (is_deleted = false);


--
-- TOC entry 5844 (class 2620 OID 320667)
-- Name: category_master trigger_audit_category_master; Type: TRIGGER; Schema: public; Owner: citus
--

CREATE TRIGGER trigger_audit_category_master AFTER DELETE OR UPDATE ON public.category_master FOR EACH ROW EXECUTE FUNCTION public.audit_changes();


--
-- TOC entry 5762 (class 2606 OID 30023)
-- Name: catalog_entity_pos_connector_glue catalog_entity_pos_connector_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_entity_pos_connector_glue
    ADD CONSTRAINT catalog_entity_pos_connector_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5681 (class 2606 OID 26574)
-- Name: category_displayable_item category_displayable_item_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT category_displayable_item_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5682 (class 2606 OID 26566)
-- Name: category_displayable_item category_displayable_item_combo_family_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT category_displayable_item_combo_family_id_fkey FOREIGN KEY (combo_family_id) REFERENCES public.combo_family(id);


--
-- TOC entry 5683 (class 2606 OID 28064)
-- Name: category_displayable_item category_displayable_item_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT category_displayable_item_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5698 (class 2606 OID 26579)
-- Name: combo_component_item_glue combo_component_item_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue
    ADD CONSTRAINT combo_component_item_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5703 (class 2606 OID 29939)
-- Name: combo_family_member combo_family_member_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family_member
    ADD CONSTRAINT combo_family_member_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5704 (class 2606 OID 26778)
-- Name: combo_family_member combo_family_member_item_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family_member
    ADD CONSTRAINT combo_family_member_item_master_id_fkey FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5707 (class 2606 OID 26642)
-- Name: combo_family combo_family_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family
    ADD CONSTRAINT combo_family_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5795 (class 2606 OID 71579)
-- Name: combo_item_modifier_group_override combo_item_modifier_group_override_combo_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT combo_item_modifier_group_override_combo_component_id_fkey FOREIGN KEY (combo_component_id) REFERENCES public.combo_component(id);


--
-- TOC entry 5709 (class 2606 OID 29944)
-- Name: combo_master_component_glue combo_master_component_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master_component_glue
    ADD CONSTRAINT combo_master_component_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5828 (class 2606 OID 3623834)
-- Name: dietary_tag_master dietary_tag_master_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.dietary_tag_master
    ADD CONSTRAINT dietary_tag_master_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5829 (class 2606 OID 3623839)
-- Name: dietary_tag_master dietary_tag_master_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.dietary_tag_master
    ADD CONSTRAINT dietary_tag_master_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5763 (class 2606 OID 28243)
-- Name: catalog_pos_connector_glue fk_catalog_pos_connector_glue_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_pos_connector_glue
    ADD CONSTRAINT fk_catalog_pos_connector_glue_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5680 (class 2606 OID 26300)
-- Name: catalog_sync_history fk_catalog_sync_history_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.catalog_sync_history
    ADD CONSTRAINT fk_catalog_sync_history_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5684 (class 2606 OID 26305)
-- Name: category_displayable_item fk_category_displayable_item_category_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT fk_category_displayable_item_category_master_id FOREIGN KEY (category_master_id) REFERENCES public.category_master(id);


--
-- TOC entry 5685 (class 2606 OID 26325)
-- Name: category_displayable_item fk_category_displayable_item_combo_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT fk_category_displayable_item_combo_id FOREIGN KEY (combo_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5686 (class 2606 OID 26310)
-- Name: category_displayable_item fk_category_displayable_item_item_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT fk_category_displayable_item_item_master_id FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5687 (class 2606 OID 26315)
-- Name: category_displayable_item fk_category_displayable_item_item_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT fk_category_displayable_item_item_variation_id FOREIGN KEY (item_variation_id) REFERENCES public.item_variation_master(id);


--
-- TOC entry 5688 (class 2606 OID 26320)
-- Name: category_displayable_item fk_category_displayable_item_pre_selected_combo_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_displayable_item
    ADD CONSTRAINT fk_category_displayable_item_pre_selected_combo_id FOREIGN KEY (pre_selected_combo_id) REFERENCES public.pre_selected_combo_master(id);


--
-- TOC entry 5696 (class 2606 OID 26330)
-- Name: category_master fk_category_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_master
    ADD CONSTRAINT fk_category_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5697 (class 2606 OID 26335)
-- Name: category_master fk_category_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_master
    ADD CONSTRAINT fk_category_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5805 (class 2606 OID 178008)
-- Name: category_parent_child_mapping fk_category_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_parent_child_mapping
    ADD CONSTRAINT fk_category_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5806 (class 2606 OID 177998)
-- Name: category_parent_child_mapping fk_category_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_parent_child_mapping
    ADD CONSTRAINT fk_category_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.category_master(id);


--
-- TOC entry 5807 (class 2606 OID 178003)
-- Name: category_parent_child_mapping fk_category_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.category_parent_child_mapping
    ADD CONSTRAINT fk_category_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.category_master(id);


--
-- TOC entry 5701 (class 2606 OID 26340)
-- Name: combo_component fk_combo_component_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component
    ADD CONSTRAINT fk_combo_component_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5699 (class 2606 OID 26350)
-- Name: combo_component_item_glue fk_combo_component_item_glue_combo_component_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue
    ADD CONSTRAINT fk_combo_component_item_glue_combo_component_id FOREIGN KEY (combo_component_id) REFERENCES public.combo_component(id);


--
-- TOC entry 5700 (class 2606 OID 26355)
-- Name: combo_component_item_glue fk_combo_component_item_glue_item_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component_item_glue
    ADD CONSTRAINT fk_combo_component_item_glue_item_master_id FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5702 (class 2606 OID 26345)
-- Name: combo_component fk_combo_component_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_component
    ADD CONSTRAINT fk_combo_component_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5708 (class 2606 OID 26360)
-- Name: combo_family fk_combo_family_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family
    ADD CONSTRAINT fk_combo_family_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5705 (class 2606 OID 26370)
-- Name: combo_family_member fk_combo_family_member_combo_family_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family_member
    ADD CONSTRAINT fk_combo_family_member_combo_family_id FOREIGN KEY (combo_family_id) REFERENCES public.combo_family(id);


--
-- TOC entry 5706 (class 2606 OID 26365)
-- Name: combo_family_member fk_combo_family_member_combo_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_family_member
    ADD CONSTRAINT fk_combo_family_member_combo_master_id FOREIGN KEY (combo_master_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5796 (class 2606 OID 69860)
-- Name: combo_item_modifier_group_override fk_combo_item_modifier_group_override_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT fk_combo_item_modifier_group_override_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5797 (class 2606 OID 69865)
-- Name: combo_item_modifier_group_override fk_combo_item_modifier_group_override_combo_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT fk_combo_item_modifier_group_override_combo_id FOREIGN KEY (combo_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5798 (class 2606 OID 69870)
-- Name: combo_item_modifier_group_override fk_combo_item_modifier_group_override_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT fk_combo_item_modifier_group_override_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5799 (class 2606 OID 69875)
-- Name: combo_item_modifier_group_override fk_combo_item_modifier_group_override_modifier_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_group_override
    ADD CONSTRAINT fk_combo_item_modifier_group_override_modifier_group_id FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5800 (class 2606 OID 69880)
-- Name: combo_item_modifier_override fk_combo_item_modifier_override_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT fk_combo_item_modifier_override_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5801 (class 2606 OID 69885)
-- Name: combo_item_modifier_override fk_combo_item_modifier_override_combo_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT fk_combo_item_modifier_override_combo_id FOREIGN KEY (combo_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5802 (class 2606 OID 69890)
-- Name: combo_item_modifier_override fk_combo_item_modifier_override_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT fk_combo_item_modifier_override_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5803 (class 2606 OID 69895)
-- Name: combo_item_modifier_override fk_combo_item_modifier_override_modifier_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_item_modifier_override
    ADD CONSTRAINT fk_combo_item_modifier_override_modifier_id FOREIGN KEY (modifier_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5712 (class 2606 OID 26385)
-- Name: combo_master fk_combo_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master
    ADD CONSTRAINT fk_combo_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5710 (class 2606 OID 26375)
-- Name: combo_master_component_glue fk_combo_master_component_glue_combo_component_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master_component_glue
    ADD CONSTRAINT fk_combo_master_component_glue_combo_component_id FOREIGN KEY (combo_component_id) REFERENCES public.combo_component(id);


--
-- TOC entry 5711 (class 2606 OID 26380)
-- Name: combo_master_component_glue fk_combo_master_component_glue_combo_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_master_component_glue
    ADD CONSTRAINT fk_combo_master_component_glue_combo_master_id FOREIGN KEY (combo_master_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5811 (class 2606 OID 178129)
-- Name: combo_parent_child_mapping fk_combo_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_parent_child_mapping
    ADD CONSTRAINT fk_combo_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5812 (class 2606 OID 178119)
-- Name: combo_parent_child_mapping fk_combo_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_parent_child_mapping
    ADD CONSTRAINT fk_combo_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5813 (class 2606 OID 178124)
-- Name: combo_parent_child_mapping fk_combo_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.combo_parent_child_mapping
    ADD CONSTRAINT fk_combo_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5804 (class 2606 OID 160745)
-- Name: concessionaire_config fk_concessionaire_config_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.concessionaire_config
    ADD CONSTRAINT fk_concessionaire_config_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5830 (class 2606 OID 3623824)
-- Name: dietary_tag_master fk_dietary_tag_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.dietary_tag_master
    ADD CONSTRAINT fk_dietary_tag_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5831 (class 2606 OID 3623829)
-- Name: dietary_tag_master fk_dietary_tag_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.dietary_tag_master
    ADD CONSTRAINT fk_dietary_tag_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5786 (class 2606 OID 63426)
-- Name: discount fk_discount_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.discount
    ADD CONSTRAINT fk_discount_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5787 (class 2606 OID 63431)
-- Name: discount fk_discount_menu_dataset_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.discount
    ADD CONSTRAINT fk_discount_menu_dataset_id FOREIGN KEY (menu_dataset_id) REFERENCES public.menu_dataset(id);


--
-- TOC entry 5788 (class 2606 OID 63436)
-- Name: discount fk_discount_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.discount
    ADD CONSTRAINT fk_discount_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5832 (class 2606 OID 3625183)
-- Name: item_dietary_tags_glue fk_item_dietary_tags_glue_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT fk_item_dietary_tags_glue_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5833 (class 2606 OID 3625193)
-- Name: item_dietary_tags_glue fk_item_dietary_tags_glue_dietary_tag_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT fk_item_dietary_tags_glue_dietary_tag_master_id FOREIGN KEY (dietary_tag_master_id) REFERENCES public.dietary_tag_master(id);


--
-- TOC entry 5834 (class 2606 OID 3625188)
-- Name: item_dietary_tags_glue fk_item_dietary_tags_glue_item_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT fk_item_dietary_tags_glue_item_master_id FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5713 (class 2606 OID 26390)
-- Name: item_master fk_item_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_master
    ADD CONSTRAINT fk_item_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5714 (class 2606 OID 26400)
-- Name: item_master fk_item_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_master
    ADD CONSTRAINT fk_item_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5715 (class 2606 OID 26395)
-- Name: item_master fk_item_master_taxgroup_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_master
    ADD CONSTRAINT fk_item_master_taxgroup_master_id FOREIGN KEY (taxgroup_master_id) REFERENCES public.tax_group_master(id);


--
-- TOC entry 5689 (class 2606 OID 26405)
-- Name: item_modifier_group_glue fk_item_modifier_group_glue_item_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_glue
    ADD CONSTRAINT fk_item_modifier_group_glue_item_master_id FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5690 (class 2606 OID 26410)
-- Name: item_modifier_group_glue fk_item_modifier_group_glue_modifier_group_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_glue
    ADD CONSTRAINT fk_item_modifier_group_glue_modifier_group_master_id FOREIGN KEY (modifier_group_master_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5808 (class 2606 OID 178023)
-- Name: item_parent_child_mapping fk_item_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_parent_child_mapping
    ADD CONSTRAINT fk_item_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5809 (class 2606 OID 178013)
-- Name: item_parent_child_mapping fk_item_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_parent_child_mapping
    ADD CONSTRAINT fk_item_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.item_master(id);


--
-- TOC entry 5810 (class 2606 OID 178018)
-- Name: item_parent_child_mapping fk_item_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_parent_child_mapping
    ADD CONSTRAINT fk_item_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.item_master(id);


--
-- TOC entry 5716 (class 2606 OID 26425)
-- Name: item_variation_master fk_item_variation_master_item_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_variation_master
    ADD CONSTRAINT fk_item_variation_master_item_master_id FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5720 (class 2606 OID 26913)
-- Name: menu_category fk_menu_category_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category
    ADD CONSTRAINT fk_menu_category_category_id FOREIGN KEY (category_id) REFERENCES public.category_master(id);


--
-- TOC entry 5718 (class 2606 OID 26430)
-- Name: menu_category_displayable_item_override fk_menu_category_displayable_item_override_menu_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category_displayable_item_override
    ADD CONSTRAINT fk_menu_category_displayable_item_override_menu_category_id FOREIGN KEY (menu_category_id) REFERENCES public.menu_category(id);


--
-- TOC entry 5721 (class 2606 OID 26435)
-- Name: menu_category fk_menu_category_menu_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category
    ADD CONSTRAINT fk_menu_category_menu_id FOREIGN KEY (menu_id) REFERENCES public.menu_master(id);


--
-- TOC entry 5823 (class 2606 OID 234284)
-- Name: menu_dataset_snapshot fk_menu_dataset_snapshot_snapshot_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_snapshot
    ADD CONSTRAINT fk_menu_dataset_snapshot_snapshot_id FOREIGN KEY (snapshot_id) REFERENCES public.menu_dataset(id);


--
-- TOC entry 5724 (class 2606 OID 26440)
-- Name: menu_item_modifier_group_modifier_override fk_menu_item_modifier_group_modifier_override_menu_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_modifier_override
    ADD CONSTRAINT fk_menu_item_modifier_group_modifier_override_menu_category_id FOREIGN KEY (menu_category_id) REFERENCES public.menu_category(id);


--
-- TOC entry 5726 (class 2606 OID 26445)
-- Name: menu_item_modifier_group_override fk_menu_item_modifier_group_override_menu_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_override
    ADD CONSTRAINT fk_menu_item_modifier_group_override_menu_category_id FOREIGN KEY (menu_category_id) REFERENCES public.menu_category(id);


--
-- TOC entry 5728 (class 2606 OID 26450)
-- Name: menu_master fk_menu_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_master
    ADD CONSTRAINT fk_menu_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5729 (class 2606 OID 26455)
-- Name: menu_master fk_menu_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_master
    ADD CONSTRAINT fk_menu_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5730 (class 2606 OID 26460)
-- Name: modifier_code_master fk_modifier_code_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_master
    ADD CONSTRAINT fk_modifier_code_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5731 (class 2606 OID 26465)
-- Name: modifier_code_master fk_modifier_code_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_master
    ADD CONSTRAINT fk_modifier_code_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5814 (class 2606 OID 184091)
-- Name: modifier_code_parent_child_mapping fk_modifier_code_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_parent_child_mapping
    ADD CONSTRAINT fk_modifier_code_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5815 (class 2606 OID 184081)
-- Name: modifier_code_parent_child_mapping fk_modifier_code_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_parent_child_mapping
    ADD CONSTRAINT fk_modifier_code_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.modifier_code_master(id);


--
-- TOC entry 5816 (class 2606 OID 184086)
-- Name: modifier_code_parent_child_mapping fk_modifier_code_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_code_parent_child_mapping
    ADD CONSTRAINT fk_modifier_code_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.modifier_code_master(id);


--
-- TOC entry 5838 (class 2606 OID 3625198)
-- Name: modifier_dietary_tags_glue fk_modifier_dietary_tags_glue_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT fk_modifier_dietary_tags_glue_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5839 (class 2606 OID 3625208)
-- Name: modifier_dietary_tags_glue fk_modifier_dietary_tags_glue_dietary_tag_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT fk_modifier_dietary_tags_glue_dietary_tag_master_id FOREIGN KEY (dietary_tag_master_id) REFERENCES public.dietary_tag_master(id);


--
-- TOC entry 5840 (class 2606 OID 3625203)
-- Name: modifier_dietary_tags_glue fk_modifier_dietary_tags_glue_modifier_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT fk_modifier_dietary_tags_glue_modifier_master_id FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5732 (class 2606 OID 26470)
-- Name: modifier_group_master fk_modifier_group_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_master
    ADD CONSTRAINT fk_modifier_group_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5747 (class 2606 OID 26480)
-- Name: modifier_group_modifier_glue fk_modifier_group_modifier_glue_modifier_group_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_glue
    ADD CONSTRAINT fk_modifier_group_modifier_glue_modifier_group_master_id FOREIGN KEY (modifier_group_master_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5748 (class 2606 OID 26475)
-- Name: modifier_group_modifier_glue fk_modifier_group_modifier_glue_modifier_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_glue
    ADD CONSTRAINT fk_modifier_group_modifier_glue_modifier_master_id FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5750 (class 2606 OID 28468)
-- Name: modifier_group_modifier_modifier_code_glue fk_modifier_group_modifier_modifier_code_glue_modifier_code_mas; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT fk_modifier_group_modifier_modifier_code_glue_modifier_code_mas FOREIGN KEY (modifier_code_master_id) REFERENCES public.modifier_code_master(id);


--
-- TOC entry 5817 (class 2606 OID 184106)
-- Name: modifier_group_parent_child_mapping fk_modifier_group_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_parent_child_mapping
    ADD CONSTRAINT fk_modifier_group_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5818 (class 2606 OID 184096)
-- Name: modifier_group_parent_child_mapping fk_modifier_group_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_parent_child_mapping
    ADD CONSTRAINT fk_modifier_group_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5819 (class 2606 OID 184101)
-- Name: modifier_group_parent_child_mapping fk_modifier_group_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_parent_child_mapping
    ADD CONSTRAINT fk_modifier_group_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5826 (class 2606 OID 2797745)
-- Name: modifier_group_subgroup fk_modifier_group_subgroup_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_subgroup
    ADD CONSTRAINT fk_modifier_group_subgroup_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5827 (class 2606 OID 2797740)
-- Name: modifier_group_subgroup fk_modifier_group_subgroup_modifier_group_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_subgroup
    ADD CONSTRAINT fk_modifier_group_subgroup_modifier_group_master_id FOREIGN KEY (modifier_group_master_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5733 (class 2606 OID 26490)
-- Name: modifier_master fk_modifier_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_master
    ADD CONSTRAINT fk_modifier_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5734 (class 2606 OID 26495)
-- Name: modifier_master fk_modifier_master_pos_linked_entity_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_master
    ADD CONSTRAINT fk_modifier_master_pos_linked_entity_id FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5820 (class 2606 OID 184121)
-- Name: modifier_parent_child_mapping fk_modifier_parent_child_mapping_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_parent_child_mapping
    ADD CONSTRAINT fk_modifier_parent_child_mapping_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5821 (class 2606 OID 184111)
-- Name: modifier_parent_child_mapping fk_modifier_parent_child_mapping_child_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_parent_child_mapping
    ADD CONSTRAINT fk_modifier_parent_child_mapping_child_id FOREIGN KEY (child_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5822 (class 2606 OID 184116)
-- Name: modifier_parent_child_mapping fk_modifier_parent_child_mapping_parent_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_parent_child_mapping
    ADD CONSTRAINT fk_modifier_parent_child_mapping_parent_id FOREIGN KEY (parent_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5735 (class 2606 OID 26500)
-- Name: pre_selected_combo_item fk_pre_selected_combo_item_combo_component_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_item
    ADD CONSTRAINT fk_pre_selected_combo_item_combo_component_id FOREIGN KEY (combo_component_id) REFERENCES public.combo_component(id);


--
-- TOC entry 5736 (class 2606 OID 26505)
-- Name: pre_selected_combo_item fk_pre_selected_combo_item_combo_component_item_glue_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_item
    ADD CONSTRAINT fk_pre_selected_combo_item_combo_component_item_glue_id FOREIGN KEY (combo_component_item_glue_id) REFERENCES public.combo_component_item_glue(id);


--
-- TOC entry 5764 (class 2606 OID 34394)
-- Name: pricebook fk_pricebook_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5765 (class 2606 OID 34404)
-- Name: pricebook fk_pricebook_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_category_id FOREIGN KEY (category_id) REFERENCES public.category_master(id);


--
-- TOC entry 5766 (class 2606 OID 34434)
-- Name: pricebook fk_pricebook_combo_component_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_combo_component_id FOREIGN KEY (combo_component_id) REFERENCES public.combo_component(id);


--
-- TOC entry 5767 (class 2606 OID 34429)
-- Name: pricebook fk_pricebook_combo_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_combo_master_id FOREIGN KEY (combo_master_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5739 (class 2606 OID 26510)
-- Name: pricebook_item fk_pricebook_item_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5740 (class 2606 OID 26520)
-- Name: pricebook_item fk_pricebook_item_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_category_id FOREIGN KEY (category_id) REFERENCES public.category_master(id);


--
-- TOC entry 5741 (class 2606 OID 26545)
-- Name: pricebook_item fk_pricebook_item_combo_master_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_combo_master_id FOREIGN KEY (combo_master_id) REFERENCES public.combo_master(id);


--
-- TOC entry 5768 (class 2606 OID 34409)
-- Name: pricebook fk_pricebook_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5742 (class 2606 OID 26525)
-- Name: pricebook_item fk_pricebook_item_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5743 (class 2606 OID 26530)
-- Name: pricebook_item fk_pricebook_item_item_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_item_variation_id FOREIGN KEY (item_variation_id) REFERENCES public.item_variation_master(id);


--
-- TOC entry 5744 (class 2606 OID 26515)
-- Name: pricebook_item fk_pricebook_item_menu_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_menu_id FOREIGN KEY (menu_id) REFERENCES public.menu_master(id);


--
-- TOC entry 5745 (class 2606 OID 26535)
-- Name: pricebook_item fk_pricebook_item_modifier_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_modifier_group_id FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5746 (class 2606 OID 26540)
-- Name: pricebook_item fk_pricebook_item_modifier_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook_item
    ADD CONSTRAINT fk_pricebook_item_modifier_id FOREIGN KEY (modifier_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5769 (class 2606 OID 34414)
-- Name: pricebook fk_pricebook_item_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_item_variation_id FOREIGN KEY (item_variation_id) REFERENCES public.item_variation_master(id);


--
-- TOC entry 5770 (class 2606 OID 34399)
-- Name: pricebook fk_pricebook_menu_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_menu_id FOREIGN KEY (menu_id) REFERENCES public.menu_master(id);


--
-- TOC entry 5771 (class 2606 OID 34419)
-- Name: pricebook fk_pricebook_modifier_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_modifier_group_id FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5772 (class 2606 OID 34424)
-- Name: pricebook fk_pricebook_modifier_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pricebook
    ADD CONSTRAINT fk_pricebook_modifier_id FOREIGN KEY (modifier_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5759 (class 2606 OID 26550)
-- Name: tax_group_master fk_tax_group_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.tax_group_master
    ADD CONSTRAINT fk_tax_group_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5760 (class 2606 OID 26555)
-- Name: tax_master fk_tax_master_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.tax_master
    ADD CONSTRAINT fk_tax_master_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5761 (class 2606 OID 26560)
-- Name: tax_master fk_tax_master_tax_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.tax_master
    ADD CONSTRAINT fk_tax_master_tax_group_id FOREIGN KEY (tax_group_id) REFERENCES public.tax_group_master(id);


--
-- TOC entry 5783 (class 2606 OID 63220)
-- Name: upsell fk_upsell_catalog_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell
    ADD CONSTRAINT fk_upsell_catalog_id FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5789 (class 2606 OID 66889)
-- Name: upsell_group_mapping fk_upsell_group_mapping_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT fk_upsell_group_mapping_category_id FOREIGN KEY (category_id) REFERENCES public.category_master(id);


--
-- TOC entry 5790 (class 2606 OID 66884)
-- Name: upsell_group_mapping fk_upsell_group_mapping_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT fk_upsell_group_mapping_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5791 (class 2606 OID 66879)
-- Name: upsell_group_mapping fk_upsell_group_mapping_upsell_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT fk_upsell_group_mapping_upsell_group_id FOREIGN KEY (upsell_group_id) REFERENCES public.upsell_group(id);


--
-- TOC entry 5774 (class 2606 OID 63245)
-- Name: upsell_group_offer fk_upsell_group_offer_category_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT fk_upsell_group_offer_category_id FOREIGN KEY (category_id) REFERENCES public.category_master(id);


--
-- TOC entry 5775 (class 2606 OID 63240)
-- Name: upsell_group_offer fk_upsell_group_offer_item_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT fk_upsell_group_offer_item_id FOREIGN KEY (item_id) REFERENCES public.item_master(id);


--
-- TOC entry 5776 (class 2606 OID 63235)
-- Name: upsell_group_offer fk_upsell_group_offer_upsell_group_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT fk_upsell_group_offer_upsell_group_id FOREIGN KEY (upsell_group_id) REFERENCES public.upsell_group(id);


--
-- TOC entry 5780 (class 2606 OID 63230)
-- Name: upsell_group fk_upsell_group_upsell_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group
    ADD CONSTRAINT fk_upsell_group_upsell_id FOREIGN KEY (upsell_id) REFERENCES public.upsell(id);


--
-- TOC entry 5784 (class 2606 OID 63225)
-- Name: upsell fk_upsell_menu_dataset_id; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell
    ADD CONSTRAINT fk_upsell_menu_dataset_id FOREIGN KEY (menu_dataset_id) REFERENCES public.menu_dataset(id);


--
-- TOC entry 5773 (class 2606 OID 59413)
-- Name: item_86 item_86_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_86
    ADD CONSTRAINT item_86_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5835 (class 2606 OID 3625213)
-- Name: item_dietary_tags_glue item_dietary_tags_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT item_dietary_tags_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5836 (class 2606 OID 3625223)
-- Name: item_dietary_tags_glue item_dietary_tags_glue_dietary_tag_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT item_dietary_tags_glue_dietary_tag_master_id_fkey FOREIGN KEY (dietary_tag_master_id) REFERENCES public.dietary_tag_master(id);


--
-- TOC entry 5837 (class 2606 OID 3625218)
-- Name: item_dietary_tags_glue item_dietary_tags_glue_item_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_dietary_tags_glue
    ADD CONSTRAINT item_dietary_tags_glue_item_master_id_fkey FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5691 (class 2606 OID 29949)
-- Name: item_modifier_group_glue item_modifier_group_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_glue
    ADD CONSTRAINT item_modifier_group_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5692 (class 2606 OID 28351)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_conf_modifier_group_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_conf_modifier_group_master_id_fkey FOREIGN KEY (modifier_group_master_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5693 (class 2606 OID 28356)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_config_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_config_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5694 (class 2606 OID 28341)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_config_item_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_config_item_master_id_fkey FOREIGN KEY (item_master_id) REFERENCES public.item_master(id);


--
-- TOC entry 5695 (class 2606 OID 28346)
-- Name: item_modifier_group_modifier_config item_modifier_group_modifier_config_modifier_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_modifier_group_modifier_config
    ADD CONSTRAINT item_modifier_group_modifier_config_modifier_master_id_fkey FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5717 (class 2606 OID 29954)
-- Name: item_variation_master item_variation_master_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.item_variation_master
    ADD CONSTRAINT item_variation_master_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5722 (class 2606 OID 29959)
-- Name: menu_category menu_category_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category
    ADD CONSTRAINT menu_category_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5719 (class 2606 OID 29969)
-- Name: menu_category_displayable_item_override menu_category_displayable_item_override_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category_displayable_item_override
    ADD CONSTRAINT menu_category_displayable_item_override_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5723 (class 2606 OID 28071)
-- Name: menu_category menu_category_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_category
    ADD CONSTRAINT menu_category_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5825 (class 2606 OID 2274696)
-- Name: menu_dataset_overrides menu_dataset_overrides_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_overrides
    ADD CONSTRAINT menu_dataset_overrides_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5824 (class 2606 OID 1528098)
-- Name: menu_dataset_snapshot menu_dataset_snapshot_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_dataset_snapshot
    ADD CONSTRAINT menu_dataset_snapshot_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5725 (class 2606 OID 29974)
-- Name: menu_item_modifier_group_modifier_override menu_item_modifier_group_modifier_override_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_modifier_override
    ADD CONSTRAINT menu_item_modifier_group_modifier_override_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5727 (class 2606 OID 29979)
-- Name: menu_item_modifier_group_override menu_item_modifier_group_override_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.menu_item_modifier_group_override
    ADD CONSTRAINT menu_item_modifier_group_override_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5841 (class 2606 OID 3625232)
-- Name: modifier_dietary_tags_glue modifier_dietary_tags_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT modifier_dietary_tags_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5842 (class 2606 OID 3625242)
-- Name: modifier_dietary_tags_glue modifier_dietary_tags_glue_dietary_tag_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT modifier_dietary_tags_glue_dietary_tag_master_id_fkey FOREIGN KEY (dietary_tag_master_id) REFERENCES public.dietary_tag_master(id);


--
-- TOC entry 5843 (class 2606 OID 3625237)
-- Name: modifier_dietary_tags_glue modifier_dietary_tags_glue_modifier_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_dietary_tags_glue
    ADD CONSTRAINT modifier_dietary_tags_glue_modifier_master_id_fkey FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5749 (class 2606 OID 29999)
-- Name: modifier_group_modifier_glue modifier_group_modifier_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_glue
    ADD CONSTRAINT modifier_group_modifier_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5751 (class 2606 OID 68787)
-- Name: modifier_group_modifier_modifier_code_glue modifier_group_modifier_modifier_code_gl_modifier_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT modifier_group_modifier_modifier_code_gl_modifier_group_id_fkey FOREIGN KEY (modifier_group_id) REFERENCES public.modifier_group_master(id);


--
-- TOC entry 5752 (class 2606 OID 29984)
-- Name: modifier_group_modifier_modifier_code_glue modifier_group_modifier_modifier_code_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT modifier_group_modifier_modifier_code_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5753 (class 2606 OID 68792)
-- Name: modifier_group_modifier_modifier_code_glue modifier_group_modifier_modifier_code_glue_modifier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_group_modifier_modifier_code_glue
    ADD CONSTRAINT modifier_group_modifier_modifier_code_glue_modifier_id_fkey FOREIGN KEY (modifier_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5754 (class 2606 OID 29989)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5755 (class 2606 OID 26261)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_item_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_item_master_id_fkey FOREIGN KEY (item_master_id) REFERENCES public.item_master(id) ON DELETE CASCADE;


--
-- TOC entry 5756 (class 2606 OID 26256)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_modifier_code_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_modifier_code_master_id_fkey FOREIGN KEY (modifier_code_master_id) REFERENCES public.modifier_code_master(id) ON DELETE CASCADE;


--
-- TOC entry 5757 (class 2606 OID 26251)
-- Name: modifier_modifier_code_glue modifier_modifier_code_glue_modifier_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_modifier_code_glue
    ADD CONSTRAINT modifier_modifier_code_glue_modifier_master_id_fkey FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id) ON DELETE CASCADE;


--
-- TOC entry 5758 (class 2606 OID 26584)
-- Name: modifier_nested_modifier_group_glue modifier_nested_modifier_group_glue_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.modifier_nested_modifier_group_glue
    ADD CONSTRAINT modifier_nested_modifier_group_glue_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5737 (class 2606 OID 29994)
-- Name: pre_selected_combo_item pre_selected_combo_item_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_item
    ADD CONSTRAINT pre_selected_combo_item_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5738 (class 2606 OID 29964)
-- Name: pre_selected_combo_master pre_selected_combo_master_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.pre_selected_combo_master
    ADD CONSTRAINT pre_selected_combo_master_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5781 (class 2606 OID 286435)
-- Name: upsell_group upsell_group_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group
    ADD CONSTRAINT upsell_group_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5792 (class 2606 OID 286440)
-- Name: upsell_group_mapping upsell_group_mapping_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT upsell_group_mapping_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5793 (class 2606 OID 123012)
-- Name: upsell_group_mapping upsell_group_mapping_modifier_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT upsell_group_mapping_modifier_master_id_fkey FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5794 (class 2606 OID 122801)
-- Name: upsell_group_mapping upsell_group_mapping_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_mapping
    ADD CONSTRAINT upsell_group_mapping_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5777 (class 2606 OID 286445)
-- Name: upsell_group_offer upsell_group_offer_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT upsell_group_offer_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalog(id);


--
-- TOC entry 5778 (class 2606 OID 123017)
-- Name: upsell_group_offer upsell_group_offer_modifier_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT upsell_group_offer_modifier_master_id_fkey FOREIGN KEY (modifier_master_id) REFERENCES public.modifier_master(id);


--
-- TOC entry 5779 (class 2606 OID 118883)
-- Name: upsell_group_offer upsell_group_offer_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group_offer
    ADD CONSTRAINT upsell_group_offer_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5782 (class 2606 OID 118873)
-- Name: upsell_group upsell_group_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell_group
    ADD CONSTRAINT upsell_group_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 5785 (class 2606 OID 119013)
-- Name: upsell upsell_pos_linked_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.upsell
    ADD CONSTRAINT upsell_pos_linked_entity_id_fkey FOREIGN KEY (pos_linked_entity_id) REFERENCES public.pos_linked_entity(id);


--
-- TOC entry 6016 (class 0 OID 0)
-- Dependencies: 44
-- Name: SCHEMA partman; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA partman TO citus WITH GRANT OPTION;


--
-- TOC entry 6018 (class 0 OID 0)
-- Dependencies: 51
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO citus WITH GRANT OPTION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO dhruvitshah;
RESET SESSION AUTHORIZATION;


--
-- TOC entry 6019 (class 0 OID 0)
-- Dependencies: 985
-- Name: FUNCTION create_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6020 (class 0 OID 0)
-- Dependencies: 821
-- Name: FUNCTION drop_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.drop_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6021 (class 0 OID 0)
-- Dependencies: 1194
-- Name: FUNCTION pg_replication_origin_create(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_create(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_create(text) TO citus;


--
-- TOC entry 6022 (class 0 OID 0)
-- Dependencies: 1149
-- Name: FUNCTION pg_replication_origin_drop(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_drop(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_drop(text) TO citus;


--
-- TOC entry 6023 (class 0 OID 0)
-- Dependencies: 611
-- Name: FUNCTION pg_replication_origin_progress(text, boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) TO citus;


--
-- TOC entry 6024 (class 0 OID 0)
-- Dependencies: 1374
-- Name: FUNCTION pg_replication_origin_session_progress(boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) TO citus;


--
-- TOC entry 6025 (class 0 OID 0)
-- Dependencies: 477
-- Name: FUNCTION pg_replication_origin_session_setup(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_setup(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_setup(text) TO citus;


--
-- TOC entry 6026 (class 0 OID 0)
-- Dependencies: 1180
-- Name: FUNCTION pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) TO citus;


--
-- TOC entry 6028 (class 0 OID 0)
-- Dependencies: 334
-- Name: TABLE catalog; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.catalog TO dhruvitshah;


--
-- TOC entry 6029 (class 0 OID 0)
-- Dependencies: 366
-- Name: TABLE catalog_entity_pos_connector_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.catalog_entity_pos_connector_glue TO dhruvitshah;


--
-- TOC entry 6030 (class 0 OID 0)
-- Dependencies: 367
-- Name: TABLE catalog_pos_connector_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.catalog_pos_connector_glue TO dhruvitshah;


--
-- TOC entry 6031 (class 0 OID 0)
-- Dependencies: 331
-- Name: TABLE catalog_sync_history; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.catalog_sync_history TO dhruvitshah;


--
-- TOC entry 6032 (class 0 OID 0)
-- Dependencies: 335
-- Name: TABLE category_displayable_item; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.category_displayable_item TO dhruvitshah;


--
-- TOC entry 6033 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE category_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.category_master TO dhruvitshah;


--
-- TOC entry 6034 (class 0 OID 0)
-- Dependencies: 381
-- Name: TABLE category_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.category_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6035 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE combo_component; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_component TO dhruvitshah;


--
-- TOC entry 6036 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE combo_component_item_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_component_item_glue TO dhruvitshah;


--
-- TOC entry 6037 (class 0 OID 0)
-- Dependencies: 369
-- Name: TABLE combo_component_item_glue_group; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_component_item_glue_group TO dhruvitshah;


--
-- TOC entry 6038 (class 0 OID 0)
-- Dependencies: 342
-- Name: TABLE combo_family; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_family TO dhruvitshah;


--
-- TOC entry 6039 (class 0 OID 0)
-- Dependencies: 341
-- Name: TABLE combo_family_member; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_family_member TO dhruvitshah;


--
-- TOC entry 6040 (class 0 OID 0)
-- Dependencies: 377
-- Name: TABLE combo_item_modifier_group_override; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_item_modifier_group_override TO dhruvitshah;


--
-- TOC entry 6041 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE combo_item_modifier_override; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_item_modifier_override TO dhruvitshah;


--
-- TOC entry 6042 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE combo_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_master TO dhruvitshah;


--
-- TOC entry 6043 (class 0 OID 0)
-- Dependencies: 343
-- Name: TABLE combo_master_component_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_master_component_glue TO dhruvitshah;


--
-- TOC entry 6044 (class 0 OID 0)
-- Dependencies: 383
-- Name: TABLE combo_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.combo_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6045 (class 0 OID 0)
-- Dependencies: 380
-- Name: TABLE concessionaire_config; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.concessionaire_config TO dhruvitshah;


--
-- TOC entry 6046 (class 0 OID 0)
-- Dependencies: 375
-- Name: TABLE discount; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.discount TO dhruvitshah;


--
-- TOC entry 6047 (class 0 OID 0)
-- Dependencies: 371
-- Name: TABLE item_86; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_86 TO dhruvitshah;


--
-- TOC entry 6048 (class 0 OID 0)
-- Dependencies: 345
-- Name: TABLE item_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_master TO dhruvitshah;


--
-- TOC entry 6049 (class 0 OID 0)
-- Dependencies: 336
-- Name: TABLE item_modifier_group_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_modifier_group_glue TO dhruvitshah;


--
-- TOC entry 6050 (class 0 OID 0)
-- Dependencies: 337
-- Name: TABLE item_modifier_group_modifier_config; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_modifier_group_modifier_config TO dhruvitshah;


--
-- TOC entry 6051 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE item_modifier_group_overrides; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_modifier_group_overrides TO dhruvitshah;


--
-- TOC entry 6052 (class 0 OID 0)
-- Dependencies: 382
-- Name: TABLE item_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6053 (class 0 OID 0)
-- Dependencies: 346
-- Name: TABLE item_variation_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.item_variation_master TO dhruvitshah;


--
-- TOC entry 6054 (class 0 OID 0)
-- Dependencies: 348
-- Name: TABLE menu_category; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_category TO dhruvitshah;


--
-- TOC entry 6055 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE menu_category_displayable_item_override; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_category_displayable_item_override TO dhruvitshah;


--
-- TOC entry 6056 (class 0 OID 0)
-- Dependencies: 365
-- Name: TABLE menu_dataset; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_dataset TO dhruvitshah;


--
-- TOC entry 6064 (class 0 OID 0)
-- Dependencies: 349
-- Name: TABLE menu_item_modifier_group_modifier_override; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_item_modifier_group_modifier_override TO dhruvitshah;


--
-- TOC entry 6065 (class 0 OID 0)
-- Dependencies: 350
-- Name: TABLE menu_item_modifier_group_override; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_item_modifier_group_override TO dhruvitshah;


--
-- TOC entry 6066 (class 0 OID 0)
-- Dependencies: 351
-- Name: TABLE menu_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.menu_master TO dhruvitshah;


--
-- TOC entry 6067 (class 0 OID 0)
-- Dependencies: 352
-- Name: TABLE modifier_code_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_code_master TO dhruvitshah;


--
-- TOC entry 6068 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE modifier_code_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_code_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6069 (class 0 OID 0)
-- Dependencies: 353
-- Name: TABLE modifier_group_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_group_master TO dhruvitshah;


--
-- TOC entry 6070 (class 0 OID 0)
-- Dependencies: 358
-- Name: TABLE modifier_group_modifier_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_group_modifier_glue TO dhruvitshah;


--
-- TOC entry 6071 (class 0 OID 0)
-- Dependencies: 359
-- Name: TABLE modifier_group_modifier_modifier_code_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_group_modifier_modifier_code_glue TO dhruvitshah;


--
-- TOC entry 6072 (class 0 OID 0)
-- Dependencies: 385
-- Name: TABLE modifier_group_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_group_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6073 (class 0 OID 0)
-- Dependencies: 354
-- Name: TABLE modifier_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_master TO dhruvitshah;


--
-- TOC entry 6074 (class 0 OID 0)
-- Dependencies: 360
-- Name: TABLE modifier_modifier_code_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_modifier_code_glue TO dhruvitshah;


--
-- TOC entry 6075 (class 0 OID 0)
-- Dependencies: 361
-- Name: TABLE modifier_nested_modifier_group_glue; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_nested_modifier_group_glue TO dhruvitshah;


--
-- TOC entry 6076 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE modifier_parent_child_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifier_parent_child_mapping TO dhruvitshah;


--
-- TOC entry 6077 (class 0 OID 0)
-- Dependencies: 368
-- Name: TABLE modifierglueid; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.modifierglueid TO dhruvitshah;


--
-- TOC entry 6078 (class 0 OID 0)
-- Dependencies: 362
-- Name: TABLE pos_linked_entity; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.pos_linked_entity TO dhruvitshah;


--
-- TOC entry 6079 (class 0 OID 0)
-- Dependencies: 355
-- Name: TABLE pre_selected_combo_item; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.pre_selected_combo_item TO dhruvitshah;


--
-- TOC entry 6080 (class 0 OID 0)
-- Dependencies: 356
-- Name: TABLE pre_selected_combo_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.pre_selected_combo_master TO dhruvitshah;


--
-- TOC entry 6081 (class 0 OID 0)
-- Dependencies: 370
-- Name: TABLE pricebook; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.pricebook TO dhruvitshah;


--
-- TOC entry 6082 (class 0 OID 0)
-- Dependencies: 357
-- Name: TABLE pricebook_item; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.pricebook_item TO dhruvitshah;


--
-- TOC entry 6083 (class 0 OID 0)
-- Dependencies: 333
-- Name: TABLE schemaversions; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.schemaversions TO dhruvitshah;


--
-- TOC entry 6085 (class 0 OID 0)
-- Dependencies: 363
-- Name: TABLE tax_group_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.tax_group_master TO dhruvitshah;


--
-- TOC entry 6086 (class 0 OID 0)
-- Dependencies: 364
-- Name: TABLE tax_master; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.tax_master TO dhruvitshah;


--
-- TOC entry 6087 (class 0 OID 0)
-- Dependencies: 374
-- Name: TABLE upsell; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.upsell TO dhruvitshah;


--
-- TOC entry 6088 (class 0 OID 0)
-- Dependencies: 373
-- Name: TABLE upsell_group; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.upsell_group TO dhruvitshah;


--
-- TOC entry 6089 (class 0 OID 0)
-- Dependencies: 376
-- Name: TABLE upsell_group_mapping; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.upsell_group_mapping TO dhruvitshah;


--
-- TOC entry 6090 (class 0 OID 0)
-- Dependencies: 372
-- Name: TABLE upsell_group_offer; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.upsell_group_offer TO dhruvitshah;


-- Completed on 2026-05-13 15:54:11

--
-- PostgreSQL database dump complete
--

\unrestrict qEtCU8c5oLyFw4Sin4Qi4H8NRJBR7Px27gWeKbXLrqgwpSUaKKwo5Atoe1i7Xw9

