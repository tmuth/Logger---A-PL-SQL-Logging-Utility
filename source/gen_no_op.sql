set sqlprompt ''
set feedback off
set linesize 200
set serverout on
set termout off

alter package logger compile body PLSQL_CCFLAGS='NO_OP:TRUE';

spool logger_no_op.pkb

prompt create or replace

begin
    dbms_preprocessor.print_post_processed_source (
       object_type    => 'PACKAGE BODY',
       schema_name    => USER,
       object_name    => 'LOGGER');
end;
/

prompt /

spool off

alter package logger compile body PLSQL_CCFLAGS='NO_OP:FALSE';

exit
