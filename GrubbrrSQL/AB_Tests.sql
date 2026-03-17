drop table if EXISTS dim.ABTests;
create table dim.ABTests (
ABTestID BIGINT NOT NULL,
OrganizationID text COLLATE pg_catalog."default",
LocationID text COLLATE pg_catalog."default",
ExperimentID text COLLATE pg_catalog."default",
ExperimentName text COLLATE pg_catalog."default",
VariantID text COLLATE pg_catalog."default",
VariantName text COLLATE pg_catalog."default",
OrderSessionID text COLLATE pg_catalog."default",
DeviceID text COLLATE pg_catalog."default",
DeviceName text COLLATE pg_catalog."default",
syscosmosts bigint,
sysinserttime TIMESTAMP
);

select * from dim.ABTests;
select coalesce(max(ABTestID), 0) as maxID from dim.ABTests



select ab.*, th.*
from dim.ABTests as ab
left join fact.transactionheader as th
on th.ordersessionid = ab.ordersessionid or th.ABTestID = ab.ABTestID;

--alter table fact.transactionheader
--add frequentcustomerid text
--add ABTestID bigint
add channel text

update fact.transactionheader
set ABTestID = ABTests.ABTestID
from dim.ABTests
where ABTests.OrderSessionID = transactionheader.ordersessionid
and transactionheader.ABTestID is null;

update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
where orderdatelocal is null;

select 1 as rn;