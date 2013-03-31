set termout off
-- setting termout off as this view will install with an error as it depends on logger.date_text_format
create or replace force view logger_logs_terse as
 select id, logger_level, 
        substr(logger.date_text_format(time_stamp),1,20) time_ago,
        substr(text,1,200) text
   from logger_logs
  where time_stamp > systimestamp - (5/1440)
  order by id asc
/

set termout on
