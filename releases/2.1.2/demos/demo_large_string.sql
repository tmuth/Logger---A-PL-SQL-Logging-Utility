declare 
  l_scope logger_logs.scope%type := 'demo.large_string';
  
  l_str varchar2(32767);
  l_str_length pls_integer := 4001;
begin

  -- Build string size
  for i in 1..l_str_length loop
    l_str := l_str || 'a';
  end loop;
  
  logger.log(l_str, l_scope);
  
end;
/

select *
from logger_logs
where 1=1
  and scope = 'demo.large_string'
order by 1 desc;
