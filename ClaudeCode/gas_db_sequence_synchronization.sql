/*
SELECT *
FROM dim.menuitem
ORDER BY id DESC
LIMIT 100;
*/

CREATE SEQUENCE IF NOT EXISTS dim.element_elementid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE dim.element_elementid_seq OWNER TO citus;


-- Link sequence lifecycle to the column
ALTER SEQUENCE dim.element_elementid_seq
    OWNED BY dim.element.elementid;


-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.element_elementid_seq',
    (SELECT COALESCE(MAX(elementid), 0) FROM dim.element)
);

-- Attach as column default
ALTER TABLE IF EXISTS dim.element
    ALTER COLUMN elementid SET DEFAULT nextval('dim.element_elementid_seq');


CREATE SEQUENCE IF NOT EXISTS dim.view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE dim.view_id_seq OWNER TO citus;

ALTER TABLE IF EXISTS dim.view
    ALTER COLUMN viewid DROP IDENTITY IF EXISTS;

-- Link sequence lifecycle to the column
ALTER SEQUENCE dim.view_id_seq
    OWNED BY dim.view.viewid;


-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.view_id_seq',
    (SELECT COALESCE(MAX(viewid), 0) FROM dim.view)
);

-- Attach as column default
ALTER TABLE IF EXISTS dim.view
    ALTER COLUMN viewid SET DEFAULT nextval('dim.view_id_seq');


CREATE SEQUENCE IF NOT EXISTS dim.frequentcustomer_customerkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.frequentcustomer_customerkey_seq OWNER TO citus;

ALTER SEQUENCE dim.frequentcustomer_customerkey_seq
    OWNED BY dim.frequentcustomer.customerkey;

-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.frequentcustomer_customerkey_seq',
    (SELECT COALESCE(MAX(customerkey), 0) FROM dim.frequentcustomer)
);


ALTER TABLE IF EXISTS dim.frequentcustomer
    ALTER COLUMN customerkey SET DEFAULT nextval('dim.frequentcustomer_customerkey_seq');




CREATE SEQUENCE IF NOT EXISTS dim.itemcategory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.itemcategory_id_seq OWNER TO citus;

ALTER TABLE IF EXISTS dim.itemcategory
    ALTER COLUMN id DROP IDENTITY IF EXISTS;

ALTER SEQUENCE dim.itemcategory_id_seq
    OWNED BY dim.itemcategory.id;



-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.itemcategory_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM dim.itemcategory)
);

ALTER TABLE IF EXISTS dim.itemcategory
    ALTER COLUMN id SET DEFAULT nextval('dim.itemcategory_id_seq');


CREATE SEQUENCE IF NOT EXISTS dim.kiosk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.kiosk_id_seq OWNER TO citus;

ALTER TABLE IF EXISTS dim.kiosk
    ALTER COLUMN id DROP IDENTITY IF EXISTS;

ALTER SEQUENCE dim.kiosk_id_seq
    OWNED BY dim.kiosk.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.kiosk_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM dim.kiosk)
);

ALTER TABLE IF EXISTS dim.kiosk
    ALTER COLUMN id SET DEFAULT nextval('dim.kiosk_id_seq');


CREATE SEQUENCE IF NOT EXISTS dim.menuitem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.menuitem_id_seq OWNER TO citus;

ALTER SEQUENCE dim.menuitem_id_seq
    OWNED BY dim.menuitem.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.menuitem_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM dim.menuitem)
);

ALTER TABLE IF EXISTS dim.menuitem
    ALTER COLUMN id SET DEFAULT nextval('dim.menuitem_id_seq');


CREATE SEQUENCE IF NOT EXISTS dim.occasionsurvey_surveykey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.occasionsurvey_surveykey_seq OWNER TO citus;


ALTER SEQUENCE dim.occasionsurvey_surveykey_seq
    OWNED BY dim.occasionsurvey.surveykey;

-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.occasionsurvey_surveykey_seq',
    (SELECT COALESCE(MAX(surveykey), 0) FROM dim.occasionsurvey)
);


ALTER TABLE IF EXISTS dim.occasionsurvey
    ALTER COLUMN surveykey SET DEFAULT nextval('dim.occasionsurvey_surveykey_seq');


CREATE SEQUENCE IF NOT EXISTS dim.ordertype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.ordertype_id_seq OWNER TO citus;

ALTER TABLE IF EXISTS dim.ordertype
    ALTER COLUMN id DROP IDENTITY IF EXISTS;

ALTER SEQUENCE dim.ordertype_id_seq
    OWNED BY dim.ordertype.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'dim.ordertype_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM dim.ordertype)
);


ALTER TABLE IF EXISTS dim.ordertype
    ALTER COLUMN id SET DEFAULT nextval('dim.ordertype_id_seq');



CREATE SEQUENCE IF NOT EXISTS fact.devicestate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.devicestate_id_seq OWNER TO citus;


ALTER SEQUENCE fact.devicestate_id_seq
    OWNED BY fact.devicestate.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'fact.devicestate_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM fact.devicestate)
);

ALTER TABLE IF EXISTS fact.devicestate
    ALTER COLUMN id SET DEFAULT nextval('fact.devicestate_id_seq');


CREATE SEQUENCE IF NOT EXISTS fact.ordertiming_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.ordertiming_id_seq OWNER TO citus;

ALTER SEQUENCE fact.ordertiming_id_seq
    OWNED BY fact.ordertiming.id;


-- Set to current max safely (handles empty table)
SELECT setval(
    'fact.ordertiming_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM fact.ordertiming)
);

ALTER TABLE IF EXISTS fact.ordertiming
    ALTER COLUMN id SET DEFAULT nextval('fact.ordertiming_id_seq');


CREATE SEQUENCE IF NOT EXISTS fact.transactionheader_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.transactionheader_id_seq OWNER TO citus;

ALTER SEQUENCE fact.transactionheader_id_seq
    OWNED BY fact.transactionheader.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'fact.transactionheader_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM fact.transactionheader)
);

ALTER TABLE IF EXISTS fact.transactionheader
    ALTER COLUMN id SET DEFAULT nextval('fact.transactionheader_id_seq');


CREATE SEQUENCE IF NOT EXISTS fact.userbehaviour_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.userbehaviour_id_seq OWNER TO citus;

ALTER SEQUENCE fact.userbehaviour_id_seq
    OWNED BY fact.userbehaviour.id;

-- Set to current max safely (handles empty table)
SELECT setval(
    'fact.userbehaviour_id_seq',
    (SELECT COALESCE(MAX(id), 0) FROM fact.userbehaviour)
);


ALTER TABLE IF EXISTS fact.userbehaviour
    ALTER COLUMN id SET DEFAULT nextval('fact.userbehaviour_id_seq');



