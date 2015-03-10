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
  :new.pref_name := upper(:new.pref_name);

  if :new.pref_name = 'LEVEL' then
    :new.pref_value := upper(:new.pref_value);
  end if;

  $if $$currently_installing is null or not $$currently_installing $then
    -- Since logger.pks may not be installed when this trigger is compiled, need to move some code here
    if 1=1
      and :new.pref_name = 'LEVEL'
      and upper(:new.pref_value) not in (logger.g_off_name, logger.g_permanent_name, logger.g_error_name, logger.g_warning_name, logger.g_information_name, logger.g_debug_name, logger.g_timing_name, logger.g_sys_context_name, logger.g_apex_name) then
      raise_application_error(-20000, '"LEVEL" must be one of the following values: ' ||
        logger.g_off_name || ', ' || logger.g_permanent_name || ', ' || logger.g_error_name || ', ' ||
        logger.g_warning_name || ', ' || logger.g_information_name || ', ' || logger.g_debug_name || ', ' ||
        logger.g_timing_name || ', ' || logger.g_sys_context_name || ', ' || logger.g_apex_name);
    end if;

    -- this is because the logger package is not installed yet.  We enable it in logger_configure
    logger.null_global_contexts;
  $end
end;
/


-- Configu Data
merge into logger_prefs p
using (
  select 'PURGE_AFTER_DAYS' pref_name, '7' pref_value from dual union
  select 'PURGE_MIN_LEVEL' pref_name, 'DEBUG' pref_value from dual union
  select 'LOGGER_VERSION' pref_name, 'x.x.x' pref_value from dual union -- x.x.x will be replaced when running the build script
  select 'LEVEL' pref_name, 'DEBUG' pref_value from dual union
  select 'PROTECT_ADMIN_PROCS' pref_name, 'TRUE' pref_value from dual union
  select 'INCLUDE_CALL_STACK' pref_name, 'TRUE' pref_value from dual union
  select 'PREF_BY_CLIENT_ID_EXPIRE_HOURS' pref_name, '12' pref_value from dual union
  select 'INSTALL_SCHEMA' pref_name, sys_context('USERENV','CURRENT_SCHEMA') pref_value from dual union
  -- #46
  -- TODO mdsouza: drop unsupported functions
  select 'PLUGIN_FN_LOG' pref_name, 'NONE' pref_value from dual union
  select 'PLUGIN_FN_ERROR' pref_name, 'NONE' pref_value from dual union
  select 'PLUGIN_FN_PERMANENT' pref_name, 'NONE' pref_value from dual union
  select 'PLUGIN_FN_WARNING' pref_name, 'NONE' pref_value from dual union
  select 'PLUGIN_FN_INFORMATION' pref_name, 'NONE' pref_value from dual union
  -- #64
  select 'LOGGER_DEBUG' pref_name, 'FALSE' pref_value from dual
  ) d
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


-- Ensure that pref_name is upper
declare
  l_count pls_integer;
  l_constraint_name user_constraints.constraint_name%type := 'LOGGER_PREFS_CK1';
  l_sql varchar2(255);
begin
  select count(1)
  into l_count
  from user_constraints
  where 1=1
    and table_name = 'LOGGER_PREFS'
    and constraint_name = l_constraint_name;

  if l_count = 0 then
    update logger_prefs
    set pref_name = upper(pref_name);

    l_sql := 'alter table logger_prefs add constraint ' || l_constraint_name || ' check (pref_name = upper(pref_name))';

    execute immediate l_sql;
  end if;

end;
/
