select *-- to_char(orderdatelocal, 'YYYYMMDDHH24') as dateid2, 
from fact.transactionheader 
where 1=1
and orderstatus <> 'order-placed' 
--and (orderdatelocal is null or dateid is null or businessdate is null) 
order by orderdatelocal desc
limit 10

select * from fact.transactionheader where transactionheaderid = 'abort-638738985311500953'
select distinct orderstatus from fact.transactionheader
select max(id), count(*) 
from fact.transactionheader --35,530T	35,574T --41,456S	41,580S --173,083P	174,358P

/*update fact.transactionheader
set dateid = cast(to_char(orderdatelocal, 'YYYYMMDDHH24') as integer)
where dateid is null;
*/

select distinct to_char('2025-01-31T11:44:10.325', 'YYYYMMDDHH24') as dateid 
from fact.transactionheader