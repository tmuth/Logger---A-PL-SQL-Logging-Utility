Logger---A-PL-SQL-Logging-Utility
=================================

Logger is used by Oracle developers to instrument their PL/SQL code

#What is Logger?
This is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

* Debugging: It's often difficult to track down the source of an error without some form of debugging instrumentation. This is particularly true in multi-tier, stateless architectures such as Application Express.
* Error Logging: While most experts agree that it's important not to mask errors, it's also nice to have a persistent record of them.
* Timing: Logger has a very simple timing framework built-in that makes it easy to benchmark sections of code.
* Instrumentation: Because it's easy to "turn-off" logger globally with virtually no performance impact, it's easy to get in the habit of leaving debug calls in production code. Now, when something does go wrong, you simply flip the switch and logger is enabled making it much quicker to debug errors.

#Installation

##To install into an existing schema:
1. If possible, connect as a privilidged user and issue the following grants to your "exising_user":

```sql
grant connect,create view, create job, create table, create sequence,
create trigger, create procedure, create any context to existing_user
/
```
2. Install logger

```sql
@logger_install.sql
```

#Advanced use
TODO other items
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

#Change Log
##Version 1.5.0
* Added log_params and append_param functions
