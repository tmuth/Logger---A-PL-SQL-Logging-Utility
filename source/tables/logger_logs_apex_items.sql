-- Initial table script built from 1.4.0
declare
  l_count pls_integer;
  l_nullable user_tab_columns.nullable%type;

  type typ_required_columns is table of varchar2(30) index by pls_integer;
  l_required_columns typ_required_columns;

begin

  -- Create Table
  select count(1)
  into l_count
  from user_tables
  where table_name = 'LOGGER_LOGS_APEX_ITEMS';

  if l_count = 0 then
    execute immediate '
create table logger_logs_apex_items(
    id				number not null,
    log_id          number not null,
    app_session     number not null,
    item_name       varchar2(1000) not null,
    item_value      clob,
    constraint logger_logs_apx_itms_pk primary key (id) enable,
    constraint logger_logs_apx_itms_fk foreign key (log_id) references logger_logs(id) ON DELETE CASCADE
)
    ';
  end if;


  $if $$logger_no_op_install $then
    null;
  $else
    -- SEQUENCE
    select count(1)
    into l_count
    from user_sequences
    where sequence_name = 'LOGGER_APX_ITEMS_SEQ';

    if l_count = 0 then
      execute immediate '
  create sequence logger_apx_items_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
      ';
    end if;

    -- INDEXES
    select count(1)
    into l_count
    from user_indexes
    where index_name = 'LOGGER_APEX_ITEMS_IDX1';

    if l_count = 0 then
      execute immediate 'create index logger_apex_items_idx1 on logger_logs_apex_items(log_id)';
    end if;
  $end -- $$logger_no_op_install
end;
/


create or replace trigger biu_logger_apex_items
  before insert or update on logger_logs_apex_items
for each row
begin
  $if $$logger_no_op_install $then
    null;
  $else
    :new.id := logger_apx_items_seq.nextval;
  $end
end;
/
