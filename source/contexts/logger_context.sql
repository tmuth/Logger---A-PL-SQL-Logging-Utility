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