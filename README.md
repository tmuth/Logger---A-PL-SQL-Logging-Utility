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

2. ssdsd
