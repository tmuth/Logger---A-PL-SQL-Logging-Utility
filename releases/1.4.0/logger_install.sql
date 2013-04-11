whenever sqlerror exit
set serveroutput on

declare
    type t_sess_privs is table of pls_integer index by varchar2(50);
    l_sess_privs t_sess_privs;
    l_req_privs t_sess_privs;
    l_priv  varchar2(50);
    l_dummy pls_integer;
    l_priv_error  boolean := false;
begin
    l_req_privs('CREATE SESSION')       := 1;            
    l_req_privs('CREATE TABLE')         := 1;
    l_req_privs('CREATE VIEW')          := 1;
    l_req_privs('CREATE SEQUENCE')      := 1;
    l_req_privs('CREATE PROCEDURE')     := 1;
    l_req_privs('CREATE TRIGGER')       := 1;
    l_req_privs('CREATE ANY CONTEXT')   := 1;
    l_req_privs('CREATE JOB')           := 1;


    for c1 in (select privilege from session_privs)
    loop
        l_sess_privs(c1.privilege) := 1;
    end loop;  --c1

    dbms_output.put_line('_____________________________________________________________________________');
    
    l_priv := l_req_privs.first;
    loop
    exit when l_priv is null;
        begin
            l_dummy := l_sess_privs(l_priv);
        exception when no_data_found then
            dbms_output.put_line('Error, the current schema is missing the following privilege: '||l_priv);
            l_priv_error := true;
        end;
        l_priv := l_req_privs.next(l_priv);
    end loop;
    
    if not l_priv_error then
        dbms_output.put_line('User has all required privileges, installation will continue.');
    end if;
    
    dbms_output.put_line('_____________________________________________________________________________');

    if l_priv_error then
      raise_application_error (-20000,
                'One or more required privileges are missing.');
    end if;
end;
/

whenever sqlerror continue



create table logger_logs(
	id				    number,
	logger_level	    number,
	text	            varchar2(4000),
	time_stamp		    timestamp,
	scope               varchar2(1000),
	module			    varchar2(100),
	action			    varchar2(100),
	user_name	        varchar2(255),
    client_identifier   varchar2(255),
    call_stack		    varchar2(4000),
	unit_name		    varchar2(255),
	line_no			    varchar2(100),
    scn                 number,
    extra               clob,
	constraint logger_logs_pk primary key (id) enable,
	constraint logger_logs_lvl_ck check(logger_level in (1,2,4,8,16,32,64,128))
)
/


create sequence logger_logs_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
/

create or replace trigger  bi_logger_logs 
before insert on logger_logs 
for each row 
begin	
	select logger_logs_seq.nextval into :new.id from dual;
	:new.time_stamp 	:= systimestamp;
	:new.client_identifier	:= sys_context('userenv','client_identifier');
	:new.module 		:= sys_context('userenv','module');
	:new.action 		:= sys_context('userenv','action');
	$IF $$APEX $THEN
        :new.user_name 		:= nvl(v('APP_USER'),user);
    $ELSE
        :new.user_name 		:= user;
    $END
	:new.unit_name 	    :=  upper(:new.unit_name);
    $IF $$FLASHBACK_ENABLED $THEN
        :new.scn := dbms_flashback.get_system_change_number;
    $END
end;
/
show errors

create index logger_logs_idx1 on logger_logs(time_stamp,logger_level)
/



create table logger_prefs(
	pref_name	varchar2(255),
	pref_value	varchar2(255) not null,
	constraint logger_prefs_pk primary key (pref_name) enable
)
/

alter session set PLSQL_CCFLAGS='CURRENTLY_INSTALLING:TRUE'
/

create or replace trigger  biu_logger_prefs 
before insert or update on logger_prefs 
for each row 
begin
    
    if :new.pref_name = 'LEVEL' then
        if upper(:new.pref_value) not in ('OFF','PERMANENT','ERROR','WARNING','INFORMATION','DEBUG','TIMING') then
            raise_application_error (-20000,
                '"LEVEL" must be one of the following values: OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING');
        end if;
        :new.pref_value := upper(:new.pref_value);
    end if;
    
    $IF not $$CURRENTLY_INSTALLING $THEN
        -- this is because the logger package is not installed yet.  We enable it in logger_configure
        logger.null_global_contexts;
    $END
end;
/


merge into logger_prefs p
using (
    select 'PURGE_AFTER_DAYS'       PREF_NAME,  '7' PREF_VALUE from dual union
    select 'PURGE_MIN_LEVEL'        PREF_NAME,  'DEBUG' PREF_VALUE from dual union
    select 'LOGGER_VERSION'         PREF_NAME,  '1.4.0' PREF_VALUE from dual union
    select 'LEVEL'                  PREF_NAME,  'DEBUG' PREF_VALUE from dual union
    select 'PROTECT_ADMIN_PROCS'    PREF_NAME,  'TRUE' PREF_VALUE from dual union
    select 'INCLUDE_CALL_STACK'     PREF_NAME,  'TRUE' PREF_VALUE from dual union
    select 'INSTALL_SCHEMA'         PREF_NAME,  sys_context('USERENV','CURRENT_SCHEMA') PREF_VALUE from dual) d
    on (p.pref_name = d.pref_name)
when matched then 
    update set p.pref_value = d.pref_value
when not matched then 
    insert (p.pref_name,p.pref_value)
    values (d.pref_name,d.pref_value);


create table logger_logs_apex_items(
    id				number not null,
    log_id          number not null,
    app_session     number not null,
    item_name       varchar2(1000) not null,
    item_value      clob,
    constraint logger_logs_apx_itms_pk primary key (id) enable,
    constraint logger_logs_apx_itms_fk foreign key (log_id) references logger_logs(id) ON DELETE CASCADE
)
/

