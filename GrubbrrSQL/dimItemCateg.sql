--drop TABLE IF EXISTS dim.itemcategory;
CREATE TABLE IF NOT EXISTS dim.itemcategory
(
    id bigint  not null,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default" NOT NULL,
    isactive boolean NOT NULL DEFAULT true,
    CONSTRAINT itemcategory_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.itemcategory
    OWNER to citus;

-- Index: dim.itemcategory_idx
CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_idx
    ON dim.itemcategory USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, categoryid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

--drop TABLE IF EXISTS dim.itemcategory;
CREATE TABLE IF NOT EXISTS dim.category_hierarchy
(
    id BIGINT,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default",
    menuitemid TEXT COLLATE pg_catalog."default",
    menuitemname TEXT COLLATE pg_catalog."default",
    entitytype TEXT COLLATE pg_catalog."default",
    syscosmosts BIGINT
)

TABLESPACE pg_default;

ALTER TABLE dim.category_hierarchy
    OWNER to citus;

SELECT menuitemid, count(*)
FROM dim.category_hierarchy
GROUP BY menuitemid
HAVING count(*) = 1

select coalesce(max(id), 0) as maxid from dim.itemcategory

ALTER TABLE dim.itemcategory
ALTER COLUMN id
DROP IDENTITY IF EXISTS;

SELECT *
FROM dim.menuitem
ORDER BY id DESC;

SELECT *
FROM dim.itemcategory
ORDER BY id DESC;

SELECT *
FROM dim.category_hierarchy
ORDER BY menuitemid DESC
LIMIT 1000

SELECT *
FROM dim.itemcategorymapping;

ALTER TABLE dim.itemcategorymapping
ADD COLUMN IF NOT EXISTS locationid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS categoryname TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS menuitemname TEXT COLLATE pg_catalog."default";