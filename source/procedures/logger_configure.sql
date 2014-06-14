create or replace procedure logger_configure
is
  -- Note: The license is defined in the package specification of the logger package
	--
	l_rac_lt_11_2 varchar2(50) := 'FALSE';  -- is this a RAC instance less than 11.2, no GAC support

  l_apex varchar2(50) := 'FALSE';
  tbl_not_exist exception;
  pls_pkg_not_exist exception;
  --no_data_found       exception;
  
  l_text_data_length user_tab_columns.data_length%type;
  l_large_text_column varchar2(50);
    
  l_sql varchar2(32767);
  l_variables varchar2(1000) := ' ';
  l_dummy number;
  l_flashback varchar2(50) := 'FALSE';
  pragma exception_init(tbl_not_exist, -942);
  --pragma 				exception_init(no_data_found, -1403);
  pragma exception_init(pls_pkg_not_exist, -06550);
    
	l_version constant number  := dbms_db_version.version + (dbms_db_version.release / 10);
begin
    
  /* ************************************************************************** */
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
    
  --
  /* ************************************************************************** */
  
  
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
  
  
  /* ************************************************************************** */
  -- Is APEX installed ?
  --
  begin
    execute immediate 'select 1 from apex_application_items where rownum = 1' into l_dummy;
      
    l_apex := 'TRUE';
  exception 
    when tbl_not_exist then l_apex := 'FALSE'; 
    when no_data_found then 
    l_apex := 'TRUE'; 
  end;
  
  l_variables := l_variables||'APEX:'||l_apex||',';
  --
  /* ************************************************************************** */
  
  
  
  
  /* ************************************************************************** */
  -- Can we call dbms_flashback to get the currect System Commit Number?
  --
  begin
    execute immediate 'begin :d := dbms_flashback.get_system_change_number; end; ' using out l_dummy;
      
    l_flashback := 'TRUE';
  exception when pls_pkg_not_exist then 
    l_flashback := 'FALSE'; 
  end;
  
  l_variables := l_variables||'FLASHBACK_ENABLED:'||l_flashback||',';
  --
  /* ************************************************************************** */
  
    
  l_variables :=  rtrim(l_variables,',');
  $IF $$LOGGER_DEBUG $THEN
    dbms_output.put_line('l_variables: ' || l_variables);
  $END    
	
	l_sql := q'[alter package logger compile body PLSQL_CCFLAGS=']'||l_variables||q'['  reuse settings]';
	execute immediate l_sql;
	
  -- #31: Dropped trigger
	-- l_sql := q'[alter trigger BI_LOGGER_LOGS compile PLSQL_CCFLAGS=']'||l_variables||q'[' reuse settings]';
	-- execute immediate l_sql;
  
  l_sql := q'[alter trigger biu_logger_prefs compile PLSQL_CCFLAGS='CURRENTLY_INSTALLING:FALSE']';
  execute immediate l_sql;
  
  -- just in case this is a re-install / upgrade, the global contexts will persist so reset them
  logger.null_global_contexts;
    
end logger_configure;
/
show errors



-- grant select on apex_030200.wwv_flow_data to logger;

-- create synonym logger.wwv_flow_data for apex_030200.wwv_flow_data;

-- (as sys) grant execute on dbms_flashback to logger;