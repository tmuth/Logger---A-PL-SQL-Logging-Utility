declare
  l_params logger.tab_param;
  l_param logger.rec_param;
  l_param2 logger.rec_param;
begin
  l_param.name := 'testname';
  l_param.val := 'val';
  l_params(1) := l_param;
  
  -- Testing non-sequential parameters
  l_param2.name := 'test2';
  l_param2.val := 'val';
  l_params(5) := l_param2;
  
  logger.log('test', 'test',null, l_params);
end;
/