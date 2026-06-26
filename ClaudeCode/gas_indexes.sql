-- ================================================================
-- SOURCE TABLES
-- ================================================================

-- Covers: partition filter + type filter on all 9 sections
--         + DELETE WHERE bronze_folderpath in FLUSH
-- Composite wins over single-column because type appears in every WHERE
CREATE INDEX IF NOT EXISTS idx_stg_silver_all_trxn_ent_folderpath_type
ON stg.silver_all_transaction_entities ("bronze_folderpath", "type");

CREATE INDEX IF NOT EXISTS ix_silver_all_gem_events_syscosmosts_brin
    ON stg.silver_all_gem_events USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;

-- Covers: partition filter + FLUSH DELETE
-- LOWER() filters on application/eventmodule are cheap after partition reduces the set
CREATE INDEX IF NOT EXISTS idx_stg_silver_all_gem_events_folderpath
ON stg.silver_all_gem_events ("bronze_folderpath");


-- ================================================================
-- TARGET TABLES — NOT EXISTS subquery lookups
-- usp_distribute_silver_transaction_entities
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_hdr_txid_loc
ON stg.silver_transaction_header (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_pmt_txid_loc
ON stg.silver_transaction_payment (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_item_txid_loc
ON stg.silver_transaction_item (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_item_mod_txid_loc
ON stg.silver_item_modifiers (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_combo_txid_loc
ON stg.silver_transaction_combo_items (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_upsell_rec_txid_loc
ON stg.silver_upsell_recommendations (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_rec_txid_loc
ON stg.silver_modifier_recommendations (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_imp_txid_loc
ON stg.silver_modifier_impressions (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_int_txid_loc
ON stg.silver_modifier_interactions (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_ref_txid_loc
ON stg.silver_transaction_refunds (locationid, transactionheaderid);


-- ================================================================
-- TARGET TABLES — NOT EXISTS subquery lookups
-- usp_distribute_silver_gem_events
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_stg_silver_kiosk_events_id_loc
ON stg.silver_kiosk_events (locationid, id);

CREATE INDEX IF NOT EXISTS idx_stg_silver_cep_incidents_id_loc
ON stg.silver_cep_incidents (locationid, id);
--
-- TOC entry 6128 (class 2604 OID 419503)
-- Name: experiment dimkey; Type: DEFAULT; Schema: dim; Owner: citus
--

--ALTER TABLE ONLY dim.experiment ALTER COLUMN dimkey SET DEFAULT nextval('dim.experiment_dimkey_seq'::regclass);




--
-- TOC entry 6306 (class 2606 OID 2178868)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--
/*
ALTER TABLE ONLY dim.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6150 (class 2606 OID 32817)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);


--
-- TOC entry 6153 (class 2606 OID 32825)
-- Name: datedim datedim_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.datedim
    ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);


--
-- TOC entry 6239 (class 2606 OID 413632)
-- Name: device device_deviceid_locationid_companyid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);


--
-- TOC entry 6241 (class 2606 OID 413630)
-- Name: device device_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- TOC entry 6157 (class 2606 OID 32835)
-- Name: element dimelement_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element
    ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);


--
-- TOC entry 6263 (class 2606 OID 419507)
-- Name: experiment experiment_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (dimkey);


--
-- TOC entry 6222 (class 2606 OID 779308)
-- Name: frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6343 (class 2606 OID 3418404)
-- Name: frequentcustomer_bkp frequentcustomer_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer_bkp
    ADD CONSTRAINT frequentcustomer_bkp_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6296 (class 2606 OID 762128)
-- Name: grubbrr_source_lookup grubbrr_source_lookup_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.grubbrr_source_lookup
    ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);


--
-- TOC entry 6315 (class 2606 OID 2888241)
-- Name: item_modifier_group_modifier_mapping item_modgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.item_modifier_group_modifier_mapping
    ADD CONSTRAINT item_modgrp_modfr_unq UNIQUE (menuitemid, modifiergroupid, modifierid);


--
-- TOC entry 6279 (class 2606 OID 514418)
-- Name: itemcategory_bkp itemcategory_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory_bkp
    ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6161 (class 2606 OID 32844)
-- Name: itemcategory itemcategory_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory
    ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);


--
-- TOC entry 6224 (class 2606 OID 311956)
-- Name: kiosk kiosk_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);


--
-- TOC entry 6226 (class 2606 OID 311958)
-- Name: kiosk kiosk_uidx; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);


--
-- TOC entry 6302 (class 2606 OID 2047632)
-- Name: category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6228 (class 2606 OID 327015)
-- Name: locationcatalog location_ctlg_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.locationcatalog
    ADD CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6235 (class 2606 OID 387346)
-- Name: weather_bkp location_date_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather_bkp
    ADD CONSTRAINT location_date_bkp_pk PRIMARY KEY (locationid, businessdate);


--
-- TOC entry 6237 (class 2606 OID 393495)
-- Name: weather location_date_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather
    ADD CONSTRAINT location_date_pk PRIMARY KEY (locationid, apicalldate);


--
-- TOC entry 6164 (class 2606 OID 32869)
-- Name: location location_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.location
    ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);


--
-- TOC entry 6304 (class 2606 OID 2047655)
-- Name: duplicate_items_master locationid_categoryid_menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.duplicate_items_master
    ADD CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6298 (class 2606 OID 806161)
-- Name: vw_grubbrrinstallbase locationid_deviceid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6341 (class 2606 OID 3327448)
-- Name: vw_grubbrrinstallbase_all_devices locationid_kioskid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT locationid_kioskid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6282 (class 2606 OID 594665)
-- Name: kioskdetails locationid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kioskdetails
    ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);


--
-- TOC entry 6294 (class 2606 OID 695509)
-- Name: menuentities menuentities_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuentities
    ADD CONSTRAINT menuentities_pkey PRIMARY KEY (entityid);


--
-- TOC entry 6231 (class 2606 OID 359373)
-- Name: menuitem menuitem_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);


--
-- TOC entry 6233 (class 2606 OID 779647)
-- Name: menuitem menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);


--
-- TOC entry 6311 (class 2606 OID 2951718)
-- Name: modifier_group_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6320 (class 2606 OID 2951561)
-- Name: modifier_group modifier_group_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6313 (class 2606 OID 2196815)
-- Name: modifier_group_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6309 (class 2606 OID 2888243)
-- Name: modifier modifierid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier
    ADD CONSTRAINT modifierid_unq UNIQUE (modifierid);


--
-- TOC entry 6284 (class 2606 OID 672299)
-- Name: ordertype_bkp ordertype_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype_bkp
    ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6168 (class 2606 OID 32886)
-- Name: ordertype ordertype_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype
    ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);


--
-- TOC entry 6265 (class 2606 OID 431163)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6173 (class 2606 OID 775937)
-- Name: organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6248 (class 2606 OID 413646)
-- Name: peripheral peripheral_deviceid_peripheralid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);


--
-- TOC entry 6251 (class 2606 OID 413644)
-- Name: peripheral peripheral_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);


--
-- TOC entry 6337 (class 2606 OID 3087662)
-- Name: occasionsurvey survey_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);


--
-- TOC entry 6275 (class 2606 OID 471809)
-- Name: upsellgrouplookup upsellgroupid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.upsellgrouplookup
    ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);


--
-- TOC entry 6209 (class 2606 OID 103204)
-- Name: userlocation userlocation_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.userlocation
    ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);


--
-- TOC entry 6346 (class 2606 OID 3518729)
-- Name: bronze_partition_registry bronze_partition_registry_pkey; Type: CONSTRAINT; Schema: etl; Owner: citus
--

ALTER TABLE ONLY etl.bronze_partition_registry
    ADD CONSTRAINT bronze_partition_registry_pkey PRIMARY KEY (entity, dateid);


--
-- TOC entry 6254 (class 2606 OID 413951)
-- Name: devicehealth devicehealth_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicehealth
    ADD CONSTRAINT devicehealth_pkey PRIMARY KEY (id);


--
-- TOC entry 6211 (class 2606 OID 3650141)
-- Name: devicetelemetry devicetelemetry_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT devicetelemetry_pkey PRIMARY KEY (locationid, deviceid, dateid);


--
-- TOC entry 6289 (class 2606 OID 694784)
-- Name: location_menu_preferences location_dayparts_itemid_itemtype_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.location_menu_preferences
    ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);


--
-- TOC entry 6267 (class 2606 OID 775712)
-- Name: recommendations locationid_trxnid_recommendationid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6188 (class 2606 OID 32958)
-- Name: ordertiming ordertiming_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);


--
-- TOC entry 6260 (class 2606 OID 413963)
-- Name: peripheralhealth peripheralhealth_healthdataid_peripheralid_key; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_peripheralid_key UNIQUE (healthdataid, peripheralid);


--
-- TOC entry 6300 (class 2606 OID 888772)
-- Name: pos_sales_details pos_sales_details_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.pos_sales_details
    ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);


--
-- TOC entry 6322 (class 2606 OID 2987108)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6192 (class 2606 OID 32976)
-- Name: timingsdatalake timingsdatalake_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.timingsdatalake
    ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);


--
-- TOC entry 6196 (class 2606 OID 294801)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 6269 (class 2606 OID 454567)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6199 (class 2606 OID 57357)
-- Name: transactionitem transactionitem_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 6186 (class 2606 OID 1175206)
-- Name: itemmodifier trxnid_itemid_mdfrgrpid_mdfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemmodifier
    ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);


--
-- TOC entry 6287 (class 2606 OID 676695)
-- Name: vw_offer_analysis trxnid_recommendationid_itemid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);


--
-- TOC entry 6271 (class 2606 OID 459796)
-- Name: userbehaviour_exceptions userbehaviour_exceptions_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour_exceptions
    ADD CONSTRAINT userbehaviour_exceptions_pkey PRIMARY KEY (id);


--
-- TOC entry 6205 (class 2606 OID 33010)
-- Name: userbehaviour userbehaviour_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour
    ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);


--
-- TOC entry 6216 (class 2606 OID 3652822)
-- Name: usercheckedin usercheckedin_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.usercheckedin
    ADD CONSTRAINT usercheckedin_pkey PRIMARY KEY (locationid, orderid);


--
-- TOC entry 6207 (class 2606 OID 3583307)
-- Name: watermarktable watermarktablename_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.watermarktable
    ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);




--
-- TOC entry 6358 (class 2606 OID 3589002)
-- Name: dim_catalog catalog_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6348 (class 2606 OID 3584739)
-- Name: dim_frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6350 (class 2606 OID 3586063)
-- Name: dim_category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6354 (class 2606 OID 3586088)
-- Name: dim_modifiergroup_modifier_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6352 (class 2606 OID 3586079)
-- Name: dim_modifiergroup modifier_group_master_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6356 (class 2606 OID 3586086)
-- Name: dim_modifiergroup_modifier_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6362 (class 2606 OID 3644486)
-- Name: dim_organization organization_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6360 (class 2606 OID 3605523)
-- Name: dim_organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6339 (class 2606 OID 3244118)
-- Name: transactionheader pk_transactionheader; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.transactionheader
    ADD CONSTRAINT pk_transactionheader PRIMARY KEY (id);


--
-- TOC entry 6317 (class 2606 OID 2959149)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6273 (class 2606 OID 461044)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6151 (class 1259 OID 32826)
-- Name: IX_dateid_datets; Type: INDEX; Schema: dim; Owner: citus
--

*/


CREATE INDEX IF NOT EXISTS "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);


--
-- TOC entry 6169 (class 1259 OID 32893)
-- Name: IX_organizationid_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);


--
-- TOC entry 6148 (class 1259 OID 32818)
-- Name: company_id_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE INDEX IF NOT EXISTS company_id_idx ON dim.company USING btree (companyid);


--
-- TOC entry 6242 (class 1259 OID 413633)
-- Name: deviceid_locationid_companyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);


--
-- TOC entry 6162 (class 1259 OID 32870)
-- Name: dim_location_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS dim_location_idx ON dim.location USING btree (locationid);


--
-- TOC entry 6154 (class 1259 OID 32827)
-- Name: idx_datedim_dateid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_datedim_dateid ON dim.datedim USING btree (dateid);


--
-- TOC entry 6155 (class 1259 OID 32828)
-- Name: idx_datedim_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_datedim_datets ON dim.datedim USING btree (datets);


--
-- TOC entry 6243 (class 1259 OID 413634)
-- Name: idx_device_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_id ON dim.device USING btree (deviceid);


--
-- TOC entry 6244 (class 1259 OID 413635)
-- Name: idx_device_location_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_location_id ON dim.device USING btree (locationid);


--
-- TOC entry 6245 (class 1259 OID 413636)
-- Name: idx_device_state; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_state ON dim.device USING btree (state);


--
-- TOC entry 6246 (class 1259 OID 413637)
-- Name: idx_device_testmode; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_testmode ON dim.device USING btree (testmode);


--
-- TOC entry 6290 (class 1259 OID 695510)
-- Name: idx_menuentities_catalog; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_catalog ON dim.menuentities USING btree (catalogid);


--
-- TOC entry 6291 (class 1259 OID 695512)
-- Name: idx_menuentities_mealavail; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_mealavail ON dim.menuentities USING gin (mealavailability);


--
-- TOC entry 6292 (class 1259 OID 695511)
-- Name: idx_menuentities_tags; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_tags ON dim.menuentities USING gin (tags);


--
-- TOC entry 6170 (class 1259 OID 32894)
-- Name: idx_organizationlocation_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);


--
-- TOC entry 6171 (class 1259 OID 32895)
-- Name: idx_organizationlocation_organizationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);


--
-- TOC entry 6174 (class 1259 OID 32911)
-- Name: idx_view_viewid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_view_viewid ON dim.view USING btree (viewid);


--
-- TOC entry 6276 (class 1259 OID 514419)
-- Name: itemcategory_bkp_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_bkp_idx ON dim.itemcategory_bkp USING btree (locationid, categoryid);


--
-- TOC entry 6277 (class 1259 OID 514420)
-- Name: itemcategory_bkp_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE INDEX IF NOT EXISTS itemcategory_bkp_locationid_idx ON dim.itemcategory_bkp USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6158 (class 1259 OID 32845)
-- Name: itemcategory_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);


--
-- TOC entry 6159 (class 1259 OID 263819)
-- Name: itemcategory_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6229 (class 1259 OID 3399343)
-- Name: ix_dim_menuitem_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid ON dim.menuitem USING btree (catalogid);


--
-- TOC entry 6307 (class 1259 OID 3399344)
-- Name: ix_dim_modifier_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid ON dim.modifier USING btree (catalogid);


--
-- TOC entry 6318 (class 1259 OID 3399345)
-- Name: ix_dim_modifiergroup_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid ON dim.modifier_group USING btree (catalogid);


--
-- TOC entry 6165 (class 1259 OID 263829)
-- Name: locationgroupid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS locationgroupid_idx ON dim.location USING btree (locationgroupid);


--
-- TOC entry 6166 (class 1259 OID 32887)
-- Name: order_type_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX IF NOT EXISTS order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);


--
-- TOC entry 6249 (class 1259 OID 413652)
-- Name: peripheral_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);


--
-- TOC entry 6218 (class 1259 OID 263813)
-- Name: rating_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);


--
-- TOC entry 6217 (class 1259 OID 263814)
-- Name: surveytransstatus_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);


