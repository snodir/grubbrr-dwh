--select * from fact.recommendations where selecteditems :: text like '%modifier%';

SELECT md.*
from fact.itemmodifier as md 
INNER JOIN fact.transactionitem as ti 
        ON md.transactionheaderid = ti.transactionheaderid
       AND md.itemid = ti.itemid
WHERE 1=1 --and ti.upselllevel is not null
  --AND ti.transactionheaderid = 'ordevt-zwkqwa5atz'
ORDER BY ti.orderdateutc desc
LIMIT 100

SELECT * 
FROM fact.transactionitem as ti
WHERE 1=1 --and ti.upselllevel is not null
  --AND ti.transactionheaderid = 'ordevt-zwkqwa5atz'
LIMIT 100


ALTER TABLE fact.itemmodifier
--add sysinserttime TIMESTAMP, 
add sysupdatetime TIMESTAMP

