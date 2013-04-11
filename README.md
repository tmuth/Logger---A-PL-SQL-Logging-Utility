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
Logger is used by Oracle developers to instrument their PL/SQL code.

This is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

* **Debugging**: It's often difficult to track down the source of an error without some form of debugging instrumentation. This is particularly true in multi-tier, stateless architectures such as Application Express.
* **Error Logging**: While most experts agree that it's important not to mask errors, it's also nice to have a persistent record of them.
* **Timing: Logger** has a very simple timing framework built-in that makes it easy to benchmark sections of code.
* **Instrumentation**: Because it's easy to "turn-off" logger globally with virtually no performance impact, it's easy to get in the habit of leaving debug calls in production code. Now, when something does go wrong, you simply flip the switch and logger is enabled making it much quicker to debug errors.

[top](#page-top)

#Installation

##Important Notes

###Pervious Installations
Version 2.0.0 build scripts were completely re-written to make it easier for future development. The new build scripts were built off Logger 1.4.0. As such, **if your current version is before 1.4.0 you need to run the uninstall script for your specific version**. If you're currently at 1.4.0 or above the installation script will automatically update your current version. The following query will identify your current version.

```sql
select pref_value
from logger_prefs
where pref_name = 'LOGGER_VERSION';
```

To uninstall an older version of logger, see the Uninstall (TODO link) instructions. If necessary, you can download the correct version from the [releases](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases) folder.

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

##To install into an existing schema:
1. If possible, connect as a privileged user and issue the following grants to your "exising_user":

	```sql
	grant connect,create view, create job, create table, create sequence,
create trigger, create procedure, create any context to existing_user
/
```

1. Run:
	```sql
@logger_install.sql
```

1. Once installed, logger is automatically set to **DEBUG** level. To configure the system logger level and other settings go to TODO link.

[top](#page-top)

#How to use Logger

The following example is the most basic us of Logger. This use-case will never change for this project as one of the goals is to eliminate any learning curve for a debugging utility.

```sql
exec logger.log('hello world');

select *
from logger_logs;
```

##TODO Main Logger Procs
TODO highlight each one 
TODO make note / reference to the various levels (which will be documented later on)

##Parameters
The primary logger procedures (TODO link to procs) have three common parameters: *p_text*, *p_scope*, and *p_extra*. Each parameter is described below.

<a name="parameters-p_text"></a>
###*p_text*
You should always include some message. *p_text* maps to the *text* column in *logger_logs*. As such it should not exceed 4000 characters. If you need to store more text you can use the [*p_extra*](#parameters-p_extra) parameter.

<a name="parameters-p_scope"></a>
###*p_scope* (optional *but highly recommend*)
The idea behind scope is to give some context to the log message, such as the application, package.procedure where it was called. Logger does capture the call stack, as well as module and action which are great for APEX logging as they are app number / page number. However, none of these options gives you a clean, consistent way to group messages. So, the *p_scope* parameter is really nothing special as it simply performs a lower() on the input and stores it in the scope column.

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

When calling *logger.log_error* it is highly recommended that you leverage this 4th parameter. See (TODO link to log params) for an example.

TODO other items

#Advanced use

##Error Handling

TODO

##Log Params
Logger has wrapper functions to quickly and easily log parameters. These parameters will be logged using the DEBUG level (i.e its the same as calling logger.log) except when explicitly used in the log_error procedure. The values are explicitly converted to strings so you don't need to convert them. The parameters will be stored either in the text field or (if they exceed 4000 characters) in the extra column.

The following example highlights how to use the log parameter wrappers:

```sql
create or replace procedure p_demo_function(
  p_empno in emp.empno%type,
  p_ename in emp.ename%type)
as
  l_scope logger_logs.scope%type := 'p_demo_function';
  l_params logger.tab_param;
begin
  logger.append_param(l_params, 'p_empno', p_empno);
  logger.append_param(l_params, 'p_ename', p_ename);
  logger.log_params(l_params, l_scope);
  -- ...
exception
  when others then
    logger.log_error('Unhandled Exception', l_scope, null, l_params);
end p_demo_function;
/
```

Parameters can also be passed in as the last (4th) parameter in the log_error procedure. This is useful in production instances where the logger level is usually set to ERROR. When an error occurs parameters will be logged in the extra column.
[top](#logger---a-pl-sql-logging-utility)

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
##Version 1.5.0
* Added log_params and append_param functions

[top](#logger---a-pl-sql-logging-utility)
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
