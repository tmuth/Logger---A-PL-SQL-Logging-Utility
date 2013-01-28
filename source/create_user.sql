Rem    NAME
Rem      create_user.sql
Rem
Rem    DESCRIPTION
Rem      Use this file to create a user / schema in which to install the logger packages
Rem
Rem    NOTES
Rem      Assumes the SYS / SYSTEM user is connected.
Rem
Rem    REQUIREMENTS
Rem      - Oracle 10.2+
Rem
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem       tmuth    11/02/2006 - Created

set define '&'

set verify off
prompt
prompt
prompt Logger create schema script.
prompt You will be prompted for a username, tablespace, temporary tablespace and password.
prompt


define LOGGER_USER=LOGGER_USER
accept LOGGER_USER char default &LOGGER_USER prompt 'Name of the new logger schema to create       [&LOGGER_USER] :'

define LOGGER_TABLESPACE=USERS
accept LOGGER_TABLESPACE char default &LOGGER_TABLESPACE prompt 'Tablespace for the new logger schema           [&LOGGER_TABLESPACE] :'

define TEMP_TABLESPACE=TEMP
accept TEMP_TABLESPACE char default &TEMP_TABLESPACE prompt 'Temporary Tablespace for the new logger schema  [&TEMP_TABLESPACE] :'

accept PASSWD CHAR prompt 'Enter a password for the logger schema              [] :' HIDE

create user &LOGGER_USER identified by &PASSWD default tablespace &LOGGER_TABLESPACE temporary tablespace &TEMP_TABLESPACE
/

alter user &LOGGER_USER quota unlimited on &LOGGER_TABLESPACE 
/

grant connect,create view, create job, create table, create sequence, create trigger, create procedure, create any context to &LOGGER_USER 
/

prompt
prompt
prompt &LOGGER_USER user successfully created.
prompt Important!!! Connect as the &LOGGER_USER user and run the logger_install.sql script.
prompt
prompt

exit