create index logger_apex_items_idx1 on logger_logs_apex_items(log_id)
/


create sequence logger_apx_items_seq
    minvalue 1
    maxvalue 999999999999999999999999999
    start with 1
    increment by 1
    cache 20
/


create or replace
TRIGGER  biu_logger_apex_items BEFORE INSERT or update ON logger_logs_apex_items 
FOR EACH ROW 
begin
	select logger_apx_items_seq.nextval into :new.id from dual;
end;
/



begin
  dbms_scheduler.create_job(
     job_name => 'LOGGER_PURGE_JOB',
     job_type => 'PLSQL_BLOCK',
     job_action => 'begin logger.purge; end; ',
     start_date => systimestamp,
     repeat_interval => 'FREQ=DAILY; BYHOUR=1',
     enabled => TRUE,
     comments => 'Purges LOGGER_LOGS using default values defined in logger_prefs.');
end;
/


create or replace force view logger_logs_5_min as
	select * 
      from logger_logs 
	 where time_stamp > systimestamp - (5/1440)
/

create or replace force view logger_logs_60_min as
	select * 
      from logger_logs 
	 where time_stamp > systimestamp - (1/24)
/


set termout off
-- setting termout off as this view will install with an error as it depends on logger.date_text_format
create or replace force view logger_logs_terse as
 select id, logger_level, 
        substr(logger.date_text_format(time_stamp),1,20) time_ago,
        substr(text,1,200) text
   from logger_logs
  where time_stamp > systimestamp - (5/1440)
  order by id asc
/

set termout on


declare 
	-- the following line is also used in a constant declaration in logger.pkb  
	l_ctx_name varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';
begin
	execute immediate 'create or replace context '||l_ctx_name||' using logger accessed globally';
	
	merge into logger_prefs p
	using (select 'GLOBAL_CONTEXT_NAME' PREF_NAME,  l_ctx_name PREF_VALUE from dual) d
		on (p.pref_name = d.pref_name)
	when matched then 
		update set p.pref_value = d.pref_value
	when not matched then 
		insert (p.pref_name,p.pref_value)
		values (d.pref_name,d.pref_value);
end;
/

create or replace package logger
authid definer
as
	g_logger_version    constant varchar2(10) := '1.4.0';
	g_context_name 		constant varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';
    
    g_permanent		    constant number := 1;
	g_error 		    constant number := 2;
	g_warning 		    constant number := 4;
	g_information	    constant number := 8;
    g_debug     	    constant number := 16;
	g_timing     	    constant number := 32;
    g_sys_context 	    constant number := 64;
    g_apex 	            constant number := 128;
    
    procedure null_global_contexts;
       
    function convert_level_char_to_num(
        p_level in varchar2)
    return number;
    
    function date_text_format (p_date in date)
        return varchar2;
	
	function get_character_codes(
		p_string 				in varchar2,
		p_show_common_codes 	in boolean default true)
	return varchar2;
    
    procedure log_error(
		p_text          in varchar2 default null,
        p_scope         in varchar2 default null,
        p_extra         in clob default null);
        
    procedure log_permanent(p_text    in varchar2,
                            p_scope   in varchar2 default null,
                            p_extra   in clob default null);
                            
    procedure log_warning(p_text    in varchar2,
                          p_scope   in varchar2 default null,
                          p_extra   in clob default null);
                          
    procedure log_information(p_text    in varchar2,
                              p_scope   in varchar2 default null,
                              p_extra   in clob default null);
                              
    procedure log(p_text    in varchar2,
                  p_scope   in varchar2 default null,
                  p_extra   in clob default null);
    
    function get_cgi_env(
			p_show_null		in boolean default false)
	return clob;
    
    procedure log_userenv(
        p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
		p_show_null 	in boolean default false,
        p_scope         in varchar2 default null);
        
    procedure log_cgi_env(
		p_show_null 	in boolean default false,
        p_scope         in varchar2 default null);
    
	procedure log_character_codes(
		p_text					in varchar2,
        p_scope					in varchar2 default null,
		p_show_common_codes 	in boolean default true);
		
    procedure log_apex_items(
		p_text		in varchar2 default 'Log APEX Items',
        p_scope		in varchar2 default null);
		
	procedure time_start(
		p_unit				in varchar2);
		
	procedure time_stop(
		p_unit				in varchar2);
        
    procedure time_reset;
        
  
	function get_pref(
		p_pref_name			in	varchar2)
	return varchar2
	$IF not dbms_db_version.ver_le_10_2 $THEN
		result_cache
	$END
	;
	
	procedure purge(
		p_purge_after_days	in varchar2	default null,
		p_purge_min_level	in varchar2	default null);
	
	procedure purge_all;
	
	procedure status(
		p_output_format	in varchar2 default null); -- SQL-DEVELOPER | HTML | DBMS_OUPUT
    
    procedure sqlplus_format;
        
    -- Valid values for p_level are:
    -- OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING
    procedure set_level(p_level in varchar2 default 'DEBUG');
end logger;
/
show errors

