set serveroutput on

create or replace procedure log_test_plugin(
  p_rec in logger.rec_logger_log)
as
  l_text logger_logs.text%type;
begin
  dbms_output.put_line('In Plugin');

  logger.log_error('Wont call plugin since recursion / infinite loop would occur');
end;
/

exec logger.set_level(p_level => logger.g_debug);

update logger_prefs
  set pref_value = 'log_test_plugin'
  where 1=1
    and pref_type = 'LOGGER'
    and pref_name = 'PLUGIN_FN_ERROR';

exec logger_configure;


declare
begin
  logger.log_error('test');
end;
/
