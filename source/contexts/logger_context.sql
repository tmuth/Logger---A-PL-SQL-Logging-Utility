declare
	-- the following line is also used in a constant declaration in logger.pkb
	l_ctx_name varchar2(35) := substr(sys_context('USERENV','CURRENT_SCHEMA'),1,23)||'_LOGCTX';
begin
	execute immediate 'create or replace context '||l_ctx_name||' using logger accessed globally';

	merge into logger_prefs p
	using (select 'GLOBAL_CONTEXT_NAME' pref_name, l_ctx_name pref_value, logger.g_pref_type_logger pref_type from dual) d
		on (1=1
			and p.pref_type = d.pref_type
			and p.pref_name = d.pref_name)
	when matched then
		update set p.pref_value = d.pref_value
	when not matched then
		insert (p.pref_name, p.pref_value, p.pref_type)
		values (d.pref_name, d.pref_value, d.pref_type);
end;
/
