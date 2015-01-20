create or replace package body logger
as
  -- Note: The license is defined in the package specification of the logger package
  --
  -- _______________________________________________________________________________
  -- 
  --
  -- Definitions of conditional compilation variables:
  -- $$NO_OP              : When true, completely disables all logger DML.  Also used to
  --                      : generate the logger_no_op.sql code path
  --
  -- $$RAC_LT_11_2        : Set in logger_configure to handle the fact that RAC doesn't
  --                      : support global app contexts until 11.2
  --
  -- $$FLASHBACK_ENABLED  : Set in logger_configure to determine whether or not we can grab the scn from dbms_flashback.
  --                      : Primarily used in the trigger on logger_logs.
  --
  -- $$APEX               : Set in logger_configure.  True if we can query a local synonym to wwv_flow_data to snapshot
  --                      : the APEX session state.
  --
  -- $$LOGGER_DEBUG       : Only to be used during development of logger
  --                      : Primarily used for dbms_output.put_line calls

  
  -- TYPES
  type ts_array is table of timestamp index by varchar2(100);
  
  -- VARIABLES
  g_Log_Id    	Number;
  g_proc_start_times ts_array;
  g_running_timers pls_integer := 0;
  
  -- CONSTANTS
  gc_line_feed constant varchar2(1) := chr(10);
  gc_date_format constant varchar2(255) := 'DD-MON-YYYY HH24:MI:SS';
  gc_timestamp_format constant varchar2(255) := gc_date_format || ':FF';
  gc_timestamp_tz_format constant varchar2(255) := gc_timestamp_format || ' TZR';
  
  gc_ctx_attr_level constant varchar2(5) := 'level';
  gc_ctx_attr_include_call_stack constant varchar2(18) := 'include_call_stack';

  
  
  -- PRIVATE

  /**
   * 
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - 
   *
   * @author Martin D'Souza
   * @created -- TODO mdsouza: 
   * @param p_str
   * @return True if p_str is a number
   */
  function is_number(p_str in varchar2)
    return boolean
  as
    l_num number;
  begin
    l_num := to_number(p_str);
    return true;
  exception
    when others then
      return false;
  end is_number;

  
  /**
   * Returns the display/print friendly parameter information
   * Private
   *
   * @author Martin D'Souza
   * @created 20-Jan-2013
   *
   * @param p_parms Array of parameters (can be null)
   * @return Clob of param information
   */
  function get_param_clob(p_params in logger.tab_param)
    return clob
  as
    l_return clob;
    l_no_vars constant varchar2(255) := 'No params defined';
  begin
    $if $$no_op $then
      null;
    $else
      -- Generate line feed delimited list
      if p_params.count > 0 then
        for x in p_params.first..p_params.last loop
          l_return := l_return || p_params(x).name || ': ' || p_params(x).val;
          
          if x != p_params.last then
            l_return := l_return || gc_line_feed;
          end if;
        end loop;
      end if; -- p_params.count > 0
      
      if l_return is null then
        l_return := l_no_vars;
      end if;
    $end
    
    return l_return;
  end get_param_clob;
   
  
  /**
   * Validates assertion. Will raise an application error if assertion is false
   * Private
   *
   * @author Martin D'Souza
   * @created 29-Mar-2013
   *
   * @param p_condition Boolean condition to validate
   * @param p_message Message to include in application error if p_condition fails
   */
  procedure assert(
    p_condition in boolean,
    p_message in varchar2)
  as
  begin
    $if $$no_op $then
      null;
    $else
      if not p_condition or p_condition is null then
        raise_application_error(-20000, p_message);
      end if;
    $end
  end assert;
  
  /**
   * Sets the global context
   *
   * @author Tyler Muth
   * @created ???
   *
   * @param p_attribute Attribute for context to set
   * @param p_value Value
   * @param p_client_id Optional client_id. If specified will only set the attribute/value for specific client_id (not global)
   */
  procedure save_global_context(
    p_attribute in varchar2,
    p_value in varchar2,
    p_client_id in varchar2 default null)
  is
    pragma autonomous_transaction;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      dbms_session.set_context(
        namespace => g_context_name,
        attribute => p_attribute,
        value => p_value,
        client_id => p_client_id);
    $END
    commit; -- MD: moved commit to outside of the NO_OP check since commit or rollback must occur in this procedure
  end save_global_context;
  
  
  /**
   * Will return the extra column appended with the display friendly parameters
   *
   * @author Martin D'Souza
   * @created 1-May-2013
   *
   * @param p_extra Current "Extra" field
   * @param p_params Parameters. If null, then no changes to the Extra column
   */
  function set_extra_with_params(
    p_extra in logger_logs.extra%type,
    p_params in tab_param
  )
    return logger_logs.extra%type
  as
    l_extra logger_logs.extra%type;
  begin
    $IF $$NO_OP $THEN
      return null;
    $ELSE
      if p_params.count = 0 then 
        return p_extra;
      else
        l_extra := p_extra || gc_line_feed || gc_line_feed || '*** Parameters ***' || gc_line_feed || gc_line_feed || get_param_clob(p_params => p_params);
      end if;
      
      return l_extra;
    $END
    
  end set_extra_with_params;
  

  -- PUBLIC


 function admin_security_check
    return boolean
  is
    l_protect_admin_procs	logger_prefs.pref_value%type;
    l_return boolean default false;
  begin
    $if $$no_op $then
      l_return := true;
    $else
      l_protect_admin_procs := get_pref('PROTECT_ADMIN_PROCS');
      if l_protect_admin_procs = 'TRUE' then
        if get_pref('INSTALL_SCHEMA') = sys_context('USERENV','SESSION_USER') then
          l_return := true;
        else
          l_return := false;
          raise_application_error (-20000, 'You are not authorized to call this procedure.');
        end if;
      else
          l_return := true;
      end if;
    $end

    return l_return;

  end admin_security_check;

  procedure null_global_contexts
  is
    pragma autonomous_transaction;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      $IF $$RAC_LT_11_2 $THEN
        null;
      $ELSE
        dbms_session.set_context(
          namespace  => g_context_name,
          attribute  => gc_ctx_attr_level,
          value      => null);

        dbms_session.set_context(
          namespace  => g_context_name,
          attribute  => gc_ctx_attr_include_call_stack,
          value      => null);
      $END
    $END
    commit;
  end null_global_contexts;


  /**
   * Converts string names to text value
   *
   * Changes
   *  - 2.1.0: Start to use global variables and correct numbers
   *
   * @author Tyler Muth
   * @created ???
   *
   * @param p_level String representation of level
   * @return level number. -1 if not found
   */
  function convert_level_char_to_num(
      p_level in varchar2)
    return number
  is
    l_level         number;
  begin
    case p_level
      when g_off_name then l_level := g_off;
      when g_permanent_name then l_level := g_permanent;
      when g_error_name then l_level := g_error;
      when g_warning_name then l_level := g_warning;
      when g_information_name then l_level := g_information;
      when g_debug_name then l_level := g_debug;
      when g_timing_name then l_level := g_timing;
      when g_sys_context_name then l_level := g_sys_context;
      when g_apex_name then l_level := g_apex;
      else l_level := -1;
    end case;

    return l_level;
  end convert_level_char_to_num;


  /**
   * Converts the logger level num to char format
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - #47
   *
   * @author Martin D'Souza
   * @created 14-Jun-2014
   * @param p_level
   * @return Logger level string format
   */
  function convert_level_num_to_char(
    p_level in number)
  return varchar2
  is
    l_return varchar2(255);
  begin
    $if $$no_op $then
      null;
    $else
      l_return :=
        case p_level
          when g_off then g_off_name
          when g_permanent then g_permanent_name
          when g_error then g_error_name
          when g_warning then g_warning_name
          when g_information then g_information_name
          when g_debug then g_debug_name
          when g_timing then g_timing_name
          when g_sys_context then g_sys_context_name
          when g_apex then g_apex_name
          else null
        end;
    $end
    
    return l_return;
  end convert_level_num_to_char;

  function get_level_number
    return number
    $IF $$RAC_LT_11_2 $THEN
      $IF not dbms_db_version.ver_le_10_2 $THEN
        result_cache relies_on (logger_prefs, logger_prefs_by_client_id)
      $END
    $END
  is
    l_level         number;
    l_level_char    varchar2(50);
    l_scope varchar2(30) := 'get_level_number';
  begin
    $IF $$NO_OP $THEN
      return 0;
    $ELSE
      $IF $$LOGGER_DEBUG $THEN
        dbms_output.put_line(l_scope || ': select logger_level');
      $END
      
      -- If enabled then first try to get the levle from it. If not go to the original code below
      select logger_level
      into l_level_char
      from (
        select logger_level, row_number () over (order by rank) rn
        from (
          -- Client specific logger levels trump system level logger level
          select logger_level, 1 rank
          from logger_prefs_by_client_id
          where client_id = sys_context('userenv','client_identifier')
          union
          -- System level configuration
          select pref_value logger_level, 2 rank
          from logger_prefs 
          where pref_name = 'LEVEL'
        )
      )
      where rn = 1;

      l_level := convert_level_char_to_num(l_level_char);

      return l_level;
    $END
  end get_level_number;

  /**
   * Determines if the statement can be stored in LOGGER_LOGS
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - #42: Expose publically
   *
   * @author Tyler Muth
   * @created ???
   *
   * @param p_level Level (number)
   * @return True of statement can be logged to LOGGER_LOGS
   */
  function ok_to_log(p_level in number)
    return boolean
    $IF $$RAC_LT_11_2 $THEN
      $IF not dbms_db_version.ver_le_10_2 $THEN
        $IF $$NO_OP is null or NOT $$NO_OP $THEN
          result_cache relies_on (logger_prefs, logger_prefs_by_client_id)
        $END
      $END
    $END
  is
    l_level         number;
    l_level_char    varchar2(50);
  begin
    $IF $$NO_OP $THEN
      return false;
    $ELSE
      $IF $$RAC_LT_11_2 $THEN
        l_level := get_level_number;
      $ELSE
        l_level := sys_context(g_context_name,gc_ctx_attr_level);
        if l_level is null then
          l_level := get_level_number;
          save_global_context(gc_ctx_attr_level,l_level);
        end if;
      $END

      if l_level >= p_level then
        return true;
      else
        return false;
      end if;
   $END
  end ok_to_log;


  /**
   * Determines if log statements will actually be stored.
   *
   * @author Martin D'Souza
   * @created 25-Jul-2013
   *
   * @param p_level Level (DEBUG etc..)
   * @return True of log statements for that level or below will be logged
   */
  function ok_to_log(p_level in varchar2)
    return boolean
  as
  begin
    $IF $$NO_OP $THEN
      return false;
    $ELSE  
      return ok_to_log(p_level => convert_level_char_to_num(p_level => p_level));
    $END
  end ok_to_log;


  function include_call_stack
    return boolean
    $IF $$RAC_LT_11_2 $THEN
      $IF not dbms_db_version.ver_le_10_2 $THEN
        $IF $$NO_OP is null or NOT $$NO_OP $THEN
          result_cache relies_on (logger_prefs, logger_prefs_by_client_id)
        $END
      $END
    $END
  is
    l_call_stack_pref   varchar2(50);
  begin
    $IF $$NO_OP $THEN
      return false;
    $ELSE
      $IF $$RAC_LT_11_2 $THEN
        l_call_stack_pref := get_pref('INCLUDE_CALL_STACK');
      $ELSE
        l_call_stack_pref := sys_context(g_context_name,gc_ctx_attr_include_call_stack);
        if l_call_stack_pref is null then
          l_call_stack_pref := get_pref('INCLUDE_CALL_STACK');
          save_global_context(gc_ctx_attr_include_call_stack,l_call_stack_pref);
        end if;
      $END

      if l_call_stack_pref = 'TRUE' then
        return true;
      else
        return false;
      end if;
    $END
  end include_call_stack;


  function date_text_format_base (
    p_date_start in date,
    p_date_stop  in date)
  return varchar2
  as
    x	varchar2(20);
  begin
    x := 	
      case
        when p_date_stop-p_date_start < 1/1440
          then round(24*60*60*(p_date_stop-p_date_start)) || ' seconds'
        when p_date_stop-p_date_start < 1/24
          then round(24*60*(p_date_stop-p_date_start)) || ' minutes'
        when p_date_stop-p_date_start < 1
          then round(24*(p_date_stop-p_date_start)) || ' hours'
        when p_date_stop-p_date_start < 14
          then trunc(p_date_stop-p_date_start) || ' days'
        when p_date_stop-p_date_start < 60
          then trunc((p_date_stop-p_date_start)/7) || ' weeks'
        when p_date_stop-p_date_start < 365
          then round(months_between(p_date_stop,p_date_start)) || ' months'
        else round(months_between(p_date_stop,p_date_start)/12,1) || ' years'
      end;
    x:= regexp_replace(x,'(^1 [[:alnum:]]{4,10})s','\1');
    x:= x || ' ago';
    return substr(x,1,20);
  end date_text_format_base;



  function date_text_format (p_date in date)
    return varchar2
  as
  begin
    return date_text_format_base(
      p_date_start => p_date   ,
      p_date_stop  => sysdate);

  end date_text_format;

	function get_character_codes(
		p_string 				in varchar2,
		p_show_common_codes 	in boolean default true)
  	return varchar2
	is
		l_string	varchar2(32767);
		l_dump		varchar2(32767);
		l_return	varchar2(32767);
	begin
		-- replace tabs with ^
    l_string := replace(p_string,chr(9),'^');
		-- replace all other control characters such as carriage return / line feeds with ~
		l_string := regexp_replace(l_string,'[[:cntrl:]]','~',1,0,'m');

		select dump(p_string) into l_dump from dual;

		l_dump	:= regexp_replace(l_dump,'(^.+?:)(.*)','\2',1,0); -- get everything after the :
		l_dump	:= ','||l_dump||','; -- leading and trailing commas
		l_dump	:= replace(l_dump,',',',,'); -- double the commas. this is for the regex.
		l_dump 	:= regexp_replace(l_dump,'(,)([[:digit:]]{1})(,)','\1  \2\3',1,0); -- lpad all single digit numbers out to 3
		l_dump 	:= regexp_replace(l_dump,'(,)([[:digit:]]{2})(,)','\1 \2\3',1,0);  -- lpad all double digit numbers out to 3
		l_dump	:= ltrim(replace(l_dump,',,',','),','); -- remove the double commas
    l_dump  := lpad(' ',(5-instr(l_dump,',')),' ')||l_dump;

		-- replace every individual character with 2 spaces, itself and a comma so it lines up with the dump output
		l_string := ' '||regexp_replace(l_string,'(.){1}','  \1,',1,0);

		l_return := rtrim(l_dump,',') || chr(10) || rtrim(l_string,',');

		if p_show_common_codes then
			l_return := 'Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab'||chr(10) ||l_return;
		end if;

		return l_return;

	end get_character_codes;

  procedure get_debug_info(
    p_callstack     in clob,
    o_unit          out varchar2,
    o_lineno        out varchar2 ) 
  as
    --
    l_callstack varchar2(3000) := p_callstack;
  begin
    $if $$no_op $then
      null;
    $else
      l_callstack := substr( l_callstack, instr( l_callstack, chr(10), 1, 5 )+1 );
      l_callstack := substr( l_callstack, 1, instr( l_callstack, chr(10), 1, 1 )-1 );
      l_callstack := trim( substr( l_callstack, instr( l_callstack, ' ' ) ) );
      o_lineno := substr( l_callstack, 1, instr( l_callstack, ' ' )-1 );
      o_unit := trim(substr( l_callstack, instr( l_callstack, ' ', -1, 1 ) ));
    $end
  end get_debug_info;


  /**
   * Main procedure that will store log data into logger_logs table
   *
   * @author Tyler Muth
   * @created ???
   * 
   * Modifications
   *  - 2.1.0: If text is > 4000 characters, it will be moved to the EXTRA column
   *
   * @param p_text
   * @param p_log_level
   * @param p_scope
   * @param p_extra
   * @param p_callstack
   * @param p_params
   *
   */
  procedure log_internal(
    p_text				in varchar2,
    p_log_level			in number,
    p_scope             in varchar2,
    p_extra             in clob default null,
    p_callstack         in varchar2 default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
  is
    l_proc_name     	varchar2(100);
    l_lineno        	varchar2(100);
    l_text 				varchar2(32767);
    l_callstack         varchar2(3000);
    l_extra logger_logs.extra%type;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      l_text := p_text;
      if p_callstack is not null and include_call_stack then
        get_debug_info(
          p_callstack     => p_callstack,
          o_unit          => l_proc_name,
          o_lineno        => l_lineno);

        l_callstack  := regexp_replace(p_callstack,'^.*$','',1,4,'m');
        l_callstack  := regexp_replace(l_callstack,'^.*$','',1,1,'m');
        l_callstack  := ltrim(replace(l_callstack,chr(10)||chr(10),chr(10)),chr(10));

      end if;
      
      l_extra := set_extra_with_params(p_extra => p_extra, p_params => p_params);

      ins_logger_logs(
        p_unit_name => upper(l_proc_name) ,
        p_scope => p_scope ,
        p_logger_level =>p_log_level,
        p_extra => l_extra,
        p_text =>l_text,
        p_call_stack  =>l_callstack,
        p_line_no => l_lineno,
        po_id => g_log_id);
--      commit;
    $END
  end log_internal;

  procedure snapshot_apex_items(
    p_log_id in number)
  is
    l_app_session number;
    l_app_id       number;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      $IF $$APEX $THEN
        l_app_session := v('APP_SESSION');
        l_app_id := v('APP_ID');
        for c1 in (
          select item_name
          from apex_application_items
          where application_id = l_app_id)
        loop
          insert into logger_logs_apex_items(log_id,app_session,item_name,item_value)
          values (p_log_id,l_app_session,c1.item_name,v(c1.item_name));
        end loop; --c1

        for c1 in (
          select item_name
          from apex_application_page_items
          where application_id = l_app_id)
        loop
          insert into logger_logs_apex_items(log_id,app_session,item_name,item_value)
          values (p_log_id,l_app_session,c1.item_name,v(c1.item_name));
        end loop; --c1

      $END
      null;
    $END
  end snapshot_apex_items;


  procedure log_error(
		p_text          in varchar2 default null,
    p_scope         in varchar2 default null,
    p_extra         in clob default null,
    p_params        in tab_param default logger.gc_empty_tab_param)
  is
    l_proc_name     varchar2(100);
    l_lineno        varchar2(100);
    l_text          varchar2(4000);
    l_call_stack    varchar2(4000);
    l_extra         clob;
	begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_error) then
        -- get_debug_info( l_proc_name, l_lineno );
  
        get_debug_info(
          p_callstack     => dbms_utility.format_call_stack,
          o_unit          => l_proc_name,
          o_lineno        => l_lineno);
  
        l_call_stack := dbms_utility.format_error_stack() ||chr(10)||dbms_utility.format_error_backtrace;
  
        if p_text is not null then
          l_text := p_text ||' '|| chr(10)||chr(10);
        end if;
  
        l_text := l_text || dbms_utility.format_error_stack();
        
        
        l_extra := set_extra_with_params(p_extra => p_extra, p_params => p_params);
        
        ins_logger_logs(
          p_unit_name => upper(l_proc_name) ,
          p_scope => p_scope ,
          p_logger_level =>logger.g_error,
          p_extra => l_extra,
          p_text =>l_text,
          p_call_stack  =>l_call_stack,
          p_line_no => l_lineno,
          po_id => g_log_id);  
      end if;
    $END
	end log_error;


  procedure log_permanent(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
  is
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_permanent) then
        log_internal(
          p_text				=> p_text,
          p_log_level			=> logger.g_permanent,
          p_scope             => p_scope,
          p_extra             => p_extra,
          p_callstack         => dbms_utility.format_call_stack,
          p_params => p_params
          );
      end if;
    $END
  end log_permanent;

  procedure log_warn(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)  
  is
  begin
    log_warning(
      p_text    => p_text,
      p_scope   => p_scope,
      p_extra   => p_extra,
      p_params  => p_params); 
  end;  

  procedure log_warning(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
  is
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_warning) then
        log_internal(
          p_text				=> p_text,
          p_log_level			=> logger.g_warning,
          p_scope             => p_scope,
          p_extra             => p_extra,
          p_callstack         => dbms_utility.format_call_stack,
          p_params => p_params);
      end if;
    $END
  end log_warning;
 
  procedure log_info(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
  is
  begin
    log_information(
      p_text    => p_text,
      p_scope   => p_scope,
      p_extra   => p_extra,
      p_params  => p_params);
  end;  

  procedure log_information(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
	is
	begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_information) then
        log_internal(
          p_text				=> p_text,
          p_log_level			=> logger.g_information,
          p_scope             => p_scope,
          p_extra             => p_extra,
          p_callstack         => dbms_utility.format_call_stack,
          p_params  => p_params);
      end if;
    $END
	end log_information;

	procedure log(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param)
	is
	begin
    
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        log_internal(
          p_text				=> p_text,
          p_log_level			=> logger.g_debug,
          p_scope             => p_scope,
          p_extra             => p_extra,
          p_callstack         => dbms_utility.format_call_stack,
          p_params => p_params);
      end if;
    $END
	end log;

  function get_sys_context(
    p_detail_level in varchar2 default 'USER', -- ALL, NLS, USER, INSTANCE
    p_vertical     in boolean default false,
    p_show_null	in boolean default false) -- vertical name value pairs or comma sep list.
    return clob
  is
    l_ctx   clob;
    l_detail_level varchar2(20) := upper(p_detail_level);

    procedure append_ctx(p_name in varchar2)
    is
      r_pad                   number := 30;
      l_crlf                  varchar2(10) := chr(13)||chr(10);
      invalid_userenv_parm    exception;
      pragma 				    exception_init(invalid_userenv_parm, -2003);
    begin
      if p_show_null or sys_context('USERENV',p_name) is not null then
        if p_vertical then
          l_ctx := l_ctx || rpad(p_name,r_pad,' ')||': '||sys_context('USERENV',p_name)||l_crlf;
        else
          l_ctx := l_ctx || p_name||': '||sys_context('USERENV',p_name)||', ';
        end if;
      end if;
    exception 
      when invalid_userenv_parm then
        --log_warning('Invalid SYS_CONTEXT Parameter: '||p_name);
        null;
    end append_ctx;

  
  begin
    $if $$no_op $then
      return null;
    $else
      if l_detail_level in ('ALL','NLS','INSTANCE') then
        append_ctx('NLS_CALENDAR');
        append_ctx('NLS_CURRENCY');
        append_ctx('NLS_DATE_FORMAT');
        append_ctx('NLS_DATE_LANGUAGE');
        append_ctx('NLS_SORT');
        append_ctx('NLS_TERRITORY');
        append_ctx('LANG');
        append_ctx('LANGUAGE');
      end if;

      if l_detail_level in ('ALL','USER') then
        append_ctx('CURRENT_SCHEMA');
        append_ctx('SESSION_USER');
        append_ctx('OS_USER');
        append_ctx('CLIENT_IDENTIFIER');
        append_ctx('CLIENT_INFO');
        append_ctx('IP_ADDRESS');
        append_ctx('HOST');
        append_ctx('TERMINAL');
      end if;

      if l_detail_level in ('ALL','USER') then
        append_ctx('AUTHENTICATED_IDENTITY');
        append_ctx('AUTHENTICATION_DATA');
        append_ctx('AUTHENTICATION_METHOD');
        append_ctx('ENTERPRISE_IDENTITY');
        append_ctx('POLICY_INVOKER');
        append_ctx('PROXY_ENTERPRISE_IDENTITY');
        append_ctx('PROXY_GLOBAL_UID');
        append_ctx('PROXY_USER');
        append_ctx('PROXY_USERID');
        append_ctx('IDENTIFICATION_TYPE');
        append_ctx('ISDBA');
      end if;

      if l_detail_level in ('ALL','INSTANCE') then
        append_ctx('DB_DOMAIN');
        append_ctx('DB_NAME');
        append_ctx('DB_UNIQUE_NAME');
        append_ctx('INSTANCE');
        append_ctx('INSTANCE_NAME');
        append_ctx('SERVER_HOST');
        append_ctx('SERVICE_NAME');
      end if;

      if l_detail_level in ('ALL') then
        append_ctx('ACTION');
        append_ctx('AUDITED_CURSORID');
        append_ctx('BG_JOB_ID');
        append_ctx('CURRENT_BIND');
        append_ctx('CURRENT_SCHEMAID');
        append_ctx('CURRENT_SQL');
        append_ctx('CURRENT_SQLn');
        append_ctx('CURRENT_SQL_LENGTH');
        append_ctx('ENTRYID');
        append_ctx('FG_JOB_ID');
        append_ctx('GLOBAL_CONTEXT_MEMORY');
        append_ctx('GLOBAL_UID');
        append_ctx('MODULE');
        append_ctx('NETWORK_PROTOCOL');
        append_ctx('SESSION_USERID');
        append_ctx('SESSIONID');
        append_ctx('SID');
        append_ctx('STATEMENTID');
      end if;

      return rtrim(l_ctx,', ');
    $end
  end get_sys_context;


	function get_cgi_env(
    p_show_null		in boolean default false)
  	return clob
	is
		l_cgienv clob;

		procedure append_cgi_env(
			p_name 		in varchar2,
			p_val	 	in varchar2)
    is
      r_pad                   number := 30;
      l_crlf                  varchar2(10) := chr(13)||chr(10);
      --invalid_userenv_parm    exception;
      --pragma 				    exception_init(invalid_userenv_parm, -2003);
    begin
			if p_show_null or p_val is not null then
        l_cgienv := l_cgienv || rpad(p_name,r_pad,' ')||': '||p_val||l_crlf;
			end if;
      --exception when invalid_userenv_parm then
      --log_warning('Invalid SYS_CONTEXT Parameter: '||p_name);
      null;
    end append_cgi_env;

	begin
    $IF $$NO_OP $THEN
      return null;
    $ELSE
      for i in 1..owa.num_cgi_vars loop
        append_cgi_env(
          p_name      => owa.cgi_var_name(i),
          p_val       => owa.cgi_var_val(i));

      end loop;

      return l_cgienv;
    $END
	end get_cgi_env;

  procedure log_userenv(
    p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
    p_show_null 	in boolean default false,
    p_scope         in varchar2 default null)
  is
    l_extra	clob;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        l_extra := get_sys_context(
          p_detail_level	=> p_detail_level,
          p_vertical		=> true,
          p_show_null		=> p_show_null);
  
        log_internal(
            p_text				=> 'USERENV values stored in the EXTRA column',
            p_log_level			=> logger.g_sys_context,
            p_scope             => p_scope,
            p_extra             => l_extra);
      end if;
    $END
  end log_userenv;


  procedure log_cgi_env(
		p_show_null 	in boolean default false,
    p_scope         in varchar2 default null)
  is
		l_extra	clob;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        l_extra := get_cgi_env(p_show_null		=> p_show_null);
        log_internal(
          p_text				=> 'CGI ENV values stored in the EXTRA column',
          p_log_level			=> logger.g_sys_context,
          p_scope             => p_scope,
          p_extra             => l_extra);
      end if;
    $END
  end log_cgi_env;



	procedure log_character_codes(
		p_text					in varchar2,
    p_scope					in varchar2 default null,
		p_show_common_codes 	in boolean default true)
  is
    l_error varchar2(4000);
		l_dump clob;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        l_dump := get_character_codes(p_text,p_show_common_codes);

        log_internal(
          p_text				=> 'GET_CHARACTER_CODES output stored in the EXTRA column',
          p_log_level			=> logger.g_debug,
          p_scope             => p_scope,
          p_extra             => l_dump);
      end if;
		$END
	end log_character_codes;



	procedure log_apex_items(
		p_text		in varchar2 default 'Log APEX Items',
    p_scope		in varchar2 default null)
  is
    l_error varchar2(4000);
  	pragma autonomous_transaction;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then

        $IF $$APEX $THEN
          log_internal(
            p_text				=> p_text,
            p_log_level			=> logger.g_apex,
            p_scope             => p_scope);

          snapshot_apex_items(p_log_id => g_log_id);
        $ELSE
          l_error := 'Error! Logger is not configured for APEX yet. '||
                     'Please check the CONFIGURATION section at https://logger.samplecode.oracle.com ';

          log_internal(
            p_text				=> l_error,
            p_log_level			=> logger.g_apex,
            p_scope             => p_scope);
        $END
      end if;
    $END
    commit;
  end log_apex_items;

	PROCEDURE time_start(
		p_unit				IN VARCHAR2,
    p_log_in_table 	    IN boolean default true)
	is
		l_proc_name     	varchar2(100);
		l_text 				varchar2(4000);
    l_pad               varchar2(100);
	begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        g_running_timers := g_running_timers + 1;

        if g_running_timers > 1 then
          l_pad := lpad(' ',g_running_timers,'>')||' ';
        end if;

        g_proc_start_times(p_unit) := systimestamp;

        l_text := l_pad||'START: '||p_unit;
        
        if p_log_in_table then
          ins_logger_logs(
            p_unit_name => p_unit ,
            p_logger_level => g_timing,
            p_text =>l_text,
            po_id => g_log_id);
        end if;
      end if;
    $END
	end time_start;

	procedure time_stop(
		p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null)
	is
		l_time_string   	varchar2(50);
    l_text 				varchar2(4000);
    l_pad               varchar2(100);
	begin
    $IF $$NO_OP $THEN
        null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        if g_proc_start_times.exists(p_unit) then

          if g_running_timers > 1 then
            l_pad := lpad(' ',g_running_timers,'>')||' ';
          end if;

          --l_time_string := rtrim(regexp_replace(systimestamp-(g_proc_start_times(p_unit)),'.+?[[:space:]](.*)','\1',1,0),0);
          l_time_string := time_stop(
            p_unit => p_unit,
            p_log_in_table => false);

          l_text := l_pad||'STOP : '||p_unit ||' - '||l_time_string;

          g_proc_start_times.delete(p_unit);
          g_running_timers := g_running_timers - 1;

          ins_logger_logs(
            p_unit_name => p_unit,
            p_scope => p_scope ,
            p_logger_level =>g_timing,
            p_text =>l_text,
            po_id => g_log_id);
        end if;
      end if;
    $END
	END time_stop;
    
  FUNCTION time_stop(
    p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    IN boolean default true
    )
    return varchar2
  is
    l_time_string   	varchar2(50);
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        if g_proc_start_times.exists(p_unit) then

          l_time_string := rtrim(regexp_replace(systimestamp-(g_proc_start_times(p_unit)),'.+?[[:space:]](.*)','\1',1,0),0);

          g_proc_start_times.delete(p_unit);
          g_running_timers := g_running_timers - 1;
          
          IF p_log_in_table THEN
            ins_logger_logs(
              p_unit_name => p_unit,
              p_scope => p_scope ,
              p_logger_level => g_timing,
              p_text => l_time_string,
              po_id => g_log_id);
          END IF;
          
          return l_time_string;
            
        end if;
      END IF;
    $END
  END time_stop;
    
  FUNCTION time_stop_seconds(
		p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    IN boolean default true
    )
    return number
  is
		l_time_string   	varchar2(50);
		l_seconds   NUMBER;
		l_interval 	INTERVAL day to second;
		
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if ok_to_log(logger.g_debug) then
        IF g_proc_start_times.EXISTS(p_unit) THEN
          l_interval := systimestamp-(g_proc_start_times(p_unit));
          l_seconds := EXTRACT(DAY FROM l_interval) * 86400 + EXTRACT(HOUR FROM l_interval) * 3600 + EXTRACT(MINUTE FROM l_interval) * 60 + EXTRACT(SECOND FROM l_interval);
                
          g_proc_start_times.delete(p_unit);
          g_running_timers := g_running_timers - 1;
                
          if p_log_in_table then
            ins_logger_logs( 
              p_unit_name => p_unit,
              p_scope => p_scope ,
              p_logger_level => g_timing,
              p_text => l_seconds,
              po_id => g_log_id);
          end if;
          
          return l_seconds;
                
        end if;
      END IF;
    $END
  END time_stop_seconds;
    

  procedure time_reset
  is
  begin
    if ok_to_log(logger.g_debug) then
      g_running_timers := 0;
      g_proc_start_times.delete;
    end if;
  end time_reset;

  /**
   * Returns Global or User preference
   * User preference is only valid for LEVEL and INCLUDE_CALL_STACK
   *  - If a user setting exists, it will be returned, if not the system level preference will be return
   *
   * Updates
   *  - 2.0.0: Added user preference support
   *  - 2.1.2: Fixed issue when calling set_level with the same client_id multiple times
   *
   * @author Tyler Muth
   * @created ???
   *
   * @param p_pref_name
   */
	function get_pref(
		p_pref_name		in	varchar2)
		return varchar2
		$IF not dbms_db_version.ver_le_10_2  $THEN
			result_cache
      $IF $$NO_OP is null or NOT $$NO_OP $THEN
        relies_on (logger_prefs, logger_prefs_by_client_id)
      $END
		$END
	is
    l_scope varchar2(30) := 'get_pref';
    l_pref_value logger_prefs.pref_value%type;
	begin
    $IF $$NO_OP $THEN
        null;
    $ELSE
      $IF $$LOGGER_DEBUG $THEN
        dbms_output.put_line(l_scope || ' select pref');
      $END
      
      select pref_value
      into l_pref_value
      from (
        select pref_value, row_number () over (order by rank) rn
        from (
          -- Client specific logger levels trump system level logger level
          select 
            case 
              when p_pref_name = 'LEVEL' then logger_level
              when p_pref_name = 'INCLUDE_CALL_STACK' then include_call_stack
            end pref_value
          
          , 1 rank
          from logger_prefs_by_client_id
          where 1=1
            and client_id = sys_context('userenv','client_identifier')
            -- Only try to get prefs at a client level if pref is in LEVEL or INCLUDE_CALL_STACK
            and p_pref_name in ('LEVEL', 'INCLUDE_CALL_STACK')
          union
          -- System level configuration
          select pref_value, 2 rank
          from logger_prefs 
          where pref_name = p_pref_name
        )
      )
      where rn = 1;
      return l_pref_value;

    $END
  exception
    when no_data_found then
      return null;
    when others then
      raise;
	end get_pref;

  /**
   * Purges logger_logs data
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - #47 Support for overloading
   *
   * @author Martin D'Souza
   * @created 14-Jun-2014
   * @param p_purge_after_days
   * @param p_purge_min_level
   */
  procedure purge(
    p_purge_after_days in number default null,
    p_purge_min_level in number)

  is
    $IF $$NO_OP is null or NOT $$NO_OP $THEN
      l_purge_after_days number := nvl(p_purge_after_days,get_pref('PURGE_AFTER_DAYS'));
    $END
    pragma autonomous_transaction;
  begin
    $IF $$NO_OP $THEN
      null;
    $ELSE

      if admin_security_check then
        delete
          from logger_logs
         where logger_level >= p_purge_min_level
           and time_stamp < systimestamp - NUMTODSINTERVAL(l_purge_after_days, 'day')
           and logger_level > g_permanent;
      end if;
    $END
    commit;
  end purge;


	procedure purge(
		p_purge_after_days in varchar2 default null,
		p_purge_min_level	in varchar2	default null)

	is
	begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      purge(
        p_purge_after_days => to_number(p_purge_after_days),
        p_purge_min_level => convert_level_char_to_num(nvl(p_purge_min_level,get_pref('PURGE_MIN_LEVEL'))));
    $END
	end purge;


	procedure purge_all
	is
		l_purge_level	number	:= g_permanent;
    pragma autonomous_transaction;
	begin
    $IF $$NO_OP $THEN
      null;
    $ELSE
      if admin_security_check then
          delete from logger_logs where logger_level > l_purge_level;
      end if;
    $END
    commit;
  end purge_all;

	procedure status(
		p_output_format	in varchar2 default null) -- SQL-DEVELOPER | HTML | DBMS_OUPUT
	is
		l_debug			varchar2(50) := 'Disabled';

		l_apex			varchar2(50) := 'Disabled';
		l_flashback		varchar2(50) := 'Disabled';
		dummy			varchar2(255);
		l_output_format	varchar2(30);
    l_version       varchar2(20);
    l_client_identifier logger_prefs_by_client_id.client_id%type;
    
    -- For current client info
    l_cur_logger_level logger_prefs_by_client_id.logger_level%type;
    l_cur_include_call_stack logger_prefs_by_client_id.include_call_stack%type;
    l_cur_expiry_date logger_prefs_by_client_id.expiry_date%type;

		procedure display_output(
			p_name	in varchar2,
			p_value	in varchar2)
		is
		begin
			if l_output_format = 'SQL-DEVELOPER' then
				dbms_output.put_line('<pre>'||rpad(p_name,25)||': <strong>'||p_value||'</strong></pre>');
			elsif l_output_format = 'HTTP' then
				htp.p('<br />'||p_name||': <strong>'||p_value||'</strong>');
			else
				dbms_output.put_line(rpad(p_name,25)||': '||p_value);
			end if;
		end display_output;

	begin
		if p_output_format is null then
			begin
				dummy := owa_util.get_cgi_env('HTTP_HOST');
				l_output_format	:= 'HTTP';
			exception
				when VALUE_ERROR then
				l_output_format	:= 'DBMS_OUTPUT';
				dbms_output.enable;
			end;
		else
			l_output_format := p_output_format;
		end if;

    display_output('Project Home Page','https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/');

    $IF $$NO_OP $THEN
      display_output('Debug Level','NO-OP, Logger completely disabled.');
    $ELSE
      $IF $$APEX $THEN
          l_apex := 'Enabled';
      $END

      for c1 in (select pref_value from logger_prefs where pref_name = 'LEVEL')
      loop
        l_debug := c1.pref_value;
      end loop; --c1

      $IF $$FLASHBACK_ENABLED $THEN
        l_flashback := 'Enabled';
      $END

      l_version := get_pref('LOGGER_VERSION');

      display_output('Logger Version',l_version);
      display_output('Debug Level',l_debug);
      display_output('Capture Call Stack',get_pref('INCLUDE_CALL_STACK'));
      display_output('Protect Admin Procedures',get_pref('PROTECT_ADMIN_PROCS'));
      display_output('APEX Tracing',l_apex);
      display_output('SCN Capture',l_flashback);
      display_output('Min. Purge Level',get_pref('PURGE_MIN_LEVEL'));
      display_output('Purge Older Than',get_pref('PURGE_AFTER_DAYS')||' days');
      display_output('Pref by client_id expire hours',get_pref('PREF_BY_CLIENT_ID_EXPIRE_HOURS')||' hours');
      $IF $$RAC_LT_11_2  $THEN
        display_output('RAC pre-11.2 Code','TRUE');
      $END
      
      
      l_client_identifier := sys_context('userenv','client_identifier');
      if l_client_identifier is not null then
        -- Since the client_identifier exists, try to see if there exists a record session sepecfic logging level
        -- Note: this query should only return 0..1 rows
        begin
          select logger_level, include_call_stack, expiry_date
          into l_cur_logger_level, l_cur_include_call_stack, l_cur_expiry_date
          from logger_prefs_by_client_id
          where client_id = l_client_identifier;
          
          display_output('Client Identifier', l_client_identifier);
          display_output('Client - Debug Level', l_cur_logger_level);
          display_output('Client - Call Stack', l_cur_include_call_stack);
          display_output('Client - Expiry Date', to_char(l_cur_expiry_date, gc_date_format));
        exception
          when no_data_found then
            null; -- No client specific logging set
          when others then
            raise;
        end;
      end if; -- client_identifier exists
      
      display_output('For all client info see', 'logger_prefs_by_client_id');
      
    $END
	end status;

  -- Valid values for p_level are:
  -- 
  /**
   * Sets the logger level
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - #59 Allow security check to be bypassed for client specific logging level
   *  - #47 Allow of numbers to be passed in p_level. Did not overload (see ticket comments as to why)
   *
   * 
   * @author Tyler Muth
   * @created ???
   *
   * @param p_level Valid values: OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING
   * @param p_client_id Optional: If defined, will set the level for the given client identifier. If null will affect global settings
   * @param p_include_call_stack Optional: Only valid if p_client_id is defined Valid values: TRUE, FALSE. If not set will use the default system pref in logger_prefs.
   * @param p_client_id_expire_hours If p_client_id, expire after number of hours. If not defined, will default to system preference PREF_BY_CLIENT_ID_EXPIRE_HOURS 
   */
  procedure set_level(
    p_level in varchar2 default logger.g_debug_name,
    p_client_id in varchar2 default null,
    p_include_call_stack in varchar2 default null,
    p_client_id_expire_hours in number default null
  )
  is
    l_level varchar2(20);
    l_ctx varchar2(2000);
    l_old_level varchar2(20);
    l_include_call_stack varchar2(255);
    l_client_id_expire_hours number;
    l_expiry_date logger_prefs_by_client_id.expiry_date%type;
    pragma autonomous_transaction;
  begin
    $IF $$NO_OP $THEN
      raise_application_error (-20000,
          'Either the NO-OP version of Logger is installed or it is compiled for NO-OP,  so you cannot set the level.');
    $ELSE
      l_level := replace(upper(p_level),' ');

      if is_number(p_str => l_level) then
        l_level := convert_level_num_to_char(p_level => p_level);
      end if;

      l_include_call_stack := nvl(trim(upper(p_include_call_stack)), get_pref('INCLUDE_CALL_STACK'));
      
      assert(l_level in (g_off_name, g_permanent_name, g_error_name, g_warning_name, g_information_name, g_debug_name, g_timing_name, g_sys_context_name, g_apex_name),
        '"LEVEL" must be one of the following values: OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING,SYS_CONTEXT,APEX');
      assert(l_include_call_stack in ('TRUE', 'FALSE'), 'l_include_call_stack must be TRUE or FALSE');

      -- #59 Allow security check to be bypassed for client specific logging level
      if p_client_id is not null or admin_security_check then
        l_ctx := 'Host: '||sys_context('USERENV','HOST');
        l_ctx := l_ctx || ', IP: '||sys_context('USERENV','IP_ADDRESS');
        l_ctx := l_ctx || ', TERMINAL: '||sys_context('USERENV','TERMINAL');
        l_ctx := l_ctx || ', OS_USER: '||sys_context('USERENV','OS_USER');
        l_ctx := l_ctx || ', CURRENT_USER: '||sys_context('USERENV','CURRENT_USER');
        l_ctx := l_ctx || ', SESSION_USER: '||sys_context('USERENV','SESSION_USER');
  
        -- Separate updates/inserts for client_id or global settings
        if p_client_id is not null then
          l_client_id_expire_hours := nvl(p_client_id_expire_hours, get_pref('PREF_BY_CLIENT_ID_EXPIRE_HOURS'));
          l_expiry_date := sysdate + l_client_id_expire_hours/24;
          
          merge into logger_prefs_by_client_id ci 
          using (select p_client_id client_id from dual) s
            on (ci.client_id = s.client_id)
          when matched then update
            set logger_level = l_level,
              include_call_stack = l_include_call_stack,
              expiry_date = l_expiry_date,
              created_date = sysdate
          when not matched then
            insert(ci.client_id, ci.logger_level, ci.include_call_stack, ci.created_date, ci.expiry_date)
            values(p_client_id, l_level, l_include_call_stack, sysdate, l_expiry_date)
          ;
          
        else
          -- Global settings
          l_old_level := logger.get_pref('LEVEL');
          update logger_prefs set pref_value = l_level where pref_name = 'LEVEL';
        end if;
        
        logger.save_global_context(
          p_attribute => gc_ctx_attr_level,
          p_value => logger.convert_level_char_to_num(l_level),
          p_client_id => p_client_id);
          
        if p_client_id is not null then
          logger.save_global_context(
            p_attribute => gc_ctx_attr_include_call_stack,
            p_value => l_include_call_stack,
            p_client_id => p_client_id);
          
        else
          logger.log_information('Log level set to ' || l_level || ' for client_id: ' || p_client_id || ' include_call_stack=' || l_include_call_stack || ' by ' || l_ctx);
        end if;
        
      end if;
    $END
    commit;
  end set_level;
  
  
  /**
   * Unsets a logger level for a given client_id
   * This will only unset for client specific logger levels
   * Note: An explicit commit will occur in this procedure
   *
   * @author Martin D'Souza
   * @created 6-Apr-2013
   *
   * @param p_client_id Client identifier (case sensitive) to unset logger level in.
   */
  procedure unset_client_level(p_client_id in varchar2)
  as
  begin
    $IF $$NO_OP $THEN
      null;
  
    $ELSE
      assert(p_client_id is not null, 'p_client_id is a required value');
      
      -- Remove from client specific table
      delete from logger_prefs_by_client_id
      where client_id = p_client_id;
      
      -- Remove context values
      dbms_session.clear_context(
       namespace => g_context_name,
       client_id => p_client_id,
       attribute => gc_ctx_attr_level);
      
      dbms_session.clear_context(
       namespace => g_context_name,
       client_id => p_client_id,
       attribute => gc_ctx_attr_include_call_stack);

    $END    
    
    commit;
  end unset_client_level;
  
  
  /**
   * Unsets client_level that are stale (i.e. past thier expiry date)
   *
   * @author Martin D'Souza
   * @created 7-Apr-2013
   *
   * @param p_unset_after_hours If null then preference UNSET_CLIENT_ID_LEVEL_AFTER_HOURS
   */
  procedure unset_client_level
  as
  begin
    
    for x in (
      select client_id
      from logger_prefs_by_client_id
      where sysdate > expiry_date) loop
      
      unset_client_level(p_client_id => x.client_id);
    end loop;
  end unset_client_level;
  
  
  /**
   * Unsets all client specific preferences
   * An implicit commit will occur as unset_client_level makes a commit
   *
   * @author Martin D'Souza
   * @created 7-Apr-2013
   *
   */
  procedure unset_client_level_all
  as
  begin
  
    for x in (select client_id from logger_prefs_by_client_id) loop
      unset_client_level(p_client_id => x.client_id);
    end loop;
    
  end unset_client_level_all;
  
 
  procedure sqlplus_format
  is
  begin
    execute immediate 'begin dbms_output.enable(1000000); end;';
    dbms_output.put_line('set linesize 200');
    dbms_output.put_line('set pagesize 100');

    dbms_output.put_line('column id format 999999');
    dbms_output.put_line('column text format a75');
    dbms_output.put_line('column call_stack format a100');
    dbms_output.put_line('column extra format a100');

  end sqlplus_format;
  

  /**
   * Converts parameter to varchar2
   *
   * Notes:
   *  - As this function could be useful for non-logging purposes will not apply a NO_OP to it for conditional compilation
   *
   * Related Tickets:
   *  - #67
   *
   * @author Martin D'Souza
   * @created 07-Jun-2014
   * @param p_value
   * @return varchar2 value for p_value
   */
  function tochar(
    p_val in number)
    return varchar2
  as
  begin
    return to_char(p_val); 
  end tochar;

  function tochar(
    p_val in date)
    return varchar2
  as
  begin
    return to_char(p_val, gc_date_format);
  end tochar;

  function tochar(
    p_val in timestamp)
    return varchar2
  as
  begin
    return to_char(p_val, gc_timestamp_format);
  end tochar;

  function tochar(
    p_val in timestamp with time zone)
    return varchar2
  as
  begin
    return to_char(p_val, gc_timestamp_tz_format);
  end tochar;

  function tochar(
    p_val in timestamp with local time zone)
    return varchar2
  as
  begin
    return to_char(p_val, gc_timestamp_tz_format);
  end tochar;

  function tochar(
    p_val in boolean)
    return varchar2
  as
  begin
    return case when p_val then 'TRUE' else 'FALSE' end;
  end tochar;



  -- Handle Parameters
  
  /**
   * Append parameter to table of parameters
   * Nothing is actually logged in this procedure
   * This procedure is overloaded
   *
   * Related Tickets:
   *  - #67: Updated to reference tochar functions
   *
   * @author Martin D'Souza
   * @created 19-Jan-2013
   *
   * @param p_params Table of parameters (param will be appended to this)
   * @param p_name Name
   * @param p_val Value in its format. Will be converted to string
   */
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in varchar2
  )
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      l_param.name := p_name;
      l_param.val := p_val;
      p_params(p_params.count + 1) := l_param;
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in number)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in date)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with time zone)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with local time zone)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in boolean)
  as
    l_param logger.rec_param;
  begin
     $IF $$NO_OP $THEN
      null;
    $ELSE
      logger.append_param(p_params => p_params, p_name => p_name, p_val => logger.tochar(p_val => p_val));
    $END  
  end append_param;


  

  
  
  /**
   * Handles inserts into LOGGER_LOGS.
   *
   * Replaces trigger for both performance issues and to be a single location for all insert statements
   *
   * autonomous_transaction so commit will be performed after insert
   *
   * @author Martin D'Souza
   * @created 30-Jul-2013
   *
   * Related Issues
   *  - #31: Initial ticket
   *  - #50: Added SID column
   *  - #69: Fixed missing no_op flag
   *
   * @param p_logger_level
   * @param p_text
   * @param p_scope
   * @param p_call_stack
   * @param p_unit_name
   * @param p_line_no
   * @param p_extra
   * @param po_id ID entered into logger_logs for this record
   */
  procedure ins_logger_logs(
    p_logger_level in logger_logs.logger_level%type,
    p_text in varchar2 default null, -- Not using type since want to be able to pass in 32767 characters
    p_scope in logger_logs.scope%type default null,
    p_call_stack in logger_logs.call_stack%type default null,
    p_unit_name in logger_logs.unit_name%type default null,
    p_line_no in logger_logs.line_no%type default null, 
    p_extra in logger_logs.extra%type default null,
    po_id out nocopy logger_logs.id%type
    )
  as
    pragma autonomous_transaction;
    
    l_id logger_logs.id%type;
    l_text varchar2(32767) := p_text;
    l_extra logger_logs.extra%type := p_extra;
    
    l_tmp_clob clob;

  begin
    $if $$no_op $then
      null;
    $else

      -- Using select into to support version older than 11gR1 (see Issue 26)
      select logger_logs_seq.nextval 
      into po_id 
      from dual;
      
      -- 2.1.0: If text is > 4000 characters, it will be moved to the EXTRA column (Issue 17)
      $IF $$LARGE_TEXT_COLUMN $THEN -- Only check for moving to Clob if small text column
        -- Don't do anything since column supports large text
      $ELSE 
        if length(l_text) > 4000 then
          if l_extra is null then
            l_extra := l_text;
          else
            -- Using temp clob for performance purposes: http://www.talkapex.com/2009/06/how-to-quickly-append-varchar2-to-clob.html
            l_tmp_clob := gc_line_feed || gc_line_feed || '*** Content moved to EXTRA column ***' || gc_line_feed;
            l_extra := l_extra || l_tmp_clob;
            l_tmp_clob := l_text;
            l_extra := l_extra || l_text;
          end if; -- l_extra is not null
    
          l_text := 'Text moved to EXTRA column';
        end if; -- length(l_text)
      $END
      
      insert into logger_logs(
        id, logger_level, text,
        time_stamp, scope, module, 
        action, 
        user_name, 
        client_identifier,
        call_stack, unit_name, line_no , 
        scn, 
        extra,
        sid
        ) 
       values(
         po_id, p_logger_level, l_text,
         systimestamp, lower(p_scope), sys_context('userenv','module'), 
         sys_context('userenv','action'), 
         nvl($IF $$APEX $THEN apex_application.g_user $ELSE user $END,user), 
         sys_context('userenv','client_identifier'),
         p_call_stack, upper(p_unit_name), p_line_no, 
         null, 
         l_extra,
         to_number(sys_context('userenv','sid'))
         );
    $end
    
    commit;
  end ins_logger_logs;


  /**
   * Does string replacement similar to C printf
   *
   * Notes:
   *  - 
   *
   * Related Tickets:
   *  - #32: Also see #58
   *
   * @author Martin D'Souza
   * @created 15-Jun-2014
   * @param p_msg Messsage to format using %s and %d replacement strings
   * @param p_s1
   * @param p_s2
   * @param p_s3
   * @param p_s4
   * @param p_s5
   * @param p_s6
   * @param p_s7
   * @param p_s8
   * @param p_s9
   * @param p_s10
   * @return p_msg with strings replaced
   */
  -- TODO mdsouza: What do we call this? get_fmt_msg, printf, f, getf ?
  -- TODO mdsouza: 
  -- 3 ways to do this: 
  -- 1 Function to generate string.
  -- 2 generic funciton with parameters of scope and level, 
  -- 3 expand logger.log function (or rename to handle each type.
  -- TODO mdsouza: Documentation on this
  function get_fmt_msg(
    p_msg in varchar2,
    p_s01 in varchar2 default null,
    p_s02 in varchar2 default null,
    p_s03 in varchar2 default null,
    p_s04 in varchar2 default null,
    p_s05 in varchar2 default null,
    p_s06 in varchar2 default null,
    p_s07 in varchar2 default null,
    p_s08 in varchar2 default null,
    p_s09 in varchar2 default null,
    p_s10 in varchar2 default null)
    return varchar2
  as
    l_return varchar2(4000);
    l_count pls_integer;
    g_substring_regexp constant varchar2(10) := '(%s|%d)';

  begin
    $if $$no_op $then
      null;
    $else
      
      $if $$logger_utl_lms $then
        -- True printf functionality (if supported): http://vbegun.blogspot.ca/2005/10/simple-plsql-printf.html
        -- Note: Did performance tests and using sys.utl_lms is faster then custom code below.
        l_return := sys.utl_lms.format_message(p_msg,p_s01, p_s02, p_s03, p_s04, p_s05, p_s06, p_s07, p_s08, p_s09, p_s10);
      $else
        l_return := p_msg;
        l_count := regexp_count(l_return, g_substring_regexp, 1, 'c');

        for i in 1..l_count loop 
          l_return := regexp_replace(l_return, g_substring_regexp, 
            case
              when i = 1 then p_s01
              when i = 2 then p_s02
              when i = 3 then p_s03
              when i = 4 then p_s04
              when i = 5 then p_s05
              when i = 6 then p_s06
              when i = 7 then p_s07
              when i = 8 then p_s08
              when i = 9 then p_s09
              when i = 10 then p_s10
              else null
            end, 
            1,1,'c');
        end loop;
      $end -- $$logger_utl_lms

    $end -- $$no_op

    return l_return;

  end get_fmt_msg;  
  
  procedure print(
    aSessionId in integer := null,
    aNumberRows in integer := null)
  is
  begin
    $if not $$RAC_LT_11_2 $then
      dbms_output.put_line('RAC_LT_11_2');
    $else
      dbms_output.put_line('ELSE');
    $end
  end;  
    
  
  
end logger;
/