--
-- TOC entry 6175 (class 1259 OID 32927)
-- Name: deviceeventidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);


--
-- TOC entry 6176 (class 1259 OID 32928)
-- Name: deviceeventuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);


--
-- TOC entry 6252 (class 1259 OID 413952)
-- Name: devicehealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS devicehealth_idx ON fact.devicehealth USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);


--
-- TOC entry 6255 (class 1259 OID 413953)
-- Name: deviceid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceid_idx ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6256 (class 1259 OID 413954)
-- Name: idx_devicehealth_deviceid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6257 (class 1259 OID 413955)
-- Name: idx_devicehealth_deviceid_status_time; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid_status_time ON fact.devicehealth USING btree (deviceid, status, healthdatatime DESC);


--
-- TOC entry 6258 (class 1259 OID 413956)
-- Name: idx_devicehealth_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_locationid ON fact.devicehealth USING btree (locationid);


--
-- TOC entry 6179 (class 1259 OID 32934)
-- Name: idx_devicestate; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');


--
-- TOC entry 6180 (class 1259 OID 32935)
-- Name: idx_devicestate_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate_dateid ON fact.devicestate USING btree (dateid);


--
-- TOC entry 6181 (class 1259 OID 32936)
-- Name: idx_devicestate_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate_locationid ON fact.devicestate USING btree (locationid);


