--SELECT * FROM stg.transactionheader;
--DROP TABLE IF EXISTS stg.transactionheader;

CREATE TABLE IF NOT EXISTS stg.transactionheader (
    -- identifiers
    id                                  text COLLATE pg_catalog."default"    NOT NULL,
    kioskSessionId                      text COLLATE pg_catalog."default",
    orderId                             text COLLATE pg_catalog."default",
    locationId                          text COLLATE pg_catalog."default",

    -- order classification
    type                                text COLLATE pg_catalog."default",
    orderType                           text COLLATE pg_catalog."default",
    orderTypeLabel                      text COLLATE pg_catalog."default",
    channel                             INTEGER,

    -- dates
    orderDate                           text COLLATE pg_catalog."default",
    businessDate                        text COLLATE pg_catalog."default",

    -- order metrics
    guestCount                          INTEGER,
    posSubmissionStatus                 INTEGER,
    isFailedToSendToPos                 BOOLEAN,
    isTestOrder                         BOOLEAN,
    clientIpAddress                     text COLLATE pg_catalog."default",

    -- concept / location context
    conceptId                           text COLLATE pg_catalog."default",
    conceptName                         text COLLATE pg_catalog."default",

    -- loyalty
    loyaltyUser                         text COLLATE pg_catalog."default",
    loyaltyProviderTransactionId        text COLLATE pg_catalog."default",
    loyaltyProviderPaymentTransactionId text COLLATE pg_catalog."default",

    -- receipt links (URLs)
    receiptImage                        text COLLATE pg_catalog."default",
    orderReceiptUrl                     text COLLATE pg_catalog."default",
    orderReceiptPdfUrl                  text COLLATE pg_catalog."default",
    guestCheckImageLink                 text COLLATE pg_catalog."default",           -- note: typo preserved from source

    -- nested objects (stored as JSON strings)
    totals                              text COLLATE pg_catalog."default",
    totalsCents                         text COLLATE pg_catalog."default",
    localCurrencyDetails                text COLLATE pg_catalog."default",
    orderIdentity                       text COLLATE pg_catalog."default",
    kioskSource                         text COLLATE pg_catalog."default",
    upsellInformation                   text COLLATE pg_catalog."default",
    receiptDetails                      text COLLATE pg_catalog."default",

    -- nested arrays (stored as JSON strings)
    items                               text COLLATE pg_catalog."default",
    combos                              text COLLATE pg_catalog."default",
    paymentDetails                      text COLLATE pg_catalog."default",
    redeemedRewards                     text COLLATE pg_catalog."default",
    discounts                           text COLLATE pg_catalog."default",
    concepts                            text COLLATE pg_catalog."default",

    -- CosmosDB system fields
    sys_rid                                text COLLATE pg_catalog."default",
    sys_self                               text COLLATE pg_catalog."default",
    sys_etag                               text COLLATE pg_catalog."default",
    sys_attachments                        text COLLATE pg_catalog."default",
    sys_lsn                                BIGINT,
    syscosmosts                            BIGINT,
    bronze_filepath text COLLATE pg_catalog."default",
    CONSTRAINT pk_transactionheader PRIMARY KEY (id)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.transactionheader
OWNER TO citus;

ALTER TABLE IF EXISTS stg.transactionheader
ADD COLUMN IF NOT EXISTS bronze_filepath text COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS concepts text COLLATE pg_catalog."default";
