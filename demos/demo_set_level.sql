-- Logger demo file

exec logger.set_level(logger.g_debug);

exec logger.log('test, this should show up');

select *
from logger_logs_5_min
order by id desc;

exec logger.set_level (logger.g_error);

exec logger.log('test, this should not show up');

select *
from logger_logs_5_min
order by id desc;

-- In a different client run the following

exec dbms_session.set_identifier('logger_demo_session');

exec logger.set_level(logger.g_debug, sys_context('userenv','client_identifier'));

exec logger.log('test, this should show up for client_id: ' || sys_context('userenv','client_identifier'));

select *
from logger_logs_5_min
order by id desc;

-- In main client run the following

exec logger.log('this should not show up since the global config is error');

select *
from logger_logs_5_min
order by id desc;


-- In other client clear identifier to return to global config

exec dbms_session.clear_identifier;


-- Unset all client specific level settings
exec logger.unset_client_level_all;



-- TODO move to seperate file?
-- How does this work for batches?

create or replace procedure run_long_batch(
  p_client_id in varchar2,
  p_iterations in pls_integer)
as
  l_params logger.tab_param;
  l_scope logger_logs.scope%type := 'run_long_batch';
begin
  logger.append_param(l_params, 'p_client_id', p_client_id);
  logger.append_param(l_params, 'p_iterations', p_iterations);
  logger.log('START', l_scope, null, l_params);

  dbms_session.set_identifier(p_client_id);

  for i in 1..p_iterations loop
    logger.log('i: ' || i, l_scope);
    dbms_lock.sleep(1);
  end loop;

  logger.log('END');

end run_long_batch;
/


-- Setup
begin
  delete from logger_logs;
  logger.set_level(logger.g_error); -- Simulates Production
  logger.unset_client_level_all;
  commit;
end;
/

-- In SQL Plus
begin
  run_long_batch(p_client_id => 'in_sqlplus', p_iterations => 50);
end;
/


-- In SQL Dev
exec logger.set_level(logger.g_debug, 'in_sqlplus');

exec logger.unset_client_level('in_sqlplus');

exec logger.set_level(logger.g_debug, 'in_sqlplus');

exec logger.unset_client_level('in_sqlplus');

select logger_level, line_no, text, time_stamp, scope
from logger_logs
order by id
;

-- Reset Logging Level
exec logger.set_level(logger.g_debug);
