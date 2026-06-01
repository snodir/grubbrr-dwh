--
-- PostgreSQL database dump
--

\restrict Ld8m5lfuQGP2c19BD1gmbusczTi0Gmj5Z9lyqXtLAD1mDro4NuVLjmVOMS9D05v

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.3

-- Started on 2026-05-28 11:00:09

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

--
-- TOC entry 6063 (class 0 OID 33011)
-- Dependencies: 399
-- Data for Name: watermarktable; Type: TABLE DATA; Schema: fact; Owner: citus
--
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.gem_failed_order_job_notifications', 'syscosmosts', NULL, NULL, 1767225610, 'gem-Job', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source, sysinserttime) VALUES ('fact.cep_incidents', 'syscosmosts', NULL, NULL, 1775002010, 'gem', NOW() :: TIMESTAMP);
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.usercheckedin', 'syscosmosts', NULL, NULL, 1775002010, 'gem');
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
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionitem', 'syscosmosts', NULL, NULL, 1720000300, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionitem', 'syscosmosts', NULL, NULL, 1720000300, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionpayment', 'syscosmosts', NULL, NULL, 1720000300, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionheader', 'syscosmosts', NULL, NULL, 1779395953, 'nge');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.transactionheader', 'syscosmosts', NULL, NULL, 1779480374, 'gem');
INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, watermarkvalue, ticks, ts, source) VALUES ('fact.itemmodifier', 'syscosmosts', NULL, NULL, 1779289519, 'nge');


-- Completed on 2026-05-28 11:00:23

--
-- PostgreSQL database dump complete
--

\unrestrict Ld8m5lfuQGP2c19BD1gmbusczTi0Gmj5Z9lyqXtLAD1mDro4NuVLjmVOMS9D05v

