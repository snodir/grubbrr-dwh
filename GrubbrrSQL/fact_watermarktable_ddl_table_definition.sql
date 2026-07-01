--
-- PostgreSQL database dump
--

--\restrict Ld8m5lfuQGP2c19BD1gmbusczTi0Gmj5Z9lyqXtLAD1mDro4NuVLjmVOMS9D05v

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.3

-- Started on 2026-05-28 11:00:09
/*
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
*/

SELECT watermarktablename, source, ts as maxts_nge
FROM fact.watermarktable
WHERE watermarktablename = 'fact.itemssurvey'
  AND source             = 'nge'

SELECT *, TO_TIMESTAMP(ts) as ts_datetime,
    CONCAT('UPDATE fact.watermarktable ', 
           'SET ts = (SELECT MAX(', watermarkcolumn, ') FROM ', watermarktablename, '), '
           'sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = ''', watermarktablename, ''' AND source = ''', source, ''';') as update_statement
FROM fact.watermarktable;

    UPDATE fact.watermarktable
    SET ts            = (SELECT max(syscosmosts) FROM fact.deviceevent),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.deviceevent'
      AND source             = 'gem';

/*
Started executing query at Line 6
UPDATE 1
Total execution time: 00:03:31.380
*/

    UPDATE fact.watermarktable
    SET ts            = (SELECT max(syscosmosts) FROM fact.userbehaviour),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.userbehaviour'
      AND source             = 'gem';

/*
Started executing query at Line 18
UPDATE 1
Total execution time: 00:01:39.136
*/

--UPDATE fact.watermarktable SET watermarkcolumn = 'syscosmosts' WHERE watermarktablename = 'fact.userbehaviour' AND source = 'gem'
--UPDATE fact.watermarktable SET watermarkcolumn = 'syscosmosts' WHERE watermarktablename = 'fact.userbehaviour' AND source = 'gem'


--
-- TOC entry 6063 (class 0 OID 33011)
-- Dependencies: 399
-- Data for Name: watermarktable; Type: TABLE DATA; Schema: fact; Owner: citus

SELECT * FROM dim.grubbrr_source_lookup;

/*
1	nge	             Next Generation Enterprise
2	gem	             Grubbrr Event Management
3	gsh	             Grubbrr System Health
4	gou	             Grubbrr Organizations and Users
5	nge-Interactions NGE Modifier Interactions
6	nge-Options	     NGE Modifier Options
7	gxs	             Grubbrr Transaction Service
*/

UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM dim.abtests),                                                    sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'dim.abtests' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.transactionitem WHERE transactionheaderid LIKE 'ordevt-%'), sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.transactionitem' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.transactionpayment),                                        sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.transactionpayment' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.gem_failed_order_job_notifications),                        sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.gem_failed_order_job_notifications' AND source = 'gem-Job';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.cep_incidents),                                             sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.cep_incidents' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.itemmodifier),                                              sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.itemmodifier' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.transactionrefunds),                                        sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.transactionrefunds' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.recommendations),                                           sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.recommendations' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.modifier_recommendations),                                  sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.modifier_recommendations' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.modifier_interactions WHERE sourceid = 5),                  sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Interactions';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.modifier_interactions WHERE sourceid = 6),                  sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Options';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.modifier_impressions),                                      sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.modifier_impressions' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.transactionheader WHERE sourceid = 2),                      sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.transactionheader' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(gem_syscosmosts) FROM fact.sent_surveys),                                          sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.sent_surveys' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(gem_syscosmosts) FROM fact.itemssurvey),                                           sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.itemssurvey' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.occasionsurveydetail WHERE sourceid = 1),                   sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.occasionsurveydetail' AND source = 'nge';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.occasionsurveydetail WHERE sourceid = 2),                   sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.occasionsurveydetail' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(nge_syscosmosts) FROM fact.itemssurvey),                                           sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.itemssurvey' AND source = 'nge';
UPDATE fact.watermarktable SET watermarkvalue = (SELECT MAX(lasteventtime) FROM fact.devicestate),                                 sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.devicestate' AND source = 'gsh';
UPDATE fact.watermarktable SET watermarkvalue = (SELECT LEAST(MAX(cputimestamp), MAX(memorytimestamp)) FROM fact.devicetelemetry), sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.devicetelemetry' AND source = 'gsh';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.ordertiming),                                               sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.ordertiming' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.usercheckedin),                                             sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.usercheckedin' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.deviceevent),                                               sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.deviceevent' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.userbehaviour),                                             sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.userbehaviour' AND source = 'gem';
UPDATE fact.watermarktable SET ts = (SELECT MAX(syscosmosts) FROM fact.transactionheader WHERE sourceid = 1),                      sysupdatetime = NOW() :: TIMESTAMP WHERE watermarktablename = 'fact.transactionheader' AND source = 'nge';
--
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.transactionitem', 'syscosmosts', NULL, NULL, 1720000300, 'nge', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.transactionpayment', 'syscosmosts', NULL, NULL, 1720000300, 'nge', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.usercheckedin', 'syscosmosts', NULL, NULL, 1767225610, 'gem', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.gem_failed_order_job_notifications', 'syscosmosts', NULL, NULL, 1767225610, 'gem-Job', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.cep_incidents', 'syscosmosts', NULL, NULL, 1767225610, 'gem', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.userbehaviour', 'busdate', '2026-04-02 09:18:34.656', NULL, 1775121514, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.deviceevent', 'syscosmosts', '2026-05-21 09:13:32.997', 639149516162368326, 1779354816, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.devicestate', 'lasteventtime', '2026-05-21 09:22:16.038379', NULL, 1720000300, 'gsh');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.devicetelemetry', 'telemetrytime', '2026-05-21 09:23:38.912166', NULL, NULL, 'gsh');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.ordertiming', 'syscosmosts', NULL, NULL, 1779355838, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.recommendations', 'syscosmosts', NULL, NULL, 1779181196, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.modifier_recommendations', 'syscosmosts', NULL, NULL, 1775002000, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.modifier_impressions', 'syscosmosts', NULL, NULL, 1775002000, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.modifier_interactions', 'syscosmosts', NULL, NULL, 1775002000, 'nge-Interactions');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.modifier_interactions', 'syscosmosts', NULL, NULL, 1775825597, 'nge-Options');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('dim.abtests', 'syscosmosts', NULL, NULL, 1742473116, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.itemssurvey', 'gem_syscosmosts', NULL, NULL, 1778739578, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.itemssurvey', 'nge_syscosmosts', NULL, NULL, 1777367431, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionrefunds', 'syscosmosts', NULL, NULL, 1777366909, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.sent_surveys', 'gem_syscosmosts', NULL, NULL, 1779287007, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.occasionsurveydetail', 'syscosmosts', NULL, NULL, 1778680308, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.occasionsurveydetail', 'syscosmosts', NULL, NULL, 1775002010, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionheader', 'syscosmosts', NULL, NULL, 1779395953, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionheader', 'syscosmosts', NULL, NULL, 1779480374, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.itemmodifier', 'syscosmosts', NULL, NULL, 1779289519, 'nge');


-- Completed on 2026-05-28 11:00:23

--
-- PostgreSQL database dump complete
--

--\unrestrict Ld8m5lfuQGP2c19BD1gmbusczTi0Gmj5Z9lyqXtLAD1mDro4NuVLjmVOMS9D05v

