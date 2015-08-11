create or replace procedure logger_configure
is
  -- Note: The license is defined in the package specification of the logger package
	--
	l_rac_lt_11_2 varchar2(50) := 'FALSE';  -- is this a RAC instance less than 11.2, no GAC support

  l_apex varchar2(50) := 'FALSE';
  tbl_not_exist exception;
  pls_pkg_not_exist exception;

  l_text_data_length user_tab_columns.data_length%type;
  l_large_text_column varchar2(50);

  l_sql varchar2(32767);
  l_variables varchar2(1000) := ' ';
  l_dummy number;
  l_flashback varchar2(50) := 'FALSE';
  l_utl_lms varchar2(5) := 'FALSE';

  pragma exception_init(tbl_not_exist, -942);
  pragma exception_init(pls_pkg_not_exist, -06550);

	l_version constant number  := dbms_db_version.version + (dbms_db_version.release / 10);
  l_pref_value logger_prefs.pref_Value%type;
  l_logger_debug boolean;

	l_pref_type_logger logger_prefs.pref_type%type;
begin

  -- Check to see if we are in a RAC Database, 11.1 or lower.
  --
  -- Tyler to check if this works
  if dbms_utility.is_cluster_database then
    l_rac_lt_11_2 := 'TRUE';
  else
    l_rac_lt_11_2 := 'FALSE';
  end if;

  if l_version >= 11.2 then
    l_rac_lt_11_2 := 'FALSE';
  end if;

  l_variables := 'RAC_LT_11_2:'||l_rac_lt_11_2||',';


  -- Check lenth of TEXT size (this is for future 12c 32767 integration
  -- In support of Issue #17 and future proofing for #30
  select data_length
  into l_text_data_length
  from user_tab_columns
  where 1=1
    and table_name = 'LOGGER_LOGS'
    and column_name = 'TEXT';

  if l_text_data_length > 4000 then
    l_large_text_column := 'TRUE';
  else
    l_large_text_column := 'FALSE';
  end if;
  l_variables := l_variables||'LARGE_TEXT_COLUMN:'||l_large_text_column||',';


  -- Is APEX installed ?
  --
  begin
    execute immediate 'select 1 from apex_application_items where rownum = 1' into l_dummy;

    l_apex := 'TRUE';
  exception
    when tbl_not_exist then
      l_apex := 'FALSE';
    when no_data_found then
      l_apex := 'TRUE';
  end;

  l_variables := l_variables||'APEX:'||l_apex||',';


  -- Can we call dbms_flashback to get the currect System Commit Number?
  --
  begin
    execute immediate 'begin :d := dbms_flashback.get_system_change_number; end; ' using out l_dummy;

    l_flashback := 'TRUE';
  exception when pls_pkg_not_exist then
    l_flashback := 'FALSE';
  end;

  l_variables := l_variables||'FLASHBACK_ENABLED:'||l_flashback||',';


  -- #64: Support to run Logger in debug mode

	-- #127
	-- Since this procedure will recompile Logger, if it directly references a variable in Logger
	-- It will lock itself while trying to recompile
	-- Work around is to pre-store the variable using execute immediate
	execute immediate 'begin :x := logger.g_pref_type_logger; end;' using out l_pref_type_logger;

  select lp.pref_value
  into l_pref_value
  from logger_prefs lp
  where 1=1
		and lp.pref_type = upper(l_pref_type_logger)
    and lp.pref_name = 'LOGGER_DEBUG';
  l_variables := l_variables || 'LOGGER_DEBUG:' || l_pref_value||',';

  l_logger_debug := false;
  if upper(l_pref_value) = 'TRUE' then
    l_logger_debug := true;
  end if;


  -- #46
  -- Handle plugin settings
-- Set for each plugin type
  for x in (
    select
      'LOGGER_' ||
      regexp_replace(lp.pref_name, '^PLUGIN_FN_', 'PLUGIN_') || ':' ||
      decode(nvl(upper(lp.pref_value), 'NONE'), 'NONE', 'FALSE', 'TRUE') ||
      ',' var
    from logger_prefs lp
    where 1=1
			and lp.pref_type = l_pref_type_logger
      and lp.pref_name like 'PLUGIN_FN%'
  ) loop
    l_variables := l_variables || x.var;
  end loop;


  l_variables := rtrim(l_variables,',');
  if l_logger_debug then
    dbms_output.put_line('l_variables: ' || l_variables);
  end if;


	-- Recompile Logger
 	l_sql := q'!alter package logger compile body PLSQL_CCFLAGS='%VARIABLES%' reuse settings!';
	l_sql := replace(l_sql, '%VARIABLES%', l_variables);
	execute immediate l_sql;

  -- #31: Dropped trigger
	-- l_sql := q'[alter trigger BI_LOGGER_LOGS compile PLSQL_CCFLAGS=']'||l_variables||q'[' reuse settings]';
	-- execute immediate l_sql;

  -- -- TODO mdsouza: 3.1.1 org l_sql := q'!alter trigger biu_logger_prefs compile PLSQL_CCFLAGS='CURRENTLY_INSTALLING:FALSE'!';
  l_sql := q'!alter trigger biu_logger_prefs compile!';
  execute immediate l_sql;

  -- just in case this is a re-install / upgrade, the global contexts will persist so reset them
  logger.null_global_contexts;

end logger_configure;
/
