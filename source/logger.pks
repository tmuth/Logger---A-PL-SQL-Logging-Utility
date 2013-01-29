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
  gc_empty_tab_param tab_param;
  
  -- VARIABLES
	g_logger_version    constant varchar2(10) := '1.4.0';
	g_context_name 		constant varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';

  g_permanent		    constant number := 1;
	g_error 		    constant number := 2;
	g_warning 		    constant number := 4;
	g_information	    constant number := 8;
  g_debug     	    constant number := 16;
	g_timing     	    constant number := 32;
  g_sys_context 	    constant number := 64;
  g_apex 	            constant number := 128;

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
    p_extra   in clob default null);

  procedure log_warning(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null);

  procedure log_information(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null);

  procedure log(
    p_text    in varchar2,
    p_scope   in varchar2 default null,
    p_extra   in clob default null);

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
		p_purge_after_days	in varchar2	default null,
		p_purge_min_level	in varchar2	default null);

	procedure purge_all;

	procedure status(
		p_output_format	in varchar2 default null); -- SQL-DEVELOPER | HTML | DBMS_OUPUT

  procedure sqlplus_format;

  -- Valid values for p_level are:
  -- OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING
  procedure set_level(p_level in varchar2 default 'DEBUG');
  
  
  procedure log_params(
    p_params in logger.tab_param,
    p_scope in logger_logs.scope%type);
  
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
end logger;