--
-- TOC entry 6212 (class 1259 OID 159819)
-- Name: idx_devicetelemetry; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);


--
-- TOC entry 6213 (class 1259 OID 159820)
-- Name: idx_devicetelemetry_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);


--
-- TOC entry 6214 (class 1259 OID 159821)
-- Name: idx_devicetelemetry_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);


--
-- TOC entry 6182 (class 1259 OID 3584720)
-- Name: idx_fact_itemmodifier_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid ON fact.itemmodifier USING btree (locationid);


--
-- TOC entry 6190 (class 1259 OID 309287)
-- Name: idx_fact_pipelinerunstatus_correlationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus);


--
-- TOC entry 6197 (class 1259 OID 3583313)
-- Name: idx_fact_transactionitem_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_transactionitem_locationid ON fact.transactionitem USING btree (locationid);


--
-- TOC entry 6200 (class 1259 OID 3583314)
-- Name: idx_fact_transactionpayment_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_transactionpayment_locationid ON fact.transactionpayment USING btree (locationid);


--
-- TOC entry 6280 (class 1259 OID 547181)
-- Name: idx_transactionrefunds_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);


--
-- TOC entry 6183 (class 1259 OID 32951)
-- Name: itemmodifieridx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE INDEX IF NOT EXISTS itemmodifieridx ON fact.itemmodifier USING btree (itemid);


