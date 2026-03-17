CREATE TABLE IF NOT EXISTS dim.itemcategory_bkp
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default" NOT NULL,
    isactive boolean NOT NULL DEFAULT true,
    CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.itemcategory_bkp
    OWNER to citus;

-- Index: dim.itemcategory_bkp_idx
CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_bkp_idx
    ON dim.itemcategory_bkp USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, categoryid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: dim.itemcategory_bkp_locationid_idx
CREATE INDEX IF NOT EXISTS itemcategory_bkp_locationid_idx
    ON dim.itemcategory_bkp USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(categoryid, isactive)
    TABLESPACE pg_default;

--TRUNCATE table dim.itemcategory

--INSERT INTO dim.itemcategory_bkp
SELECT * FROM dim.itemcategory--_bkp

--UPDATE fact.transactionitem
set categoryid = NULL

select * from fact.transactionitem LIMIT 10