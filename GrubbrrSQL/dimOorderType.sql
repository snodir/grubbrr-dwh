drop TABLE IF EXISTS dim.ordertype;
CREATE TABLE IF NOT EXISTS dim.ordertype
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default" NOT NULL,
    ordertypeid text COLLATE pg_catalog."default" NOT NULL,
    ordertypelabel text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ordertype_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.ordertype
    OWNER to citus;

-- Index: dim.order_type_uidx
CREATE INDEX IF NOT EXISTS order_type_uidx
    ON dim.ordertype USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, kioskid COLLATE pg_catalog."default" ASC NULLS LAST, ordertypeid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

select * from dim.ordertype
select * from dim.ABTests

select * from dim.element

ALTER TABLE dim.ordertype
ALTER COLUMN id
DROP IDENTITY IF EXISTS;