--
-- TOC entry 6177 (class 1259 OID 2198165)
-- Name: ix_deviceevent_journey_lookup; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken) WHERE ((datacategory = 'insight'::text) AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text])));


--
-- TOC entry 6178 (class 1259 OID 3605477)
-- Name: ix_deviceevent_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_deviceevent_syscosmosts_brin ON fact.deviceevent USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6193 (class 1259 OID 3617347)
-- Name: ix_transactionheader_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_transactionheader_syscosmosts_brin ON fact.transactionheader USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6202 (class 1259 OID 3617344)
-- Name: ix_userbehaviour_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_userbehaviour_syscosmosts_brin ON fact.userbehaviour USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6285 (class 1259 OID 676696)
-- Name: locationid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS locationid_idx ON fact.vw_offer_analysis USING btree (locationid);


--
-- TOC entry 6261 (class 1259 OID 413969)
-- Name: peripheralhealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE INDEX IF NOT EXISTS peripheralhealth_idx ON fact.peripheralhealth USING btree (healthdataid, peripheralid) INCLUDE (peripheraltype, status);


--
-- TOC entry 6189 (class 1259 OID 32964)
-- Name: peripheralstate_uidx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE UNIQUE INDEX peripheralstate_uidx ON fact.peripheralstate USING btree (deviceid, peripheralid, state, statestart);


