create or replace force view logger_logs_60_min as
	select * 
      from logger_logs 
	 where time_stamp > systimestamp - (1/24)
/
