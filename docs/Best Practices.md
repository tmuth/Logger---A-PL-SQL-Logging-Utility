- [PL/SQL Procedure / Function Template](#plsql-example)
- [Logger Levels Guide](#logger-level-guide)

<a name="plsql-example"></a>
##PL/SQL Procedure / Function Template

For packages the recommended practice is as follows:

```sql
create or replace package body pkg_example
as

  gc_scope_prefix constant VARCHAR2(31) := lower($$PLSQL_UNIT) || '.';

  /**
   * TODO_Comments
   *
   * Notes:
   *  -
   *
   * Related Tickets:
   *  -
   *
   * @author TODO
   * @created TODO
   * @param TODO
   * @return TODO
   */
  procedure todo_proc_name(
    p_param1_todo in varchar2)
  as
    l_scope logger_logs.scope%type := gc_scope_prefix || 'todo_proc_name';
    l_params logger.tab_param;

  begin
    logger.append_param(l_params, 'p_param1_todo', p_param1_todo);
    logger.log('START', l_scope, null, l_params);

    ...
    -- All calls to logger should pass in the scope
    ...

    logger.log('END', l_scope);
  exception
    when others then
      logger.log_error('Unhandled Exception', l_scope, null, l_params);
      raise;
  end todo_proc_name;

  ...

end pkg_example;
```

<a name="logger-level-guide"></a>
##Logger Levels Guide
Logger supports multiple logging levels. This section will provide an outline of recommended situations for calling each level. The procedures are ordered in most frequently used to least frequently used.

###Summary

<table>
  <tr>
    <th>Level</th>
    <th>Actionable</th>
    <th>Target Audience</th>
    <th>~%Reference</th>
  </tr>
  <tr>
    <td>Debug</td>
    <td>No</td>
    <td>Developers</td>
    <td>90%</td>
  </tr>
  <tr>
    <td>Information</td>
    <td>No</td>
    <td>Developers/Business</td>
    <td>1%</td>
  </tr>
  <tr>
    <td>Warning</td>
    <td>Yes</td>
    <td>Developers/Business</td>
    <td>1%</td>
  </tr>
  <tr>
    <td>Error</td>
    <td>Yes</td>
    <td>Developers/IT/DBA</td>
    <td>5%</td>
  </tr>
  <tr>
    <td>Permanent</td>
    <td>No</td>
    <td>Developers/Business</td>
    <td>0.5%</td>
  </tr>
</table>

*Actionable* means issues that require follow up by a business unit.


###Debug / Log

`logger.log` should be used for all developer related content. This can really be anything and everything except for items that require additional investigation. In those situations use the other logging options.

By default, Logger is configured to delete all `debug` level calls after 7 days. As such, developers are encouraged to log as much as they need to with this option. Using other logging levels may result (depending on the settings) in permanent storage and should not be used as frequently.

###Information
`logger.log_info[rmation]` should be used for messages that need to be retained at a higher level than `debug` but are not actionable issues.

Information logging will vary in each organization but should fall between the rules for `debug` and `warning`. An example is to use it for a long running process to highlight some of the following items:

- When did the process start
- Major steps/milestones in the process
- Number of rows processed
- When did the process end

###Warning
`logger.log_warn[ing]` should be used for non-critical system level / business logic issues that are actionable. If it is a critical issue than an error should be raised and `logger.log_error` should be called. An example would be when a non-critical configuration item is missing. In this case a warning message should be logged stating that the configuration option was not set / mssing and the deafult value that the code is using in place.

###Error
`logger.log_error` should be used when a PL/SQL error has occurred. In most cases this is in an exception block. Regardless of any other configuration, `log_error` will store the callstack. Errors are considered actionalble items as an error has occurred and something (code, configuration, server down, etc) needs attention.

###Permanent
`logger.log_permanent` should be used for messages that need to be permanently retained. `logger.purge` and `logger.purge_all` will not delete these messages regardless of the `PURGE_MIN_LEVEL` configuration option. Only an implicit delete to `logger_logs` will delete these messages.

An example would be to use this procedure when updating your application to a new version. At the end of the update you can log that the upgrade was successful and the new version number. This way you can find exactly when all the upgrades occurred on your system.
