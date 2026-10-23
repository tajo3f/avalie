-- TAJO Avalia - Verification queries
-- Safe to run after installation.

-- 1) Expected tables.
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'companies','stores','profiles','platform_admins','company_users','employees',
    'evaluation_points','point_slug_aliases','shifts','evaluation_reasons','feedbacks',
    'incidents','incident_feedbacks','internal_notes','notifications','audit_logs','subscriptions'
  )
order by tablename;

-- All returned rows should have rowsecurity = true.

-- 2) Public schema must not contain SECURITY DEFINER application RPCs after hardening.
select n.nspname as schema_name, p.proname, p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_my_context','get_public_evaluation_context','submit_feedback','start_shift','end_shift',
    'dashboard_summary','top_employees','point_performance','reason_stats','hourly_performance',
    'admin_create_company','add_company_user_by_email','admin_set_subscription'
  )
order by p.proname;

-- security_definer should be false for all rows above.

-- 3) Privileged bodies should be in private and SECURITY DEFINER.
select n.nspname as schema_name, p.proname, p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private'
  and p.proname in (
    'get_my_context','get_public_evaluation_context','submit_feedback','start_shift','end_shift',
    'dashboard_summary','top_employees','point_performance','reason_stats','hourly_performance',
    'admin_create_company','add_company_user_by_email','admin_set_subscription'
  )
order by p.proname;

-- security_definer should be true for all rows above.

-- 4) The anon role should NOT have direct table writes.
select
  has_table_privilege('anon', 'public.feedbacks', 'insert') as anon_can_insert_feedback,
  has_table_privilege('anon', 'public.feedbacks', 'select') as anon_can_select_feedback,
  has_table_privilege('anon', 'public.companies', 'select') as anon_can_select_companies;

-- All values above should be false.

-- 5) Public RPCs should be callable by anon, but management RPCs should not.
select
  has_function_privilege('anon', 'public.get_public_evaluation_context(text,text)', 'execute') as anon_context,
  has_function_privilege('anon', 'public.submit_feedback(text,text,integer,text[],text,text)', 'execute') as anon_submit,
  has_function_privilege('anon', 'public.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer)', 'execute') as anon_admin_create;

-- Expected: true, true, false.

-- 6) Views.
select table_name
from information_schema.views
where table_schema = 'public'
  and table_name like 'v_%'
order by table_name;