create or replace package body logger
as
    g_log_id    	number;
	
    
    -- Definitions of conditional compilation variables:
    -- $$NO_OP              : When true, completely disables all logger DML.  Also used to 
    --                      : generate the logger_no_op.sql code path
    --                      
    -- $$RAC_LT_11_2        : Set in logger_configure to handle the fact that RAC doesn't
    --                      : support global app contexts until 11.2
    --                      
    -- $$FLASHBACK_ENABLED  : Set in logger_configure to determine whether or not we can grab the scn from dbms_flashback.
    --                      : Primarily used in the trigger on logger_logs.
    --
    -- $$APEX               : Set in logger_configure.  True if we can query a local synonym to wwv_flow_data to snapshot
    --                      : the APEX session state.
    
   
    type ts_array is table of timestamp index by varchar2(100);
    g_proc_start_times ts_array;
    g_running_timers        pls_integer := 0;
    
    function admin_security_check
    return boolean
    is
        l_protect_admin_procs	varchar2(50)	:= get_pref('PROTECT_ADMIN_PROCS');
        l_return                boolean default false;
    begin
        if get_pref('PROTECT_ADMIN_PROCS') = 'TRUE' then
            if get_pref('INSTALL_SCHEMA') = sys_context('USERENV','SESSION_USER') then
                l_return := true;
            else
                l_return := false;
                raise_application_error (-20000,
                    'You are not authorized to call this procedure.');
            end if;
        else
            l_return := true;
        end if;
        
        return l_return;        
        
    end admin_security_check;

    procedure null_global_contexts
    is
    pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            $IF $$RAC_LT_11_2 $THEN
                null;
            $ELSE
                dbms_session.set_context(  
                    namespace  => g_context_name, 
                    attribute  => 'level', 
                    value      => null);
                    
                dbms_session.set_context(  
                    namespace  => g_context_name, 
                    attribute  => 'include_call_stack', 
                    value      => null);
            $END
           
        $END
        commit;
    end null_global_contexts;
    
    procedure save_global_context(
        p_attribute     in varchar2,
        p_value         in varchar2)
    is
    pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            dbms_session.set_context(  
                namespace  => g_context_name, 
                attribute  => p_attribute, 
                value      => p_value);
           commit;
        $END
    end save_global_context;
    
    function convert_level_char_to_num(
        p_level in varchar2)
    return number
    is
        l_level         number;
    begin
        case p_level
            when 'OFF'          then l_level := 0;
            when 'PERMANENT'    then l_level := 1;
            when 'ERROR'        then l_level := 2;
            when 'WARNING'      then l_level := 4;
            when 'INFORMATION'  then l_level := 8;
            when 'DEBUG'        then l_level := 16;
            when 'TIMING'       then l_level := 32;
            when 'SYS_CONTEXT'  then l_level := 64;
        else l_level := -1;
        end case;
        
        return l_level;
    end convert_level_char_to_num;
    
    function get_level_number
    return number
        $IF $$RAC_LT_11_2 $THEN
            $IF not dbms_db_version.ver_le_10_2 $THEN
                result_cache relies_on (logger_prefs)
            $END
        $END
    is
        l_level         number;
        l_level_char    varchar2(50);
    begin
        $IF $$NO_OP $THEN
            return 0;
        $ELSE
            for c1 in (select pref_value from logger_prefs where pref_name = 'LEVEL')
            loop
                l_level_char := c1.pref_value;
            end loop; --c1
            
            l_level := convert_level_char_to_num(l_level_char);
            
            return l_level;
        $END
    end get_level_number;

    function ok_to_log(p_level  in  number)        
        return boolean
        $IF $$RAC_LT_11_2 $THEN
            $IF not dbms_db_version.ver_le_10_2 $THEN
                $IF $$NO_OP is null or NOT $$NO_OP $THEN
                    result_cache relies_on (logger_prefs)
                $END
            $END
        $END
    is
        l_level         number;
        l_level_char    varchar2(50);
    begin
    $IF $$NO_OP $THEN
            return false;
    $ELSE
        $IF $$RAC_LT_11_2 $THEN
            l_level := get_level_number;
        $ELSE
            l_level := sys_context(g_context_name,'level');
            if l_level is null then 
                l_level := get_level_number;
                save_global_context('level',l_level);
            end if;
        $END
        
        if l_level >= p_level then
            return true;
        else
            return false;
        end if;
    $END
    end ok_to_log;
    
    
    function include_call_stack
        return boolean
        $IF $$RAC_LT_11_2 $THEN
            $IF not dbms_db_version.ver_le_10_2 $THEN
                $IF $$NO_OP is null or NOT $$NO_OP $THEN
                    result_cache relies_on (logger_prefs)
                $END
            $END
        $END
    is
        l_call_stack_pref   varchar2(50);
    begin
    $IF $$NO_OP $THEN
            return false;
    $ELSE
        $IF $$RAC_LT_11_2 $THEN
            l_call_stack_pref := get_pref('INCLUDE_CALL_STACK');
        $ELSE
            l_call_stack_pref := sys_context(g_context_name,'include_call_stack');
            if l_call_stack_pref is null then 
                l_call_stack_pref := get_pref('INCLUDE_CALL_STACK');
                save_global_context('include_call_stack',l_call_stack_pref);
            end if;
        $END
        
        if l_call_stack_pref = 'TRUE' then
            return true;
        else
            return false;
        end if;
    $END
    end include_call_stack;
    
    
    function date_text_format_base (
        p_date_start in date,
        p_date_stop  in date)
    return varchar2
    as
        x	varchar2(20);
    begin
        x := 	case
                    when p_date_stop-p_date_start < 1/1440
                        then round(24*60*60*(p_date_stop-p_date_start)) || ' seconds'
                    when p_date_stop-p_date_start < 1/24
                        then round(24*60*(p_date_stop-p_date_start)) || ' minutes'
                    when p_date_stop-p_date_start < 1
                        then round(24*(p_date_stop-p_date_start)) || ' hours'
                    when p_date_stop-p_date_start < 14
                        then trunc(p_date_stop-p_date_start) || ' days'
                    when p_date_stop-p_date_start < 60
                        then trunc((p_date_stop-p_date_start)/7) || ' weeks'
                    when p_date_stop-p_date_start < 365
                        then round(months_between(p_date_stop,p_date_start)) || ' months'
                    else round(months_between(p_date_stop,p_date_start)/12,1) || ' years'
               end;
        x:= regexp_replace(x,'(^1 [[:alnum:]]{4,10})s','\1');
        x:= x || ' ago';
        return substr(x,1,20);
    end date_text_format_base;
    
    
    
    function date_text_format (p_date in date)
    return varchar2
    as
    begin
        return date_text_format_base(
                p_date_start => p_date   ,
                p_date_stop  => sysdate);

    end date_text_format;
	
	function get_character_codes(
		p_string 				in varchar2,
		p_show_common_codes 	in boolean default true)
	return varchar2
	is
		l_string	varchar2(32767);
		l_dump		varchar2(32767);
		l_return	varchar2(32767);
	begin
		-- replace tabs with ^
        l_string := replace(p_string,chr(9),'^');
		-- replace all other control characters such as carriage return / line feeds with ~
		l_string := regexp_replace(l_string,'[[:cntrl:]]','~',1,0,'m');
		
		
		select dump(p_string) into l_dump from dual;
		
		l_dump	:= regexp_replace(l_dump,'(^.+?:)(.*)','\2',1,0); -- get everything after the :
		l_dump	:= ','||l_dump||','; -- leading and trailing commas
		l_dump	:= replace(l_dump,',',',,'); -- double the commas. this is for the regex.
		l_dump 	:= regexp_replace(l_dump,'(,)([[:digit:]]{1})(,)','\1  \2\3',1,0); -- lpad all single digit numbers out to 3
		l_dump 	:= regexp_replace(l_dump,'(,)([[:digit:]]{2})(,)','\1 \2\3',1,0);  -- lpad all double digit numbers out to 3
		l_dump	:= ltrim(replace(l_dump,',,',','),','); -- remove the double commas
        l_dump  := lpad(' ',(5-instr(l_dump,',')),' ')||l_dump;
		
		-- replace every individual character with 2 spaces, itself and a comma so it lines up with the dump output
		l_string := ' '||regexp_replace(l_string,'(.){1}','  \1,',1,0);
		
       
        
		l_return := rtrim(l_dump,',') || chr(10) || rtrim(l_string,',');
		
		if p_show_common_codes then
			l_return := 'Common Codes: 13=Line Feed, 10=Carriage Return, 32=Space, 9=Tab'||chr(10) ||l_return;
		end if;
		
		return l_return;
		
	end get_character_codes;
	
    procedure get_debug_info(
        p_callstack     in clob,
        o_unit          out varchar2,
        o_lineno        out varchar2 ) as
    --
        l_callstack varchar2(3000) := p_callstack;
    begin
      l_callstack := substr( l_callstack, instr( l_callstack, chr(10), 1, 5 )+1 );
      l_callstack := substr( l_callstack, 1, instr( l_callstack, chr(10), 1, 1 )-1 );
      l_callstack := trim( substr( l_callstack, instr( l_callstack, ' ' ) ) );
      o_lineno := substr( l_callstack, 1, instr( l_callstack, ' ' )-1 );
      o_unit := trim(substr( l_callstack, instr( l_callstack, ' ', -1, 1 ) ));
    end get_debug_info;
    
    
    procedure  log_internal(
            p_text				in varchar2,
            p_log_level			in number,
            p_scope             in varchar2,
            p_extra             in clob default null,
            p_callstack         in varchar2 default null)
	is
        l_proc_name     	varchar2(100);
        l_lineno        	varchar2(100);
        l_text 				varchar2(4000);
        l_callstack         varchar2(3000);
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            l_text := p_text;
            if p_callstack is not null and include_call_stack then
                get_debug_info(
                    p_callstack     => p_callstack,
                    o_unit          => l_proc_name, 
                    o_lineno        => l_lineno);
                    
                l_callstack  := regexp_replace(p_callstack,'^.*$','',1,4,'m');
                l_callstack  := regexp_replace(l_callstack,'^.*$','',1,1,'m');
                l_callstack  := ltrim(replace(l_callstack,chr(10)||chr(10),chr(10)),chr(10));
                    
            end if;
                        
            insert into logger_logs (logger_level,text,call_stack,unit_name,line_no,scope,extra)
                values	  			(p_log_level,l_text,l_callstack,l_proc_name,l_lineno,lower(p_scope), p_extra) returning id into g_log_id ;
            commit;
        $END
	end log_internal;   
    
    procedure snapshot_apex_items(
        p_log_id in number)
    is
        l_app_session number;
        l_app_id       number;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            $IF $$APEX $THEN
                l_app_session := v('APP_SESSION');
                l_app_id := v('APP_ID');
                for c1 in (select item_name
                             from apex_application_items
                            where application_id = l_app_id)
                loop
                    insert into logger_logs_apex_items(log_id,app_session,item_name,item_value)
                    values
                    (p_log_id,l_app_session,c1.item_name,v(c1.item_name));
                end loop; --c1
				
				for c1 in (select item_name
                             from apex_application_page_items
                            where application_id = l_app_id)
                loop
                    insert into logger_logs_apex_items(log_id,app_session,item_name,item_value)
                    values
                    (p_log_id,l_app_session,c1.item_name,v(c1.item_name));
                end loop; --c1
              
            $END
            null;
        $END
    end snapshot_apex_items;
    
    
    procedure log_error(
		p_text          in varchar2 default null,
        p_scope         in varchar2 default null,
        p_extra         in clob default null)
	is
        l_proc_name     varchar2(100);
        l_lineno        varchar2(100);
        l_text          varchar2(4000);
		pragma autonomous_transaction;
        l_call_stack    varchar2(4000);
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_error) then
                -- get_debug_info( l_proc_name, l_lineno );
                
                get_debug_info(
                    p_callstack     => dbms_utility.format_call_stack,
                    o_unit          => l_proc_name, 
                    o_lineno        => l_lineno);
                    
                l_call_stack := dbms_utility.format_error_stack() ||chr(10)||dbms_utility.format_error_backtrace;
                
                if p_text is not null then
                    l_text := p_text ||' '|| chr(10)||chr(10);
                end if;
                
                l_text := l_text || dbms_utility.format_error_stack();
                        
                insert into logger_logs (logger_level,text,unit_name,line_no,call_stack,scope,extra)
                            values	  (logger.g_error,l_text,l_proc_name,l_lineno,l_call_stack,p_scope,p_extra) returning id into g_log_id;
                            
                commit;
            end if;
        $END
	end log_error;
	
    
    procedure log_permanent(p_text    in varchar2,
                            p_scope   in varchar2 default null,
                            p_extra   in clob default null)
	is
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_permanent) then
                log_internal(
                    p_text				=> p_text,
                    p_log_level			=> logger.g_permanent,
                    p_scope             => p_scope,
                    p_extra             => p_extra,
                    p_callstack         => dbms_utility.format_call_stack);
                commit;
            end if;
        $END
	end log_permanent;
    
    
    procedure log_warning(p_text    in varchar2,
                          p_scope   in varchar2 default null,
                          p_extra   in clob default null)
	is
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
        if ok_to_log(logger.g_warning) then
            log_internal(
                p_text				=> p_text,
                p_log_level			=> logger.g_warning,
                p_scope             => p_scope,
                p_extra             => p_extra,
                p_callstack         => dbms_utility.format_call_stack);
            commit;
        end if;
        $END
	end log_warning;
    
    procedure log_information(p_text    in varchar2,
                              p_scope   in varchar2 default null,
                              p_extra   in clob default null)
	is
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_information) then
                log_internal(
                    p_text				=> p_text,
                    p_log_level			=> logger.g_information,
                    p_scope             => p_scope,
                    p_extra             => p_extra,
                    p_callstack         => dbms_utility.format_call_stack);
                commit;
            end if;
        $END
	end log_information;
    
	procedure log(p_text    in varchar2,
                  p_scope   in varchar2 default null,
                  p_extra   in clob default null)
	is
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_debug) then
                log_internal(
                    p_text				=> p_text,
                    p_log_level			=> logger.g_debug,
                    p_scope             => p_scope,
                    p_extra             => p_extra,
                    p_callstack         => dbms_utility.format_call_stack);
                commit;
            end if;
        $END
	end log;
    
    function get_sys_context(p_detail_level in varchar2 default 'USER', -- ALL, NLS, USER, INSTANCE
                             p_vertical     in boolean default false,
							 p_show_null	in boolean default false) -- vertical name value pairs or comma sep list.
    return clob
    is
        l_ctx   clob;
        l_detail_level varchar2(20) := upper(p_detail_level);
        
        procedure append_ctx(p_name in varchar2)
        is
            r_pad                   number := 30;
            l_crlf                  varchar2(10) := chr(13)||chr(10);
            invalid_userenv_parm    exception;
            pragma 				    exception_init(invalid_userenv_parm, -2003);
        begin
			if p_show_null or sys_context('USERENV',p_name) is not null then
				if p_vertical then
					l_ctx := l_ctx || rpad(p_name,r_pad,' ')||': '||sys_context('USERENV',p_name)||l_crlf;
				else
					l_ctx := l_ctx || p_name||': '||sys_context('USERENV',p_name)||', ';
				end if;
			end if;
            exception when invalid_userenv_parm then
                --log_warning('Invalid SYS_CONTEXT Parameter: '||p_name);
                null;
        end append_ctx;
    begin
        
        if l_detail_level in ('ALL','NLS','INSTANCE') then
            append_ctx('NLS_CALENDAR');
            append_ctx('NLS_CURRENCY');
            append_ctx('NLS_DATE_FORMAT');
            append_ctx('NLS_DATE_LANGUAGE');
            append_ctx('NLS_SORT');
            append_ctx('NLS_TERRITORY');
            append_ctx('LANG');
            append_ctx('LANGUAGE');
        end if;
        
        if l_detail_level in ('ALL','USER') then
            append_ctx('CURRENT_SCHEMA');
            append_ctx('SESSION_USER');
            append_ctx('OS_USER');
            append_ctx('CLIENT_IDENTIFIER');
            append_ctx('CLIENT_INFO');
            append_ctx('IP_ADDRESS');
            append_ctx('HOST');
            append_ctx('TERMINAL');
        end if;
        
        if l_detail_level in ('ALL','USER') then
            append_ctx('AUTHENTICATED_IDENTITY');
            append_ctx('AUTHENTICATION_DATA');
            append_ctx('AUTHENTICATION_METHOD');
            append_ctx('ENTERPRISE_IDENTITY');
            append_ctx('POLICY_INVOKER');
            append_ctx('PROXY_ENTERPRISE_IDENTITY');
            append_ctx('PROXY_GLOBAL_UID');
            append_ctx('PROXY_USER');
            append_ctx('PROXY_USERID');
            append_ctx('IDENTIFICATION_TYPE');
            append_ctx('ISDBA');
        end if;

        if l_detail_level in ('ALL','INSTANCE') then
            append_ctx('DB_DOMAIN');
            append_ctx('DB_NAME');
            append_ctx('DB_UNIQUE_NAME');
            append_ctx('INSTANCE');
            append_ctx('INSTANCE_NAME');
            append_ctx('SERVER_HOST');
            append_ctx('SERVICE_NAME');
        end if;
        
        
        
        if l_detail_level in ('ALL') then
            append_ctx('ACTION');
            append_ctx('AUDITED_CURSORID');
            append_ctx('BG_JOB_ID');
            append_ctx('CURRENT_BIND');
            append_ctx('CURRENT_SCHEMAID');
            append_ctx('CURRENT_SQL');
            append_ctx('CURRENT_SQLn');
            append_ctx('CURRENT_SQL_LENGTH');
            append_ctx('ENTRYID');
            append_ctx('FG_JOB_ID');
            append_ctx('GLOBAL_CONTEXT_MEMORY');
            append_ctx('GLOBAL_UID');
            append_ctx('MODULE');
            append_ctx('NETWORK_PROTOCOL');
            append_ctx('SESSION_USERID');
            append_ctx('SESSIONID');
            append_ctx('SID');
            append_ctx('STATEMENTID');
        end if;
		
		
		
        
        return rtrim(l_ctx,', ');
    end get_sys_context;
	
	
	function get_cgi_env(
			p_show_null		in boolean default false)
	return clob
	is
		l_cgienv clob;
		
		procedure append_cgi_env(
			p_name 		in varchar2,
			p_val	 	in varchar2)
        is
            r_pad                   number := 30;
            l_crlf                  varchar2(10) := chr(13)||chr(10);
            --invalid_userenv_parm    exception;
            --pragma 				    exception_init(invalid_userenv_parm, -2003);
        begin
			if p_show_null or p_val is not null then
                l_cgienv := l_cgienv || rpad(p_name,r_pad,' ')||': '||p_val||l_crlf;
			end if;
            --exception when invalid_userenv_parm then
                --log_warning('Invalid SYS_CONTEXT Parameter: '||p_name);
                null;
        end append_cgi_env;
	begin
        $IF $$NO_OP $THEN
            return null;
        $ELSE
            for i in 1..owa.num_cgi_vars loop
                append_cgi_env(
                    p_name      => owa.cgi_var_name(i),
                    p_val       => owa.cgi_var_val(i));
                
            end loop;
            
            return l_cgienv;
        $END
	end get_cgi_env;
    
    procedure log_userenv(
        p_detail_level  in varchar2 default 'USER',-- ALL, NLS, USER, INSTANCE,
		p_show_null 	in boolean default false,
        p_scope         in varchar2 default null) 
    is
		l_extra	clob;
    pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
             if ok_to_log(logger.g_debug) then
				l_extra := get_sys_context(
								p_detail_level	=> p_detail_level,
								p_vertical		=> true,
								p_show_null		=> p_show_null);
								
                log_internal(
                    p_text				=> 'USERENV values stored in the EXTRA column',
                    p_log_level			=> logger.g_sys_context,
                    p_scope             => p_scope,
                    p_extra             => l_extra);
                commit;
            end if;
        $END
    end log_userenv;
    
    
    
    procedure log_cgi_env(
		p_show_null 	in boolean default false,
        p_scope         in varchar2 default null) 
    is
		l_extra	clob;
    pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
             if ok_to_log(logger.g_debug) then
				l_extra := get_cgi_env(p_show_null		=> p_show_null);
								
                log_internal(
                    p_text				=> 'CGI ENV values stored in the EXTRA column',
                    p_log_level			=> logger.g_sys_context,
                    p_scope             => p_scope,
                    p_extra             => l_extra);
                commit;
            end if;
        $END
    end log_cgi_env;
	
	
	
	procedure log_character_codes(
		p_text					in varchar2,
        p_scope					in varchar2 default null,
		p_show_common_codes 	in boolean default true)
    is
        l_error varchar2(4000);
		l_dump clob;
	pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
			if ok_to_log(logger.g_debug) then
				l_dump := get_character_codes(p_text,p_show_common_codes);
			
                log_internal(
                    p_text				=> 'GET_CHARACTER_CODES output stored in the EXTRA column',
                    p_log_level			=> logger.g_debug,
                    p_scope             => p_scope,
                    p_extra             => l_dump);
                commit;
            end if;
		$END
	end log_character_codes;
    
	
	
	procedure log_apex_items(
		p_text		in varchar2 default 'Log APEX Items',
        p_scope		in varchar2 default null)
    is
        l_error varchar2(4000);
	pragma autonomous_transaction;
    begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_debug) then
                
                $IF $$APEX $THEN
                    log_internal(
                        p_text				=> p_text,
                        p_log_level			=> logger.g_apex,
                        p_scope             => p_scope);
                        
                    snapshot_apex_items(p_log_id => g_log_id);
                $ELSE
                    l_error := 'Error! Logger is not configured for APEX yet. '||
                               'Please check the CONFIGURATION section at https://logger.samplecode.oracle.com ';
                
                    log_internal(
                        p_text				=> l_error,
                        p_log_level			=> logger.g_apex,
                        p_scope             => p_scope);
                $END
            end if;
        $END
        commit;
    end log_apex_items;
	
	procedure time_start(
		p_unit				in varchar2)
	is
		l_proc_name     	varchar2(100);
		l_text 				varchar2(4000);
        l_pad               varchar2(100);
		pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_debug) then      
                g_running_timers := g_running_timers + 1;
                
                if g_running_timers > 1 then
                    l_pad := lpad(' ',g_running_timers,'>')||' ';
                end if;
                
                g_proc_start_times(p_unit) := systimestamp;

                l_text := l_pad||'START: '||p_unit;
                
                insert into logger_logs (logger_level,text,unit_name)
                            values	    (g_timing,l_text,p_unit) returning id into g_log_id ;
                commit;
            end if;
        $END
	end time_start;
	
	procedure time_stop(
		p_unit				in varchar2)
	is
		l_time_string   	varchar2(50);
        l_text 				varchar2(4000);
        l_pad               varchar2(100);
        
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if ok_to_log(logger.g_debug) then
                if g_proc_start_times.exists(p_unit) then
                    
                    if g_running_timers > 1 then
                        l_pad := lpad(' ',g_running_timers,'>')||' ';
                    end if;
                    
                    l_time_string := rtrim(regexp_replace(systimestamp-(g_proc_start_times(p_unit)),'.+?[[:space:]](.*)','\1',1,0),0);
                        
                    l_text := l_pad||'STOP : '||p_unit ||' - '||l_time_string;

                    g_proc_start_times.delete(p_unit);
                    g_running_timers := g_running_timers - 1;
                    
                    insert into logger_logs (logger_level,text,unit_name)
                                values	    (g_timing,l_text,p_unit) returning id into g_log_id ;
                    commit;
                end if;
            end if;
        $END
	end time_stop;
    
    procedure time_reset
    is
    begin
        if ok_to_log(logger.g_debug) then
            g_running_timers := 0;
            g_proc_start_times.delete;
        end if;
    end time_reset;
	
	function get_pref(
		p_pref_name		in	varchar2)
		return varchar2
		$IF not dbms_db_version.ver_le_10_2  $THEN
			result_cache 
            $IF $$NO_OP is null or NOT $$NO_OP $THEN
                relies_on (logger_prefs)
            $END
		$END
	is
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            for c1 in (select pref_value from logger_prefs where pref_name = p_pref_name)
            loop
                return c1.pref_value;
            end loop; --c1
            return null;
        $END
	end get_pref;
	
	procedure purge(
		p_purge_after_days	in varchar2	default null,
		p_purge_min_level	in varchar2	default null)

	is
		$IF $$NO_OP is null or NOT $$NO_OP $THEN
            l_purge_min_level	    number	:= convert_level_char_to_num(nvl(p_purge_min_level,get_pref('PURGE_MIN_LEVEL')));
            l_purge_after_days	    number	:= nvl(p_purge_after_days,get_pref('PURGE_AFTER_DAYS'));
        $END
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if admin_security_check then
                delete
                  from logger_logs
                 where logger_level >= l_purge_min_level
                   and time_stamp < systimestamp - NUMTODSINTERVAL(l_purge_after_days, 'day')
                   and logger_level > g_permanent;
            end if;
        $END
        commit;
	end purge;
  
  
	procedure purge_all
	is
		l_purge_level	number	:= g_permanent;
        pragma autonomous_transaction;
	begin
        $IF $$NO_OP $THEN
            null;
        $ELSE
            if admin_security_check then
                delete from logger_logs where logger_level > l_purge_level;
            end if;
        $END
        commit;
	end purge_all;
	
	procedure status(
		p_output_format	in varchar2 default null) -- SQL-DEVELOPER | HTML | DBMS_OUPUT
	is
		l_debug			varchar2(50) := 'Disabled';
        
		l_apex			varchar2(50) := 'Disabled';
		l_flashback		varchar2(50) := 'Disabled';
		dummy			varchar2(255);
		l_output_format	varchar2(30);
        l_version       varchar2(20);
		
		procedure display_output(
			p_name	in varchar2,
			p_value	in varchar2)
		is
		begin
			if l_output_format = 'SQL-DEVELOPER' then
				dbms_output.put_line('<pre>'||rpad(p_name,20)||': <strong>'||p_value||'</strong></pre>');
			elsif l_output_format = 'HTTP' then
				htp.p('<br />'||p_name||': <strong>'||p_value||'</strong>');
			else
				dbms_output.put_line(rpad(p_name,25)||': '||p_value);
			end if;
		end display_output;
		
	begin
		if p_output_format is null then
			begin
				dummy := owa_util.get_cgi_env('HTTP_HOST');
				l_output_format	:= 'HTTP';
			exception
				when VALUE_ERROR then
				l_output_format	:= 'DBMS_OUTPUT';
				dbms_output.enable;
			end;
		else
			l_output_format := p_output_format;
		end if;
		
        display_output('Project Home Page','https://logger.samplecode.oracle.com/');
        
        $IF $$NO_OP $THEN
            display_output('Debug Level','NO-OP, Logger completely disabled.');
        $ELSE
            $IF $$APEX $THEN
                l_apex := 'Enabled';
            $END
            
            for c1 in (select pref_value from logger_prefs where pref_name = 'LEVEL')
            loop
                l_debug := c1.pref_value;
            end loop; --c1
        
		

		
            $IF $$FLASHBACK_ENABLED $THEN
                l_flashback := 'Enabled';
            $END
            
            l_version := get_pref('LOGGER_VERSION');
            
            
            
            display_output('Logger Version',l_version);
            display_output('Debug Level',l_debug);
            display_output('Capture Call Stack',get_pref('INCLUDE_CALL_STACK'));
            display_output('Protect Admin Procedures',get_pref('PROTECT_ADMIN_PROCS'));
            display_output('APEX Tracing',l_apex);
            display_output('SCN Capture',l_flashback);
            display_output('Min. Purge Level',get_pref('PURGE_MIN_LEVEL'));
            display_output('Purge Older Than',get_pref('PURGE_AFTER_DAYS')||' days');
            $IF $$RAC_LT_11_2  $THEN
                display_output('RAC pre-11.2 Code','TRUE');
            $END
        $END
       
		
	end status;
    
    -- Valid values for p_level are:
    -- OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING
    procedure set_level(p_level in varchar2 default 'DEBUG')
    is
        l_level varchar2(20);
        l_ctx   varchar2(2000);
        l_old_level varchar2(20);
        pragma autonomous_transaction;
    begin
        l_level := replace(upper(p_level),' ');
        
        if l_level not in ('OFF','PERMANENT','ERROR','WARNING','INFORMATION','DEBUG','TIMING') then
            raise_application_error (-20000,
                '"LEVEL" must be one of the following values: OFF,PERMANENT,ERROR,WARNING,INFORMATION,DEBUG,TIMING');
        end if;
        
        $IF $$NO_OP $THEN
            raise_application_error (-20000,
                'Either the NO-OP version of Logger is installed or it is compiled for NO-OP,  so you cannot set the level.');
        $ELSE
            if admin_security_check then
                l_ctx := 'Host: '||sys_context('USERENV','HOST');
                l_ctx := l_ctx || ', IP: '||sys_context('USERENV','IP_ADDRESS');
                l_ctx := l_ctx || ', TERMINAL: '||sys_context('USERENV','TERMINAL');
                l_ctx := l_ctx || ', OS_USER: '||sys_context('USERENV','OS_USER');
                l_ctx := l_ctx || ', CURRENT_USER: '||sys_context('USERENV','CURRENT_USER');
                l_ctx := l_ctx || ', SESSION_USER: '||sys_context('USERENV','SESSION_USER');
                
                l_old_level := logger.get_pref('LEVEL');
                
                update logger_prefs set pref_value = l_level where pref_name = 'LEVEL';
                logger.save_global_context('level',logger.convert_level_char_to_num(l_level));
                logger.log_information('Log level changed from '||l_old_level||' to '||l_level||' by '||l_ctx);
            end if;
        $END
        commit;
    end set_level;
    
    procedure sqlplus_format
    is
    begin
        execute immediate 'begin dbms_output.enable(1000000); end;';
        dbms_output.put_line('set linesize 200');
        dbms_output.put_line('set pagesize 100');
        
        dbms_output.put_line('column id format 999999');
        dbms_output.put_line('column text format a75');
        dbms_output.put_line('column call_stack format a100');
        dbms_output.put_line('column extra format a100');
        
    end sqlplus_format;
   

