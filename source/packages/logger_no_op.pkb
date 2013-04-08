create or replace package body logger
as
  g_log_id    	number;
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
  type ts_array is table of timestamp index by varchar2(100);

  g_proc_start_times ts_array;
  g_running_timers        pls_integer := 0;


  function admin_security_check
    return boolean
  is
    l_protect_admin_procs	varchar2(50)	:= get_pref('PROTECT_ADMIN_PROCS');
    l_return                boolean default false;
  begin
    if get_pref('PROTECT_ADMIN_PROCS') = 'TRUE' then
      if get_pref('INSTALL_SCHEMA') = sys_context('USERENV','SESSION_USER') then
        l_return := true;
      else
        l_return := false;
        raise_application_error (-20000, 'You are not authorized to call this procedure.');
      end if;
    else
      l_return := true;
    end if;
    
    return l_return;
  end admin_security_check;


  procedure null_global_contexts
  is
    pragma autonomous_transaction;
  begin
    null;
    commit;
  end null_global_contexts;
  
  procedure save_global_context(
    p_attribute     in varchar2,
    p_value         in varchar2)
  is
    pragma autonomous_transaction;
  begin
    null;
  end save_global_context;
  
  
  function convert_level_char_to_num(
    p_level in varchar2)
    return number
  is
    l_level         number;
  begin
    case p_level
      when 'OFF'          then l_level := 0;
      when 'PERMANENT'    then l_level := 1;
      when 'ERROR'        then l_level := 2;
      when 'WARNING'      then l_level := 4;
      when 'INFORMATION'  then l_level := 8;
      when 'DEBUG'        then l_level := 16;
      when 'TIMING'       then l_level := 32;
      when 'SYS_CONTEXT'  then l_level := 64;
      else l_level := -1;
    end case;
    return l_level;
  end convert_level_char_to_num;


  function get_level_number
    return number
  is
    l_level         number;
    l_level_char    varchar2(50);
  begin
    return 0;
  end get_level_number;


  function ok_to_log(p_level  in  number)
    return boolean
  is
    l_level         number;
    l_level_char    varchar2(50);
  begin
    return false;
  end ok_to_log;


  function include_call_stack
    return boolean
  is
    l_call_stack_pref   varchar2(50);
  begin
    return false;
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
o_lineno        out varchar2 ) as
--
l_callstack varchar2(3000) := p_callstack;
begin
l_callstack := substr( l_callstack, instr( l_callstack, chr(10), 1, 5 )+1 );
l_callstack := substr( l_callstack, 1, instr( l_callstack, chr(10), 1, 1 )-1 );
l_callstack := trim( substr( l_callstack, instr( l_callstack, ' ' ) ) );
o_lineno := substr( l_callstack, 1, instr( l_callstack, ' ' )-1 );
o_unit := trim(substr( l_callstack, instr( l_callstack, ' ', -1, 1 ) ));
end get_debug_info;
procedure  log_internal(
p_text				in varchar2,
p_log_level			in number,
p_scope             in varchar2,
p_extra             in clob default null,
p_callstack         in varchar2 default null)
	is
l_proc_name     	varchar2(100);
l_lineno        	varchar2(100);
l_text 				varchar2(4000);
l_callstack         varchar2(3000);
	begin
null;
	end log_internal;
procedure snapshot_apex_items(
p_log_id in number)
is
l_app_session number;
l_app_id       number;
begin
null;
end snapshot_apex_items;


  procedure log_error(
    p_text          in varchar2 default null,
    p_scope         in varchar2 default null,
    p_extra         in clob default null,
    p_params        in tab_param default logger.gc_empty_tab_param
    )
  is
    l_proc_name     varchar2(100);
    l_lineno        varchar2(100);
    l_text          varchar2(4000);
    pragma autonomous_transaction;
    l_call_stack    varchar2(4000);
  begin
    null;
	end log_error;
  
  
procedure log_permanent(p_text    in varchar2,
p_scope   in varchar2 default null,
p_extra   in clob default null)
	is
pragma autonomous_transaction;
	begin
null;
	end log_permanent;
procedure log_warning(p_text    in varchar2,
p_scope   in varchar2 default null,
p_extra   in clob default null)
	is
pragma autonomous_transaction;
	begin
null;
	end log_warning;
procedure log_information(p_text    in varchar2,
p_scope   in varchar2 default null,
p_extra   in clob default null)
	is
pragma autonomous_transaction;
	begin
null;
	end log_information;
	procedure log(p_text    in varchar2,
p_scope   in varchar2 default null,
p_extra   in clob default null)
	is
