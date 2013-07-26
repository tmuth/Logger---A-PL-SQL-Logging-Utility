<a name="page-top" />
Logger: A PL/SQL Logging Utility
=================================
TODO remove invalid link and link to wiki
- [What is Logger?](#what-is-logger)
- [Installation](#installation)
- [How to use Logger](#how-to-use-logger)
- [Advanced use](#advanced-use)
- [Best Practices](#best-practices)
- [Change Log](#change-log)
- [License](#license)

#What is Logger? 

Logger is a PL/SQL logging and debugging framework. The goal of logger is to be as simple as possible to install and use. The primary use cases for this utility include:

* **Debugging**: It's often difficult to track down the source of an error without some form of debugging instrumentation. This is particularly true in multi-tier, stateless architectures such as Application Express.
* **Error Logging**: While most experts agree that it's important not to mask errors, it's also nice to have a persistent record of them.
* **Timing: Logger** has a very simple timing framework built-in that makes it easy to benchmark sections of code.
* **Instrumentation**: Because it's easy to "turn-off" logger globally with virtually no performance impact, it's easy to get in the habit of leaving debug calls in production code. Now, when something does go wrong, you simply flip the switch and logger is enabled making it much quicker to debug errors.

##Feedback/Issues
Please submit any feedback, suggestions, or issues on the project's [issue page](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/issues).

#Demo
```sql
exec logger.log('hello world');

select * from logger_logs;
-- This will display all the logged logs
```

See the [Logger API](wiki/Logger-API) documentation for complete set of procedures.

#Change Log
##[Version 2.1.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/2.0.1)
* TODO check what was flagged in the 2.1.0 milestone
* Made ok\_to\_log (TODO link) public function
* If *p\_text* is greater than 4000 characters, it automatically moves content to *EXTRA* column. (TODO thank Jurgen for this)
- TODO test
- TODO document


##[Version 2.0.0](https://github.com/tmuth/Logger---A-PL-SQL-Logging-Utility/tree/master/releases/2.0.0)
* Moved to GitHub and restructured / updated documentation
* Added [p_params](#log-params) support and [append_params](#log-params) function
* [Client specific level](#client-specific-configuration) setting (to enable logging based on client_id)
* New build script which will allow for future versions of logger to be updated. This was built off a 1.4.0 release.


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
