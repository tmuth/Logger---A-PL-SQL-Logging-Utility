create or replace package body logger_test
as

  -- CONTANTS
  gc_line_feed constant varchar2(1) := chr(10);
  gc_unknown_err constant varchar2(50) := 'Unknown error';
  gc_client_id constant varchar2(30) := 'test_client_id'; -- Consistent client id to use


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

    -- Reset all contexts
    logger.null_global_contexts;

    -- Reset timers
    logger.time_reset;
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

    -- Reset timers
    logger.time_reset;
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


  /**
   * Returns unique scope
   *
   * Notes:
   *  - This is useful when trying to back reference which log was just inserted
   *  - Should look in logger_logs_5_mins since recent
   *
   * Related Tickets:
   *  -
   *
   * @author Martin D'Souza
   * @created 2-Mar-2015
   */
  function util_get_unique_scope
    return varchar2
  as
  begin
    return lower('logger_test_' || dbms_random.string('x',20));
  end util_get_unique_scope;

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

    if l_clob != 'p_test1: test1' || gc_line_feed || 'p_test2: test2' then
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
    dbms_session.set_identifier(gc_client_id);
    logger.save_global_context(
      p_attribute => 'TEST',
      p_value => 'test_client_id',
      p_client_id => gc_client_id);

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
      util_add_error(gc_unknown_err);
  end get_sys_context;


  procedure admin_security_check
  as
    l_bool boolean;
  begin
    g_proc_name := 'admin_security_check';

    -- Test simple case
    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'PROTECT_ADMIN_PROCS';

    l_bool := logger.admin_security_check;

    if not l_bool then
      util_add_error('FALSE failing');
    end if;

    -- Test when install schema is same as current schema. This should still pass
    update logger_prefs
    set pref_value = 'TRUE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'PROTECT_ADMIN_PROCS';

    update logger_prefs
    set pref_value = sys_context('USERENV','SESSION_USER')
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INSTALL_SCHEMA';

    l_bool := logger.admin_security_check;

    if not l_bool then
      util_add_error('Failing when set to true and user is same as INSTALL_SCHEMA');
    end if;

    -- Test when install schema is different as current schema (still set to TRUE)
    update logger_prefs
    set pref_value = 'DUMMY'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INSTALL_SCHEMA';

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
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'LEVEL';

    l_level := logger.get_level_number;

    if l_level != logger.g_debug then
      util_add_error('Level number not matching');
    end if;

    -- Client level Test
    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_error,
      p_client_id => sys_context('userenv','client_identifier')
    );
    l_level := logger.get_level_number;

    if l_level != logger.g_error then
      util_add_error('Invalid clientid level');
    end if;
  end get_level_number;


  procedure include_call_stack
  as
  begin
    g_proc_name := 'include_call_stack';

    update logger_prefs
    set pref_value = 'TRUE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    if not logger.include_call_stack then
      util_add_error('Faling on true');
    end if;

    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    -- reset contexts so that it looks at new one (could have called Logger.configure but more than what I need here)
    logger.null_global_contexts;

    if logger.include_call_stack then
      util_add_error('Faling on false');
    end if;

    -- Test with client
    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE'
    );

    if not logger.include_call_stack then
      util_add_error('Faling on true (client_id)');
    end if;

  end include_call_stack;


  procedure date_text_format_base
  as
    l_start date;
    l_stop date;
  begin
    g_proc_name := 'date_text_format_base';

    -- Test Seconds
    l_start := to_date('10-Jan-2015 20:40:10', 'DD-MON-YYYY HH24:MI:SS');
    l_stop := to_date('10-Jan-2015 20:40:20', 'DD-MON-YYYY HH24:MI:SS');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '10 seconds ago' then
      util_add_error('Error with seconds');
    end if;

    -- Test Minutes
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('10-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '10 minutes ago' then
      util_add_error('Error with minutes');
    end if;

    -- Test Hours (and that it's 1 hour not 1 hours)
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('10-Jan-2015 21:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '1 hour ago' then
      util_add_error('Error with hours');
    end if;

    -- Test Days
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('12-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '2 days ago' then
      util_add_error('Error with days');
    end if;

    -- Test Weeks
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('30-Jan-2015 20:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '2 weeks ago' then
      util_add_error('Error with weeks');
    end if;

    -- Test Months
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('11-Mar-2015 20:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '2 months ago' then
      util_add_error('Error with months');
    end if;

    -- Test Years
    l_start := to_date('10-Jan-2015 20:30', 'DD-MON-YYYY HH24:MI');
    l_stop := to_date('11-Mar-2016 20:40', 'DD-MON-YYYY HH24:MI');
    if logger.date_text_format_base (
        p_date_start => l_start,
        p_date_stop => l_stop) != '1.2 years ago' then
      util_add_error('Error with years');
    end if;

  end date_text_format_base;


  -- Will not test date_text_format since it's dependant on current date and uses date_text_format_base

  -- Will not test get_debug_info since it's too specific to where it's being called

  procedure log_internal
  as
    l_params logger.tab_param;
    l_scope logger_logs.scope%type;
    l_row logger_logs_5_min%rowtype;

  begin
    g_proc_name := 'log_internal';

    logger.append_param(l_params, 'p_test1', 'test1');

    -- Set the level to error then log at debug.
    -- Should still register since log_internal doesn't check ok_to_log (which is as expected)
    logger.set_level(p_level => logger.g_error);

    l_scope := util_get_unique_scope;
    logger.log_internal(
      p_text => 'test',
      p_log_level => logger.g_debug,
      p_scope => l_scope,
      p_extra => 'extra',
      p_callstack => null,
      p_params => l_params);

    select *
    into l_row
    from logger_logs_5_min
    where 1=1
      and scope = l_scope;

    if l_row.text != 'test' then
      util_add_error('text failed');
    end if;

    if l_row.logger_level != logger.g_debug then
      util_add_error('Level failed');
    end if;

    if l_row.extra !=
'extra

*** Parameters ***

p_test1: test1' then
      util_add_error('Extra Failed');
    end if;

    -- Add test to make sure other columns aren't null?


  end log_internal;



  -- *** PUBLIC *** --


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


  procedure convert_level_char_to_num
  as
  begin
    g_proc_name := 'convert_level_char_to_num';

    if logger.convert_level_char_to_num(p_level => logger.g_error_name) != logger.g_error then
      util_add_error('Not converting properly');
    end if;
  end convert_level_char_to_num;


  procedure convert_level_num_to_char
  as
  begin
    g_proc_name := 'convert_level_num_to_char';

    if logger.convert_level_num_to_char(p_level => logger.g_information) != logger.g_information_name then
      util_add_error('Not converting properly');
    end if;
  end convert_level_num_to_char;


  procedure get_character_codes
  as
    l_temp varchar2(1000);
  begin
    g_proc_name := 'get_character_codes';

    l_temp := logger.get_character_codes(
  		p_string =>
'Test
new line',
  		p_show_common_codes => false);

    if l_temp !=
'  84,101,115,116, 10,110,101,119, 32,108,105,110,101
   T,  e,  s,  t,  ~,  n,  e,  w,   ,  l,  i,  n,  e' then
      util_add_error('Failed on show common codes false');
    end if;

    l_temp := logger.get_character_codes(
  		p_string =>
'Test
new line',
  		p_show_common_codes => true);

    if l_temp !=
'Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab
  84,101,115,116, 10,110,101,119, 32,108,105,110,101
   T,  e,  s,  t,  ~,  n,  e,  w,   ,  l,  i,  n,  e' then
      util_add_error('Failed on show common codes true');
    end if;
  end get_character_codes;

  -- FUTURE mdsouza: Add test for get_debug_info

  procedure ok_to_log
  as
    l_bool boolean;
    test_type dbms_sql.varchar2_table;
  begin
    g_proc_name := 'ok_to_log';

    test_type(1) := 'global';
    test_type(2) := 'client';

    for i in test_type.first .. test_type.last loop
      -- for client reset global to debug then set client to error
      if test_type(i) = 'global' then
        logger.set_level(p_level => logger.g_error);
      else
        -- Client
        -- Reset global level
        logger.set_level(p_level => logger.g_debug);

        dbms_session.set_identifier(gc_client_id);
        logger.set_level(
          p_level => logger.g_error,
          p_client_id => gc_client_id);
      end if;

      -- Tests
      -- Should be false since lower
      if logger.ok_to_log(p_level => logger.g_debug) then
        util_add_error('not registering lower levels. Test Type: ' || test_type(i));
      end if;

      -- Should be true
      if not logger.ok_to_log(p_level => logger.g_error) then
        util_add_error('failing when same level. Test Type: ' || test_type(i));
      end if;

      -- Should be true
      if not logger.ok_to_log(p_level => logger.g_permanent) then
        util_add_error('failing when higher level. Test Type: ' || test_type(i));
      end if;


    end loop;

  end ok_to_log;

  -- ok_to_log (varchar2): Not running since it's a wrapper


  -- snapshot_apex_items not going to be tested for now

  procedure log_error
  as
    l_scope logger_logs.scope%type := util_get_unique_scope;
    l_count pls_integer;
    l_row logger_logs_5_min%rowtype;
  begin
    g_proc_name := 'log_error';

    -- Should not log
    logger.set_level(p_level => logger.g_permanent);
    logger.log_error('test', l_scope);

    select count(1)
    into l_count
    from logger_logs_5_min
    where 1=1
      and scope = l_scope;

    if l_count > 0 then
      util_add_error('logging error when shouldnt');
    end if;


    logger.set_level(p_level => logger.g_debug);
    logger.log_error('test', l_scope);

    -- Reset callstack context and set pref to false to ensure that callstack is still set even though this setting is false
    update logger_prefs
    set pref_value = 'FALSE'
    where 1=1
      and pref_type = logger.g_pref_type_logger
      and pref_name = 'INCLUDE_CALL_STACK';

    -- Wipe the sys context so that it reloads
    logger.save_global_context(
      p_attribute => 'include_call_stack',
      p_value => null);

    begin
      select *
      into l_row
      from logger_logs_5_min
      where 1=1
        and scope = l_scope;

      if l_row.call_stack is null then
        util_add_error('Callstack is empty when it should always have a value');
      end if;
    exception
      when no_data_found then
        util_add_error('not logging');
    end;
  end log_error;

  -- Test all log functions (except for log_error)
  procedure log_all_logs
  as
    type rec_log_fn is record(
      fn_name varchar2(30),
      level_off number,
      level_self number,
      level_on number
    );

    type tab_log_fn is table of rec_log_fn index by pls_integer;


    l_log_fns tab_log_fn;

    l_scope logger_logs.scope%type;
    l_count pls_integer;
    l_sql varchar2(255);

    function get_log_fn(
      p_fn_name varchar2,
      p_level_off number,
      p_level_self number,
      p_level_on number)
      return rec_log_fn
    as
      l_log_fn rec_log_fn;
      l_count pls_integer;
    begin
      l_log_fn.fn_name := p_fn_name;
      l_log_fn.level_off := p_level_off;
      l_log_fn.level_self := p_level_self;
      l_log_fn.level_on := p_level_on;

      return l_log_fn;
    end get_log_fn;

  begin


    l_log_fns(l_log_fns.count + 1) := get_log_fn('log_permanent', logger.g_off, logger.g_permanent, logger.g_debug);
    l_log_fns(l_log_fns.count + 1) := get_log_fn('log_warning', logger.g_error, logger.g_warning, logger.g_debug);
    l_log_fns(l_log_fns.count + 1) := get_log_fn('log_information', logger.g_warning, logger.g_information, logger.g_debug);
    l_log_fns(l_log_fns.count + 1) := get_log_fn('log', logger.g_warning, logger.g_debug, logger.g_debug);

    for i in l_log_fns.first .. l_log_fns.last loop
      g_proc_name := l_log_fns(i).fn_name;

      for x in (
        select regexp_substr('off:self:on','[^:]+', 1, level) action
        from dual
        connect by regexp_substr('off:self:on', '[^:]+', 1, level) is not null
      ) loop

        if x.action = 'off' then
          -- Test off
          logger.set_level(l_log_fns(i).level_off);
        elsif x.action = 'self' then
          -- Test self
          logger.set_level(l_log_fns(i).level_self);
        elsif x.action = 'on' then
          -- Test on
          logger.set_level(l_log_fns(i).level_on);
        end if;

        l_scope := util_get_unique_scope;
        l_sql := 'begin logger.' || l_log_fns(i).fn_name || q'!('test', :scope); end;!';
        execute immediate l_sql using l_scope;

        select count(1)
        into l_count
        from logger_logs_5_min
        where 1=1
          and scope = l_scope;

        if 1=2
          or (x.action = 'off' and l_count != 0)
          or (x.action in ('self', 'on') and l_count != 1) then
          util_add_error(l_log_fns(i).fn_name || ' failed test: ' || x.action);
        end if;
      end loop; -- x

    end loop;

  end log_all_logs;


  -- get_cgi_env requires http connection so no tests for now (can simulate in future)

  -- log_userenv: Dependant on get_sys_context which varies for each system

  -- log_cgi_env: Same as above

  -- log_character_codes: covered in get_character_codes

  -- log_apex_items: Future / dependant on APEX instance

  procedure time_start
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_text logger_logs.text%type;
  begin
    g_proc_name := 'time_start';

    logger.set_level(logger.g_timing);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => true
    );

    select max(text)
    into l_text
    from logger_logs_5_min
    where 1=1
      and unit_name = upper(l_unit_name);

    if l_text is null or l_text != 'START: ' || l_unit_name then
      util_add_error('Logged text invalid: ' || l_text);
    end if;

  end time_start;


  procedure time_stop
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_scope logger_logs.scope%type := util_get_unique_scope;
    l_text logger_logs.text%type;
    l_sleep_time number := 1;
  begin
    g_proc_name := 'time_stop';

    logger.set_level(logger.g_debug); -- Time stop only requires g_debug

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    apex_util.pause(l_sleep_time + 0.1);

    logger.time_stop(
      p_unit => l_unit_name,
      p_scope => l_scope
    );

    select max(text)
    into l_text
    from logger_logs_5_min
    where 1=1
      and scope = l_scope;

    dbms_output.put_line(l_text);
    if l_text is null or l_text not like 'STOP : ' || l_unit_name || ' - 00:00:0' || l_sleep_time || '%' then
      util_add_error('Issue with text: ' || l_text);
    end if;

  end time_stop;


  procedure time_stop_fn
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_sleep_time number := 2;
    l_text varchar2(50);
  begin
    g_proc_name := 'time_stop (function)';

    logger.set_level(logger.g_debug);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    apex_util.pause(l_sleep_time + 0.1);

    l_text := logger.time_stop(p_unit => l_unit_name);

    if l_text is null or l_text not like '00:00:0' || l_sleep_time || '%' then
      util_add_error('Issue with return: ' || l_text);
    end if;

  end time_stop_fn;


  procedure time_stop_seconds
  as
    l_unit_name logger_logs.unit_name%type := util_get_unique_scope;
    l_sleep_time number := 2;
    l_text varchar2(50);
  begin
    g_proc_name := 'time_stop_seconds';

    logger.set_level(logger.g_debug);

    logger.time_start(
      p_unit => l_unit_name,
      p_log_in_table => false
    );

    apex_util.pause(l_sleep_time + 0.05);

    l_text := logger.time_stop_seconds(p_unit => l_unit_name);

    if l_text is null or l_text not like l_sleep_time || '.0%' then
      util_add_error('Issue with return: ' || l_text);
    end if;

  end time_stop_seconds;


  -- time_reset: won't test for now

  procedure get_pref
  as
    l_pref logger_prefs.pref_value%type;
  begin
    g_proc_name := 'get_pref';

    logger.set_level(p_level => logger.g_debug);

    l_pref := nvl(logger.get_pref('LEVEL'), 'a');
    if l_pref != logger.g_debug_name then
      util_add_error('Global level not fetching correctly');
    end if;

    dbms_session.set_identifier(gc_client_id);
    logger.set_level(
      p_level => logger.g_warning,
      p_client_id => gc_client_id);
    l_pref := nvl(logger.get_pref('LEVEL'), 'a');
    if l_pref != logger.g_warning_name then
      util_add_error('Client pref not correct');
    end if;

  end get_pref;

  -- purge

  procedure purge_all
  as
    l_count pls_integer;
  begin
    g_proc_name := 'purge_all';

    logger.set_level(p_level => logger.g_debug);
    logger.log('test');

    logger.purge_all;

    select count(1)
    into l_count
    from logger_logs
    where 1=1
      and logger_level > logger.g_permanent;

    if l_count > 0 then
      util_add_error('Non permanent records being kept.');
    end if;
  end purge_all;

  -- status: Won't test since no real easy way to test output


  procedure set_level
  as
    l_scope logger_logs.scope%type;
    l_count pls_integer;
    l_call_stack logger_logs.call_stack%type;

    procedure log_and_count
    as
    begin
      l_scope := util_get_unique_scope;
      logger.log('test', l_scope);

      select count(1)
      into l_count
      from logger_logs_5_min
      where scope = l_scope;
    end log_and_count;

  begin
    g_proc_name := 'set_level';

    logger.set_level(p_level => logger.g_debug);


    log_and_count;
    if l_count != 1 then
      util_add_error('Not logging debug');
    end if;

    logger.set_level(p_level => logger.g_error);
    log_and_count;
    if l_count != 0 then
      util_add_error('Logging when shouldnt be');
    end if;

    -- Test client specific
    dbms_session.set_identifier(gc_client_id);


    -- Disable logging globally then set on for client
    logger.set_level(p_level => logger.g_error);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE');

    log_and_count;
    if l_count != 1 then
      util_add_error('Not logging for client');
    else
      -- Test callstack
      select call_stack
      into l_call_stack
      from logger_logs_5_min
      where scope = l_scope;

      if l_call_stack is null then
        util_add_error('Callstack not being logged when it should be');
      end if;
    end if;


    -- Test callstack off
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'FALSE');

    log_and_count;
    if l_count = 1 then
      -- Test callstack
      select call_stack
      into l_call_stack
      from logger_logs_5_min
      where scope = l_scope;

      if l_call_stack is not null then
        util_add_error('Callstack being logged when it should not be');
      end if;
    end if;


    -- Testing unset_client_level here since structure is in place
    g_proc_name := 'unset_client_level';

    logger.set_level(p_level => logger.g_error);
    logger.set_level(
      p_level => logger.g_debug,
      p_client_id => gc_client_id,
      p_include_call_stack => 'TRUE');

    logger.unset_client_level(p_client_id => gc_client_id);
    log_and_count;
    if l_count != 0 then
      util_add_error('unset not succesful');
    end if;

  end set_level;


  -- unset_client_level (tested above)

  -- unset_client_level

  -- unset_client_level_all

  -- sqlplus_format

  -- Test all tochar commands
  procedure tochar
  as
    l_val varchar2(255);
  begin
    g_proc_name := 'tochar';

    if logger.tochar(1) != '1' then
      util_add_error('number');
    end if;

    l_val := logger.tochar(to_date('1-Jan-2013'));
    if l_val != '01-JAN-2013 00:00:00' then
      util_add_error('date: ' || l_val);
    end if;

    l_val := logger.tochar(to_timestamp ('10-sep-02 14:10:10.123000', 'dd-mon-rr hh24:mi:ss.ff'));
    if l_val != '10-SEP-2002 14:10:10:123000000' then
      util_add_error('timestamp: ' || l_val);
    end if;

    l_val := logger.tochar(to_timestamp_tz('1999-12-01 11:00:00 -8:00', 'yyyy-mm-dd hh:mi:ss tzh:tzm'));
    if l_val != '01-DEC-1999 11:00:00:000000000 -08:00' then
      util_add_error('timezone: ' || l_val);
    end if;

    -- Local timezone based on above and is dependant on each system

    l_val := logger.tochar(true) || ':' || logger.tochar(false);
    if l_val != 'TRUE:FALSE' then
      util_add_error('boolean: ' || l_val);
    end if;

  end tochar;


  procedure append_param
  as
    l_params logger.tab_param;
  begin
    g_proc_name := 'append_param';

    logger.append_param(
      p_params => l_params,
      p_name => 'test',
      p_val => 'val');

    if l_params.count != 1 then
      util_add_error('Did not add');
    end if;

    if l_params(1).name != 'test' then
      util_add_error('Name invalid');
    end if;

    if l_params(1).val != 'val' then
      util_add_error('Val Invalid');
    end if;
  end append_param;

  -- TODO: ins_logger_logs (to test post functions)

  -- TODO: get_fmt_msg are we adding it in here?

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

    -- Private
    util_test_setup; is_number; util_test_teardown;
    util_test_setup; assert; util_test_teardown;
    util_test_setup; get_param_clob; util_test_teardown;
    util_test_setup; save_global_context; util_test_teardown;
    util_test_setup; set_extra_with_params; util_test_teardown;
    util_test_setup; get_sys_context; util_test_teardown;
    util_test_setup; admin_security_check; util_test_teardown;
    util_test_setup; get_level_number; util_test_teardown;
    util_test_setup; include_call_stack; util_test_teardown;
    util_test_setup; date_text_format_base; util_test_teardown;
    util_test_setup; log_internal; util_test_teardown;


    -- Public
    util_test_setup; null_global_contexts; util_test_teardown;
    util_test_setup; convert_level_char_to_num; util_test_teardown;
    util_test_setup; convert_level_num_to_char; util_test_teardown;
    util_test_setup; get_character_codes; util_test_teardown;
    util_test_setup; ok_to_log; util_test_teardown;
    util_test_setup; log_error; util_test_teardown;
    util_test_setup; log_all_logs; util_test_teardown;
    util_test_setup; time_start; util_test_teardown;
    util_test_setup; time_stop; util_test_teardown;
    util_test_setup; time_stop_fn; util_test_teardown;
    util_test_setup; time_stop_seconds; util_test_teardown;
    util_test_setup; get_pref; util_test_teardown;
    util_test_setup; purge_all; util_test_teardown;
    util_test_setup; set_level; util_test_teardown;
    util_test_setup; tochar; util_test_teardown;
    util_test_setup; append_param; util_test_teardown;


    -- Display errors
    util_display_errors;

  end util_run_tests;

end logger_test;
/
