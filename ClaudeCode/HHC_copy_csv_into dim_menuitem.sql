-- Table: dim.menuitem

-- DROP TABLE IF EXISTS dim.menuitem;

CREATE TABLE IF NOT EXISTS dim.menuitem_hhc
(
    --catalogid text COLLATE pg_catalog."default" DEFAULT 'catlg-52f55d50-1b76-46c9-a984-104788b48ce2' :: TEXT, --HoustonHotChicken
    menuitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemname text COLLATE pg_catalog."default" NOT NULL,
    average_rating numeric(3,2),
    rating_count integer,
    rating_stddev numeric(3,2),
    sysinserttime timestamp without time zone DEFAULT NOW() :: TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.menuitem_hhc
    OWNER to citus;

/*
\copy dim.menuitem_hhc (menuitemid, menuitemname, average_rating, rating_count, rating_stddev)
FROM '"C:\Users\user\Work\Grubbrr\grubbrr-dwh\SampleDatasets\ratings_scenario1_high_confidence.csv"'
WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', NULL '');
*/

SELECT * FROM dim.menuitem_hhc;

UPDATE dim.menuitem
SET average_rating = hhc.average_rating,
    rating_count   = hhc.rating_count,
    sysupdatetime  = NOW() :: TIMESTAMP
FROM dim.menuitem_hhc as hhc 
WHERE menuitem.menuitemid = hhc.menuitemid