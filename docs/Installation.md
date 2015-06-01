- [Installation](#installation)<br/>
    - [Restrict Logger Access (Grants & Synonyms)](#restrict-access)<br/>
- [Configuration](#configuration)<br/>
- [Maintenance](#maintenance)

<a name="installation"></a>
#Installation

If you're new to Logger it's recommended you simply [install into an existing schema](#install-into-existing-schema) on a development environment to get up and running as quickly as possible. You are encouraged to review the rest of the installation sections after you're more familiar with Logger. Once you are comfortable using Logger it is recommended that you read the [Best Practices](Best-Practices) section

##Important Notes

###Previous Installations
Version 2.0.0 build scripts were completely re-written to make it easier for future development. The new build scripts were built off Logger 1.4.0. As such, **if your current version is lower than 1.4.0 you need to run the uninstall script for your specific version**. If you're currently 1.4.0 or above the installation script will automatically update your current version. The following query will identify your current version.

```sql
select pref_value
from logger_prefs
where pref_name = 'LOGGER_VERSION';
```

To uninstall an older version of logger, see the [Uninstall](#uninstall) instructions. If necessary, you can download the correct version from the [releases](https://github.com/oraopensource/logger/tree/master/releases) folder.

###Install Through APEX
Logger is no longer supported from a web-only installation if the schema was provisioned by APEX. Essentially the APEX team removed the "create any context" privilege when provisioning a new workspace, likely for security reasons. I agree with their choice, it unfortunately impacts logger.

<a name="install-into-new-schema"></a>
##Install into a new schema

1. Using sql*plus or SQL Developer, connect to the database as system or a user with the DBA role.

1. Run:
```sql
@create_user.sql
```

1. Enter the username, tablespace, temporary tablespace and password for the new schema.

1. Connect to the database as the newly created user.

1. Follow the steps to install into an existing schema (below).  

<a name="install-into-existing-schema"></a>
##Install into an existing schema:
1. If possible, connect as a privileged user and issue the following grants to your "existing_user":
```sql
grant connect,create view, create job, create table, create sequence,
create trigger, create procedure, create any context to existing_user;
```
1. Run:
```sql
@logger_install.sql
```

1. Once installed, Logger is automatically set to **DEBUG** level. View the [configurations](#configuration) section to modify its settings.

<a name="install-no-op"></a>
##NO-OP Option for Production Environments
To make sure there is no fear of leaving debug statements in production code, Logger comes with a [NO-OP](http://en.wikipedia.org/wiki/NOP) (No Operation) installation file (logger_no_op.sql). This installs only a shell of the Logger package. All procedures are essentially NO-OPs. It does not even create the tables so there is absolutely no chance it is doing any logging. It is recommended that you leave the full version installed and simply [set the Logger level](Logger-API#procedure-set_level) to ERROR as the performance hit is exceptionally small.

##Objects
The following database objects are installed with Logger:

```sql
OBJECT_TYPE         OBJECT_NAME
------------------- ------------------------------
JOB                 LOGGER_PURGE_JOB
                    LOGGER_UNSET_PREFS_BY_CLIENT
PACKAGE             LOGGER
PROCEDURE           LOGGER_CONFIGURE
SEQUENCE            LOGGER_APX_ITEMS_SEQ
                    LOGGER_LOGS_SEQ
TABLE               LOGGER_LOGS
                    LOGGER_LOGS_APEX_ITEMS
                    LOGGER_PREFS
                    LOGGER_PREFS_BY_CLIENT_ID
VIEW                LOGGER_LOGS_5_MIN
                    LOGGER_LOGS_60_MIN
                    LOGGER_LOGS_TERSE
LOGGER_GLOBAL_CTX   CONTEXT -- Global Application Contexts are owned by SYS
```

<a name="uninstall"></a>
##Uninstall
To uninstall Logger simple run the following script in the schema that Logger was installed in:

```sql
@drop_logger.sql
```

<a name="restrict-access"></a>
##Restrict Access (Grants & Synonyms)
You may want to [install Logger into it's own schema](#install-into-new-schema) for various reasons. Some of the most common ones are:

- DBA does not want to give `CREATE ANY CONTEXT` access to your user.
  - If this is the case, the DBA can then lock the Logger schema after running the grant scripts (below) to prevent any access to the privileged user.
- Restrict Logger to never be able to access your data. *Note: Logger does not try to reference any of your data. Some security policies require that 3rd party solutions can not reside in the same schema as your data. This follows the concept that Logger doesn't need to see your data, your schema just needs access to Logger.*

Once you have installed Logger into it's own schema they're two additional scripts that need to be run. The first grants the appropriate privileges to your schema and the second will create synonyms in your schema.

Run as the user with Logger installed:

```sql
@scripts/grant_logger_to_user.sql <grant_to_username>
```

If you want to restrict access to the "Logger Schema" (since it has `CREATE ANY CONTEXT` privilege) you can simple lock it as `SYSTEM`:

```sql
alter user <username> account lock;
```

Run as the user that needs to access Logger:

```sql
@scripts/create_logger_synonyms.sql <from_username>
```


<a name="configuration"></a>
#Configuration

<a name="config-logger-levels"></a>
###Logger Levels
They're various logger levels. To see the complete list, go to the [Constants](Logger API.md#constants) section in the Logger API.

###Enable
To enable logging for the entire schema:
```sql
exec logger.set_level(logger.g_debug);
```

###Disable
To disable logging:
```sql
exec logger.set_level(logger.g_off);
```

Instead of disabling all logging, setting the level to "ERROR" might be a better approach:

```sql
exec logger.set_level(logger.g_error);
```
If you never want logger to run in an environment you can install the [NO-OP](#install-no-op) version.



###Client Specific Configuration
Logger now supports client specific configuration. For more information and examples view the [Set Logging Level](Logger API.md#set-logging-level) section in the Logger API documentation.

###Status
To view the status/configuration of the Logger:

```sql
set serveroutput on
exec logger.status

Project Home Page	 	 : https://github.com/oraopensource/logger/
Logger Version		 	 : 2.0.0.a01
Debug Level		  	 	 : DEBUG
Capture Call Stack	 	 : TRUE
Protect Admin Procedures : TRUE
APEX Tracing		 	 : Disabled
SCN Capture		 		 : Disabled
Min. Purge Level	 	 : DEBUG
Purge Older Than	 	 : 7 days
Pref by client_id expire : 12 hours
For all client info see  : logger_prefs_by_client_id

PL/SQL procedure successfully completed.
```

###Preferences
Logger stores its configuration settings in LOGGER_PREFS. These are the following preferences:

<table border="0">
  <tr>
    <td>Preference</td>
    <td>Description</td>
  </tr>
  <tr>
    <td>GLOBAL_CONTEXT_NAME</td>
    <td>Context that Logger uses to save values. It is not recommended to modify this setting.</td>
  </tr>
    <tr>
    <td>INCLUDE_CALL_STACK</td>
    <td>Store the call stack. Note <a href="Logger API.md#set-logging-level">client specific settings</a> can override this.</td>
  </tr>
  <tr>
    <td>INSTALL_SCHEMA</td>
    <td>Schema that Logger is installed in. Do not modify.</td>
  </tr>
  <tr>
    <td>LEVEL</td>
    <td>The current schema Logger level.</td>
  </tr>
  <tr>
    <td>LOGGER_VERSION</td>
    <td>Current version of Logger. Do no modify this as it may affect future migrations.</td>
  </tr>
  <tr>
    <td>PREF_BY_CLIENT_ID_EXPIRE_HOURS</td>
    <td>Default time (in hours) that client specific logging levels are set for.</td>
  </tr>
  <tr>
    <td>PROTECT_ADMIN_PROCS</td>
    <td>If TRUE then only user, defined in INSTALL_SCHEMA, can run privilidged procedures.</td>
  </tr>
  <tr>
    <td>PURGE_AFTER_DAYS</td>
    <td>Purge logs, equal to or higher than PURGE_MIN_LEVEL, after this many days. A purge job is run each night to clean up logger.</td>
  </tr>
  <tr>
    <td>PURGE_MIN_LEVEL</td>
    <td>Min level to purge logs used in auto Logger cleanup job.</td>
  </tr>
</table>

###Other Options

Once you perform the following described steps for the Flashback or APEX option, simply run the *logger_configure* procedure, then run *logger.status* to check validate your changes.

```sql
exec logger_configure;
exec logger.status;
```

####Flashback
To enable this option, grant execute on *dbms_flashback* to the user that owns the logger packages. Every insert into *logger_logs* will include the SCN (System Commit Number). This allows you to flashback a session to the time when the error occurred to help debug it or even undo any data corruption. As SYS from sql*plus:

```sql
grant execute on dbms_flashback to logger;
```

####APEX
This option allows you to call logger.log_apex_items which grabs the names and values of all APEX items from the current session and stores them in the logger_logs_apex_items table. This is extremely useful in debugging APEX issues. This option is enabled automatically by logger_configure if APEX is installed in the database.


<a name="maintenance"></a>
#Maintenance

By default, the DBMS\_SCHEDULER job "LOGGER\_PURGE\_JOB" runs every night at 1:00am and deletes any logs older than 7 days that are of error level *g_debug* or higher which includes *g_debug* and *g_timing*. This means logs with any lower level such as *g_error* or *g_permanent* will never be purged. You can also manually purge all logs using *logger.purge_all*, but this will not delete logs of error level *g_permanent*.

Starting in 2.0.0 a new job was *LOGGER\_UNSET\_PREFS\_BY\_CLIENT* introduced to remove [client specific logging](Logger-API#set-logging-level). By default this job is run every hour on the hour.
