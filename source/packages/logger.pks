create or replace package logger
  authid definer
as
  -- This project using the following Revised BSD License:
  --
  -- Copyright (c) 2013, Tyler D. Muth, tylermuth.wordpress.com 
  -- and contributors to the project at 
  -- https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility
  -- All rights reserved.
  --
  -- Project Contributors
  --  - Martin Giffy D'Souza: http://www.talkapex.com
  -- 
  -- Redistribution and use in source and binary forms, with or without
  -- modification, are permitted provided that the following conditions are met:
  --     * Redistributions of source code must retain the above copyright
  --       notice, this list of conditions and the following disclaimer.
  --     * Redistributions in binary form must reproduce the above copyright
  --       notice, this list of conditions and the following disclaimer in the
  --       documentation and/or other materials provided with the distribution.
  --     * Neither the name of Tyler D Muth, nor Oracle Corporation, nor the
  --       names of its contributors may be used to endorse or promote products
  --       derived from this software without specific prior written permission.
  -- 
  -- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  -- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  -- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  -- DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  -- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  -- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  -- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  -- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  -- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  -- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  -- TYPES
  type rec_param is record(
    name varchar2(255),
    val varchar2(4000));
  
  type tab_param is table of rec_param index by binary_integer;
  
  -- VARIABLES
	g_logger_version constant varchar2(10) := 'x.x.x'; -- Don't change this. Build script will replace with right version number
	g_context_name constant varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';
  
  g_off constant number := 0;
  g_permanent constant number := 1;
	g_error constant number := 2;
	g_warning constant number := 4;
	g_information constant number := 8;
  g_debug constant number := 16;
	g_timing constant number := 32;
  g_sys_context constant number := 64;
  g_apex constant number := 128;

  -- #43
  g_off_name constant varchar2(30) := 'OFF';
  g_permanent_name constant varchar2(30) := 'PERMANENT';
  g_error_name constant varchar2(30) := 'ERROR';
  g_warning_name constant varchar2(30) := 'WARNING';
  g_information_name constant varchar2(30) := 'INFORMATION';
  g_debug_name constant varchar2(30) := 'DEBUG';
  g_timing_name constant varchar2(30) := 'TIMING';
  g_sys_context_name constant varchar2(30) := 'SYS_CONTEXT';
  g_apex_name constant varchar2(30) := 'APEX';

  gc_empty_tab_param tab_param;


  -- PROCEDURES and FUNCTIONS
  
  procedure null_global_contexts;

  function convert_level_char_to_num(
    p_level in varchar2)
    return number;

  function date_text_format (p_date in date)
    return varchar2;

	function get_character_codes(
		p_string 				in varchar2,
		p_show_common_codes 	in boolean default true)
    return varchar2;

  procedure log_error(
    p_text          in varchar2 default null,
    p_scope         in varchar2 default null,
    p_extra         in clob default null,
    p_params        in tab_param default logger.gc_empty_tab_param);

  procedure log_permanent(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param);

  procedure log_warning(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param);

  procedure log_information(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param);

  procedure log(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null,
    p_params  in tab_param default logger.gc_empty_tab_param);

  function get_cgi_env(
    p_show_null		in boolean default false)
  	return clob;

  procedure log_userenv(
    p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
    p_show_null 	in boolean default false,
    p_scope         in varchar2 default null);

  procedure log_cgi_env(
    p_show_null 	in boolean default false,
    p_scope         in varchar2 default null);

	procedure log_character_codes(
		p_text					in varchar2,
    p_scope					in varchar2 default null,
		p_show_common_codes 	in boolean default true);

  procedure log_apex_items(
		p_text		in varchar2 default 'Log APEX Items',
    p_scope		in varchar2 default null);

	procedure time_start(
		p_unit				in varchar2,
    p_log_in_table 	    IN boolean default true);

	procedure time_stop(
		p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null);
        
  function time_stop(
    p_unit				IN VARCHAR2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    IN boolean default true
    )
    return varchar2;
        
  function time_stop_seconds(
    p_unit				in varchar2,
    p_scope             in varchar2 default null,
    p_log_in_table 	    in boolean default true
    )
    return number;

  procedure time_reset;

	function get_pref(
		p_pref_name			in	varchar2)
    return varchar2
    $IF not dbms_db_version.ver_le_10_2 $THEN
      result_cache
    $END
    ;

	procedure purge(
		p_purge_after_days in varchar2 default null,
		p_purge_min_level	in varchar2	default null);

  procedure purge(
    p_purge_after_days in number default null,
    p_purge_min_level in number);

	procedure purge_all;

	procedure status(
		p_output_format	in varchar2 default null); -- SQL-DEVELOPER | HTML | DBMS_OUPUT

  procedure sqlplus_format;

  procedure set_level(
    p_level in varchar2 default logger.g_debug_name,
    p_client_id in varchar2 default null,
    p_include_call_stack in varchar2 default null,
    p_client_id_expire_hours in number default null
  );

  procedure set_level(
    p_level in number,
    p_client_id in varchar2 default null,
    p_include_call_stack in varchar2 default null,
    p_client_id_expire_hours in number default null
  );
    
  procedure unset_client_level(p_client_id in varchar2);
  
  procedure unset_client_level;
  
  procedure unset_client_level_all;


  function tochar(
    p_val in number)
    return varchar2;

  function tochar(
    p_val in date)
    return varchar2;

  function tochar(
    p_val in timestamp)
    return varchar2;

  function tochar(
    p_val in timestamp with time zone)
    return varchar2;

  function tochar(
    p_val in timestamp with local time zone)
    return varchar2;

  function tochar(
    p_val in boolean)
    return varchar2;


  
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in varchar2);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in number);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in date);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with time zone);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in timestamp with local time zone);
    
  procedure append_param(
    p_params in out nocopy logger.tab_param,
    p_name in varchar2,
    p_val in boolean);

  function ok_to_log(p_level in number)
    return boolean;
    
  function ok_to_log(p_level in varchar2)
    return boolean;
    
  procedure ins_logger_logs(
    p_logger_level in logger_logs.logger_level%type,
    p_text in varchar2 default null, -- Not using type since want to be able to pass in 32767 characters
    p_scope in logger_logs.scope%type default null,
    p_call_stack in logger_logs.call_stack%type default null,
    p_unit_name in logger_logs.unit_name%type default null,
    p_line_no in logger_logs.line_no%type default null, 
    p_extra in logger_logs.extra%type default null,
    po_id out nocopy logger_logs.id%type
  );
  
  
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
    return varchar2;
end logger;
/