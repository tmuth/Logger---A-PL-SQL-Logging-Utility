whenever sqlerror exit
set serveroutput on

#SESSION PRIVILEGES
declare
    type t_sess_privs is table of pls_integer index by varchar2(50);
    l_sess_privs t_sess_privs;
    l_req_privs t_sess_privs;
    l_priv  varchar2(50);
    l_dummy pls_integer;
    l_priv_error  boolean := false;
begin
    l_req_privs('CREATE SESSION')       := 1;            
    l_req_privs('CREATE TABLE')         := 1;
    l_req_privs('CREATE VIEW')          := 1;
    l_req_privs('CREATE SEQUENCE')      := 1;
    l_req_privs('CREATE PROCEDURE')     := 1;
    l_req_privs('CREATE TRIGGER')       := 1;
    l_req_privs('CREATE ANY CONTEXT')   := 1;
    l_req_privs('CREATE JOB')           := 1;


    for c1 in (select privilege from session_privs)
    loop
        l_sess_privs(c1.privilege) := 1;
    end loop;  --c1

    dbms_output.put_line('_____________________________________________________________________________');
    
    l_priv := l_req_privs.first;
    loop
    exit when l_priv is null;
        begin
            l_dummy := l_sess_privs(l_priv);
        exception when no_data_found then
            dbms_output.put_line('Error, the current schema is missing the following privilege: '||l_priv);
            l_priv_error := true;
        end;
        l_priv := l_req_privs.next(l_priv);
    end loop;
    
    if not l_priv_error then
        dbms_output.put_line('User has all required privileges, installation will continue.');
    end if;
    
    dbms_output.put_line('_____________________________________________________________________________');

    if l_priv_error then
      raise_application_error (-20000, 'One or more required privileges are missing.');
    end if;
end;
/

whenever sqlerror continue

#*** DDL START ***
# The DDL base tables are based of 1.4.0
# All other changes should be added as ALTER statements



#*** LOGGER_LOGS_APEX_ITEMS ***
create table logger_logs_apex_items(
    id				number not null,
    log_id          number not null,
    app_session     number not null,
    item_name       varchar2(1000) not null,
    item_value      clob,
    constraint logger_logs_apx_itms_pk primary key (id) enable,
    constraint logger_logs_apx_itms_fk foreign key (log_id) references logger_logs(id) ON DELETE CASCADE
)
/

create index logger_apex_items_idx1 on logger_logs_apex_items(log_id)
/


create sequence logger_apx_items_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
/


create or replace trigger biu_logger_apex_items
  before insert or update on logger_logs_apex_items 
for each row 
begin
  :new.id := logger_apx_items_seq.nextval;
end;
/