--
-- TOC entry 6194 (class 1259 OID 263880)
-- Name: transactionheader_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 6184 (class 1259 OID 263867)
-- Name: transactionheaderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);


--
-- TOC entry 6201 (class 1259 OID 33003)
-- Name: transactionpaymentuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);


--
-- TOC entry 6203 (class 1259 OID 263900)
-- Name: userbehaviour_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);


--
-- TOC entry 6335 (class 1259 OID 3050933)
-- Name: ix_ml_imm_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_imm_locationid ON ml.item_modifiergroup_modifier_mapping USING btree (locationid);


--
-- TOC entry 6330 (class 1259 OID 3044539)
-- Name: ix_ml_me_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_me_locationid ON ml.menu_entities USING btree (locationid);


--
-- TOC entry 6331 (class 1259 OID 3044540)
-- Name: ix_ml_me_menuitemid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_me_menuitemid ON ml.menu_entities USING btree (menuitemid);


--
-- TOC entry 6333 (class 1259 OID 3050934)
-- Name: ix_ml_mi_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww ON ml.modifier_interactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6334 (class 1259 OID 3050935)
-- Name: ix_ml_mimp_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_mimp_locid_yyyy_ww ON ml.modifier_impressions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6332 (class 1259 OID 3050806)
-- Name: ix_ml_trx_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_trx_locid_yyyy_ww ON ml.transactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6323 (class 1259 OID 3042200)
-- Name: ix_ml_ua_businessdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_businessdate ON ml.upsell_analysis USING btree (businessdate);


