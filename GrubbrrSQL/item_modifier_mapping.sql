SELECT * FROM public.item_modifier_group_glue as img 
WHERE 1=1 
  AND img.catalog_id = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  AND img.item_master_id = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND img.modifier_group_master_id = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'
LIMIT 100

SELECT * FROM public.modifier_group_modifier_glue as mg 
WHERE 1=1 
  --AND mg.catalog_id = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  --AND mg.item_master_id = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND mg.modifier_group_master_id = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'
LIMIT 100

SELECT DISTINCT
       img.catalog_id as catalogid,
       img.item_master_id as menuitemid,
       img.modifier_group_master_id as modifiergroupid,
       mg.modifier_master_id as modifierid,
       img.min_selection as itm_modgrp_min_selection,
       img.max_selection as itm_modgrp_max_selection,
       img.free_count as itm_modgrp_free_count,
       img.is_active as is_itm_modgrp_active,
       img.is_deleted as is_itm_modgrp_deleted,
       img.created_on as itm_modgrp_created_on,
       img.modified_on as itm_modgrp_modified_on,
       img.is_invisible as is_itm_modgrp_invisible,
       mg.is_default,
       mg.min_quantity,
       mg.max_quantity,
       mg.allow_quantity_increment,
       mg.increment_step,
       mg.default_quantity,
       mg.is_active as is_modgrp_modfr_active,
       mg.is_deleted as is_modgrp_modfr_deleted,
       mg.created_on as modgrp_modfr_created_on,
       mg.modified_on as modgrp_modfr_modified_on,
       mg.is_invisible as is_modgrp_modfr_invisible
FROM public.item_modifier_group_glue as img 
INNER JOIN public.modifier_group_modifier_glue as mg
        ON img.catalog_id = mg.catalog_id
        AND img.modifier_group_master_id = mg.modifier_group_master_id
WHERE 1=1 
  AND img.catalog_id = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  AND img.item_master_id = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND img.modifier_group_master_id = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'
LIMIT 100







CREATE TABLE if not EXISTS dim.item_modifier_group_modifier_mapping(
    catalogid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    menuitemid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    itm_modgrp_min_selection integer,
    itm_modgrp_max_selection integer,
    itm_modgrp_free_count integer,
    is_itm_modgrp_active boolean,
    is_itm_modgrp_deleted boolean,
    itm_modgrp_created_on timestamp without time zone,
    itm_modgrp_modified_on timestamp without time zone,
    is_itm_modgrp_invisible boolean,
    is_default BOOLEAN,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    default_quantity integer,
    is_modgrp_modfr_active boolean NOT NULL,
    is_modgrp_modfr_deleted boolean NOT NULL,
    modgrp_modfr_created_on timestamp without time zone,
    modgrp_modfr_modified_on timestamp without time zone,
    is_modgrp_modfr_invisible boolean
);

ALTER TABLE dim.item_modifier_group_modifier_mapping
OWNER to citus;

SELECT --mgmg.modifier_group_master_id, mgmg.modifier_master_id, 
       count(*)
FROM public.modifier_group_modifier_glue as mgmg --3,502,461///Stage**791,667
GROUP BY mgmg.modifier_group_master_id, mgmg.modifier_master_id
HAVING count(*) > 1
LIMIT 1000;

SELECT --mgmg.item_master_id, mgmg.modifier_group_master_id,
      count(*)
FROM public.item_modifier_group_glue as mgmg --1,473,202///Stage**455,885
GROUP BY mgmg.item_master_id, mgmg.modifier_group_master_id
HAVING count(*) > 1
LIMIT 1000;


WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE 1=1
      AND (
          CASE 
              WHEN 'org-cf184e55-c5f4-4f43-9581-c7c9d2b72be2' NOT LIKE 'loc-%' 
              THEN ol.organizationid 
              ELSE ol.locationid 
          END
      ) = 'org-cf184e55-c5f4-4f43-9581-c7c9d2b72be2'
      AND ol.organizationtype = 0
),org_loc_ctlg AS (
    SELECT 
        ol.*,
        c.catalogid,
        c.catalogname
    FROM org_loc_lookup AS ol
    INNER JOIN dim.catalog AS c
        ON ol.organizationid = c.organizationid
       AND ol.locationid = c.gem_location_id
)

