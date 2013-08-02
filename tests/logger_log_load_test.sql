set serveroutput on
set timing on
set verify off

define param_text_size = '&1'
define param_iterations = '&2'

declare
  l_user varchar2(255);
  l_text varchar2(32767);

  l_text_size pls_integer := &param_text_size;
  l_iterations pls_integer := &param_iterations;
  l_extra clob;

begin
  for i in 1..l_text_size loop
    l_text := l_text || 'a';
  end loop;

  -- Add text to Extra to test appending 
  if length(l_text) > 4000 then
    l_extra := l_text;
  end if;
  
  for i in 1..l_iterations loop
    logger.log(l_text, null, l_extra);
  end loop;
end;
/
