SELECT ol.name, fc.frequentcustomerid, fc.firstname, fc.lastname, fc.source, fc.ordercount, fc.amountspent,
       fc.amountspent / case when fc.ordercount > 0 then fc.ordercount else 1 end as avg_amount_spent_per_order
FROM dim.frequentcustomer as fc
inner join dim.organization as ol 
        on fc.organizationid = ol.id
--group by ol.id, ol.name
ORDER BY fc.ordercount desc;


select ol.id, 
       ol.name, 
       --count(fc.frequentcustomerid) as total_freq_customers,
       sum(case when fc.ordercount > 0 then 1 else 0 end) as active_freq_customers,
       --sum(case when fc.ordercount is null or fc.ordercount = 0 then 1 else 0 end) as inactive_freq_customers,
       sum(fc.ordercount) as orders_placed_by_freq_customers,
       sum(fc.amountspent) as amount_spent_by_freq_customers,
       sum(fc.amountspent) / case when sum(fc.ordercount) > 0 then sum(fc.ordercount) else 1 end as avg_amount_spent_by_freq_customers
from dim.frequentcustomer as fc 
inner join dim.organization as ol 
        on fc.organizationid = ol.id
group by ol.id, ol.name
order by active_freq_customers desc, 
         orders_placed_by_freq_customers desc, 
         amount_spent_by_freq_customers desc;--createddate desc-- customerkey-- syscosmosts desc-- customerkey desc, 

SELECT --lmp.organizationid, lmp.locationid,
       ol.organizationname, ol.locationname,
       lmp.day_parts,
       lmp.itemid,
       mi.menuitemname,
       lmp.itemtype,
       lmp.item_selection_frequency,
       lmp.itemtags,
       lmp.sysinserttime
FROM fact.location_menu_preferences as lmp 
INNER JOIN dim.menuitem as mi 
        ON lmp.itemid = mi.menuitemid
LEFT JOIN (SELECT * FROM dim.organizationlocation as ol WHERE ol.organizationtype = 0) as ol 
       ON lmp.organizationid = ol.organizationid
      AND lmp.locationid = ol.locationid
ORDER BY lmp.item_selection_frequency desc
LIMIT 1000;



SELECT ol.organizationname, ol.locationname, 
       cmp.frequentcustomerid, cmp.day_parts, 
       cmp.itemid, mi.menuitemname, cmp.itemtype, 
       cmp.item_selection_frequency
FROM fact.customer_menu_preferences as cmp
LEFT JOIN dim.menuitem as mi 
       ON cmp.itemid = mi.menuitemid
LEFT JOIN (SELECT * FROM dim.organizationlocation as ol WHERE ol.organizationtype = 0) as ol 
       ON cmp.organizationid = ol.organizationid
      AND cmp.locationid = ol.locationid
ORDER BY frequentcustomerid, cmp.day_parts, item_selection_frequency desc
LIMIT 1000;

SELECT ol.organizationname, ol.locationname, 
       th.transactionheaderid, ti.

FROM fact.transactionheader as th 
INNER JOIN fact.transactionitem as ti 
        ON th.locationid = ti.locationid 
       AND th.transactionheaderid = ti.transactionheaderid
LEFT JOIN (SELECT * FROM dim.organizationlocation as ol WHERE ol.organizationtype = 0) as ol 
        ON th.locationid = ol.locationid
WHERE th.orderstatus = 'order-placed'

ORDER BY 

SELECT * FROM dim.weather WHERE weather.apicalldate is not null ORDER BY apicalldate DESC LIMIT 1000