drop package logger
/

drop procedure logger_configure
/

drop table logger_logs_apex_items cascade constraints
/

drop table logger_prefs cascade constraints
/

drop table logger_logs cascade constraints
/

drop sequence logger_logs_seq
/

drop sequence logger_apx_items_seq
/

begin
	dbms_scheduler.drop_job('LOGGER_PURGE_JOB');
end;
/

drop view logger_logs_5_min
/

drop view logger_logs_60_min
/

drop view logger_logs_terse
/