--
-- TOC entry 6324 (class 1259 OID 3042199)
-- Name: ix_ml_ua_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_locid_yyyy_ww ON ml.upsell_analysis USING btree (locationid, yyyy, ww);


--
-- TOC entry 6325 (class 1259 OID 3042198)
-- Name: ix_ml_ua_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_yyyy_ww ON ml.upsell_analysis USING btree (yyyy, ww);


--
-- TOC entry 6326 (class 1259 OID 3044148)
-- Name: ix_ml_wth_locationid_weatherdate_hh; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_locationid_weatherdate_hh ON ml.weather USING btree (locationid, weatherdate, hh);


--
-- TOC entry 6327 (class 1259 OID 3042228)
-- Name: ix_ml_wth_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_locid_yyyy_ww ON ml.weather USING btree (locationid, yyyy, ww);


--
-- TOC entry 6328 (class 1259 OID 3042229)
-- Name: ix_ml_wth_weatherdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_weatherdate ON ml.weather USING btree (weatherdate);


--
-- TOC entry 6329 (class 1259 OID 3042227)
-- Name: ix_ml_wth_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_yyyy_ww ON ml.weather USING btree (yyyy, ww);


--
-- TOC entry 6344 (class 1259 OID 3605478)
-- Name: ix_silver_kiosk_events_syscosmosts_brin; Type: INDEX; Schema: stg; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin ON stg.silver_kiosk_events USING brin (syscosmosts) WITH (pages_per_range='128');

