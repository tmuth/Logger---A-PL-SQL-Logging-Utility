***This document is best viewed in [flatdoc format](http://oraopensource.github.io/flatdoc?repo=logger&path=docs%2FPlugins.md)***

<a name="about"></a>
#About
Plugins are a new feature introduced in Logger 3.0.0. They allow developers to run custom code after a log has been inserted. This can be very useful for things such as custom notifications after an error.

To help with performance, the plugin architecture uses conditional compilation which will only execute one a plugin has been properly configured.

<a name="plugin-types"></a>
##Plugin Methods

The following types of plugins are currently supported:

<table>
  <tr>
    <th>Name</th>
    <th>Associated Procedure</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>PLUGIN_FN_ERROR</td>
    <td>logger.log_error</td>
    <td>Allows you to take a logger record type returned as part of the logger.log_error method and use the attributes of it for subsequent actions</td>
  </tr>
</table>

<a name="config"></a>
#Configuration
There are two steps to configure a plugin. The first is to register a custom function ([more on this below](#plugin-interface)) in the logger prefs table. The following examples shows how to register a custom plugin procedure (in this example called ```custom_plugin_method```) to be run after calls to ```logger.log_error```:
```sql
update logger_prefs
set pref_value = 'custom_plugin_method'
where 1=1
  and pref_type = logger.g_pref_type_logger
  and pref_name = 'PLUGIN_FN_ERROR'
```

Once the custom method has been set in the `logger_prefs table`, you must run the `logger_configure` procedure which will recompile Logger.

```sql
exec logger_configure;
```

To deregister a plugin, set the appropriate `logger_prefs.pref_value` to `null` and re-run the `logger_configure` procedure. *Note: since `pref_value` is not a nullable column, null values will be automatically converted to "NONE".*

<a name="plugin-interface"></a>
#Plugin Interface
Plugins can either be standalone procedures or a procedure in a package. Plugins must implement the following interface:

```sql
procedure <name_of_procedure>(
  p_rec in logger.rec_logger_log)
```

For more information about the `logger.rec_logger_log` type please see the [Types documentation](Logger%20API.md#types).

<a name="example"></a>
#Example

The following example shows how to create a custom plugin, configure, and run it.

<a name="ex-plugin-procedure"></a>
##Plugin Procedure
The first thing to do is create a method that will be called when an error is logged:

```sql
create or replace procedure log_test_plugin(
  p_rec in logger.rec_logger_log)
as
  l_text logger_logs.text%type;
begin
  dbms_output.put_line('In Plugin');
  dbms_output.put_line('p_rec.id: ' || p_rec.id);

  select text
  into l_text
  from logger_logs_5_min
  where id = p_rec.id;

  dbms_output.put_line('Text: ' || l_text);

end;
/
```

<a name="ex-configure"></a>
##Register Plugin and Configure

```sql
-- Register new plugin procedure for errors
update logger_prefs
  set pref_value = 'log_test_plugin'
  where 1=1
    and pref_type = logger.g_pref_type_logger
    and pref_name = 'PLUGIN_FN_ERROR';

-- Configure with Logger
exec logger_configure;
```

<a name="ex-run"></a>
##Run

```sql
set serveroutput on

exec logger.log_error('hello');

In Plugin
p_rec.id: 811
Text: hello
```

<a name="other"></a>
#Other
There are several important things to know about plugins.

##Recursion
Plugins do not support recursing for the same type of plugin. I.e. when in an error plugin and the plugin code calls ```logger.log_error```, the error plugin will not execute for the recursive call (but the second error record is still stored in ```logger_logs```. This is to avoid infinite loops in the plugin.

The following example highlights this (note that ```logger.log_error``` is called in the plugin).

```sql
create or replace procedure log_test_plugin(
  p_rec in logger.rec_logger_log)
as
  l_text logger_logs.text%type;
begin
  dbms_output.put_line('In Plugin');

  -- This will not trigger the plugin to be
  -- run again since called inside the plugin
  logger.log_error('will not trigger plugin');  
end;
/

exec logger.log_error('regular log_error call');

In Plugin
```

The output shows that the plugin was only run once, despite ```logger.log_error``` being called a second time inside the plugin.

##Errors in Plugin

When an error occurs inside a plugin, it is logged (using ```logger.log_error```) and the error is then raised.

Example:

```sql
create or replace procedure log_test_plugin(
  p_rec in logger.rec_logger_log)
as
  l_text logger_logs.text%type;
begin
  dbms_output.put_line('In Plugin');

  raise_application_error(-20001, 'test error');
end;
/

-- Highlight error being raised
exec logger.log_error('testing plugin error');

*
ERROR at line 1:
ORA-20001: test error
ORA-06512: at "GIFFY.LOGGER", line 809
ORA-06512: at "GIFFY.LOGGER", line 1234
ORA-06512: at line 1

-- Show error that was logged

select id, text
from logger_logs_5_min
order by id asc;

  ID TEXT
---- -----------------------------------------------
  818 testing plugin error
  819 Exception in plugin procedure: LOG_TEST_PLUGIN ORA-20001: test error
```
