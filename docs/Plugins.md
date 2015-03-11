***This document is best viewed in [flatdoc format](http://oraopensource.github.io/flatdoc?repo=logger&path=docs%2FPlugins.md)***

<a name="about"></a>
#About
Plugins is a new feature that was introduced in Logger 3.0.0. They allow developers to run custom code after a log has been inserted. This can be very useful for things such as custom notifications after an error.

To help with performance, the plugin architecture uses conditional compilation (TODO link) which will only execute one a plugin has been configured properly.

<a name="plugin-types"></a>
##Types

The following types of plugins are currently supported:

<table>
  <tr>
    <th>Name</th>
    <th>Associated Procedure</th>
  </tr>
  <tr>
    <td>PLUGIN_FN_ERROR</td>
    <td>logger.log_error</td>
  </tr>
</table>

<a name="config"></a>
#Configuration
They're two steps to configure a plugin. The first is to register a custom function (more on this below) in the logger prefs table. The following examples shows how to register a custom plugin procedure for errors:
```sql
update logger_prefs
set pref_value = 'custom_method'
where pref_name = 'PLUGIN_FN_ERROR'
```

Once the custom method has been set in the logger_prefs table, you must run the ```logger_configure``` procedure which will recompile logger. 

```sql
exec logger_configure;
```

To deregister a plugin set the appropriate ```logger_prefs.pref_value``` to ```NONE``` and re-run the ```logger_configure``` procedure.