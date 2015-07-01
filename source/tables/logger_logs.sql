-- Initial table script built from 1.4.0
declare
  l_count pls_integer;
  l_nullable user_tab_columns.nullable%type;

  type typ_required_columns is table of varchar2(30) index by pls_integer;
  l_required_columns typ_required_columns;


  type typ_tab_col is record (
    column_name varchar2(30),
    data_type varchar2(100));
  type typ_arr_tab_col is table of typ_tab_col index by pls_integer;

  l_new_col typ_tab_col;
  l_new_cols typ_arr_tab_col;

begin
  -- Create Table
  select count(1)
  into l_count
  from user_tables
  where table_name = 'LOGGER_LOGS';

  if l_count = 0 then
    execute immediate '
create table logger_logs(
  id number,
  logger_level number,
  text varchar2(4000),
  time_stamp timestamp,
  scope varchar2(1000),
  module varchar2(100),
  action varchar2(100),
  user_name varchar2(255),
  client_identifier varchar2(255),
  call_stack varchar2(4000),
  unit_name varchar2(255),
  line_no varchar2(100),
  scn number,
  extra clob,
  constraint logger_logs_pk primary key (id) enable,
  constraint logger_logs_lvl_ck check(logger_level in (1,2,4,8,16,32,64,128))
)
    ';
  end if;

  -- 2.0.0
  l_required_columns(l_required_columns.count+1) := 'LOGGER_LEVEL';
  l_required_columns(l_required_columns.count+1) := 'TIME_STAMP';

  for i in l_required_columns.first .. l_required_columns.last loop

    select nullable
    into l_nullable
    from user_tab_columns
    where table_name = 'LOGGER_LOGS'
      and column_name = upper(l_required_columns(i));

    if l_nullable = 'Y' then
      execute immediate 'alter table logger_logs modify ' || l_required_columns(i) || ' not null';
    end if;
  end loop;


  -- 2.2.0
  -- Add additional columns
  -- #51
  l_new_col.column_name := 'SID';
  l_new_col.data_type := 'NUMBER';
  l_new_cols(l_new_cols.count+1) := l_new_col;

  -- #25
  l_new_col.column_name := 'CLIENT_INFO';
  l_new_col.data_type := 'VARCHAR2(64)'; -- taken from v$session.client_info
  l_new_cols(l_new_cols.count+1) := l_new_col;


  for i in 1 .. l_new_cols.count loop
    select count(1)
    into l_count
    from user_tab_columns
    where 1=1
      and table_name = 'LOGGER_LOGS'
      and column_name = l_new_cols(i).column_name;

    if l_count = 0 then
      execute immediate 'alter table LOGGER_LOGS add (' || l_new_cols(i).column_name || ' ' || l_new_cols(i).data_type || ')';
    end if;
  end loop;


  $if $$logger_no_op_install $then
    null;
  $else
    -- SEQUENCE
    select count(1)
    into l_count
    from user_sequences
    where sequence_name = 'LOGGER_LOGS_SEQ';

    if l_count = 0 then
      execute immediate '
        create sequence logger_logs_seq
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
    where index_name = 'LOGGER_LOGS_IDX1';

    if l_count = 0 then
      execute immediate 'create index logger_logs_idx1 on logger_logs(time_stamp,logger_level)';
    end if;
  $end

end;
/


-- TRIGGER (removed as part of 2.1.0 release)
-- Drop trigger if still exists (from pre-2.1.0 releases) - Issue #31
declare
  l_count pls_integer;
  l_trigger_name user_triggers.trigger_name%type := 'BI_LOGGER_LOGS';
begin
  select count(1)
  into l_count
  from user_triggers
  where 1=1
    and trigger_name = l_trigger_name;

  if l_count > 0 then
    execute immediate 'drop trigger ' || l_trigger_name;
  end if;
end;
/
