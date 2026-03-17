--drop table if EXISTS dim.weather;
create table if not EXISTS dim.weather(--_bkp(
organizationid text COLLATE pg_catalog."default",
locationid text COLLATE pg_catalog."default",
city text COLLATE pg_catalog."default",
timezone text COLLATE pg_catalog."default",
locationinfo jsonb,
historyapicalldate date,
historyweatherinfo jsonb,
currentapicalldate date,
currentweatherinfo jsonb,
futureapicalldate date,
futureweatherinfo jsonb,
sysinserttime timestamp,
sysupdatetime timestamp
);

alter table dim.weather
OWNER to citus;

alter table dim.weather
add CONSTRAINT location_city_date_uidx UNIQUE (locationid, city, historyapicalldate);


--insert into dim.weather(organizationid, locationid, city, timezone, 
historyapicalldate, locationinfo, historyweatherinfo, sysinserttime, sysupdatetime)
select *
from dim.weather--_bkp --
limit 10


--insert into dim.weather(organizationid, locationid, city, 
--timezone, apicalldate, weatherinfo, sysinserttime, sysupdatetime)
select * from dim.weather
where 1=1
--and historyweatherinfo is not null
and weatherinfo :: text like '{"Date":%'
--and apicalldate BETWEEN '2025-06-01' and '2025-06-05'
--and locationid in ('loc-05e17610-0d89-4a3b-8bf8-a27510f7213f')
order by apicalldate desc
limit 1000;

select * from dim.organization 
where 1=1
and organizationtype = 5
and latitude is not null and longitude is not null

SELECT w.locationid,
  (w.weatherinfo->>'Date')::date            AS date,
  (hour_entry.hour_data->>'Hour')::int    AS hour,
  (hour_entry.hour_data->>'Humidity')::int AS humidity,
  (hour_entry.hour_data->>'Condition')     AS condition,
  (hour_entry.hour_data->>'TemperatureInCelcius')::numeric AS temperature_c
FROM
  dim.weather as w
  -- unpack "Hours" into key/value pairs
  CROSS JOIN LATERAL jsonb_each(weatherinfo->'Hours') AS hour_entry(hour_key, hour_data)  
WHERE w.weatherinfo :: text like '{"Date":%'
ORDER BY
  date, hour
LIMIT 1000;

select * from dim.location;

select *-- distinct concat(l.city, ' ', coalesce(l.state, '')) as city 
from dim.location as l
where 1=1
and l.locationname = 'Excalibur'
and l.state = 'Florida'
and l.city in ('West Palm Beach','Tampa','Fort Lauderdale');


--insert into dim.weather(organizationid,locationid,city,timezone,businessdate,sysinserttime)
select distinct companyid, locationid, city, 
concat(city, ' ', coalesce(o.state, '')) as city,
timezone, (current_date - 2 * INTERVAL '2 day') :: date as businessdate, 
now() as sysinserttime
from dim.location
where concat(city, ' ', coalesce(o.state, '')) in (
select DISTINCT city from dim.weather where weatherinfo is not null
)



select distinct concat(city, ' ', coalesce(state, ''), ' ', 'United States') as city 
from dim.location 
where 1=1
--and o.state = 'Arizona'
--and city in ('West Palm Beach Florida','Tampa Florida','Fort Lauderdale Florida')
and locationid in ('loc-d60c9341-3aa1-4d8d-a44f-1840d257111b',
                   'loc-41cca490-a602-459f-8868-e55c80b105ac',
                   'loc-38170088-1b4b-4b2d-941c-bb462cc576b1');

select ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname,
       count(1) as ordercounts, sum(ordertotal) as amtspent, avg(ordertotal) as avg_amtspent
from fact.transactionheader as th
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on th.locationid = ol.locationid
where 1=1
and th.orderstatus = 'order-placed'
and th.businessdate BETWEEN '2025-01-01' and CURRENT_DATE :: date--'2025-07-13' --
group by ol.organizationId, ol.organizationname, th.locationid, ol.locationname
order by count(1) desc

/*Sample Prod data
org-0281beee-a2f2-46fb-ac88-cc20df85fbfc	BurgerFi
org-21b9c258-ad27-4aab-8663-4d480c235950	Pizza Hut
org-d7a82a2f-b933-4459-8a1e-91a605df80f7	Mr. Pickles Sandwich Shop
org-ug5zsn9mpq	                     Einstein Bros. Bagels
loc-x4pw1awq97	                     Excalibur
loc-f5apk9hxfi	                     Circus Circus
loc-6e6a1e38-f495-417a-95a0-cc9a1dd1a88a	Pasadena
loc-273ffa25-f0d2-48e5-befa-47f0934f3baa	Mead 241 Welker Rd
*/


insert into dim.weather(organizationid,locationid,city,timezone,apicalldate,sysinserttime)
select distinct 
       companyid, 
       locationid, 
       concat(city, ' ', coalesce(o.state, '')) as city,
       timezone, 
       (current_date - 4 * INTERVAL '1 day') :: date as apicalldate, 
       now() as sysinserttime
from dim.location
where (current_date - 5 * INTERVAL '1 day') :: date = (select max(apicalldate) from dim.weather);

select 1 as rn;

select distinct concat(city, ' ', coalesce(o.state, '')) as city 
from dim.location 
where 1=1
and o.state = 'Florida'
and city in ('West Palm Beach','Tampa','Fort Lauderdale');


@concat('update dim.weather set locationinfo = ''', replace(string(activity('Get HistoryWeatherInfo').output.location), '\',''), ''' :: jsonb, 
historyweatherinfo = ''', replace(string(activity('Get HistoryWeatherInfo').output.forecast.forecastday[0]), '\',''), ''' :: jsonb,
currentweatherinfo = ''', replace(string(activity('Get CurrentWeatherInfo').output.forecast.forecastday[0]), '\',''), ''' :: jsonb,
futureweatherinfo = ''', replace(string(activity('Get FutureWeatherInfo').output.forecast.forecastday[0]), '\',''), ''' :: jsonb,
timezone = coalesce(timezone, ''', activity('Get HistoryWeatherInfo').output.location.tz_id, '''), 
sysupdatetime = now() 
where city = ''', variables('v_city'), ''' and historyapicalldate = (current_date - ', string(pipeline().parameters.p_days_to_add), 
' * INTERVAL ''1 day'') :: date; select 1 as rn;')

SELECT * from dim.organization
where isdeleted = False and active = True
and organizationtype = 5

select *-- distinct concat(city, ' ', coalesce(o.state, '')) as city 
from dim.location;

delete from dim.weather
where locationid not in (select locationid from fact.transactionheader where orderstatus = 'order-placed');

SELECT distinct concat(o.city, ' ', 
                       coalesce(case when o.state = 'FL' then 'Florida' 
                                     when o.state = 'NY' then 'New York'
                                     when o.state = 'NV' then 'Nevada' else o.state end, ''), ' ', 
                       coalesce(o.country, '')) as city/*,
       l.companyid,
       l.locationid,
       o.name*/
from dim.organization as o
inner join dim.location as l
        on o.id = l.locationid
where 1=1
and o.isdeleted = False and o.active = True
and o.organizationtype = 5
and o.id in (select locationid from fact.transactionheader where orderstatus = 'order-placed');

select distinct dt.yearval, dt.weekval
from dim.datedim as dt
where 1=1
and dt.dayval >= '2025-01-01' and dt.dayval <= cast(now() as date)
order by yearval, weekval
LIMIT 10

select CURRENT_DATE :: date


select ol.organizationname, 
       ol.locationname,
       --count(1) as ordercounts, sum(ordertotal) as amtspent, avg(ordertotal) as avg_amtspent
       th.orderdatelocal,
       th.businessdate,
       th.orderid,
       th.orderdiscount,
       
from fact.transactionheader as th
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on th.locationid = ol.locationid
where 1=1
and th.orderstatus = 'order-placed'
and th.businessdate BETWEEN '2025-07-12' and '2025-07-13' --CURRENT_DATE
group by ol.organizationId, ol.organizationname--, th.locationid, ol.locationname
order by count(1) desc
