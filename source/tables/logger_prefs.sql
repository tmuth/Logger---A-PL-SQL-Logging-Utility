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


-- Append existing PLSQL_CCFLAGS
-- Since may be set with existing flags (specifically no_op)
var cur_plsql_ccflags varchar2(500);

declare
  parnam varchar2(256);
  intval binary_integer;
  strval varchar2(500);
  partyp binary_integer;
begin
  partyp := dbms_utility.get_parameter_value('plsql_ccflags',                                             intval, strval);

  if strval is not null then
    strval := ',' || strval;
  end if;
  :cur_plsql_ccflags := strval;
end;
/

-- Convert bind variable to substitution string
-- https://blogs.oracle.com/opal/entry/sqlplus_101_substitution_varia
column cur_plsql_ccflags new_value cur_plsql_ccflags
select :cur_plsql_ccflags cur_plsql_ccflags from dual;

alter session set plsql_ccflags='currently_installing:true&cur_plsql_ccflags'
/

create or replace trigger biu_logger_prefs
  before insert or update on logger_prefs
  for each row
begin
  $if $$logger_no_op_install $then
    null;
  $else
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

      -- Allow for null to be used for Plugins, then default to NONE
      if :new.pref_name like 'PLUGIN_FN%' and :new.pref_value is null then
        :new.pref_value := 'NONE';
      end if;

      -- #103
      -- Only predefined preferences and Custom Preferences are allowed
      -- Custom Preferences must be prefixed with CUST_
      if substr (:new.pref_name, 1, 5) <> 'CUST_'
      and :new.pref_name not in ('GLOBAL_CONTEXT_NAME'
                             ,'INCLUDE_CALL_STACK'
                             ,'INSTALL_SCHEMA'
                             ,'LEVEL'
                             ,'LOGGER_DEBUG'
                             ,'LOGGER_VERSION'
                             ,'PLUGIN_FN_ERROR'
                             ,'PREF_BY_CLIENT_ID_EXPIRE_HOURS'
                             ,'PROTECT_ADMIN_PROCS'
                             ,'PURGE_AFTER_DAYS'
                             ,'PURGE_MIN_LEVEL'
                             )
      then
         raise_application_error (-20000, 'Only Predefined Preferences and Custom Preferences that begin with "CUST_" are allowed');
      end if;

      -- this is because the logger package is not installed yet.  We enable it in logger_configure
      logger.null_global_contexts;
    $end
  $end -- $$logger_no_op_install
end;
/


declare
begin
  $if $$logger_no_op_install $then
    null;
  $else
    -- Configure Data
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
      select 'PLUGIN_FN_ERROR' pref_name, 'NONE' pref_value from dual union
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
  $end
end;
/


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