-- New indexes from schema evolution file
CREATE INDEX IF NOT EXISTS idx_fact_transactionitem_locationid
    ON fact.transactionitem(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_transactionpayment_locationid
    ON fact.transactionpayment(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid
    ON fact.itemmodifier(locationid);
CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid
    ON dim.menuitem(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid
    ON dim.modifier(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid
    ON dim.modifier_group(catalogid);



--
-- TOC entry 6384 (class 2606 OID 3327449)
-- Name: vw_grubbrrinstallbase_all_devices organizationid_locationid_fk; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--
/*
ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT organizationid_locationid_fk FOREIGN KEY (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6379 (class 2606 OID 413647)
-- Name: peripheral peripheral_deviceid_fkey; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);


--
-- TOC entry 6367 (class 2606 OID 514947)
-- Name: transactionitem categoryid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);


--
-- TOC entry 6372 (class 2606 OID 788239)
-- Name: devicetelemetry location_deviceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);


--
-- TOC entry 6381 (class 2606 OID 775338)
-- Name: recommendations location_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6373 (class 2606 OID 788249)
-- Name: devicetelemetry locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6364 (class 2606 OID 775954)
-- Name: transactionheader locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6368 (class 2606 OID 779636)
-- Name: transactionitem locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6374 (class 2606 OID 784801)
-- Name: itemssurvey locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6376 (class 2606 OID 784796)
-- Name: occasionsurveydetail locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6369 (class 2606 OID 2970909)
-- Name: transactionitem locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6371 (class 2606 OID 775974)
-- Name: transactionpayment locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionpayment
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6382 (class 2606 OID 775984)
-- Name: vw_offer_analysis locationid_trxnid_recommendationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6370 (class 2606 OID 359444)
-- Name: transactionitem menuitemid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);


--
-- TOC entry 6365 (class 2606 OID 775964)
-- Name: transactionheader ordertype_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);


--
-- TOC entry 6363 (class 2606 OID 788254)
-- Name: deviceevent orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.deviceevent
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6375 (class 2606 OID 788219)
-- Name: itemssurvey orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6377 (class 2606 OID 788224)
-- Name: occasionsurveydetail orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6380 (class 2606 OID 413964)
-- Name: peripheralhealth peripheralhealth_healthdataid_fkey; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_fkey FOREIGN KEY (healthdataid) REFERENCES fact.devicehealth(id);


--
-- TOC entry 6383 (class 2606 OID 779648)
-- Name: vw_offer_analysis selecteditem_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid);


--
-- TOC entry 6378 (class 2606 OID 774836)
-- Name: occasionsurveydetail sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6366 (class 2606 OID 787892)
-- Name: transactionheader sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);

*/

-- TOC entry 6559 (class 0 OID 0)
-- Dependencies: 64
-- Name: SCHEMA dim; Type: ACL; Schema: -; Owner: citus
--


/*
GRANT USAGE ON SCHEMA dim TO dhanraj;
GRANT USAGE ON SCHEMA dim TO varshil;


--
-- TOC entry 6560 (class 0 OID 0)
-- Dependencies: 65
-- Name: SCHEMA fact; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA fact TO dhanraj;
GRANT USAGE ON SCHEMA fact TO varshil;


--
-- TOC entry 6562 (class 0 OID 0)
-- Dependencies: 62
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO citus WITH GRANT OPTION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO varshil;
RESET SESSION AUTHORIZATION;




--
-- TOC entry 6571 (class 0 OID 0)
-- Dependencies: 410
-- Name: TABLE abtests; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.abtests TO varshil;


--
-- TOC entry 6572 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE datedim; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.datedim TO dhanraj;
GRANT SELECT ON TABLE dim.datedim TO varshil;


--
-- TOC entry 6573 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE businessdate; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.businessdate TO dhanraj;
GRANT SELECT ON TABLE dim.businessdate TO varshil;


--
-- TOC entry 6574 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE company; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.company TO dhanraj;
GRANT SELECT ON TABLE dim.company TO varshil;


--
-- TOC entry 6575 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE device; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.device TO varshil;


--
-- TOC entry 6576 (class 0 OID 0)
-- Dependencies: 380
-- Name: TABLE element; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.element TO dhanraj;
GRANT SELECT ON TABLE dim.element TO varshil;


--
-- TOC entry 6577 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE experiment; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.experiment TO varshil;


--
-- TOC entry 6579 (class 0 OID 0)
-- Dependencies: 404
-- Name: TABLE feedbackrating; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackrating TO varshil;


--
-- TOC entry 6580 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE feedbackstatus; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;


--
-- TOC entry 6581 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE frequentcustomer; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;


--
-- TOC entry 6582 (class 0 OID 0)
-- Dependencies: 438
-- Name: TABLE grubbrr_source_lookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;


--
-- TOC entry 6583 (class 0 OID 0)
-- Dependencies: 381
-- Name: TABLE itemcategory; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory TO dhanraj;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;


--
-- TOC entry 6584 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE itemcategory_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;


--
-- TOC entry 6585 (class 0 OID 0)
-- Dependencies: 432
-- Name: TABLE itemcategorymapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;


--
-- TOC entry 6586 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE kiosk; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kiosk TO varshil;


--
-- TOC entry 6587 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE kioskdetails; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kioskdetails TO varshil;


--
-- TOC entry 6588 (class 0 OID 0)
-- Dependencies: 382
-- Name: TABLE location; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.location TO dhanraj;
GRANT SELECT ON TABLE dim.location TO varshil;


--
-- TOC entry 6589 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE locationcatalog; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.locationcatalog TO varshil;


--
-- TOC entry 6590 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE menuentities; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuentities TO varshil;


--
-- TOC entry 6591 (class 0 OID 0)
-- Dependencies: 413
-- Name: TABLE menuitem; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem TO varshil;


--
-- TOC entry 6592 (class 0 OID 0)
-- Dependencies: 383
-- Name: TABLE ordertype; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype TO dhanraj;
GRANT SELECT ON TABLE dim.ordertype TO varshil;


--
-- TOC entry 6593 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE ordertype_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;


--
-- TOC entry 6594 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE organization; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organization TO varshil;


--
-- TOC entry 6595 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE organizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;


--
-- TOC entry 6596 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE peripheral; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.peripheral TO varshil;


--
-- TOC entry 6597 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE upsellgrouplookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;


--
-- TOC entry 6598 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE userlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.userlocation TO varshil;


--
-- TOC entry 6599 (class 0 OID 0)
-- Dependencies: 385
-- Name: TABLE view; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.view TO dhanraj;
GRANT SELECT ON TABLE dim.view TO varshil;


--
-- TOC entry 6600 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE weather; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather TO varshil;


--
-- TOC entry 6601 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE vw_weatherhourlydata; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;


--
-- TOC entry 6602 (class 0 OID 0)
-- Dependencies: 387
-- Name: TABLE vworganizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vworganizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;


--
-- TOC entry 6603 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE weather_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather_bkp TO varshil;


--
-- TOC entry 6604 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE cep_incidents; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.cep_incidents TO dhanraj;


--
-- TOC entry 6605 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE customer_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;


--
-- TOC entry 6606 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE deviceevent; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.deviceevent TO dhanraj;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;


--
-- TOC entry 6607 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE devicehealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicehealth TO varshil;


--
-- TOC entry 6608 (class 0 OID 0)
-- Dependencies: 389
-- Name: TABLE devicestate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicestate TO dhanraj;
GRANT SELECT ON TABLE fact.devicestate TO varshil;


--
-- TOC entry 6609 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE devicetelemetry; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;


--
-- TOC entry 6610 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE itemmodifier; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemmodifier TO dhanraj;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;


--
-- TOC entry 6611 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE itemssurvey; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemssurvey TO varshil;


--
-- TOC entry 6612 (class 0 OID 0)
-- Dependencies: 436
-- Name: TABLE location_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;


--
-- TOC entry 6613 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE occasionsurveydetail; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;


--
-- TOC entry 6614 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE ordertiming; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.ordertiming TO dhanraj;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;


--
-- TOC entry 6615 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE peripheralhealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralhealth TO varshil;


--
-- TOC entry 6616 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE peripheralstate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralstate TO dhanraj;
GRANT SELECT ON TABLE fact.peripheralstate TO varshil;


--
-- TOC entry 6617 (class 0 OID 0)
-- Dependencies: 393
-- Name: TABLE pipelinerunstatus; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pipelinerunstatus TO dhanraj;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;


--
-- TOC entry 6618 (class 0 OID 0)
-- Dependencies: 424
-- Name: TABLE recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations TO varshil;


--
-- TOC entry 6619 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE recommendations_bkp; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations_bkp TO varshil;


--
-- TOC entry 6620 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE timingsdatalake; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.timingsdatalake TO dhanraj;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;


--
-- TOC entry 6621 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE transactionheader; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;


--
-- TOC entry 6622 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE transactionitem; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;


--
-- TOC entry 6623 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE transactionpayment; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;


--
-- TOC entry 6624 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE transactionrefunds; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;


--
-- TOC entry 6625 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE userbehaviour; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour TO dhanraj;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;


--
-- TOC entry 6626 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE userbehaviour_exceptions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour_exceptions TO varshil;


--
-- TOC entry 6627 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE usercheckedin; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.usercheckedin TO varshil;


--
-- TOC entry 6628 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE vw_offer_analysis; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;


--
-- TOC entry 6629 (class 0 OID 0)
-- Dependencies: 399
-- Name: TABLE watermarktable; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.watermarktable TO dhanraj;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;


--
-- TOC entry 6630 (class 0 OID 0)
-- Dependencies: 463
-- Name: TABLE modifier_interactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;




-- Completed on 2026-05-30 14:14:07

--
-- PostgreSQL database dump complete
--

\unrestrict VFfQD00ditWwDSVTzvrOfGRggS3PfSQDVme4BEMRffIDxSUJxEDWUYHdIpBBv5N
*/
