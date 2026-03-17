--SELECT * FROM public.i_group;

-- Create a centralized tracking table
CREATE TABLE IF NOT EXISTS public.data_change_audit (
    id BIGSERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    operation_type TEXT NOT NULL, -- 'INSERT' or 'UPDATE'
    primary_key_values JSONB NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    migration_batch_id TEXT,
    is_out_of_band BOOLEAN DEFAULT FALSE
);

-- Distribute the audit table in Citus (if needed across nodes)
--SELECT create_distributed_table('data_change_audit', 'public');


-- Add soft delete columns to your audit table
ALTER TABLE public.data_change_audit 
ADD COLUMN IF NOT EXISTS marked_for_deletion BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS deleted_by TEXT,
ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

-- Add soft delete columns to each business table
-- You can do this programmatically for all tables:
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'citus', 'pg_toast')
          AND tablename != 'data_change_audit'
    LOOP
        -- Add columns if they don't exist
        EXECUTE format(
            'ALTER TABLE %I.%I 
             ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
             ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
             ADD COLUMN IF NOT EXISTS deleted_by TEXT,
             ADD COLUMN IF NOT EXISTS deletion_reason TEXT',
            r.schemaname, r.tablename
        );
        
        -- Create index for better query performance
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%I_is_deleted ON %I.%I (is_deleted) 
             WHERE is_deleted = FALSE',
            r.tablename, r.schemaname, r.tablename
        );
    END LOOP;
END $$;


CREATE OR REPLACE FUNCTION auto_mark_out_of_band_for_deletion()
RETURNS TRIGGER AS $$
DECLARE
    pk_columns TEXT[];
    pk_values JSONB := '{}'::jsonb;
    col TEXT;
    current_batch_id TEXT;
    v_should_mark BOOLEAN;
BEGIN
    current_batch_id := current_setting('app.migration_batch_id', TRUE);

    IF current_batch_id IS NULL OR current_batch_id = '' THEN
        SELECT array_agg(a.attname)
        INTO pk_columns
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = TG_RELID AND i.indisprimary;

        FOREACH col IN ARRAY pk_columns LOOP
            pk_values := pk_values || jsonb_build_object(
                col,
                to_jsonb(NEW) -> col
            );
        END LOOP;

        v_should_mark := COALESCE(
            current_setting('app.auto_mark_out_of_band', TRUE)::BOOLEAN,
            FALSE
        );

        INSERT INTO public.data_change_audit (
            schema_name,
            table_name,
            operation_type,
            primary_key_values,
            migration_batch_id,
            is_out_of_band,
            marked_for_deletion
        ) VALUES (
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME,
            TG_OP,
            pk_values,
            NULL,
            TRUE,
            v_should_mark
        );

        IF v_should_mark THEN
            NEW.is_deleted := TRUE;
            NEW.deleted_at := CURRENT_TIMESTAMP;
            NEW.deleted_by := COALESCE(
                current_setting('app.user_id', TRUE),
                'system_auto_mark'
            );
            NEW.deletion_reason := 'Out-of-band change during migration';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;






DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'citus')
          AND tablename != 'data_change_audit'
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS track_and_mark_changes_trigger ON %I.%I',
            r.schemaname, r.tablename
        );

        EXECUTE format(
            'CREATE TRIGGER track_and_mark_changes_trigger
             BEFORE INSERT OR UPDATE ON %I.%I
             FOR EACH ROW
             EXECUTE FUNCTION auto_mark_out_of_band_for_deletion()',
            r.schemaname, r.tablename
        );
    END LOOP;
END $$;


INSERT INTO i_group(status, created_by)
VALUES('ACTIVE', 2);

UPDATE public.i_group
SET created_date = now()
WHERE id = 10;

SELECT * FROM public.i_group;
SELECT * FROM public.data_change_audit;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


SELECT * FROM public.i_group

INSERT INTO i_group(status, created_by)
VALUES('INACTIVE', 3);

SELECT TRIM('   Nate   Is   Here   '); 
--Nate   Is   Here

SELECT status,
       concat('mstritm-', uuid_generate_v5(uuid_ns_dns(), status)) AS dedup_uuid
FROM public.i_group;

