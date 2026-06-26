-- ============================================================================
-- Extensions
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

SELECT *--name, default_version, installed_version
FROM   pg_available_extensions
WHERE  name IN ('pg_trgm', 'fuzzystrmatch')
ORDER  BY name;


-- ============================================================================
-- Support functions
-- ============================================================================
CREATE OR REPLACE FUNCTION dim.ml_normalize(raw_string TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $BODY$
SELECT regexp_replace(
    regexp_replace(
        replace(
            regexp_replace(
                regexp_replace(
                    regexp_replace(
                        regexp_replace(lower(trim(raw_string)), '[^[:alnum:]_[:space:]]', ' ', 'g'),
                        '\m(\d+)pc\M', '\1 piece', 'g'     -- 3pc → 3 piece
                    ),
                    '\moz\M', 'ounce', 'g'                 -- oz → ounce (word boundary)
                ),
                '\mslaw\M', 'coleslaw', 'g'                -- slaw → coleslaw (word boundary,
                                                           -- fixes Python str.replace bug)
            ),
            'n''', ' and '                                 -- Shake N' Waffle → Shake N and Waffle
        ),
        '\s+', ' ', 'g'                                    -- collapse whitespace
    ),
    '^\s+|\s+$', '', 'g'                                   -- final trim
)
$BODY$;


CREATE OR REPLACE FUNCTION dim.token_sort(normalized_text TEXT)
RETURNS TEXT
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $BODY$
SELECT string_agg(tok, ' ' ORDER BY tok)
FROM   unnest(string_to_array(trim(normalized_text), ' ')) AS tok
WHERE  tok <> ''
$BODY$;


CREATE OR REPLACE FUNCTION dim.token_sort_ratio(a TEXT, b TEXT)
RETURNS NUMERIC
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE AS $BODY$
SELECT CASE
    WHEN a = b THEN 100
    ELSE ROUND(
        (1.0 -
            levenshtein_less_equal(
                dim.token_sort(dim.ml_normalize(a)),
                dim.token_sort(dim.ml_normalize(b)),
                CEIL(0.30 * (
                    length(dim.token_sort(dim.ml_normalize(a))) +
                    length(dim.token_sort(dim.ml_normalize(b)))
                ))::INT
            )::NUMERIC
            / NULLIF(
                length(dim.token_sort(dim.ml_normalize(a))) +
                length(dim.token_sort(dim.ml_normalize(b))),
                0
            )
        ) * 100,
    2)
END
$BODY$;


-- ============================================================================
-- GIN indexes on ml source tables
-- Generated columns survive DELETE/INSERT cycles in the refresh SPs
-- ============================================================================
ALTER TABLE ml.item_modifiergroup_modifier_mapping
    ADD COLUMN IF NOT EXISTS norm_ts_name TEXT
        GENERATED ALWAYS AS (dim.token_sort(dim.ml_normalize(modifiername))) STORED;

CREATE INDEX IF NOT EXISTS ix_ml_imm_norm_ts_name
    ON ml.item_modifiergroup_modifier_mapping USING GIN (norm_ts_name gin_trgm_ops);

ALTER TABLE ml.menu_entities
    ADD COLUMN IF NOT EXISTS norm_ts_name TEXT
        GENERATED ALWAYS AS (dim.token_sort(dim.ml_normalize(menuitemname))) STORED;

CREATE INDEX IF NOT EXISTS ix_ml_me_norm_ts_name
    ON ml.menu_entities USING GIN (norm_ts_name gin_trgm_ops);


-- ============================================================================
-- TABLE: ml.modifier_item_match
-- ============================================================================
CREATE TABLE IF NOT EXISTS ml.modifier_item_match (

    -- scope
    organizationid          TEXT            NOT NULL,
    organizationname        TEXT,
    locationid              TEXT,
    locationname            TEXT,
    catalogid               TEXT,
    catalogname             TEXT,

    -- modifier identity
    modifierid              TEXT            NOT NULL,
    modifiername            TEXT            NOT NULL,

    -- best match (flat columns — highest tsr_score candidate)
    matched_menuitemid      TEXT            NOT NULL,
    matched_menuitemname    TEXT            NOT NULL,

    -- match quality
    tsr_score               NUMERIC(5,2)    NOT NULL,
    match_confidence_tier   TEXT            NOT NULL
        GENERATED ALWAYS AS (
            CASE
                WHEN tsr_score >= 90 THEN 'high'
                WHEN tsr_score >= 75 THEN 'medium'
                ELSE 'review'
            END
        ) STORED,
    match_direction         TEXT,           -- 'near_equal' | 'modifier_adds_size'
                                            -- 'modifier_adds_flavor' | 'item_extends_modifier'

    -- full array of all matches above threshold, sorted best-first
    -- mirrors modifier_name_to_items[mod] from Python pipeline
    -- e.g. [{"menuitemid": "...", "menuitemname": "Cheese Sauce (2 oz)",
    --         "tsr_score": 85.5, "match_direction": "near_equal", "item_price": 0.50}]
    matched_menuitems           JSONB           NOT NULL DEFAULT '[]',

    -- key ML signal: independent group confirmations of this pairing
    -- equivalent to len(modifier_name_to_items[mod]) in Python pipeline
    group_occurrence_count  INT             NOT NULL DEFAULT 1,

    -- pricing features
    modifier_price          NUMERIC(12,4),
    item_price              NUMERIC(12,3),
    price_delta             NUMERIC(14,4)
        GENERATED ALWAYS AS (item_price - modifier_price) STORED,

    -- item-level features
    item_entity_type        TEXT,
    item_calories           TEXT,
    item_categoryid         TEXT,
    item_categoryname       TEXT,
    item_is_alcoholic       BOOLEAN,
    item_is_vegetarian      BOOLEAN,
    item_is_vegan           BOOLEAN,
    item_has_allergen       BOOLEAN,
    item_average_rating     NUMERIC(3,2),
    item_rating_count       INT,

    -- modifier-level features
    modifier_is_default     BOOLEAN,
    modifier_calories       TEXT,
    modifier_max_quantity   INT,
    modifier_min_quantity   INT,
    is_size_variant         BOOLEAN         NOT NULL DEFAULT FALSE,

    -- audit
    matched_at              TIMESTAMPTZ     DEFAULT NOW(),
    pipeline_version        TEXT            DEFAULT 'v1',

    -- one row per modifier — matched_items array carries all candidates
    PRIMARY KEY (organizationid, modifierid)
);

CREATE INDEX IF NOT EXISTS ix_ml_mim_locationid
    ON ml.modifier_item_match (locationid);

CREATE INDEX IF NOT EXISTS ix_ml_mim_catalogid
    ON ml.modifier_item_match (catalogid);

CREATE INDEX IF NOT EXISTS ix_ml_mim_tsr_score
    ON ml.modifier_item_match (organizationid, tsr_score DESC);


-- ============================================================================
-- PROCEDURE: ml.usp_run_item_modifier_matching
-- ============================================================================
CREATE OR REPLACE PROCEDURE ml.usp_run_item_modifier_matching(
    p_organizationid  TEXT,
    p_tsr_threshold   NUMERIC  DEFAULT 70,
    p_trgm_prefilter  NUMERIC  DEFAULT 0.40
)
LANGUAGE plpgsql AS $BODY$
DECLARE
    v_mod_count   INT;
    v_item_count  INT;
    v_match_count INT;
BEGIN

    -- ----------------------------------------------------------------
    -- Purge existing matches for this org before rebuild
    -- ----------------------------------------------------------------
    DELETE FROM ml.modifier_item_match
    WHERE CASE
        WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid
        ELSE locationid
    END = p_organizationid;

    -- ----------------------------------------------------------------
    -- Step 1+2: modifier_id_to_name + _filter_modifiers()
    -- Collapse to one row per modifierid — locationid/catalogid use MIN()
    -- since the same modifier can appear at multiple locations within an org
    -- group_occurrence_count = COUNT(DISTINCT modifiergroupid) across all
    -- locations — this is the list-length signal from the Python pipeline
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_filtered_modifiers ON COMMIT DROP AS
    SELECT
        organizationid,
        organizationname,
        MIN(locationid)                             AS locationid,
        MIN(locationname)                           AS locationname,
        MIN(catalogid)                              AS catalogid,
        MIN(catalogname)                            AS catalogname,
        modifierid,
        modifiername,
        norm_ts_name,
        MIN(price)                                  AS modifier_price,
        BOOL_OR(is_modifier_default)                AS modifier_is_default,
        MIN(calories)                               AS modifier_calories,
        MAX(max_quantity)                           AS modifier_max_quantity,
        MIN(min_quantity)                           AS modifier_min_quantity,
        COUNT(DISTINCT modifiergroupid)             AS group_occurrence_count
    FROM ml.item_modifiergroup_modifier_mapping
    WHERE CASE
            WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid
            ELSE locationid
          END = p_organizationid
      AND is_modifier_deleted = FALSE
      AND is_modifier_active  = TRUE
      AND lower(modifiergroupname) NOT LIKE '%level%'
      AND lower(modifiergroupname) NOT LIKE '%change%'
      AND lower(modifiergroupname) NOT LIKE '%sauce choice%'
      AND lower(modifiername)      NOT LIKE 'no %'
    GROUP BY
        organizationid, organizationname,
        modifierid, modifiername, norm_ts_name;

    GET DIAGNOSTICS v_mod_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % modifiers after group/keyword filtering',
                 p_organizationid, v_mod_count;

    -- ----------------------------------------------------------------
    -- Step 3: master_items
    -- Deduplicate by menuitemid — same item can appear at multiple locations
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_master_items ON COMMIT DROP AS
    SELECT DISTINCT ON (menuitemid)
        menuitemid,
        menuitemname,
        norm_ts_name,
        itemunitprice,
        entitytype,
        calories,
        categoryid,
        categoryname,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        average_rating,
        rating_count
    FROM ml.menu_entities
    WHERE CASE
            WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid
            ELSE locationid
          END = p_organizationid
      AND is_deleted    = FALSE
      AND menuitemname  IS NOT NULL
    ORDER BY menuitemid, sysinserttime DESC;

    GET DIAGNOSTICS v_item_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % master items from menu_entities',
                 p_organizationid, v_item_count;

    CREATE INDEX ON tmp_master_items USING GIN (norm_ts_name gin_trgm_ops);
    ANALYZE tmp_master_items;
    ANALYZE tmp_filtered_modifiers;

    -- ----------------------------------------------------------------
    -- Step 4: collect ALL matches above threshold
    -- No DISTINCT ON here — one modifier can match multiple items,
    -- all of which go into the matched_items JSONB array
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_matches ON COMMIT DROP AS
    SELECT
        fm.organizationid,
        fm.organizationname,
        fm.locationid,
        fm.locationname,
        fm.catalogid,
        fm.catalogname,
        fm.modifierid,
        fm.modifiername,
        fm.group_occurrence_count,
        fm.modifier_price,
        fm.modifier_is_default,
        fm.modifier_calories,
        fm.modifier_max_quantity,
        fm.modifier_min_quantity,
        mi.menuitemid                                               AS matched_menuitemid,
        mi.menuitemname                                             AS matched_menuitemname,
        dim.token_sort_ratio(fm.modifiername, mi.menuitemname)      AS tsr_score,
        CASE
            WHEN dim.ml_normalize(mi.menuitemname)
                    LIKE '%' || dim.ml_normalize(fm.modifiername) || '%'
             AND dim.ml_normalize(fm.modifiername)
                 <> dim.ml_normalize(mi.menuitemname)
                THEN 'item_extends_modifier'
            WHEN dim.ml_normalize(fm.modifiername)  ~ '\y(small|regular|large)\y'
             AND dim.ml_normalize(mi.menuitemname)  !~ '\y(small|regular|large)\y'
                THEN 'modifier_adds_size'
            WHEN dim.ml_normalize(fm.modifiername)
                    ~ '\y(vanilla|chocolate|strawberry|blueberry|cucumber|hibiscus|lavender)\y'
             AND dim.ml_normalize(mi.menuitemname)
                    !~ '\y(vanilla|chocolate|strawberry|blueberry|cucumber|hibiscus|lavender)\y'
                THEN 'modifier_adds_flavor'
            ELSE 'near_equal'
        END                                                         AS match_direction,
        mi.itemunitprice,
        mi.entitytype,
        mi.calories,
        mi.categoryid,
        mi.categoryname,
        mi.is_alcoholic,
        mi.is_vegetarian_item,
        mi.is_vegan_item,
        mi.has_allergen,
        mi.average_rating,
        mi.rating_count,
        (   dim.ml_normalize(fm.modifiername)  ~ '\y(small|regular|large)\y'
        AND dim.ml_normalize(mi.menuitemname) !~ '\y(small|regular|large)\y'
        )                                                           AS is_size_variant
    FROM tmp_filtered_modifiers fm
    CROSS JOIN LATERAL (
        SELECT
            menuitemid, menuitemname, itemunitprice, entitytype, calories,
            categoryid, categoryname, is_alcoholic, is_vegetarian_item,
            is_vegan_item, has_allergen, average_rating, rating_count
        FROM   tmp_master_items
        WHERE  norm_ts_name % fm.norm_ts_name
          AND  similarity(norm_ts_name, fm.norm_ts_name) >= p_trgm_prefilter
        ORDER  BY similarity(norm_ts_name, fm.norm_ts_name) DESC
        LIMIT  5
    ) mi
    WHERE dim.token_sort_ratio(fm.modifiername, mi.menuitemname) >= p_tsr_threshold;

    -- ----------------------------------------------------------------
    -- Step 5: aggregate into one row per modifier and upsert
    -- Flat columns carry the best match (highest tsr_score)
    -- matched_items JSONB carries all matches sorted best-first
    -- ----------------------------------------------------------------
    INSERT INTO ml.modifier_item_match (
        organizationid,
        organizationname,
        locationid,
        locationname,
        catalogid,
        catalogname,
        modifierid,
        modifiername,
        matched_menuitemid,
        matched_menuitemname,
        tsr_score,
        match_direction,
        matched_items,
        group_occurrence_count,
        modifier_price,
        item_price,
        item_entity_type,
        item_calories,
        item_categoryid,
        item_categoryname,
        item_is_alcoholic,
        item_is_vegetarian,
        item_is_vegan,
        item_has_allergen,
        item_average_rating,
        item_rating_count,
        modifier_is_default,
        modifier_calories,
        modifier_max_quantity,
        modifier_min_quantity,
        is_size_variant,
        matched_at
    )
    SELECT
        organizationid,
        organizationname,
        locationid,
        locationname,
        catalogid,
        catalogname,
        modifierid,
        modifiername,
        -- best match flat columns
        (array_agg(matched_menuitemid   ORDER BY tsr_score DESC))[1],
        (array_agg(matched_menuitemname ORDER BY tsr_score DESC))[1],
        MAX(tsr_score),
        (array_agg(match_direction      ORDER BY tsr_score DESC))[1],
        -- all matches as JSONB array, sorted best-first
        jsonb_agg(
            jsonb_build_object(
                'menuitemid',       matched_menuitemid,
                'menuitemname',     matched_menuitemname,
                'tsr_score',        tsr_score,
                'match_direction',  match_direction,
                'item_price',       itemunitprice
            )
            ORDER BY tsr_score DESC
        )                                                           AS matched_items,
        MAX(group_occurrence_count),
        MIN(modifier_price),
        -- item features from best match
        (array_agg(itemunitprice        ORDER BY tsr_score DESC))[1],
        (array_agg(entitytype           ORDER BY tsr_score DESC))[1],
        (array_agg(calories             ORDER BY tsr_score DESC))[1],
        (array_agg(categoryid           ORDER BY tsr_score DESC))[1],
        (array_agg(categoryname         ORDER BY tsr_score DESC))[1],
        BOOL_OR(is_alcoholic),
        BOOL_OR(is_vegetarian_item),
        BOOL_OR(is_vegan_item),
        BOOL_OR(has_allergen),
        MAX(average_rating),
        MAX(rating_count),
        -- modifier features
        BOOL_OR(modifier_is_default),
        MIN(modifier_calories),
        MAX(modifier_max_quantity),
        MIN(modifier_min_quantity),
        BOOL_OR(is_size_variant),
        NOW()
    FROM tmp_matches
    GROUP BY
        organizationid, organizationname,
        locationid, locationname,
        catalogid, catalogname,
        modifierid, modifiername
    ON CONFLICT (organizationid, modifierid) DO UPDATE SET
        organizationname       = EXCLUDED.organizationname,
        locationid             = EXCLUDED.locationid,
        locationname           = EXCLUDED.locationname,
        catalogid              = EXCLUDED.catalogid,
        catalogname            = EXCLUDED.catalogname,
        modifiername           = EXCLUDED.modifiername,
        matched_menuitemid     = EXCLUDED.matched_menuitemid,
        matched_menuitemname   = EXCLUDED.matched_menuitemname,
        tsr_score              = EXCLUDED.tsr_score,
        match_direction        = EXCLUDED.match_direction,
        matched_items          = EXCLUDED.matched_items,
        group_occurrence_count = EXCLUDED.group_occurrence_count,
        modifier_price         = EXCLUDED.modifier_price,
        item_price             = EXCLUDED.item_price,
        item_entity_type       = EXCLUDED.item_entity_type,
        item_calories          = EXCLUDED.item_calories,
        item_categoryid        = EXCLUDED.item_categoryid,
        item_categoryname      = EXCLUDED.item_categoryname,
        item_is_alcoholic      = EXCLUDED.item_is_alcoholic,
        item_is_vegetarian     = EXCLUDED.item_is_vegetarian,
        item_is_vegan          = EXCLUDED.item_is_vegan,
        item_has_allergen      = EXCLUDED.item_has_allergen,
        item_average_rating    = EXCLUDED.item_average_rating,
        item_rating_count      = EXCLUDED.item_rating_count,
        modifier_is_default    = EXCLUDED.modifier_is_default,
        modifier_calories      = EXCLUDED.modifier_calories,
        modifier_max_quantity  = EXCLUDED.modifier_max_quantity,
        modifier_min_quantity  = EXCLUDED.modifier_min_quantity,
        is_size_variant        = EXCLUDED.is_size_variant,
        matched_at             = EXCLUDED.matched_at;
        -- match_confidence_tier and price_delta are GENERATED — updated automatically

    GET DIAGNOSTICS v_match_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % modifiers matched (threshold=%s%%)',
                 p_organizationid, v_match_count, p_tsr_threshold;

    DROP TABLE IF EXISTS tmp_matches;
    DROP TABLE IF EXISTS tmp_filtered_modifiers;
    DROP TABLE IF EXISTS tmp_master_items;

END;
$BODY$;

ALTER PROCEDURE ml.usp_run_item_modifier_matching(TEXT, NUMERIC, NUMERIC)
    OWNER TO citus;



-- Single org (mirrors one call to run_item_modifier_matching(org_id, data))
CALL dim.usp_run_item_modifier_matching('org-2ad9799e-...');

-- Tighten threshold for a noisy catalog
CALL dim.usp_run_item_modifier_matching('org-2ad9799e-...', 80);

-- All active orgs from ADF ForEach
DO $BODY$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT organizationid FROM dim.organization WHERE is_active = TRUE LOOP
        CALL dim.usp_run_item_modifier_matching(r.organizationid);
    END LOOP;
END $BODY$;

-- Query results — equivalent to modifier_name_to_items dict
SELECT modifiername, matched_itemname, tsr_score
FROM   dim.modifier_item_match
WHERE  organizationid = 'org-2ad9799e-...'
ORDER  BY tsr_score DESC;




