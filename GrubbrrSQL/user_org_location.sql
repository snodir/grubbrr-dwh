--c-cosmospostgresql-gou-service-test-eastus.wx2cpvfecws536.postgres.cosmos.azure.com
select userid, locationid, count(*) as dupl
from public.vw_userlocation
group by userid, locationid
HAVING count(*)>1

select distinct userid, locationid from public.vw_userlocation;
order by userid desc limit 100

select * from dim.userlocation