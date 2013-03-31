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
  where table_name = 'LOGGER_PREFS';
  
  if l_count = 0 then
    execute immediate '
create table logger_prefs(
  pref_name	varchar2(255),
  pref_value	varchar2(255) not null,
  constraint logger_prefs_pk primary key (pref_name) enable
)
    ';
  end if;
  
end;
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


-- DATA
merge into logger_prefs p
using (
  select 'PURGE_AFTER_DAYS'       PREF_NAME,  '7' PREF_VALUE from dual union
  select 'PURGE_MIN_LEVEL'        PREF_NAME,  'DEBUG' PREF_VALUE from dual union
  select 'LOGGER_VERSION'         PREF_NAME,  'x.x.x' PREF_VALUE from dual union -- x.x.x will be replaced when running the build script
  select 'LEVEL'                  PREF_NAME,  'DEBUG' PREF_VALUE from dual union
  select 'PROTECT_ADMIN_PROCS'    PREF_NAME,  'TRUE' PREF_VALUE from dual union
  select 'INCLUDE_CALL_STACK'     PREF_NAME,  'TRUE' PREF_VALUE from dual union
  select 'INSTALL_SCHEMA'         PREF_NAME,  sys_context('USERENV','CURRENT_SCHEMA') PREF_VALUE from dual) d
  on (p.pref_name = d.pref_name)
when matched then 
  update set p.pref_value = 
    case 
      -- Only LOGGER_VERSION should be updated during an update
      when p.pref_name = 'LOGGER_VERSION' then d.pref_value 
      else p.pref_value
    end
when not matched then 
  insert (p.pref_name,p.pref_value)
  values (d.pref_name,d.pref_value);
