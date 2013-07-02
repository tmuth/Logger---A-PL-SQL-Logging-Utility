-- Post installation configuration tasks
begin
  logger_configure;
end;
/


-- Only set level if not in DEBUG mode
declare
  l_current_level logger_prefs.pref_value%type;
begin 

  select pref_value
  into l_current_level
  from logger_prefs
  where pref_name = 'LEVEL';
  
  -- Note: Probably not necessary but pre 1.4.0 code had this in place
  logger.set_level(l_current_level);  
end;
/

prompt 
prompt ************************************************* 
prompt Now executing LOGGER.STATUS...
prompt 

begin 
	logger.status; 
end;
/

prompt ************************************************* 
begin 
	logger.log_permanent('Logger version '||logger.get_pref('LOGGER_VERSION')||' installed.'); 
end;
/
