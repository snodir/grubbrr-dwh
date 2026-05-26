SELECT * FROM fact.userbehaviour as ub ORDER BY id DESC LIMIT 1000;

ALTER TABLE fact.userbehaviour
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

--CALL fact.usp_silver_userbehaviour_to_fact();

-- Table: fact.userbehaviour

-- DROP TABLE IF EXISTS fact.userbehaviour;

CREATE TABLE IF NOT EXISTS fact.userbehaviour
(
    id bigint NOT NULL,
    busdate timestamp without time zone,
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    daypart text COLLATE pg_catalog."default",
    ordertype bigint,
    eventtype text COLLATE pg_catalog."default",
    ordersessionidentifier text COLLATE pg_catalog."default",
    viewidentifier integer,
    itemsessionidentifier text COLLATE pg_catalog."default",
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone,
    syscosmosts bigint,
    eventinstant text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    CONSTRAINT userbehaviour_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.userbehaviour
    OWNER to citus;


-- Index: userbehaviour_locationid_dateid_idx

-- DROP INDEX IF EXISTS fact.userbehaviour_locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx
    ON fact.userbehaviour USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier)
    TABLESPACE pg_default;

CREATE SEQUENCE IF NOT EXISTS fact.userbehaviour_id_seq;

SELECT setval(
    'fact.userbehaviour_id_seq',
    COALESCE((SELECT MAX(id) FROM fact.userbehaviour), 0)
);

ALTER TABLE fact.userbehaviour
    ALTER COLUMN id SET DEFAULT nextval('fact.userbehaviour_id_seq');



CREATE OR REPLACE PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour()
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    -- -10 buffer mirrors transactionheader pattern to catch late-arriving events
    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts
    FROM fact.userbehaviour;


    WITH new_events AS (

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.locationid,
            ske.token                               AS ordersessionidentifier,
            ske.eventcategory,
            ske.eventinstant,
            ske.eventtype,
            ske.data,
            ske.device,
            ske.syscosmosts
        FROM stg.silver_kiosk_events                AS ske
        WHERE ske.eventmodule      = 'kiosk'
          AND ske.eventcategory    = 'insight'
          AND ske.syscosmosts      > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.userbehaviour             AS ub
                WHERE ub.locationid             = ske.locationid
                  AND ub.ordersessionidentifier = ske.token
                  AND ub.eventcategory          = ske.eventcategory
                  AND ub.eventtype              = ske.eventtype
                  AND ub.eventinstant           = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organization               AS o
                WHERE o.id = ske.locationid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    ), parsed_events AS (

        SELECT
            ne.locationid,
            ne.ordersessionidentifier,
            ne.eventcategory,
            ne.eventinstant,
            ne.eventtype,
            ne.syscosmosts,
            ne.device,
            fact.parse_iso_timestamp(ne.eventinstant)                             AS busdate,
            REPLACE(REPLACE(SUBSTRING(ne.eventinstant, 1, 13), '-', ''), 'T', '')
                :: INTEGER                                                         AS dateid,
            NULLIF(TRIM(ne.data::jsonb->>'view'),         '')                     AS view_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'element'),   ''), 'None')      AS element_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'elementId'), ''), 'None')      AS source_element_id,
            NULLIF(TRIM(ne.data::jsonb->>'quantity'), '')::INTEGER                AS quantity,
            NULLIF(TRIM(ne.data::jsonb->>'itemSessionId'), '')                    AS itemsessionidentifier
        FROM new_events ne
        WHERE ne.data IS NOT NULL
          AND ne.data <> ''

    ), enriched AS (

        SELECT
            pe.locationid,
            pe.ordersessionidentifier,
            pe.eventcategory,
            pe.eventinstant,
            pe.eventtype,
            pe.syscosmosts,
            pe.busdate,
            pe.dateid,
            pe.itemsessionidentifier,
            pe.quantity,
            ot.id                                   AS ordertype,
            dv.viewid                               AS viewidentifier,
            de.elementid                            AS elementidentifier,
            'None'  :: TEXT                         AS daypart,
            NOW()   :: TIMESTAMP                    AS createddate
        FROM parsed_events                          AS pe
        LEFT JOIN dim.ordertype                     AS ot
            ON  ot.locationid = pe.locationid
            AND ot.kioskid    = pe.device
        LEFT JOIN dim.view                          AS dv
            ON  dv.viewname   = pe.view_name
        LEFT JOIN dim.element                       AS de
            ON  de.elementname     = pe.element_name
            AND de.sourceelementid = pe.source_element_id

    )
    INSERT INTO fact.userbehaviour (
        id,
        busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    )
    SELECT
        nextval('fact.userbehaviour_id_seq'),
        busdate :: TIMESTAMP AS busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    FROM enriched;

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour()
    OWNER TO citus;