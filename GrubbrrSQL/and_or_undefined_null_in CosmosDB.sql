select count(1) from c --320,859
select * from c order by c._ts desc

select count(1) from c where c.isTestOrder <> true --820
select * from c where c.isTestOrder <> true order by c._ts desc

select count(1) from c where c.isTestOrder = false --820
select * from c where c.isTestOrder = false order by c._ts desc

select count(1) from c where c.isTestOrder = true --332
select * from c where c.isTestOrder = true order by c._ts desc
select distinct c.orderId from c where c.isTestOrder = true and (c.orderDate like '2025-01-16%' or c.orderDate like '2025-01-17%') order by c._ts desc

select count(1) from c where is_defined(c.isTestOrder) = true --820 + 332 = 1,152
select * from c where is_defined(c.isTestOrder) = true order by c._ts desc

select count(1) from c where is_defined(c.isTestOrder) = false --319,707
select * from c where is_defined(c.isTestOrder) = false order by c._ts desc

select count(1) from c where c.isTestOrder = false or is_defined(c.isTestOrder) = false -- 320,859 - 332 = 320,527
select * from c where c.isTestOrder = false or is_defined(c.isTestOrder) = false order by c._ts desc

select count(1) from c 
where 1=1
and (c.isTestOrder = false or is_defined(c.isTestOrder) = false)
order by c._ts desc
