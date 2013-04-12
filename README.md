<a name="page-top" />
Logger: A PL/SQL Logging Utility
=================================
* [What is Logger?](#what-is-logger)
	* TODO menu
* [Installation](#installation)
* [Change log](#change-log)
* [License](#license)
* TODO autogenerate TOC with http://stackoverflow.com/questions/9721944/automatic-toc-in-github-flavoured-markdown





#What is Logger? 

Logger is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

* **Debugging**: It's often difficult to track down the source of an error without some form of debugging instrumentation. This is particularly true in multi-tier, stateless architectures such as Application Express.
* **Error Logging**: While most experts agree that it's important not to mask errors, it's also nice to have a persistent record of them.
* **Timing: Logger** has a very simple timing framework built-in that makes it easy to benchmark sections of code.
* **Instrumentation**: Because it's easy to "turn-off" logger globally with virtually no performance impact, it's easy to get in the habit of leaving debug calls in production code. Now, when something does go wrong, you simply flip the switch and logger is enabled making it much quicker to debug errors.





[top](#page-top)

#Installation

If you're new to Logger it's recommended you simply [install into an existing schema](install-into-existing-schema) on a development environment to get up and running as quickly as possible. You are encouraged to review the rest of the installation sections after you're more familiar with Logger. Once installed go to [How to use Logger](#how-to-use-logger) to get a quick tutorial. Once you are comfortable using Logger it is recommended that you read the [Best Practices](#best-practices) section

##Important Notes

###Previous Installations
Version 2.0.0 build scripts were completely re-written to make it easier for future development. The new build scripts were built off Logger 1.4.0. As such, **if your current version is lower than 1.4.0 you need to run the uninstall script for your specific version**. If you're currently 1.4.0 or above the installation script will automatically update your current version. The following query will identify your current version.

```sql
select pref_value
from logger_prefs
where pref_name = 'LOGGER_VERSION';
```

To uninstall an older version of logger, see the [Uninstall](#uninstall) instructions. If necessary, you can download the correct version from the [releases](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases) folder.

###Install Through APEX
Logger is no longer supported from a web-only installation if the schema was provisioned by APEX. Essentially the APEX team removed the "create any context" privilege when provisioning a new workspace, likely for security reasons. I agree with their choice, it unfortunately impacts logger. 

##Install into a new schema

1. Using sql*plus or SQL Developer, connect to the database as system or a user with the DBA role.

1. Run:
	```sql
	@create_user.sql
```

1. Enter the username, tablespace, temporary tablespace and password for the new schema.

1. Connect to the database as the newly created user.

1. Follow the steps to install into an existing schema (below)  

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

<a name="intsall-no-op"></a>
##NO-OP Option for Production Environments
To make sure there is no fear of leaving debug statements in production code, Logger comes with a [NO-OP](http://en.wikipedia.org/wiki/NOP) (No Operation) installation file (logger_no_op.sql). This installs only a shell of the Logger package. All procedures are essentially NO-OPs. It does not even create the tables so there is absolutely no chance it is doing any logging. It is recommended that you leave the full version installed and simply dial-down the TOOD LINK level to "ERROR" as the performance hit is exceptionally small.

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

<a name="configuration"></a>
##Configuration

<a name="config-logger-levels"></a>
###Logger Levels
```sql
g_permanent     constant number := 1;
g_error         constant number := 2;
g_warning       constant number := 4;
g_information   constant number := 8;
g_debug         constant number := 16;
-- Any level > debug (16) is enabled when the LEVEL is set to DEBUG, but you cannot explicitly set the LEVEL to say TIMING.  
-- The additional levels are there for reporting purposes only.
g_timing        constant number := 32;
g_sys_context   constant number := 64;
g_apex          constant number := 128;
```

###Enable
To enable logging for the entire schema:
```sql
exec logger.set_level('DEBUG');
```

###Disable
To disable logging:
```sql
exec logger.set_level('OFF');
```

Instead of disabling all logging, setting the level to "ERROR" might be a better approach:

```sql
exec logger.set_level('ERROR');
```
If you never want logger to run in an environment you can install the [NO-OP](#intsall-no-op) version.

###Client specific configuration
TODO Pref by client



###Status
To view the status/configuration of the Logger:

```sql
ser serveroutput on
exec logger.status

Project Home Page	 : https://logger.samplecode.oracle.com/
Logger Version		 : 2.0.0
Debug Level		 : DEBUG
Capture Call Stack	 : TRUE
Protect Admin Procedures : TRUE
APEX Tracing		 : Enabled
SCN Capture		 : Disabled
Min. Purge Level	 : DEBUG
Purge Older Than	 : 7 days
Pref by client_id expire : 12 hours

PL/SQL procedure successfully completed.
```





[top](#page-top)

<a name="how-to-use-logger"></a>
#How to use Logger

The following example is the most basic use of Logger. This use-case will never change for this project as one of the goals is to eliminate any learning curve for a debugging utility.

```sql
exec logger.log('hello world');

select * from logger_logs;
```

<a name="main-logger-procs"></a>
##Main Logger Procedures

Logger is based on [multiple levels](#config-logger-levels). Calling the following procedures will log the content at each of the levels. 

```sql
begin
  logger.log('This is a debug message. (level = DEBUG)');
  logger.log_information('This is an informational message. (level = INFORMATION)');
  logger.log_warning('This is a warning message. (level = WARNING)');
  logger.log_error('This is an error message (level = ERROR)');
  logger.log_permanent('This is a permanent message, good for upgrades and milestones. (level = PERMANENT)');
end;
/

select id, logger_level, text
from logger_logs_5_min
order by id;

  ID LOGGER_LEVEL TEXT
---- ------------ ------------------------------------------------------------------------------------------
  10	       16 This is a debug message. (level = DEBUG)
  11			8 This is an informational message. (level = INFORMATION)
  12			4 This is a warning message. (level = WARNING)
  13			2 This is an error message (level = ERROR)
  14			1 This is a permanent message, good for upgrades and milestones. (level = PERMANENT)
```

##Parameters
The [primary logger procedures](main-logger-procs) have three common parameters: *p_text*, *p_scope*, and *p_extra*. Each parameter is described below.

<a name="parameters-p_text"></a>
###*p_text*
You should always include some message. *p_text* maps to the *text* column in *logger_logs*. As such it should not exceed 4000 characters. If you need to store more text you can use the [*p_extra*](#parameters-p_extra) parameter.

<a name="parameters-p_scope"></a>
###*p_scope* (optional *but highly recommend*)
The idea behind scope is to give some context to the log message, such as the application, package.procedure where it was called. Logger does capture the call stack, as well as module and action which are great for APEX logging as they are app number / page number. However, none of these options gives you a clean, consistent way to group messages. The *p_scope* parameter is really nothing special as it simply performs a lower() on the input and stores it in the scope column.

The following example demonstrates how to use *p_scope* when called from an APEX application:

```sql
exec logger.log('Some text', 'apex.my_app.page4.some_process');

select id,text,scope from logger_logs where scope like 'apex.my_app.%' order by id;

 ID  TEXT		          SCOPE
---- -------------------- ----------------------------------------
   3 Some text		  apex.my_app.page4.some_process
```

See the [Best Practices](#best-practices) section for scope standards.

<a name="parameters-p_extra"></a>
###*p_extra* (optional)
When logging large (over 4000 characters) blocks of text, use the third parameter: *p_extra*. *p_extra* is a clob field and thus isn't restricted to the 4000 character limit.

The following example highlights the p_extra usage:

```sql
exec logger.log('Some text', 'a.scope', 'Large block of text');

select id, text, scope, extra from logger_logs_5_min;

ID   TEXT	    SCOPE	   EXTRA
---- ---------- ---------- --------------------
   4 Some text	a.scope    Large block of text

```

<a name="parameters-p_params"></a>
###*p_params* (optional)

The parameter field is currently only available for *logger.log_error*. Since most production environments have their logging level set to ERROR (or anther low level) developers need to have an easy way to see the parameters that were passed into a procedure when an error occurs. 

When calling *logger.log_error* it is highly recommended that you leverage this 4th parameter. See [Log Params](#config-logger-levels) section for an example.

TODO other items




[top](#page-top)
#Advanced use

##Error Handling

```sql
declare
  x number;
begin
  execute immediate 'select count(*) into x from foo1234';
exception when others then
logger.log_error('Intentional error');
  raise;
end;
/
 
select * from logger_logs where logger_level = 2;
 
ID LOGGER_LEVEL  TEXT      CALL_STACK  TIME_STAMP                APP_SESSION   MODULE         ACTION  USER_NAME   UNIT_NAME          LINE_NO  COMMENTS  SCN
-- ------------  --------  ----------  ------------------------  ------------  -------------  ------  ----------  -----------------  -------- --------- ---
 2            2  ORA-0094  ORA-06512:  13-OCT-09 09.14.50.07 AM                SQL Developer          LOGGER      INTENTIONAL ERROR         6
```

##Error Handling Showing the Call Stack
In this example, procedure test1 calls procedure test2 which in turn class test3. Test3 has a run-time error.

```sql
create or replace procedure test3 as
begin
    execute immediate 'select count(*) into x from foo1234';
end test3;
/
 
create  or replace  procedure test2 as
begin
    test3;
end;
/
 
create  or replace procedure test1 as
begin
    test2;
    exception when others then
    logger.log_error();
    raise;
end;
/
 
exec test1;
 
SQL> select call_stack from logger_logs where id = 4;
 
CALL_STACK
-----------------------------------------
ORA-00942: table or view does not exist
 
ORA-06512: at "LOGGER.TEST3", line 5
ORA-06512: at "LOGGER.TEST2", line 5
ORA-06512: at "LOGGER.TEST1", line 4
```

##Timing
```sql
declare
    l_number number;
begin
    logger.time_reset;
    logger.time_start('foo');
    logger.time_start('bar');
    for i in 1..500000 loop
        l_number := power(i,15);
        l_number := sqrt(1333);
    end loop; --i
    logger.time_stop('bar');
    for i in 1..500000 loop
        l_number := power(i,15);
        l_number := sqrt(1333);
    end loop; --i
    logger.time_stop('foo');
end;
/
 
select text from logger_logs_5_min;
 
TEXT
---------------------------------
START: foo
>  START: bar
>  STOP : bar - 1.000843 seconds
STOP : foo - 2.015953 seconds
```

##Log User Environment Variables
There are many occasions when the value of one of the USERENV session variables (Documentation: [Overview](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions172.htm), [list of variables](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions172.htm#g1513460)) is a big step in the right direction of finding a problem. A simple call to the *logger.log_userenv* procedure is all it takes to save them in the "EXTRA" column of logger_logs.

```sql
logger.log_userenv(
  p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE
  p_show_null     in boolean  default false,
  p_scope         in varchar2 default null)
```

```sql
exec logger.log_userenv('NLS');
 
select text,extra from logger_logs_5_min;

TEXT                                           EXTRA
---------------------------------------------- -----------------------------------------------------------------
USERENV values stored in the EXTRA column      NLS_CALENDAR                  : GREGORIAN
                                               NLS_CURRENCY                  : $
                                               NLS_DATE_FORMAT               : DD-MON-RR
                                               NLS_DATE_LANGUAGE             : AMERICAN
                                               NLS_SORT                      : BINARY
                                               NLS_TERRITORY                 : AMERICA
                                               LANG                          : US
                                               LANGUAGE                      : AMERICAN_AMERICA.WE8MSWIN1252
```

```sql
exec logger.log_userenv('USER');

select text,extra from logger_logs_5_min;
TEXT                                               EXTRA
-------------------------------------------------- -------------------------------------------------------
USERENV values stored in the EXTRA column          CURRENT_SCHEMA                : LOGGER
                                                   SESSION_USER                  : LOGGER
                                                   OS_USER                       : tmuth
                                                   IP_ADDRESS                    : 192.168.1.7
                                                   HOST                          : WORKGROUP\TMUTH-LAP
                                                   TERMINAL                      : TMUTH-LAP
                                                   AUTHENTICATED_IDENTITY        : logger
                                                   AUTHENTICATION_METHOD         : PASSWORD
```



##Log OWA_UTL CGI Environment Variables

This option only works within a web session, but it's a great way to quickly take a look at an APEX environment:

```sql
SQL> exec logger.log_cgi_env;
 
select extra from logger_logs where text like '%CGI%';
TEXT                                               EXTRA
-------------------------------------------------- -------------------------------------------------------
 ...
SERVER_SOFTWARE               : Oracle-Application-Server-10g/10.1.3.1.0 Oracle-HTTP-Server
GATEWAY_INTERFACE             : CGI/1.1
SERVER_PORT                   : 80
SERVER_NAME                   : 11g
REQUEST_METHOD                : POST
PATH_INFO                     : /wwv_flow.show
SCRIPT_NAME                   : /pls/apex
REMOTE_ADDR                   : 192.168.1.7    
...
```

 


##Log Character Codes

Have you ever run into an issue with a string that contains control characters such as carriage returns, line feeds and tabs that are difficult to debug? The sql [dump()](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions048.htm#sthref1340) function is great for this, but the output is a bit hard to read as it outputs the character codes for each character, so you end up comparing the character code to an [ascii table](http://www.asciitable.com/) to figure out what it is. The function get_character_codes and the procedure log_character_codes make it much easier as they line up the characters in the original string under the corresponding character codes from dump. Additionally, all tabs are replaced with "^" and all other control characters such as carriage returns and line feeds are replaced with "~".

```sql
exec logger.log_character_codes('Hello World'||chr(9)||'Foo'||chr(13)||chr(10)||'Bar');
 
select extra from logger_logs_5_min;
 
EXTRA
----------------------------------------------------------------------------------
Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab
  72,101,108,108,111, 32, 87,111,114,108,100,  9, 70,111,111, 13, 10, 66, 97,114
   H,  e,  l,  l,  o,   ,  W,  o,  r,  l,  d,  ^,  F,  o,  o,  ~,  ~,  B,  a,  r
```



##Log APEX Item Values
This feature is useful in debugging issues in an APEX application that are related session state. The developers toolbar in APEX provides a place to view session state, but it won't tell you the value of items midway through page rendering or right before and after an AJAX call to an application process.

Before using this feature it's important to note that it must be configured first. The next section discusses this configuration.

```sql
-- in an on-submit page process
begin
  logger.log_apex_items('Debug Edit Customer');
end;
```

```sql
select id,logger_level,text,module,action,client_identifier from logger_logs where logger_level = 128;
 
 ID     LOGGER_LEVEL TEXT                 MODULE                 ACTION    CLIENT_IDENTIFIER
------- ------------ -------------------- ---------------------- --------- --------------------
     47          128 Debug Edit Customer  APEX:APPLICATION 100   PAGE 7    ADMIN:45588554040361
      
select * from logger_logs_apex_items where log_id = 47; --log_id relates to logger_logs.id
 
ID      LOG_ID  APP_SESSION 	 ITEM_NAME                 ITEM_VALUE
------- ------- ---------------- ------------------------- ---------------------------------------------
    136      47   45588554040361 P1_QUOTA
    137      47   45588554040361 P1_TOTAL_SALES
    138      47   45588554040361 P6_PRODUCT_NAME           3.2 GHz Desktop PC
    139      47   45588554040361 P6_PRODUCT_DESCRIPTION    All the options, this machine is loaded!
    140      47   45588554040361 P6_CATEGORY               Computer
    141      47   45588554040361 P6_PRODUCT_AVAIL          Y
    142      47   45588554040361 P6_LIST_PRICE             1200
    143      47   45588554040361 P6_PRODUCT_IMAGE
    144      47   45588554040361 P4_CALENDAR_DATE          20091103
    145      47   45588554040361 P7_CUSTOMER_ID            6
    146      47   45588554040361 P7_BRANCH                 2
    147      47   45588554040361 P29_ORDER_ID_NEXT
    148      47   45588554040361 P29_ORDER_ID_PREV
    149      47   45588554040361 P29_ORDER_ID_COUNT        0 of 0
    150      47   45588554040361 P7_CUST_FIRST_NAME        Albert
    151      47   45588554040361 P7_CUST_LAST_NAME         Lambert
    152      47   45588554040361 P7_CUST_STREET_ADDRESS1   10701 Lambert International Blvd.
    153      47   45588554040361 P7_CUST_STREET_ADDRESS2
    154      47   45588554040361 P7_CUST_CITY              St. Louis
    155      47   45588554040361 P7_CUST_STATE             MO
    156      47   45588554040361 P7_CUST_POSTAL_CODE       63145
    157      47   45588554040361 P7_CUST_EMAIL
    158      47   45588554040361 P7_PHONE_NUMBER1          314-555-4022
    159      47   45588554040361 P7_PHONE_NUMBER2
    160      47   45588554040361 P7_CREDIT_LIMIT           1000
    161      47   45588554040361 P6_PRODUCT_ID             1
    162      47   45588554040361 P29_ORDER_ID              9

```

<a name="log-params"></a>
##Log Params
Logger has wrapper functions to quickly and easily log parameters. These parameters will be logged using the DEBUG level (i.e its the same as calling *logger.log*) except when explicitly used in the *logger.log_error* procedure. The values are explicitly converted to strings so you don't need to convert them. The parameters will be stored either in the text field or (if they exceed 4000 characters) in the *extra* column.

The following example highlights how to use the log parameter wrappers:

```sql
create or replace procedure p_demo_function(
  p_empno in emp.empno%type,
  p_ename in emp.ename%type)
as
  l_scope logger_logs.scope%type := 'p_demo_function';
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'p_empno', p_empno); -- Parameter name and value just stored in PL/SQL array and not logged yet
  logger.append_param(l_params, 'p_ename', p_ename); -- Parameter name and value just stored in PL/SQL array and not logged yet
  logger.log_params(l_params, l_scope); -- All parameters are logged at this point
  -- ...
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
end p_demo_function;
/
```

Parameters can also be passed in as the last (4th) parameter in the *logger.log_error* procedure. This is useful in production instances where the Logger level is usually set to *ERROR*. When an error occurs parameters will be logged in the extra column.

[top](#page-top)

<a name="best-practices"></a>
#TODO Best Practices

##TODO APEX
TODO provide a procedure template with everything in it

For packages the recommended practice is as follows:

```sql
create or replace package body pkg_example
as

	gc_scope_prefix constant VARCHAR2(31) := lower($$PLSQL_UNIT) || '.';
	
	procedure demo_proc
	as
		l_scope logger_logs.scope%type := gc_scope_prefix || 'demo_proc'; -- Use the function or procedure name
	begin
		logger.log('START', l_scope);
		TODO pameters
		...
		-- All calls to logger should pass in the scope
	 	... 
		logger.log('END', l_scope);
	TODO exception
	end demo proc;
...
```

#Change Log
##[Version 2.0.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/2.0.0)
TODO Links for each section
* Moved to GitHub an restructured / updated documentation
* Added [log_params](#log-params) and [append_params](#log-params) functions
* Client specific level setting (to enable logging based on client_id)
* New build script which will allow for future versions of logger to be updated. This was built off a 1.4.0 release.
* TODO Tyler: Add in your new features here

##[Version 1.4.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/1.4.0)
* Fixed an issue detecting 11.2 RAC installations
* APEX no longer supported from a web-only installation if the schema was provisioned by APEX. Essentially the APEX team removed the "create any context" privelege when provisioning a new workspace, likely for security reasons. I (Tyler) agree with their choice, it unfortunately impacts logger.

##[Version 1.3.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/1.3.0)
* Fixed major flaw in time calculation used in time_start/time_stop
* Changed implementation of LOG_APEX_ITEMS to use the APEX views so explicit privs on wwv_flow_data are not required. Thanks to Scott Spendolini for this suggestion.

##[Version 1.2.2](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/1.2.2)
* Fixed an error with the admin security check reported by John Flack
* It is now possible to install logger in multiple schemas as the global context is now prefixed with the schema name. So, the global context name in the LOGGER schema would be LOGGER_LOGCTX and the SCOTT schema would be SCOTT_LOGCTX. Thanks to Bill Wheeling for reporting this one.

##[Version 1.2.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/1.2.0)
* New: PROTECT_ADMIN_PROCS preference which is TRUE by default, protects set_level, purge and purge_all. This means that only someone logged into the schema where logger is installed can call these procedures. The idea is that you could grant execute on logger to other schemas, but want to prevent them from changing the levels or purging the logs.
* New: preference called INCLUDE_CALL_STACK allows you to enable / disable logging of the full call stack for LEVELS greater than ERROR (such as debug). Logging the call stack does take additional resources and also requires additional storage per row. So, you can still read your debug messages, but you simply won't see the full call stack. The value is TRUE by default.
* New: CLOB parameter of "P_EXTRA" was added to call LOG... procedures. This populates a CLOB column in LOGGER_LOGS called "EXTRA". This column is also used by several new functions / procedures where the values are relatively large.
* New: logger.log_userenv procedure logs information obtained through sys_context('userenv'...), such as IP Address, NLS info, schema / user information. It's use is documented here.
* New: logger.log_cgi_env procedure grabs all output from owa_util.print_cgi_env and logs it to logger_logs.extra. Useful in debugging some APEX issues. It's use is documented here.
* New: logger.log_character_codes procedure supplements the output of the SQL DUMP() function, great for finding hidden carriage return / line feeds or other non-printable characters.It's use is documented here.
* Fixed set_level, purge and purge_all so they are now autonomous transactions (thanks Tony).

[top](#page-top)
<a name="license"></a>
#License

Copyright (c) 2013, Tyler D. Muth, tylermuth.wordpress.com 
and contributors to the project at 
https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
* Neither the name of Tyler D Muth, nor Oracle Corporation, nor the
  names of its contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[top](#page-top)
