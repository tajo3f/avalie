-- TAJO Avalie V2 base - 006 Move privileged function bodies out of exposed public schema.
-- Public functions become SECURITY INVOKER wrappers; privileged bodies live in private.

alter function public.get_my_context() set schema private;
alter function public.get_public_evaluation_context(text,text) set schema private;
alter function public.submit_feedback(text,text,integer,text[],text,text) set schema private;
alter function public.start_shift(uuid,uuid) set schema private;
alter function public.end_shift(uuid) set schema private;
alter function public.dashboard_summary(uuid,timestamptz,timestamptz) set schema private;
alter function public.top_employees(uuid,timestamptz,timestamptz,integer) set schema private;
alter function public.point_performance(uuid,timestamptz,timestamptz) set schema private;
alter function public.reason_stats(uuid,timestamptz,timestamptz) set schema private;
alter function public.hourly_performance(uuid,timestamptz,timestamptz) set schema private;
alter function public.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) set schema private;
alter function public.add_company_user_by_email(uuid,text,text,uuid) set schema private;
alter function public.admin_set_subscription(uuid,text,numeric,numeric,integer,date) set schema private;

-- Public wrappers used by PostgREST / supabase.rpc().
create or replace function public.get_my_context()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.get_my_context();
$$;

create or replace function public.get_public_evaluation_context(p_company_slug text, p_point_slug text)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.get_public_evaluation_context(p_company_slug, p_point_slug);
$$;

create or replace function public.submit_feedback(
  p_company_slug text,
  p_point_slug text,
  p_rating integer,
  p_reason_codes text[] default '{}'::text[],
  p_comment text default null,
  p_client_nonce text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.submit_feedback(
    p_company_slug, p_point_slug, p_rating, p_reason_codes, p_comment, p_client_nonce
  );
$$;

create or replace function public.start_shift(p_point_id uuid, p_employee_id uuid)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.start_shift(p_point_id, p_employee_id);
$$;

create or replace function public.end_shift(p_shift_id uuid)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select private.end_shift(p_shift_id);
$$;

create or replace function public.dashboard_summary(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()),
  p_to timestamptz default now()
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.dashboard_summary(p_company_id, p_from, p_to);
$$;

create or replace function public.top_employees(
  p_company_id uuid,
  p_from timestamptz default date_trunc('month', now()),
  p_to timestamptz default now(),
  p_min_reviews integer default 20
)
returns table(
  employee_id uuid,
  employee_name text,
  average_rating numeric,
  review_count bigint,
  positive_percent numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.top_employees(p_company_id, p_from, p_to, p_min_reviews);
$$;

create or replace function public.point_performance(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()),
  p_to timestamptz default now()
)
returns table(
  point_id uuid,
  point_name text,
  point_type text,
  average_rating numeric,
  review_count bigint,
  negative_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.point_performance(p_company_id, p_from, p_to);
$$;

create or replace function public.reason_stats(
  p_company_id uuid,
  p_from timestamptz default date_trunc('month', now()),
  p_to timestamptz default now()
)
returns table(reason_code text, reason_label text, mention_count bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.reason_stats(p_company_id, p_from, p_to);
$$;

create or replace function public.hourly_performance(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()) - interval '30 days',
  p_to timestamptz default now()
)
returns table(hour_of_day integer, average_rating numeric, review_count bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.hourly_performance(p_company_id, p_from, p_to);
$$;

create or replace function public.admin_create_company(
  p_name text,
  p_slug text,
  p_store_name text default 'Loja Principal',
  p_store_slug text default 'principal',
  p_primary_color text default '#0A5CFF',
  p_monthly_price numeric default 390.00,
  p_setup_price numeric default 390.00,
  p_point_limit integer default 12,
  p_billing_day integer default 15
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.admin_create_company(
    p_name, p_slug, p_store_name, p_store_slug, p_primary_color,
    p_monthly_price, p_setup_price, p_point_limit, p_billing_day
  );
$$;

create or replace function public.add_company_user_by_email(
  p_company_id uuid,
  p_email text,
  p_role text,
  p_store_id uuid default null
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.add_company_user_by_email(p_company_id, p_email, p_role, p_store_id);
$$;

create or replace function public.admin_set_subscription(
  p_company_id uuid,
  p_status text,
  p_monthly_price numeric default null,
  p_setup_price numeric default null,
  p_point_limit integer default null,
  p_next_due_date date default null
)
returns boolean
language sql
security invoker
set search_path = ''
as $$
  select private.admin_set_subscription(
    p_company_id, p_status, p_monthly_price, p_setup_price, p_point_limit, p_next_due_date
  );
$$;

-- Private bodies are not exposed by PostgREST; grant only what wrappers need.
grant usage on schema private to anon, authenticated;

revoke all on function private.get_my_context() from public, anon, authenticated;
revoke all on function private.get_public_evaluation_context(text,text) from public, anon, authenticated;
revoke all on function private.submit_feedback(text,text,integer,text[],text,text) from public, anon, authenticated;
revoke all on function private.start_shift(uuid,uuid) from public, anon, authenticated;
revoke all on function private.end_shift(uuid) from public, anon, authenticated;
revoke all on function private.dashboard_summary(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function private.top_employees(uuid,timestamptz,timestamptz,integer) from public, anon, authenticated;
revoke all on function private.point_performance(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function private.reason_stats(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function private.hourly_performance(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function private.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) from public, anon, authenticated;
revoke all on function private.add_company_user_by_email(uuid,text,text,uuid) from public, anon, authenticated;
revoke all on function private.admin_set_subscription(uuid,text,numeric,numeric,integer,date) from public, anon, authenticated;

grant execute on function private.get_public_evaluation_context(text,text) to anon, authenticated;
grant execute on function private.submit_feedback(text,text,integer,text[],text,text) to anon, authenticated;

grant execute on function private.get_my_context() to authenticated;
grant execute on function private.start_shift(uuid,uuid) to authenticated;
grant execute on function private.end_shift(uuid) to authenticated;
grant execute on function private.dashboard_summary(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function private.top_employees(uuid,timestamptz,timestamptz,integer) to authenticated;
grant execute on function private.point_performance(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function private.reason_stats(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function private.hourly_performance(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function private.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) to authenticated;
grant execute on function private.add_company_user_by_email(uuid,text,text,uuid) to authenticated;
grant execute on function private.admin_set_subscription(uuid,text,numeric,numeric,integer,date) to authenticated;

-- Public wrapper permissions.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.get_public_evaluation_context(text,text) to anon, authenticated;
grant execute on function public.submit_feedback(text,text,integer,text[],text,text) to anon, authenticated;

grant execute on function public.get_my_context() to authenticated;
grant execute on function public.start_shift(uuid,uuid) to authenticated;
grant execute on function public.end_shift(uuid) to authenticated;
grant execute on function public.dashboard_summary(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.top_employees(uuid,timestamptz,timestamptz,integer) to authenticated;
grant execute on function public.point_performance(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.reason_stats(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.hourly_performance(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) to authenticated;
grant execute on function public.add_company_user_by_email(uuid,text,text,uuid) to authenticated;
grant execute on function public.admin_set_subscription(uuid,text,numeric,numeric,integer,date) to authenticated;

-- Safer defaults for future migrations created by the same owner.
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema private revoke execute on functions from public;
