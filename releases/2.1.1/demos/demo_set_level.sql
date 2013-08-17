-- Logger demo file

exec logger.set_level('DEBUG');

exec logger.log('test, this should show up');

select *
from logger_logs_5_min
order by id desc;

exec logger.set_level ('ERROR');

exec logger.log('test, this should not show up');

select *
from logger_logs_5_min
order by id desc;

-- In a different client run the following

exec dbms_session.set_identifier('logger_demo_session');

exec logger.set_level('DEBUG', sys_context('userenv','client_identifier'));

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