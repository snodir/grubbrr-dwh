select * from dim.occasionsurvey;
select * from fact.occasionsurveydetail;

select *-- locationid, surveytransid, orderid, itemid, count(*) --* 
from fact.itemssurvey


select --ol.organizationid, 
       mi.* 
from dim.menuitem as mi 
left join (select distinct organizationid, locationid from dim.organizationlocation where organizationtype = 0) as ol
on ol.locationid = mi.locationid

select distinct itemssurvey.surveytransstatus from fact.itemssurvey
