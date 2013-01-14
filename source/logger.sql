whenever sqlerror exit
set serveroutput on


declare
    type t_sess_privs is table of pls_integer index by varchar2(50);
    l_sess_privs t_sess_privs;
    l_req_privs t_sess_privs;
    l_priv  varchar2(50);
    l_dummy pls_integer;
    l_priv_error  boolean := false;
begin
    l_req_privs('CREATE SESSION')       := 1;            
    l_req_privs('CREATE TABLE')         := 1;
    l_req_privs('CREATE VIEW')          := 1;
    l_req_privs('CREATE SEQUENCE')      := 1;
    l_req_privs('CREATE PROCEDURE')     := 1;
    l_req_privs('CREATE TRIGGER')       := 1;
    l_req_privs('CREATE ANY CONTEXT')   := 1;
    l_req_privs('CREATE JOB')           := 1;


    for c1 in (select privilege from session_privs)
    loop
        l_sess_privs(c1.privilege) := 1;
    end loop;  --c1

    dbms_output.put_line('_____________________________________________________________________________');
    
    l_priv := l_req_privs.first;
    loop
    exit when l_priv is null;
        begin
            l_dummy := l_sess_privs(l_priv);
        exception when no_data_found then
            dbms_output.put_line('Error, the current schema is missing the following privilege: '||l_priv);
            l_priv_error := true;
        end;
        l_priv := l_req_privs.next(l_priv);
    end loop;
    
    if not l_priv_error then
        dbms_output.put_line('User has all required privileges, installation will continue.');
    end if;
    
    dbms_output.put_line('_____________________________________________________________________________');

    if l_priv_error then
      raise_application_error (-20000,
                'One or more required privileges are missing.');
    end if;
end;
/

whenever sqlerror continue



create table logger_logs(
	id				    number,
	logger_level	    number,
	text	            varchar2(4000),
	time_stamp		    timestamp,
	scope               varchar2(1000),
	module			    varchar2(100),
	action			    varchar2(100),
	user_name	        varchar2(255),
    client_identifier   varchar2(255),
    call_stack		    varchar2(4000),
	unit_name		    varchar2(255),
	line_no			    varchar2(100),
    scn                 number,
    extra               clob,
	constraint logger_logs_pk primary key (id) enable,
	constraint logger_logs_lvl_ck check(logger_level in (1,2,4,8,16,32,64,128))
)
/


create sequence logger_logs_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
/

create or replace trigger  bi_logger_logs 
before insert on logger_logs 
for each row 
begin	
	select logger_logs_seq.nextval into :new.id from dual;
	:new.time_stamp 	:= systimestamp;
	:new.client_identifier	:= sys_context('userenv','client_identifier');
	:new.module 		:= sys_context('userenv','module');
	:new.action 		:= sys_context('userenv','action');
	$IF $$APEX $THEN
        :new.user_name 		:= nvl(v('APP_USER'),user);
    $ELSE
        :new.user_name 		:= user;
    $END
	:new.unit_name 	    :=  upper(:new.unit_name);
    $IF $$FLASHBACK_ENABLED $THEN
        :new.scn := dbms_flashback.get_system_change_number;
    $END
end;
/
show errors

create index logger_logs_idx1 on logger_logs(time_stamp,logger_level)
/



create table logger_prefs(
	pref_name	varchar2(255),
	pref_value	varchar2(255) not null,
	constraint logger_prefs_pk primary key (pref_name) enable
)
/

alter session set PLSQL_CCFLAGS='CURRENTLY_INSTALLING:TRUE'
/

create or replace trigger  biu_logger_prefs 
before insert or update on logger_prefs 
for each row 
begin
    
    if :new.pref_name = 'LEVEL' then
        if upper(:new.pref_value) not in ('OFF','PERMANENT','ERROR','WARNING','INFORMATION','DEBUG','TIMING') then
            raise_application_error (-20000,
                '"LEVEL" must be one of the following values: OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING');
        end if;
        :new.pref_value := upper(:new.pref_value);
    end if;
    
    $IF not $$CURRENTLY_INSTALLING $THEN
        -- this is because the logger package is not installed yet.  We enable it in logger_configure
        logger.null_global_contexts;
    $END
end;
/


merge into logger_prefs p
using (
    select 'PURGE_AFTER_DAYS'       PREF_NAME,  '7' PREF_VALUE from dual union
    select 'PURGE_MIN_LEVEL'        PREF_NAME,  'DEBUG' PREF_VALUE from dual union
    select 'LOGGER_VERSION'         PREF_NAME,  'x.x.x' PREF_VALUE from dual union
    select 'LEVEL'                  PREF_NAME,  'DEBUG' PREF_VALUE from dual union
    select 'PROTECT_ADMIN_PROCS'    PREF_NAME,  'TRUE' PREF_VALUE from dual union
    select 'INCLUDE_CALL_STACK'     PREF_NAME,  'TRUE' PREF_VALUE from dual union
    select 'INSTALL_SCHEMA'         PREF_NAME,  sys_context('USERENV','CURRENT_SCHEMA') PREF_VALUE from dual) d
    on (p.pref_name = d.pref_name)
when matched then 
    update set p.pref_value = d.pref_value
when not matched then 
    insert (p.pref_name,p.pref_value)
    values (d.pref_name,d.pref_value);


create table logger_logs_apex_items(
    id				number not null,
    log_id          number not null,
    app_session     number not null,
    item_name       varchar2(1000) not null,
    item_value      clob,
    constraint logger_logs_apx_itms_pk primary key (id) enable,
    constraint logger_logs_apx_itms_fk foreign key (log_id) references logger_logs(id) ON DELETE CASCADE
)
/

create index logger_apex_items_idx1 on logger_logs_apex_items(log_id)
/


create sequence logger_apx_items_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
/


create or replace
TRIGGER  biu_logger_apex_items BEFORE INSERT or update ON logger_logs_apex_items 
FOR EACH ROW 
begin
	select logger_apx_items_seq.nextval into :new.id from dual;
end;
/



begin
  dbms_scheduler.create_job(
     job_name => 'LOGGER_PURGE_JOB',
     job_type => 'PLSQL_BLOCK',
     job_action => 'begin logger.purge; end; ',
     start_date => systimestamp,
     repeat_interval => 'FREQ=DAILY; BYHOUR=1',
     enabled => TRUE,
     comments => 'Purges LOGGER_LOGS using default values defined in logger_prefs.');
end;
/


create or replace force view logger_logs_5_min as
	select * 
      from logger_logs 
	 where time_stamp > systimestamp - (5/1440)
/

create or replace force view logger_logs_60_min as
	select * 
      from logger_logs 
	 where time_stamp > systimestamp - (1/24)
/


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


declare 
	-- the following line is also used in a constant declaration in logger.pkb  
	l_ctx_name varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';
begin
	execute immediate 'create or replace context '||l_ctx_name||' using logger accessed globally';
	
	merge into logger_prefs p
	using (select 'GLOBAL_CONTEXT_NAME' PREF_NAME,  l_ctx_name PREF_VALUE from dual) d
		on (p.pref_name = d.pref_name)
	when matched then 
		update set p.pref_value = d.pref_value
	when not matched then 
		insert (p.pref_name,p.pref_value)
		values (d.pref_name,d.pref_value);
end;
/
