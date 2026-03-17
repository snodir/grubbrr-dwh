select count(*) from fact.transactionitem   --46,059 --50,963 --66,744
select count(*) from fact.transactionheader --35,048 --39,082 --48,288
select count(*) from fact.itemmodifier --136,204
select count(*) from fact.ordertiming --0
select count(*) from fact.userbehaviour --656  --878
select count(*) from fact.devicetelemetry --402,993  --1,203,775
select count(*) from fact.deviceevent --386,043  --724,863
select count(*) from fact.devicestate --15,641  --19,367
select count(*) from fact.watermarktable --3
select count(*) from dim.company  --13 --17
select count(*) from dim.location --31 --50
select count(*) from dim.ordertype --49 --52
select count(*) from dim.itemcategory --103 --109
select count(*) from dim.menuitem --901
select count(*) from dim.organizationlocation --154
select count(*) from dim.datedim
select * from fact.pipelinerunstatus

select * 
from fact.devicestate
where dateid is not null
order by dateid desc

select * from dim.element

select * from fact.watermarktable

select * 
from dim.datedim 
where dayval= '2024-10-01'