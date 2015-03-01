declare
  l_log boolean;
  l_log_str varchar2(255);
begin

  l_log := logger.ok_to_log(logger.g_warning); -- Just change this with the level you want to test

  if l_log then
    l_log_str := 'TRUE';
  else
    l_log_str := 'FALSE';
  end if;

  dbms_output.put_line('Ok to log? ' || l_log_str);

end;
/