end logger;
/
show errors


create or replace procedure logger_configure
is
    l_rac_lt_11_2       varchar2(50) := 'FALSE';  -- is this a RAC instance less than 11.2, no GAC support
    
    l_apex              varchar2(50) := 'FALSE';
    tbl_not_exist       exception;
    pls_pkg_not_exist   exception;
    --no_data_found       exception;
    
    l_sql		        varchar2(32767);
	l_variables	        varchar2(1000) := ' ';
    l_dummy             number;
    l_flashback         varchar2(50) := 'FALSE';
    pragma 				exception_init(tbl_not_exist, -942);
    --pragma 				exception_init(no_data_found, -1403);
    pragma 				exception_init(pls_pkg_not_exist, -06550);
    
	l_version           constant number  := dbms_db_version.version + (dbms_db_version.release / 10);
begin
    
    /* ************************************************************************** */
    -- Check to see if we are in a RAC Database, 11.1 or lower.
    --
    if dbms_utility.is_cluster_database then
        l_rac_lt_11_2 := 'TRUE';
    else
        l_rac_lt_11_2 := 'FALSE';
    end if;
    
    if l_version >= 11.2 then
		l_rac_lt_11_2 := 'FALSE';
	end if;
    
    l_variables := 'RAC_LT_11_2:'||l_rac_lt_11_2||',';
    --
    /* ************************************************************************** */
    
    
    /* ************************************************************************** */
    -- Is APEX installed ?
    --
    begin
        execute immediate 'select 1 from apex_application_items where rownum = 1' into l_dummy;
        
        l_apex := 'TRUE';
    exception 
        when tbl_not_exist then l_apex := 'FALSE'; 
        when no_data_found then 
            l_apex := 'TRUE'; 
    end;
    
    l_variables := l_variables||'APEX:'||l_apex||',';
    --
    /* ************************************************************************** */
    
    
    
    
    /* ************************************************************************** */
    -- Can we call dbms_flashback to get the currect System Commit Number?
    --
    begin
        execute immediate 'begin :d := dbms_flashback.get_system_change_number; end; ' using out l_dummy;
        
        l_flashback := 'TRUE';
    exception when pls_pkg_not_exist then 
                l_flashback := 'FALSE'; 
    end;
    
    l_variables := l_variables||'FLASHBACK_ENABLED:'||l_flashback||',';
    --
    /* ************************************************************************** */
    
    
    
    
    
    l_variables :=  rtrim(l_variables,',');
    
	
	l_sql := q'[alter package logger compile body PLSQL_CCFLAGS=']'||l_variables||q'['  reuse settings]';
	
	execute immediate l_sql;
	
	l_sql := q'[alter trigger BI_LOGGER_LOGS compile PLSQL_CCFLAGS=']'||l_variables||q'[' reuse settings]';

	execute immediate l_sql;
    
    l_sql := q'[alter trigger biu_logger_prefs compile PLSQL_CCFLAGS='CURRENTLY_INSTALLING:FALSE']';
    
    execute immediate l_sql;
    
    -- just in case this is a re-install / upgrade, the global contexts will persist so reset them
    logger.null_global_contexts;
    
end logger_configure;
/
show errors



-- grant select on apex_030200.wwv_flow_data to logger;

-- create synonym logger.wwv_flow_data for apex_030200.wwv_flow_data;

-- (as sys) grant execute on dbms_flashback to logger;

begin 
	logger_configure; 
 end;
/

begin 
	logger.set_level('DEBUG'); 
end;
/

prompt 
prompt ************************************************* 
prompt Now executing LOGGER.STATUS...
prompt 

begin 
	logger.status; 
end;
/

prompt ************************************************* 
begin 
	logger.log_permanent('Logger version '||logger.get_pref('LOGGER_VERSION')||' installed.'); 
end;
/



