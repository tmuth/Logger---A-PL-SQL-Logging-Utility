-- Initial table script built from 1.4.0
declare
  l_count pls_integer;
  l_nullable user_tab_columns.nullable%type;
  
  type typ_required_columns is table of varchar2(30) index by pls_integer;
  l_required_columns typ_required_columns;
  
begin
  -- Create Table
  select count(1)
  into l_count
  from user_tables
  where table_name = 'LOGGER_LOGS';
  
  if l_count = 0 then
    execute immediate '
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
    ';
  end if;
  
  -- 2.0.0
  l_required_columns(l_required_columns.count+1) := 'LOGGER_LEVEL';
  l_required_columns(l_required_columns.count+1) := 'TIME_STAMP';
  
  for i in l_required_columns.first .. l_required_columns.last loop
    
    select nullable
    into l_nullable
    from user_tab_columns
    where table_name = 'LOGGER_LOGS'
      and column_name = upper(l_required_columns(i));
      
    if l_nullable = 'Y' then
      execute immediate 'alter table logger_logs modify ' || l_required_columns(i) || ' not null';
    end if;
  end loop;
  

  -- SEQUENCE
  select count(1)
  into l_count
  from user_sequences
  where sequence_name = 'LOGGER_LOGS_SEQ';
  
  if l_count = 0 then
    execute immediate '
      create sequence logger_logs_seq
          minvalue 1
          maxvalue 999999999999999999999999999
          start with 1
          increment by 1
          cache 20
    ';
  end if;
  
  -- INDEXES
  select count(1)
  into l_count
  from user_indexes
  where index_name = 'LOGGER_LOGS_IDX1';
  
  if l_count = 0 then
    execute immediate 'create index logger_logs_idx1 on logger_logs(time_stamp,logger_level)';
  end if;
end;
/
  
  
-- TRIGGER

create or replace trigger  bi_logger_logs 
  before insert on logger_logs 
  for each row 
begin	
  -- 2.1.0: Changed to support 10g, since 10g requires a select into for IDs
  $IF $$LT_11 $THEN
    select logger_logs_seq.nextval into :new.id from dual;
  $ELSE
    :new.id := logger_logs_seq.nextval;
  $END
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