SELECT olc.organizationid,
       olc.organizationname,
       olc.locationid,
       olc.locationname,
       imgm.catalogid,
       olc.catalogname,
       2026 AS yyyy,
       10 AS ww,
       imgm.menuitemid,
       imgm.modifiergroupid,
       imgm.modifierid,
       imgm.itm_modgrp_min_selection,
       imgm.itm_modgrp_max_selection,
       imgm.itm_modgrp_free_count,
       imgm.is_itm_modgrp_active,
       imgm.is_itm_modgrp_deleted,
       imgm.itm_modgrp_created_on,
       imgm.itm_modgrp_modified_on,
       imgm.is_itm_modgrp_invisible,
       imgm.is_default,
       imgm.min_quantity,
       imgm.max_quantity,
       imgm.allow_quantity_increment,
       imgm.increment_step,
       imgm.default_quantity,
       imgm.is_modgrp_modfr_active,
       imgm.is_modgrp_modfr_deleted,
       imgm.modgrp_modfr_created_on,
       imgm.modgrp_modfr_modified_on,
       imgm.is_modgrp_modfr_invisible
FROM org_loc_ctlg as olc 
LEFT JOIN dim.item_modifier_group_modifier_mapping as imgm
        ON olc.catalogid = imgm.catalogid
WHERE (
        EXTRACT(YEAR FROM imgm.modgrp_modfr_created_on)::INTEGER = 2026
        AND EXTRACT(WEEK FROM imgm.modgrp_modfr_created_on)::INTEGER <= 10
    )
    OR (
        EXTRACT(YEAR FROM imgm.modgrp_modfr_created_on)::INTEGER < 2026
    )

WHERE 1=1 
  AND img.catalog_id = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  AND img.item_master_id = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND img.modifier_group_master_id = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'


SELECT * FROM dim.CATALOG WHERE catalogid = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'

SELECT *-- count(*)
FROM dim.item_modifier_group_modifier_mapping as img
WHERE 1=1 
  AND img.catalogid = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  AND img.menuitemid = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND img.modifiergroupid = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'



SELECT DISTINCT
       img.catalog_id AS catalogid,
       img.item_master_id AS menuitemid,
       im.name AS item_name,
       img.modifier_group_master_id AS modifiergroupid,
       mgm.name AS modifier_group_name,
       mg.modifier_master_id AS modifierid,
       mm.name AS modifier_name,
       img.min_selection AS itm_modgrp_min_selection,
       img.max_selection AS itm_modgrp_max_selection,
       img.free_count AS itm_modgrp_free_count,
       img.is_active AS is_itm_modgrp_active,
       img.is_deleted AS is_itm_modgrp_deleted,
       img.created_on AS itm_modgrp_created_on,
       img.modified_on AS itm_modgrp_modified_on,
       img.is_invisible AS is_itm_modgrp_invisible,
       mg.is_default,
       mg.min_quantity,
       mg.max_quantity,
       mg.allow_quantity_increment,
       mg.increment_step,
       mg.default_quantity,
       mg.is_active AS is_modgrp_modfr_active,
       mg.is_deleted AS is_modgrp_modfr_deleted,
       mg.created_on AS modgrp_modfr_created_on,
       mg.modified_on AS modgrp_modfr_modified_on,
       mg.is_invisible AS is_modgrp_modfr_invisible
FROM public.item_modifier_group_glue AS img
INNER JOIN public.item_master AS im
        ON im.catalog_id = img.catalog_id
       AND im.id = img.item_master_id
INNER JOIN public.modifier_group_master AS mgm
        ON mgm.catalog_id = img.catalog_id
       AND mgm.id = img.modifier_group_master_id
INNER JOIN public.modifier_group_modifier_glue AS mg
        ON img.catalog_id = mg.catalog_id
       AND img.modifier_group_master_id = mg.modifier_group_master_id
LEFT JOIN public.modifier_master AS mm
        ON mm.catalog_id = mg.catalog_id
       AND mm.id = mg.modifier_master_id
WHERE img.catalog_id = 'catlg-72d9629f-b501-4707-84c9-cd31943837b7'
  AND img.item_master_id = 'itm-bfc98578-a9c7-4d82-a6f6-1fc187e43476'
  AND img.modifier_group_master_id = 'modgrp-58788338-8abb-4418-8fb7-1920e92dc527'
LIMIT 100;