    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (
            SELECT * FROM dim.organizationlocation
            WHERE CASE WHEN 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'
              AND organizationtype = 0 
        ) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    )
    SELECT count(*) as row_count, 'menuitem' as  table_name FROM dim.menuitem WHERE catalogid IN (SELECT catalogid FROM org_loc_ctlg) --LIMIT 100 --10,978   
    UNION ALL
    SELECT count(*), 'modifier' FROM dim.modifier WHERE catalogid IN (SELECT catalogid FROM org_loc_ctlg) --LIMIT 100 --10,978   
    UNION ALL
    SELECT count(*), 'item_modifier_group_modifier_mapping' FROM dim.item_modifier_group_modifier_mapping WHERE catalogid IN (SELECT catalogid FROM org_loc_ctlg)-- LIMIT 100 --10,978   
    UNION ALL
    SELECT count(*), 'modifier_group' FROM dim.modifier_group WHERE catalogid IN (SELECT catalogid FROM org_loc_ctlg) --LIMIT 100 --10,978   

/* Bojangles
10978	menuitem
37586	modifier
90402	item_modifier_group_modifier_mapping
16911	modifier_group
*/

ALTER TABLE IF EXISTS dim.menuitem
ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);

CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid
    ON dim.menuitem(catalogid);

CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid
    ON dim.modifier(catalogid);

CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid
    ON dim.modifier_group(catalogid);

SELECT count(*), 'modifier_group' FROM dim.modifier_group;