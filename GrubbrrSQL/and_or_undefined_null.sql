SELECT 
    CASE WHEN NULL IS NULL THEN 'True, NULL is really NULL' END null_is_null,
    CASE WHEN NULL IS NOT NULL THEN 'True, NULL is really NOT NULL' WHEN NULL IS NULL THEN 'False, NULL is actually NULL' END null_is_not_null,
    CASE WHEN NULL = NULL THEN 'True, NULL = NULL' WHEN NULL <> NULL THEN 'False, NULL <> NULL' END null_equal_null,
    CASE WHEN NULL <> NULL THEN 'True, NULL <> NULL' WHEN NULL = NULL THEN 'False, NULL = NULL' END null_not_equal_null;

SELECT NULL IS NULL null_is_null,
       NULL IS NOT NULL null_is_not_null,
       NULL = NULL null_equal_null,
       NULL <> NULL null_not_equal_null;


SELECT 
    '/orders/transactionpayment/date=2026-05-08/hour=20/' < '/orders/transactionpayment/date=2026-05-08/hour=21/' as hour_comparison,
    '/orders/transactionpayment/date=2026-05-09/hour=20/' > '/orders/transactionpayment/date=2026-05-08/hour=20/' as day_comparison,
    '/orders/transactionpayment/date=2026-06-08/hour=20/' > '/orders/transactionpayment/date=2026-05-08/hour=20/' as month_comparison,
    '/orders/transactionpayment/date=2027-05-08/hour=20/' > '/orders/transactionpayment/date=2026-05-08/hour=20/' as year_comparison;


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
