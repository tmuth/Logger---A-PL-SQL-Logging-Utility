***This document is best viewed in [flatdoc format](http://oraopensource.github.io/flatdoc?repo=logger&path=docs%2FLogger+API.md)***
<a name="constants"></a>
#Constants

<a name="constants-general"></a>
##General
<table border="0">
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
	<tr>
		<td>g_logger_version</td>
		<td>Version of Logger.</td>
	</tr>
	<tr>
		<td>g_context_name</td>
		<td>Context Logger uses for storing attributes.</td>
	</tr>
	<tr>
		<td>gc_empty_tab_param</td>
		<td>Empty param used for default value in logger main procedures.</td>
	</tr>
</table>

<a name="constants-logger-levels"></a>
##Logger Levels
For historical purposes, logger levels supports both integers and names which are intergchangble when calling a function that requires a logger level.

Note: If setting the Logger level to a deprecated level, it will automatically default to `g_debug`.
###Numeric
This is the preferred method
<table border="0">
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
	<tr>
    <td>g_off</td>
    <td>Logger level off (0).</td>
  </tr>
  <tr>
		<td>g_permanent</td>
		<td>Logger level permanent (1).</td>
	</tr>
	<tr>
		<td>g_error</td>
		<td>Logger level error (2).</td>
	</tr>
	<tr>
		<td>g_warning</td>
		<td>Logger level warning (4).</td>
	</tr>
	<tr>
		<td>g_information</td>
		<td>Logger level information (8).</td>
	</tr>
	<tr>
		<td>g_debug</td>
		<td>Logger level debug (16).</td>
	</tr>
	<tr>
		<td>g_timing</td>
		<td>*Deprecated* Logger level timing (32).</td>
	</tr>
	<tr>
		<td>g_sys_context</td>
		<td>*Deprecated* Logger level sys context (64). This is applicable for logging system variables.</td>
	</tr>
	<tr>
		<td>g_apex</td>
		<td>*Deprecated* Logger level apex (128).</td>
	</tr>
</table>

###Name
This will still work, however it is recommended that you use the numeric values.
<table border="0">
  <tr>
    <td>g_off_name</td>
    <td>Logger level name: OFF</td>
  </tr>
  <tr>
    <td>g_permanent_name</td>
    <td>Logger level name: PERMANENT</td>
  </tr>
  <tr>
    <td>g_error_name</td>
    <td>Logger level name: ERROR</td>
  </tr>
  <tr>
    <td>g_warning_name</td>
    <td>Logger level name: WARNING</td>
  </tr>
  <tr>
    <td>g_information_name</td>
    <td>Logger level name: INFORMATION</td>
  </tr>
  <tr>
    <td>g_debug_name</td>
    <td>Logger level name: DEBUG</td>
  </tr>
  <tr>
    <td>g_timing_name</td>
    <td>*Deprecated* Logger level name: TIMING</td>
  </tr>
  <tr>
    <td>g_sys_context_name</td>
    <td>*Deprecated* Logger level name: SYS_CONTEXT</td>
  </tr>
  <tr>
    <td>g_apex_name</td>
    <td>*Deprecated* Logger level name: APEX</td>
  </tr>
</table>

<a name="apex-item-types"></a>
##APEX Item Types
`log_apex_items` takes in an optional variable `p_item_scope`. This determines which items to log in APEX. Use the following global variables as valid vaules.
<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>g_apex_item_type_all</td>
    <td>Log both application and page level items</td>
  </tr>
  <tr>
    <td>g_apex_item_type_app</td>
    <td>Only application level items</td>
  </tr>
  <tr>
    <td>g_apex_item_type_page</td>
    <td>Only page level items</td>
  </tr>
  <tr>
    <td>&lt;page_number&gt;</td>
    <td>All page items corresponding to the given page will be logged</td>
  </tr>
</table>

<a name="types"></a>
#Types
<table border="0">
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
	<tr>
		<td>rec_param</td>
		<td>
			Consists of:<br />
			name (varchar2)<br/>
			value (varchar2)
		</td>
	</tr>
	<tr>
		<td>tab_param</td>
		<td>Array of rec_param</td>
	</tr>
	<tr>
		<td>rec_logger_log</td>
		<td>Consists of:<br />
		  id (number) <br/>
		  logger_level (number) </br>
		  </br>
         See <a href="Plugins.md">Plugins documentation</a> for more information and examples.</td>
	</tr>
</table>

<a name="subprograms"></a>
#Subprograms

<a name="main-logger-procedures"></a>
##Main Logger Procedures
Since the main Logger procedures all have the same syntax and behavior (except for the procedure names) the documentation has been combined to avoid replication.

<a name="main-logger-best-practices"></a>
###Best Practices
The [Best Practices](Best%20Practices.md#logger-level-guide) guide covers which Logger procedure to use in different circumstances.

<a name="main-logger-syntax"></a>
###Syntax
The syntax for the main Logger procedures are all the same.

```sql
logger.procedure_name(
  p_text    in varchar2,
  p_scope   in varchar2 default null,
  p_extra   in clob default null,
  p_params  in tab_param default logger.gc_empty_tab_param);
```

<a name="main-logger-parameters"></a>
###Parameters
All of the main Logger procedures have the same parameters

<table border="0">
	<tr>
    	<th>Parameter</th>
	    <th>Description</th>
  	</tr>
	<tr>
		<td>p_text</td>
		<td>p_text maps to the TEXT column in LOGGER_LOGS. It can handle up to 32767 characters. If p_text exceeds 4000 characters its content will be moved appended to the EXTRA column. If you need to store large blocks of text (i.e. clobs) you can use the p_extra parameter.
		</td>
	</tr>
	<tr>
		<td>p_scope</td>
		<td>p_scope is optional but highly recommend. The idea behind scope is to give some context to the log message, such as the application, package.procedure where it was called from. Logger captures the call stack, as well as module and action which are great for APEX logging as they are app number / page number. However, none of these options gives you a clean, consistent way to group messages. The p_scope parameter performs a lower() on the input and stores it in the SCOPE column.</td>
	</tr>
	<tr>
		<td>p_extra</td>
		<td>When logging large (over 4000 characters) blocks of text, use the third parameter: p_extra. p_extra is a clob field and thus isn't restricted to the 4000 character limit.</td>
	</tr>
	<tr>
		<td>p_params</td>
		<td>p_params is for storing the parameters object. The goal of this parameter is to allow for a simple and consistent method to log the parameters to a given function. The values are explicitly converted to a string so there is no need to convert them when appending a parameter.
		<br/><br/>The data from the parameters array will be appended to the EXTRA column.<br/><br/>
Since most production instances set the logging level to error, it is highly recommended that you leverage this 4th parameter when calling logger.log_error so that developers know the input that triggered the error. </td>
	</tr>
</table>

<a name="main-logger-examples"></a>
###Examples
The following code snippet highlights the main Logger procedures. Since they all have the same parameters, this will serve as the general example for all the main Logger procedures.
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
  11		8 This is an informational message. (level = INFORMATION)
  12	4 This is a warning message. (level = WARNING)
  13		2 This is an error message (level = ERROR)
  14		1 This is a permanent message, good for upgrades and milestones. (level = PERMANENT)
```

The following example shows how to use the p_params parameter. The parameter values are stored in the EXTRA column.

```sql
create or replace procedure p_demo_procedure(
  p_empno in emp.empno%type,
  p_ename in emp.ename%type)
as
  l_scope logger_logs.scope%type := 'p_demo_function';
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'p_empno', p_empno); -- Parameter name and value just stored in PL/SQL array and not logged yet
  logger.append_param(l_params, 'p_ename', p_ename); -- Parameter name and value just stored in PL/SQL array and not logged yet
  logger.log('START', l_scope, null, l_params); -- All parameters are logged at this point
  -- ...
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
end p_demo_procedure;
/
```


<a name="procedure-log"></a>
###LOG
This procedure will log an entry into the LOGGER\_LOGS table when the logger_level is set to *debug*. See [Main Logger Procedures](#main-logger-procedures) for syntax, parameters, and examples.

<a name="procedure-log_information"></a>
###LOG_INFORMATION / LOG_INFO
This procedure will log an entry into the LOGGER\_LOGS table when the logger_level is set to *information*. See [Main Logger Procedures](#main-logger-procedures) for syntax, parameters, and examples.

```log_info``` is a shortcut wrapper for ```log_information```.

<a name="procedure-log_warning"></a>
###LOG_WARNING / LOG_WARN
This procedure will log an entry into the LOGGER\_LOGS table when the logger_level is set to *warning*. See [Main Logger Procedures](#main-logger-procedures) for syntax, parameters, and examples.

```log_warn``` is a shortcut wrapper for ```log_warning```.

<a name="procedure-log_error"></a>
###LOG_ERROR
This procedure will log an entry into the LOGGER\_LOGS table when the logger_level is set to *error*. See [Main Logger Procedures](#main-logger-procedures) for syntax, parameters, and examples.

<a name="procedure-log_permanent"></a>
###LOG_PERMANENT
This procedure will log an entry into the LOGGER\_LOGS table when the logger_level is set to *permanent*. See [Main Logger Procedures](#main-logger-procedures) for syntax, parameters, and examples.

<a name="other-logger-procedures"></a>
##Other Logger Procedures

<a name="procedure-log_userenv"></a>
###LOG_USERENV

There are many occasions when the value of one of the USERENV session variables (Documentation: [Overview](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions172.htm), [list of variables](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions172.htm#g1513460)) is a big step in the right direction of finding a problem. A simple call to the *logger.log_userenv* procedure is all it takes to save them in the EXTRA column of logger_logs.

*log-userenv* will be logged using the *g\_sys\_context* level.

####Syntax

```sql
log_userenv(
  p_detail_level in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
  p_show_null in boolean default false,
  p_scope in logger_logs.scope%type default null,
  p_level in logger_logs.logger_level%type default null);
```

####Parameters

<table border="0">
  <tr>
    <th>Parameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_detail_level</td>
    <td>Valid values are: ALL, NLS, USER (default), or INSTANCE</td>
  </tr>
  <tr>
    <td>p_show_null</td>
    <td>If true, then variables that have no value will still be displayed.</td>
  </tr>
  <tr>
    <td>p_scope</td>
    <td>Scope to log variables under.</td>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Highest level to run at (default logger.g_debug). Example. If you set to logger.g_error it will work when both in DEBUG and ERROR modes. However if set to logger.g_debug (default) will not store values when level is set to ERROR.</td>
  </tr>
</table>


####Example
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

<a name="procedure-log_cgi_env"></a>
###LOG_CGI_ENV
This option only works within a web session, but it's a great way to quickly take a look at an APEX environment.

####Syntax

```sql
logger.log_cgi_env(
  p_show_null in boolean default false,
  p_scope in logger_logs.scope%type default null,
  p_level in logger_logs.logger_level%type default null);
```

####Parameters
<table border="0">
  <tr>
    <th>Parameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_show_null</td>
    <td>If true, then variables that have no value will still be displayed.</td>
  </tr>
    <tr>
    <td>p_scope</td>
    <td>Scope to log CGI variables under.</td>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Highest level to run at (default logger.g_debug). Example. If you set to logger.g_error it will work when both in DEBUG and ERROR modes. However if set to logger.g_debug (default) will not store values when level is set to ERROR.</td>
  </tr>
</table>

####Example
```sql
exec logger.log_cgi_env;

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

<a name="procedure-log_character_codes"></a>
###LOG_CHARACTER_CODES
Have you ever run into an issue with a string that contains control characters such as carriage returns, line feeds and tabs that are difficult to debug? The sql [dump()](http://download.oracle.com/docs/cd/B28359_01/server.111/b28286/functions048.htm#sthref1340) function is great for this, but the output is a bit hard to read as it outputs the character codes for each character, so you end up comparing the character code to an [ascii table](http://www.asciitable.com/) to figure out what it is. The function get_character_codes and the procedure log_character_codes make it much easier as they line up the characters in the original string under the corresponding character codes from dump. Additionally, all tabs are replaced with "^" and all other control characters such as carriage returns and line feeds are replaced with "~".

####Syntax

```sql
logger.log_character_codes(
  p_text in varchar2,
  p_scope in logger_logs.scope%type default null,
  p_show_common_codes in boolean default true,
  p_level in logger_logs.logger_level%type default null);
```

####Parameters
<table border="0">
  <tr>
    <th>Parameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_text</td>
    <td>Text to retrieve character codes for.</td>
  </tr>
    <tr>
    <td>p_scope</td>
    <td>Scope to log text under.</td>
  </tr>
  <tr>
    <td>p_show_common_codes</td>
    <td>Provides legend of common character codes in output.</td>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Highest level to run at (default logger.g_debug). Example. If you set to logger.g_error it will work when both in DEBUG and ERROR modes. However if set to logger.g_debug (default) will not store values when level is set to ERROR.</td>
  </tr>
</table>

####Example
```sql
exec logger.log_character_codes('Hello World'||chr(9)||'Foo'||chr(13)||chr(10)||'Bar');

select extra from logger_logs_5_min;

EXTRA
----------------------------------------------------------------------------------
Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab
  72,101,108,108,111, 32, 87,111,114,108,100,  9, 70,111,111, 13, 10, 66, 97,114
   H,  e,  l,  l,  o,   ,  W,  o,  r,  l,  d,  ^,  F,  o,  o,  ~,  ~,  B,  a,  r
```

<a name="procedure-log_apex_items"></a>
###LOG_APEX_ITEMS
This feature is useful in debugging issues in an APEX application that are related session state. The developers toolbar in APEX provides a place to view session state, but it won't tell you the value of items midway through page rendering or right before and after an AJAX call to an application process.

####Syntax
```sql
logger.log_apex_items(
  p_text in varchar2 default 'Log APEX Items',
  p_scope in logger_logs.scope%type default null,
  p_item_type in varchar2 default logger.g_apex_item_type_all,
  p_log_null_items in boolean default true,
  p_level in logger_logs.logger_level%type default null);
```

####Parameters
<table border="0">
  <tr>
    <th>Parameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_text</td>
    <td>Text to be added to TEXT column.</td>
  </tr>
  <tr>
    <td>p_scope</td>
    <td>Scope to log text under.</td>
  </tr>
  <tr>
    <td>p_item_type</td>
    <td>Determines what type of APEX items are logged (all, application, page). See the <a href="#apex-item-type">corresponding global variables</a> that it can reference. Alternatively it can reference a page_id which will then only log items on the defined page.</td>
  </tr>
  <tr>
    <td>p_log_null_items</td>
    <td>If set to false, null values won't be logged.</td>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Highest level to run at (default logger.g_debug). Example. If you set to logger.g_error it will work when both in DEBUG and ERROR modes. However if set to logger.g_debug (default) will not store values when level is set to ERROR.</td>
  </tr>
</table>

####Example
```sql
-- Include in your APEX code
begin
  logger.log_apex_items('Debug Edit Customer');
end;
```

```sql
select id,logger_level,text,module,action,client_identifier
from logger_logs
where logger_level = 128;

 ID     LOGGER_LEVEL TEXT                 MODULE                 ACTION    CLIENT_IDENTIFIER
------- ------------ -------------------- ---------------------- --------- --------------------
     47          128 Debug Edit Customer  APEX:APPLICATION 100   PAGE 7    ADMIN:45588554040361

select *
from logger_logs_apex_items
where log_id = 47; --log_id relates to logger_logs.id

ID      LOG_ID  APP_SESSION    ITEM_NAME                 ITEM_VALUE
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

<a name="utility-functions"></a>
##Utility Functions


<a name="procedure-tochar"></a>
###TOCHAR

TOCHAR will convert the value to a string (varchar2). It is useful when wanting to log items, such as booleans, without having to explicitly convert them.

**Note: ```tochar ``` does not use the *no_op* conditional compilation so it will always execute.** This means that you can use outside of Logger (i.e. within your own application business logic).

####Syntax
```sql
logger.tochar(
  p_val in number | date | timestamp | timestamp with time zone | timestamp with local time zone | boolean
  return varchar2);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_val</td>
    <td>Value (in original data type)</td>
  </tr>
    <tr>
    <td>return</td>
    <td>Varchar2 value of p_val</td>
  </tr>
</table>

####Example
```sql
select logger.tochar(sysdate)
from dual;

LOGGER.TOCHAR(SYSDATE)
-----------------------
13-JUN-2014 21:20:34


-- In PL/SQL highlighting conversion from boolean to varchar2
SQL> exec dbms_output.put_line(logger.tochar(true));
TRUE

PL/SQL procedure successfully completed.

```

<a name="procedure-sprintf"></a>
###SPRINTF

```sprintf``` is similar to the common procedure [```printf```](http://en.wikipedia.org/wiki/Printf_format_string) found in many programming languages. It replaces substitution strings for a given string. Substitution strings can be either ```%s``` or ```%s<n>``` where ```<n>``` is a number 1~10.

The following rules are used to handle substitution strings (in order):
- Replaces ```%s<n>``` with ```p_s<n>```, regardless of order that they appear in ```p_str```
- Occurrences of ```%s``` (no number) are replaced with ```p_s1..p_s10``` in order that they appear in ```p_str```
- ```%%``` is escaped to ```%```

**Note: ```sprintf ``` does not use the *no_op* conditional compilation so it will always execute.** This means that you can use outside of Logger (i.e. within your own application business logic).


####Syntax
```sql
function sprintf(
  p_str in varchar2,
  p_s1 in varchar2 default null,
  p_s2 in varchar2 default null,
  p_s3 in varchar2 default null,
  p_s4 in varchar2 default null,
  p_s5 in varchar2 default null,
  p_s6 in varchar2 default null,
  p_s7 in varchar2 default null,
  p_s8 in varchar2 default null,
  p_s9 in varchar2 default null,
  p_s10 in varchar2 default null)
  return varchar2;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_str</td>
    <td>String to apply substitution strings to</td>
  </tr>
    <tr>
    <td>p_s&lt;1..10&gt;</td>
    <td>Substitution strings</td>
  </tr>
  <tr>
    <td>return</td>
    <td>Formated string</td>
  </tr>
</table>

####Example
```sql
select logger.sprintf('hello %s, how are you %s', 'martin', 'today') msg
from dual;

MSG
-------------------------------
hello martin, how are you today

-- Advance features

-- Escaping %
select logger.sprintf('hello, %% (escape) %s1', 'martin') msg
from dual;

MSG
-------------------------
hello, % (escape) martin

-- %s<n> replacement
select logger.sprintf('%s1, %s2, %s', 'one', 'two') msg
from dual;

MSG
-------------------------
one, two, one
```


<a name="procedure-get_cgi_env"></a>
###GET_CGI_ENV
TODO Description

####Syntax
```sql
logger.get_cgi_env(
  p_show_null   in boolean default false)
  return clob;
```
####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_show_null</td>
    <td>Show null variables.</td>
  </tr>
    <tr>
    <td>return</td>
    <td>Formatted list of CGI variables</td>
  </tr>
</table>

####Example
```sql
TODO
```


<a name="procedure-get_pref"></a>
###GET_PREF
Returns the preference from LOGGER_PREFS. If `p_pref_type` is not defined then the system level preferences will be returned.

####Syntax
```sql
logger.get_pref(
  p_pref_name in logger_prefs.pref_name%type,
  p_pref_type in logger_prefs.pref_type%type default logger.g_pref_type_logger)
  return varchar2
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_pref_name</td>
    <td>Preference to get value for.</td>
  </tr>
  <tr>
    <td>p_pref_type</td>
    <td>Preference type</td>
  </tr>
  <tr>
    <td>return</td>
    <td>Prefence value.</td>
  </tr>
</table>

####Example
```sql
dbms_output.put_line('Logger level: ' || logger.get_pref('LEVEL'));
```


<a name="procedure-set_pref"></a>
###SET_PREF
In some cases you may want to store custom preferences in the `LOGGER_PREFS` table. A use case for this would be when creating a plugin that needs to reference some parameters.

This procedure allows you to leverage the `LOGGER_PREFS` table to store your custom preferences. To avoid any naming conflicts with Logger, you must use a type (defined in `p_pref_type`). You can not use the type `LOGGER` as it is reserved for Logger system preferences.

`SET_PREF` will either create or udpate a value. Values must contain data. If not, use [`DEL_PREF`](#procedure-del_pref) to delete unused preferences.

####Syntax
```sql
logger.set_pref(
  p_pref_type in logger_prefs.pref_type%type,
  p_pref_name in logger_prefs.pref_name%type,
  p_pref_value in logger_prefs.pref_value%type);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_pref_type</td>
    <td>Type of preference. Use your own name space to avoid conflicts with Logger. Types will automatically be converted to uppercase</td>
  </tr>
  <tr>
    <td>p_pref_name</td>
    <td>Preference to get value for. Must be prefixed with "CUST_". Value will be created or updated. This value will be stored as uppercase.</td>
  </tr>
  <tr>
    <td>p_pref_value</td>
    <td>Prefence value.</td>
  </tr>
</table>

####Example
```sql
logger.set_pref(
  p_pref_type => 'CUSTOM'
  p_pref_name => 'MY_PREF',
  p_pref_value => 'some value');
```


<a name="procedure-del_pref"></a>
###DEL_PREF
Deletes a preference except for system level preferences.

####Syntax
```sql
logger.del_pref(
  p_pref_type in logger_prefs.pref_type%type,
  p_pref_name in logger_prefs.pref_name%type);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_pref_type</td>
    <td>Namepsace / type of preference.</td>
  </tr>
  <tr>
    <td>p_pref_name</td>
    <td>Custom preference to delete.</td>
  </tr>
</table>

####Example
```sql
logger.del_pref(
  p_pref_type => 'CUSTOM'
  p_pref_name => 'MY_PREF');
```


<a name="procedure-purge"></a>
###PURGE
TODO_DESC

####Syntax
```sql
logger.purge(
  p_purge_after_days  in varchar2 default null,
  p_purge_min_level in varchar2 default null);
```
####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_purge_after_days</td>
    <td>Purge entries older than n days.</td>
  </tr>
    <tr>
    <td>p_purge_min_level</td>
    <td>Minimum level to purge entries. For example if set to *logger.g\_information* then information, debug, timing, sys_context, and apex logs will be deleted.</td>
  </tr>
</table>

####Example
```sql
TODO
```


<a name="procedure-purge_all"></a>
###PURGE_ALL
Purges all non-permanent entries in LOGGER_LOGS.


####Syntax
```sql
logger.purge_all;
```

####Parameters
No Parameters

####Example
```sql
TODO
-- For this one show a count before of logger_logs. Then run, then show what's left in the table.
```


<a name="procedure-status"></a>
###STATUS
Prints the Logger's current status and configuration settings.

####Syntax
```sql
logger.status(
  p_output_format in varchar2 default null); -- SQL-DEVELOPER | HTML | DBMS_OUPUT
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_output_format</td>
    <td>What type of output. Accepted values are SQL-DEVELOPER, HTML, and DBMS_OUPUT.</td>
  </tr>
</table>


####Example
```sql
set serveroutput on
exec logger.status

Project Home Page    : https://github.com/oraopensource/logger/
Logger Version       : 2.0.0.a01
Debug Level          : DEBUG
Capture Call Stack     : TRUE
Protect Admin Procedures : TRUE
APEX Tracing       : Disabled
SCN Capture        : Disabled
Min. Purge Level     : DEBUG
Purge Older Than     : 7 days
Pref by client_id expire : 12 hours
For all client info see  : logger_prefs_by_client_id

PL/SQL procedure successfully completed.
```


<a name="procedure-sqlplus_format"></a>
###SQLPLUS_FORMAT
TODO_DESC

####Syntax
```sql
logger.sqlplus_format;
```

####Parameters
No Parameters

####Example
```sql
TODO
```

<a name="procedure-null_global_contexts"></a>
###NULL_GLOBAL_CONTEXTS
TODO_DESC

####Syntax
```sql
logger.null_global_contexts;
```

####Parameters
No Parameters.

####Example
```sql
TODO
```

<a name="procedure-convert_level_char_to_num"></a>
###CONVERT_LEVEL_CHAR_TO_NUM
Returns the number representing the given level (string).

####Syntax
```sql
logger.convert_level_char_to_num(
  p_level in varchar2)
  return number;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Level name.</td>
  </tr>
    <tr>
    <td>return</td>
    <td>Level number</td>
  </tr>
</table>

####Example
```sql
select logger.convert_level_char_to_num(p_level => 'DEBUG') level_number
from dual;

LEVEL_NUMBER
------------
    16
```

<a name="procedure-date_text_format"></a>
###DATE_TEXT_FORMAT
Returns the time difference (in nicely formatted string) of *p\_date* compared to now (sysdate).

####Syntax
```sql
logger.date_text_format (p_date in date)
  return varchar2;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_date</td>
    <td>Date to compare</td>
  </tr>
    <tr>
    <td>return</td>
    <td>Time difference between p_date and now.</td>
  </tr>
</table>

####Example
```sql
select logger.date_text_format(sysdate-1) date_diff
from dual;

DATE_DIFF
-----------
1 days ago
```

<a name="procedure-get_character_codes"></a>
###GET_CHARACTER_CODES
Similar to [log_character_codes](#procedure-log_character_codes) except will return the character codes instead of logging them.

####Syntax
```sql
logger.get_character_codes(
  p_string        in varchar2,
  p_show_common_codes   in boolean default true)
  return varchar2;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_string</td>
    <td>String to get codes for.</td>
  </tr>
    <tr>
    <td>p_show_common_codes</td>
    <td>Display legend of common character codes.</td>
  </tr>
  <tr>
    <td>return</td>
    <td>String with character codes.</td>
  </tr>
</table>

####Example
```sql
select logger.get_character_codes('Hello World') char_codes
from dual;

CHAR_CODES
--------------------------------------------------------------------------------
Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab
  72,101,108,108,111, 32, 87,111,114,108,100
   H,  e,  l,  l,  o, ,  W,  o,  r,  l,  d
```


<a name="procedure-append_param"></a>
###APPEND_PARAM
Logger has wrapper functions to quickly and easily log parameters. All primary log procedures take in a fourth parameter to support logging a parameter array. The values are explicitly converted to strings so you don't need to convert them. The parameter values will be stored n the *extra* column.

####Syntax
```sql
logger.append_param(
  p_params in out nocopy logger.tab_param,
  p_name in varchar2,
  p_val in <various_data_types>);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_params</td>
    <td>Param array to append parameter value to.</td>
  </tr>
    <tr>
    <td>p_name</td>
    <td>Name of the parameter.</td>
  </tr>
  <tr>
    <td>p_val</td>
    <td>Value (in original data type).</td>
  </tr>
</table>

####Example
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
  logger.log('START', l_scope, null, l_params); -- All parameters are logged at this point  
  -- ...
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
end p_demo_function;
/
```

<a name="procedure-ok_to_log"></a>
###OK_TO_LOG
Though Logger internally handles when a statement is stored in the LOGGER_LOGS table there may be situations where you need to know if logger will log a statement before calling logger. This is useful when doing an expensive operation just to log the data.

A classic example is looping over an array for the sole purpose of logging the data. In this case, there's no reason why the code should perform the additional computations when logging is disabled for a certain level.

*ok\_to\_log* will also factor in client specific logging settings.

*Note*: *ok\_to\_log* is not something that should be used frequently. All calls to logger run this command internally.

####Syntax
```sql
logger.ok_to_log(p_level  in  varchar2)
  return boolean;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Level (name) to test for.</td>
  </tr>
    <tr>
    <td>return</td>
    <td>Wether or not level will be logged.</td>
  </tr>
</table>

####Example
```sql
declare
  type typ_array is table of number index by pls_integer;
  l_array typ_array;
begin
  -- Load test data
  for x in 1..100 loop
    l_array(x) := x;
  end loop;

  -- Only log if logging is enabled
  if logger.ok_to_log(logger.g_debug) then
    for x in 1..l_array.count loop
      logger.log(l_array(x));
    end loop;
  end if;
end;
/
```

Note: ok\_to\_log should not be used for one-off log commands. This defeats the whole purpose of having the various log commands. For example ok\_to\_log should *not* be used in the following way:

```sql
-- Reminder: This is an example of how not to use ok_to_log
...
if logger.ok_to_log(logger.g_debug) then
 logger.log('test');
end if;
...
```


<a name="procedure-ins_logger_logs"></a>
###INS_LOGGER_LOGS
Similar to ```ok_to_log```, this procedure should be used very infrequently as the main Logger procedures should handle everything that is required for quickly logging information.

As part of the 2.1.0 release, the trigger on ```LOGGER_LOGS``` was removed for both performance and other issues. Though inserting directly to the ```LOGGER_LOGS``` table is not a supported feature of Logger, you may have some code that does a direct insert. The primary reason that a manual insert into ```LOGGER_LOGS``` was done was to obtain the ```ID``` column for the log entry.

To help prevent any issues with backwards compatibility, ```ins_logger_logs```  has been made publicly accessible to handle any inserts into ```LOGGER_LOGS```. This is a supported procedure and any manual insert statements will need to be modified to use this procedure instead.

Important things to now about ```ins_logger_logs```:

 - It does not check the Logger level. This means it will always insert into the ```LOGGER_LOGS``` table. It is also an Autonomous Transaction procedure so a commit is always performed, however it will not affect the current session.
 - [Plugins](Plugins.md) will not be executed when calling this procedure. If you have critical processes which leverage plugin support you should use the proper log function instead.

####Syntax
```sql
logger.ins_logger_logs(
  p_logger_level in logger_logs.logger_level%type,
  p_text in varchar2 default null,
  p_scope in logger_logs.scope%type default null,
  p_call_stack in logger_logs.call_stack%type default null,
  p_unit_name in logger_logs.unit_name%type default null,
  p_line_no in logger_logs.line_no%type default null,
  p_extra in logger_logs.extra%type default null,
  po_id out nocopy logger_logs.id%type);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_logger_level</td>
    <td>Logger level. See <a href="#constants">Constants</a> section for list of variables to chose from.</td>
  </tr>
    <tr>
    <td>p_text</td>
    <td>Text column.</td>
  </tr>
  <tr>
    <td>p_scope</td>
    <td>Scope.</td>
  </tr>
  <tr>
    <td>p_call_stack</td>
    <td>PL/SQL call stack.</td>
  </tr>
  <tr>
    <td>p_unit_name</td>
    <td>Unit name (this is usually the calling procedure).</td>
  </tr>
  <tr>
    <td>p_line_no</td>
    <td>Line number</td>
  </tr>
  <tr>
    <td>p_extra</td>
    <td>Extra CLOB.</td>
  </tr>
  <tr>
    <td>po_id</td>
    <td>Logger ID (out).</td>
  </tr>
</table>

####Example
```sql
set serveroutput on

declare
  l_id logger_logs.id%type;
begin
  -- Note: Commented out parameters not used for this demo (but still accessible via API)
  logger.ins_logger_logs(
    p_logger_level => logger.g_debug,
    p_text => 'Custom Insert',
    p_scope => 'demo.logger.custom_insert',
--    p_call_stack => ''
    p_unit_name => 'Dynamic PL/SQL',
--    p_line_no => ,
--    p_extra => ,
    po_id => l_id
  );

  dbms_output.put_line('ID: ' || l_id);
end;
/

ID: 2930650
```


<a name="set-logging-level"></a>
##Set Logging Level

Logger allows you to configure both system logging levels and client specific logging levels. If a client specific logging level is defined, it will override the system level configuration. If no client level is defined Logger will defautl to the system level configuration.

Prior to version 2.0.0 Logger only supported one logger level. The primary goal of this approach was to enable Logger at Debug level for development environments, then change it to Error levels in production environments so the logs did not slow down the system. Over time developers start to find that in some situations they needed to see what a particular user / session was doing in production. Their only option was to enable Logger for the entire system which could potentially slow everyone down.

Starting in version 2.0.0 you can now specify the logger level along with call stack setting by specifying the *client_identifier*. If not explicitly unset, client specific configurations will expire after a set period of time.

The following query shows all the current client specific log configurations:
```sql
select *
from logger_prefs_by_client_id;

CLIENT_ID     LOGGER_LEVEL  INCLUDE_CALL_STACK CREATED_DATE   EXPIRY_DATE
------------------- ------------- ------------------ -------------------- --------------------
logger_demo_session ERROR   TRUE         24-APR-2013 02:48:13 24-APR-2013 14:48:13
```


<a name="procedure-set_level"></a>
###SET_LEVEL
Set both system and client logging levels.

####Syntax
```sql
logger.set_level(
  p_level in varchar2 default logger.g_debug_name,
  p_client_id in varchar2 default null,
  p_include_call_stack in varchar2 default null,
  p_client_id_expire_hours in number default null
);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_level</td>
    <td>Use logger.g_&lt;level&gt;_name variables. See [Constants](#constants-logger-levels). If the level is deprecated it will automatically be set to DEBUG.</td>
  </tr>
    <tr>
    <td>p_client_id</td>
    <td>Optional: If defined, will set the level for the given client identifier. If null will affect global settings.</td>
  </tr>
  <tr>
    <td>p_include_call_stack</td>
    <td>Optional: Only valid if p_client_id is defined Valid values: TRUE, FALSE. If not set will use the default system pref in logger_prefs.</td>
  </tr>
  <tr>
    <td>p_client_id_expire_hours</td>
    <td>If p_client_id, expire after number of hours. If not defined, will default to system preference PREF_BY_CLIENT_ID_EXPIRE_HOURS.</td>
  </tr>
</table>

####Example
Set system level logging level:
```sql
exec logger.set_level(logger.g_debug_name);
```

Client Specific Configuration:
```sql
-- In Oracle Session-1
exec logger.set_level(logger.g_debug_name);

exec logger.log('Session-1: this should show up');

select id, logger_level, text, client_identifier, call_stack
from logger_logs_5_min
order by id;

  ID LOGGER_LEVEL TEXT                      CLIENT_IDENTIFIER CALL_STACK
---- ------------ ----------------------------------- ----------------- ----------------------------
  31         16 Session-1: this should show up              object      line  object

exec logger.set_level (logger.g_error_name);

exec logger.log('Session-1: this should NOT show up');

-- The previous line does not get logged since the logger level is set to ERROR and it made a .log call


-- In Oracle Session-2 (i.e. a different session)
exec dbms_session.set_identifier('my_identifier');

-- This sets the logger level for current identifier
exec logger.set_level(logger.g_debug_name, sys_context('userenv','client_identifier'));

exec logger.log('Session-2: this should show up');

select id, logger_level, text, client_identifier, call_stack
from logger_logs_5_min
order by id;

  ID LOGGER_LEVEL TEXT                      CLIENT_IDENTIFIER CALL_STACK
---- ------------ ----------------------------------- ----------------- ----------------------------
  31         16 Session-1: this should show up                  object      line  object
  32         16 Session-2: this should show up    my_identifier   object      line  object

-- Notice how the CLIENT_IDENTIFIER field also contains the current client_identifer
```

In APEX the *client\_identifier* is
```sql
:APP_USER || ':' || :APP_SESSION
```


<a name="procedure-unset_client_level"></a>
###UNSET_CLIENT_LEVEL
Unset logger level by specific *client_id*.

####Syntax
```sql
logger.unset_client_level(p_client_id in varchar2);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_client_id</td>
    <td>Client identifier to unset logging level.</td>
  </tr>
</table>

####Example
```sql
exec logger.unset_client_level('my_client_id');
```

<a name="procedure-unset_client_level2"></a>
###UNSET_CLIENT_LEVEL
Unset all expired *client_id*s. Note this run automatically each hour by the *LOGGER\_UNSET\_PREFS\_BY\_CLIENT* job.

####Syntax
```sql
logger.unset_client_level;
```

####Parameters
No parameters.

####Example
```sql
exec logger.unset_client_level;
```

<a name="procedure-unset_client_level_all"></a>
###UNSET_CLIENT_LEVEL_ALL
Unset all client configurations (regardless of expiry time).

####Syntax
```sql
logger.unset_client_level_all;
```

####Parameters
No Parameters.

####Example
```sql
exec logger.unset_client_level_all;
```

<a name="timing-procedures"></a>
##Timing Procedures

TODO description?

<a name="timing-procedures-example"></a>
###Example
Since all the timing procedures are tightly coupled, the following example will be used to cover all of them:

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

<a name="procedure-time_reset"></a>
###TIME_RESET
Resets all timers.

####Syntax
```sql
logger.time_reset;
```

####Parameters
No Parameters.

####Example
```sql
logger.time_reset;
```

<a name="procedure-time_start"></a>
###TIME_START
Starts a timer.

####Syntax
```sql
logger.time_start(
  p_unit        IN VARCHAR2,
  p_log_in_table      IN boolean default true)
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_unit</td>
    <td>Name for timing unit</td>
  </tr>
    <tr>
    <td>p_log_in_table</td>
    <td>If true, will log the start event in LOGGER_LOGS.</td>
  </tr>
</table>

####Example
See [Timing Procedures Example](#timing-procedures-example).

<a name="procedure-time_stop"></a>
###TIME_STOP
Stops a timing event and logs in LOGGER_LOGS using level = logger.g_timing.

####Syntax
```sql
logger.time_stop(
  p_unit in varchar2,
  p_scope in varchar2 default null);
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_unit</td>
    <td>Timer to stop.</td>
  </tr>
    <tr>
    <td>p_scope</td>
    <td>Scope to log timer under.</td>
  </tr>
</table>

####Example
See [Timing Procedures Example](#timing-procedures-example).

<a name="procedure-time_stop2"></a>
###TIME_STOP
Similar to [TIME_STOP](#time_stop) procedure, this function will stop a timer. Logging into LOGGER_LOGS is configurable. Returns the stop time string.

####Syntax
```sql
logger.time_stop(
  p_unit in varchar2,
  p_scope in varchar2 default null,
  p_log_in_table in boolean default true)
  return varchar2;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_unit</td>
    <td>Timer to stop.</td>
  </tr>
    <tr>
    <td>p_scope</td>
    <td>Scope to log timer under.</td>
  </tr>
  <tr>
    <td>p_log_in_table</td>
    <td>Store result in LOGGER_LOGS.</td>
  </tr>
  <tr>
    <td>return</td>
    <td>Timer results.</td>
  </tr>
</table>

####Example
```sql
TODO
```

<a name="procedure-time_stop_seconds"></a>
###TIME_STOP_SECONDS
TODO_DESC

####Syntax
```sql
logger.time_stop_seconds(
  p_unit        in varchar2,
  p_scope             in varchar2 default null,
  p_log_in_table      in boolean default true)
  return number;
```

####Parameters
<table border="0">
  <tr>
    <th>Prameter</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>p_unit</td>
    <td>Timer to stop.</td>
  </tr>
    <tr>
    <td>p_scope</td>
    <td>Scope to log timer under.</td>
  </tr>
  <tr>
    <td>p_log_in_table</td>
    <td>Store result in LOGGER_LOGS.</td>
  </tr>
</table>

####Example
```sql
TODO
```
