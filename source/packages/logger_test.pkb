create or replace package body logger_test
as

  -- CONTANTS
  c_line_feed constant varchar2(1) := chr(10);
  c_unknown_err constant varchar2(50) := 'Unknown error';

  -- GLOBAL VARIABLES
  g_proc_name varchar2(30); -- current proc name being tested


  -- UTILITY PROCS
  procedure util_add_error(
    p_error in varchar2)
  as
    l_err logger_test.rec_error;
  begin
    l_err.proc_name := g_proc_name;
    l_err.error := p_error;
    g_errors(g_errors.count + 1) := l_err;
  end util_add_error;

  /**
   * Setups test
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_test_setup
  as
    table_does_not_exist exception;
    pragma exception_init(table_does_not_exist, -942);
  begin
    -- Drop table if it still exists
    begin
      execute immediate 'drop table logger_prefs_tmp';
    exception
      when table_does_not_exist then
        null;
    end;

    -- Create temp logger_prefs table
    execute immediate 'create table logger_prefs_tmp as select * from logger_prefs';

    -- Reset client_id
    dbms_session.set_identifier(null);
  end util_test_setup;


  /**
   * Setups test
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_test_teardown
  as
    l_count pls_integer;
  begin
    -- Make sure logger_prefs_tmp table exists
    select count(1)
    into l_count
    from user_tables
    where table_name = 'LOGGER_PREFS_TMP';

    if l_count = 1 then

      delete from logger_prefs;

      -- Need to do an execute immediate here since logger_prefs_tmp doesn't always exist
      execute immediate 'insert into logger_prefs select * from logger_prefs_tmp';

      execute immediate 'drop table logger_prefs_tmp';
    end if;

    dbms_session.set_identifier(null);

  end util_test_teardown;


  /**
   * Displays errors
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_display_errors
  as
    l_index pls_integer;
  begin

    if g_errors.count > 0 then
      dbms_output.put_line('*** ERRORS ***');

      l_index := g_errors.first;

      while true loop
        dbms_output.put_line(g_errors(l_index).proc_name || ': ' || g_errors(l_index).error);

        l_index := g_errors.next(l_index);

        if l_index is null then
          exit;
        end if;
      end loop;
    else
      dbms_output.put_line('No errors.');
    end if;
  end util_display_errors;


  -- *** TESTS ***

  procedure is_number
  as
  begin
    g_proc_name := 'is_number';

    if logger.is_number(p_str => 'a') then
      util_add_error('not failing on letter');
    end if;

    if not logger.is_number(p_str => '1') then
      util_add_error('not failing on number');
    end if;
  end is_number;




  procedure assert
  as
  begin
    g_proc_name := 'assert';

    begin
      logger.assert(1=1, 'message');
    exception
      when others then
        util_add_error('1=1 is failing when it shouldnt be');
    end;

    -- Fail on purpose to ensure error is raised
    begin
      logger.assert(1=2, 'message');

      -- If assert works, should never get to this point
      util_add_error('1=2 is not failing when it should');

    exception
      when others then
        if sqlerrm != 'ORA-20000: message' then
          util_add_error('Invalid error message');
        end if;
    end;
  end assert;


  procedure get_param_clob
  as
    l_params logger.tab_param;
    l_clob clob;
  begin
    g_proc_name := 'get_param_clob';

    logger.append_param(l_params, 'p_test1', 'test1');
    logger.append_param(l_params, 'p_test2', 'test2');

    l_clob := logger.get_param_clob(p_params => l_params);

    if l_clob != 'p_test1: test1' || c_line_feed || 'p_test2: test2' then
      util_add_error('Not displaying correctly');
    end if;
  end get_param_clob;


  procedure save_global_context
  as
  begin
    g_proc_name := 'save_global_context';

    -- Reset client_id
    dbms_session.set_identifier(null);
    logger.save_global_context(
      p_attribute => 'TEST',
      p_value => 'test_value',
      p_client_id => null);

    if sys_context(logger.g_context_name, 'TEST') != 'test_value' then
      util_add_error('Context not setting (globally);');
    end if;

    -- Test for client_id
    dbms_session.set_identifier('test_identifier');
    logger.save_global_context(
      p_attribute => 'TEST',
      p_value => 'test_client_id',
      p_client_id => 'test_identifier');

    if sys_context(logger.g_context_name, 'TEST') != 'test_client_id' then
      util_add_error('Context not setting (client_id);');
    end if;
  end save_global_context;

  procedure set_extra_with_params
  as
    l_clob logger_logs.extra%type;
    l_return logger_logs.extra%type;
    l_params logger.tab_param;
  begin
    g_proc_name := 'set_extra_with_params';

    -- Test empty params
    l_clob := 'test';
    l_return := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    if l_return != 'test' then
      util_add_error('empty params test failed');
    end if;

    -- Test one param
    logger.append_param(l_params, 'p_test1', 'test1');
    l_return := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    if l_return !=
'test

*** Parameters ***

p_test1: test1' then
      util_add_error('failed with one param');
    end if;

    -- Test 2 params
    logger.append_param(l_params, 'p_test2', 'test2');
    l_return := logger.set_extra_with_params(
      p_extra => l_clob,
      p_params => l_params);

    if l_return !=
'test

*** Parameters ***

p_test1: test1
p_test2: test2' then
      util_add_error('failed with 2 params');
    end if;

  end set_extra_with_params;


  procedure get_sys_context
  as
    l_clob clob;
  begin
    g_proc_name := 'get_sys_context';

    l_clob := logger.get_sys_context(
      p_detail_level => 'USER',
      p_vertical => false,
      p_show_null => true);
    -- The output from this is very specific to the user/setup so just going to check for any errors raised

  exception
    when others then
      util_add_error(c_unknown_err);
  end get_sys_context;


  procedure admin_security_check
  as
    l_bool boolean;
  begin
    g_proc_name := 'admin_security_check';

    -- Test simple case
    update logger_prefs
    set pref_value = 'FALSE'
    where pref_name = 'PROTECT_ADMIN_PROCS';

    l_bool := logger.admin_security_check;

    if not l_bool then
      util_add_error('FALSE failing');
    end if;

    -- Test when install schema is same as current schema. This should still pass
    update logger_prefs
    set pref_value = 'TRUE'
    where pref_name = 'PROTECT_ADMIN_PROCS';

    update logger_prefs
    set pref_value = sys_context('USERENV','SESSION_USER')
    where pref_name = 'INSTALL_SCHEMA';

    l_bool := logger.admin_security_check;

    if not l_bool then
      util_add_error('Failing when set to true and user is same as INSTALL_SCHEMA');
    end if;

    -- Test when install schema is different as current schema (still set to TRUE)
    update logger_prefs
    set pref_value = 'DUMMY'
    where pref_name = 'INSTALL_SCHEMA';

    begin
      -- This should raise an exception
      l_bool := logger.admin_security_check;

      -- If got to this point then issue
      util_add_error('TRUE failing when different schema (not raising exception)');
    exception
      when others then
        if sqlcode != -20000 then
          util_add_error('TRUE failing when differen schema (invalid error code)');
        end if;
    end;

  end admin_security_check;


  procedure get_level_number
  as
    l_level number;
  begin
    g_proc_name := 'get_level_number';

    update logger_prefs
    set pref_value = 'DEBUG'
    where pref_name = 'LEVEL';

    l_level := logger.get_level_number;

    if l_level != logger.g_debug then
      util_add_error('Level number not matching');
    end if;

    -- Client level Test
    dbms_session.set_identifier('test_identifier');
    logger.set_level(
      p_level => logger.g_error,
      p_client_id => sys_context('userenv','client_identifier')
    );
    l_level := logger.get_level_number;

    if l_level != logger.g_error then
      util_add_error('Invalid clientid level');
    end if;
  end get_level_number;


  procedure null_global_contexts
  as
  begin
    g_proc_name := 'null_global_contexts';

    -- Null values
    logger.null_global_contexts;

    if 1=2
      or sys_context(logger.g_context_name,'level') is not null
      or sys_context(logger.g_context_name,'include_call_stack') is not null
      or sys_context(logger.g_context_name,'plugin_fn_error') is not null
      then
      util_add_error('Contexts still contain values when they shouldnt');
    end if;


  end null_global_contexts;



  /**
   * Runs all the tests and displays errors
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 28-Feb-2015
   */
  procedure util_run_tests
  as
    l_error_null logger_test.tab_error;
  begin
    -- Reset error array
    g_errors := l_error_null;

    -- Run tests
    util_test_setup; is_number; util_test_teardown;
    util_test_setup; assert; util_test_teardown;
    util_test_setup; get_param_clob; util_test_teardown;
    util_test_setup; save_global_context; util_test_teardown;
    util_test_setup; set_extra_with_params; util_test_teardown;
    util_test_setup; get_sys_context; util_test_teardown;
    util_test_setup; admin_security_check; util_test_teardown;
    util_test_setup; get_level_number; util_test_teardown;
    null_global_contexts;

    -- Display errors
    util_display_errors;

  end util_run_tests;

end logger_test;
/
