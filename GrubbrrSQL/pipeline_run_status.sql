CREATE TABLE IF NOT EXISTS fact.pipelinerunstatus
(
    pipelinename text COLLATE pg_catalog."default" NOT NULL,
    pipelinerunid character varying(100) COLLATE pg_catalog."default" NOT NULL,
    pipelinetriggertime timestamp without time zone NOT NULL,
    issuccess boolean,
    pipelinecompletedtime timestamp without time zone,
    correlationid character varying(100) COLLATE pg_catalog."default",
    pipelinestatus character varying(50) COLLATE pg_catalog."default",
    pipelinemessage text COLLATE pg_catalog."default",
    triggeredbyuserid character varying(100) COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE fact.pipelinerunstatus
    OWNER to citus;

-- Index: fact.idx_fact_pipelinerunstatus_correlationid
CREATE INDEX IF NOT EXISTS idx_fact_pipelinerunstatus_correlationid
    ON fact.pipelinerunstatus USING btree
    (correlationid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(pipelinestatus)
    TABLESPACE pg_default;

select * from fact.pipelinerunstatus;



--UPDATE fact.pipelinerunstatus 
SET pipelinerunid = case when correlationid is null then '@{pipeline().RunId}' else pipelinerunid end, 
    pipelinetriggertime = case when correlationid is null then '@{pipeline().TriggerTime}' else pipelinetriggertime end,
    triggeredbyuserid = case when correlationid is null then '@{pipeline().DataFactory}' else triggeredbyuserid end,
    pipelinecompletedtime = case when correlationid is null or pipelinecompletedtime is null then  '@{convertFromUtc(utcNow(),'Eastern Standard Time')}' else pipelinecompletedtime end,
    pipelinestatus = case when correlationid is null or pipelinestatus is null then 'Completed' else pipelinestatus end,
    issuccess = case when correlationid is null or issuccess is null then true else issuccess end
WHERE pipelinename = '@{pipeline().Pipeline}'
and correlationid is null;

--UPDATE
    fact.pipelinerunstatus 
SET
    issuccess = true,
    pipelinestatus = 'Completed',
    pipelinecompletedtime = CURRENT_TIMESTAMP
WHERE
    pipelinerunid = '@{pipeline().RunId}'
and correlationid is not null;

Select 0 as DummyValue

select * from fact.pipelinerunstatus where correlationid is null

--update fact.pipelinerunstatus
set pipelinemessage = null
where 1=1
--and pipelinename = 'AbortedItemsToPG'
and pipelinestatus = 'Completed'
and pipelinemessage is not null
and correlationid is null

update fact.pipelinerunstatus
set pipelinename = 'CopyGOUViewsToGAS'
where pipelinename = 'CopyGOUViewToGASNEW'

--delete from fact.pipelinerunstatus
--where pipelinerunid = 'adf_run_id2'

select * from fact.pipelinerunstatus

/*insert into fact.pipelinerunstatus(pipelinename, pipelinerunid, pipelinetriggertime)
values('UpdateFieldsInTrxnFactTables', 'adf_run_id1', '1900-01-01'),
      ('DimensionsFactsMaster', 'adf_run_id2', '1900-01-01')*/



--UPDATE fact.pipelinerunstatus 
SET pipelinerunid = '@{pipeline().RunId}', 
    pipelinetriggertime = '@{pipeline().TriggerTime}',
    pipelinecompletedtime = '@{variables('v_finishtime')}',
    pipelinestatus = 'Completed',
    triggeredbyuserid = '@{pipeline().DataFactory}',
    issuccess = true
WHERE pipelinename = '@{pipeline().Pipeline}'
and correlationid is null;

--UPDATE
    fact.pipelinerunstatus 
SET
    issuccess = true,
    pipelinestatus = 'Completed',
    pipelinecompletedtime = '@{variables('v_finishtime')}'
WHERE
    pipelinerunid = '@{pipeline().RunId}'
and correlationid is not null;

Select 0 as DummyValue