pragma autonomous_transaction;
	begin
null;
	end log;
function get_sys_context(p_detail_level in varchar2 default 'USER', -- ALL, NLS, USER, INSTANCE
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
exception when invalid_userenv_parm then
--log_warning('Invalid SYS_CONTEXT Parameter: '||p_name);
null;
end append_ctx;
begin
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
return null;
	end get_cgi_env;
procedure log_userenv(
p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
		p_show_null 	in boolean default false,
p_scope         in varchar2 default null)
is
		l_extra	clob;
pragma autonomous_transaction;
begin
null;
end log_userenv;
procedure log_cgi_env(
		p_show_null 	in boolean default false,
p_scope         in varchar2 default null)
is
		l_extra	clob;
pragma autonomous_transaction;
begin
null;
end log_cgi_env;
	procedure log_character_codes(
		p_text					in varchar2,
p_scope					in varchar2 default null,
		p_show_common_codes 	in boolean default true)
is
l_error varchar2(4000);
		l_dump clob;
	pragma autonomous_transaction;
begin
null;
	end log_character_codes;
	procedure log_apex_items(
		p_text		in varchar2 default 'Log APEX Items',
p_scope		in varchar2 default null)
is
l_error varchar2(4000);
	pragma autonomous_transaction;
begin
null;
commit;
end log_apex_items;
	
    
  procedure time_start(
		p_unit				in varchar2,
    p_log_in_table 	    IN boolean default true)
	is
		l_proc_name     	varchar2(100);
		l_text 				varchar2(4000);
    l_pad               varchar2(100);
		pragma autonomous_transaction;
	begin
    null;
	end time_start;
	
  
  procedure time_stop(
		p_unit				in varchar2,
    p_scope             in varchar2 default null)
	is
		l_time_string   	varchar2(50);
    l_text 				varchar2(4000);
    l_pad               varchar2(100);
    pragma autonomous_transaction;
  begin
    null;
  end time_stop;
  
  
  function time_stop(
    p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    IN boolean default true
    )
    return varchar2
  is    
  begin
    return null;
  end time_stop;
  
  
  function time_stop_seconds(
    p_unit				in varchar2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    in boolean default true
    )
    return number
  is
  begin
    return null;
  end time_stop_seconds;
      
  
procedure time_reset
is
begin
if ok_to_log(logger.g_debug) then
g_running_timers := 0;
g_proc_start_times.delete;
end if;
end time_reset;
	function get_pref(
		p_pref_name		in	varchar2)
		return varchar2
		
			result_cache
		
	is
	begin
null;
	end get_pref;
	procedure purge(
		p_purge_after_days	in varchar2	default null,
		p_purge_min_level	in varchar2	default null)
	is
		
pragma autonomous_transaction;
	begin
null;
commit;
	end purge;
	procedure purge_all
	is
		l_purge_level	number	:= g_permanent;
pragma autonomous_transaction;
	begin
null;
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
		procedure display_output(
			p_name	in varchar2,
			p_value	in varchar2)
		is
		begin
			if l_output_format = 'SQL-DEVELOPER' then
				dbms_output.put_line('<pre>'||rpad(p_name,20)||': <strong>'||p_value||'</strong></pre>');
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
display_output('Project Home Page','https://logger.samplecode.oracle.com/');
display_output('Debug Level','NO-OP, Logger completely disabled.');
	end status;
  
  
  -- Valid values for p_level are:
  -- OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING
  procedure set_level(
    p_level in varchar2 default 'DEBUG',
    p_client_id in varchar2 default null,
    p_include_call_stack in varchar2 default null,
    p_client_id_expire_hours in number default null
  )
  is
    l_level varchar2(20);
    l_ctx   varchar2(2000);
    l_old_level varchar2(20);
    pragma autonomous_transaction;
  begin
    raise_application_error (-20000, 'Either the NO-OP version of Logger is installed or it is compiled for NO-OP,  so you cannot set the level.');
    commit;
  end set_level;
  
  
  procedure unset_client_level(p_client_id in varchar2)
  is
  begin
    null;
  end unset_client_level;
  
  procedure unset_client_level
  is
  begin
    null;
  end unset_client_level;
  
  
  procedure unset_client_level_all
  as
  begin
    null;
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
  
  procedure log_params(
    p_params in logger.tab_param,
    p_scope in logger_logs.scope%type)
  is
  begin
    null;
  end log_params;
  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in varchar2)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in number)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in date)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with time zone)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with local time zone)
  is
  begin
    null;
  end append_param;
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in boolean)
  is
  begin
    null;
  end append_param;
  
end logger;
/
