create or replace package logger
  authid definer
as
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
    p_extra         in clob default null);

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
end logger;