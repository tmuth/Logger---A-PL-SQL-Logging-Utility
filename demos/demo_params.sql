declare
  l_scope logger_logs.scope%type := 'demo.params';
  
  -- Simulates parameters 
  l_num number := 1;
  l_date date := sysdate;
  l_boolean boolean := false;
  
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'l_num', l_num);
  logger.append_param(l_params, 'l_date', l_date);
  logger.append_param(l_params, 'l_boolean', l_boolean);
  
  logger.log('START', l_scope, null, l_params);
  

  logger.log('END', l_scope);
end;
/



-- Look at the EXTRA column in the Start log
select *
from logger_logs
where 1=1
  and scope = 'demo.params'
order by 1 desc;


