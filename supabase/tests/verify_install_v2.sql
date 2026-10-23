-- TAJO Avalie V2 - verificação estrutural pós-instalação
-- Deve retornar zero linhas na seção 'missing'.

with expected(kind,name) as (
  values
  ('table','companies'),('table','stores'),('table','profiles'),('table','platform_admins'),('table','company_users'),
  ('table','employees'),('table','evaluation_points'),('table','point_slug_aliases'),('table','shifts'),('table','evaluation_reasons'),
  ('table','feedbacks'),('table','incidents'),('table','incident_feedbacks'),('table','internal_notes'),('table','notifications'),
  ('table','audit_logs'),('table','subscriptions'),('table','company_contacts'),('table','billing_invoices'),
  ('view','v_points_live'),('view','v_feedback_details'),('view','v_incident_details'),('view','v_team_members')
), present as (
  select 'table'::text kind, tablename::text name from pg_tables where schemaname='public'
  union all
  select 'view'::text kind, viewname::text name from pg_views where schemaname='public'
)
select 'missing' as check_type,e.kind,e.name
from expected e left join present p using(kind,name)
where p.name is null
order by e.kind,e.name;

-- Funções que o frontend usa.
select routine_name
from information_schema.routines
where routine_schema='public'
  and routine_name in (
    'get_my_context','get_public_evaluation_context','submit_feedback','start_shift','end_shift',
    'dashboard_summary','top_employees','point_performance','reason_stats','hourly_performance',
    'set_feedback_status','set_incident_status','admin_companies','admin_create_company_v2','admin_upsert_invoice'
  )
order by routine_name;

-- RLS deve estar ativo nas tabelas sensíveis.
select c.relname as table_name,c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('companies','company_users','employees','evaluation_points','feedbacks','incidents','subscriptions','company_contacts','billing_invoices')
order by c.relname;
