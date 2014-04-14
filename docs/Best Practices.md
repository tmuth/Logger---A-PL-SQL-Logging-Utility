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
