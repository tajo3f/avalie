-- TAJO AVALIE SaaS V2
-- Billing, contacts, admin overview and controlled status mutations.

create table if not exists public.company_contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  email text,
  phone text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists company_contacts_one_primary_idx on public.company_contacts(company_id) where is_primary = true;
create index if not exists company_contacts_company_idx on public.company_contacts(company_id);

create table if not exists public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  reference_month date not null,
  amount numeric(10,2) not null check (amount >= 0),
  due_date date not null,
  status text not null default 'open' check (status in ('open','paid','overdue','cancelled')),
  paid_at timestamptz,
  external_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, reference_month)
);
create index if not exists billing_invoices_company_due_idx on public.billing_invoices(company_id, due_date desc);
create index if not exists billing_invoices_status_idx on public.billing_invoices(status, due_date);

-- updated_at automatico
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='company_contacts_set_updated_at') THEN
    CREATE TRIGGER company_contacts_set_updated_at BEFORE UPDATE ON public.company_contacts
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='billing_invoices_set_updated_at') THEN
    CREATE TRIGGER billing_invoices_set_updated_at BEFORE UPDATE ON public.billing_invoices
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

alter table public.company_contacts enable row level security;
alter table public.billing_invoices enable row level security;

revoke all on public.company_contacts from anon, authenticated;
revoke all on public.billing_invoices from anon, authenticated;
grant select on public.company_contacts to authenticated;
grant select on public.billing_invoices to authenticated;

create policy company_contacts_select on public.company_contacts
for select to authenticated
using (private.has_company_access(company_id) or private.is_platform_admin());

create policy billing_invoices_select on public.billing_invoices
for select to authenticated
using (private.has_company_access(company_id) or private.is_platform_admin());

-- Dono/gerente pode alterar somente o status operacional da avaliação via RPC.
create or replace function public.set_feedback_status(p_feedback_id uuid, p_status text)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare v_company_id uuid;
begin
  if p_status not in ('new','analyzing','resolved','archived') then raise exception 'INVALID_STATUS'; end if;
  select company_id into v_company_id from public.feedbacks where id=p_feedback_id;
  if v_company_id is null then raise exception 'NOT_FOUND'; end if;
  if not private.has_company_access(v_company_id) then raise exception 'FORBIDDEN'; end if;
  update public.feedbacks set status=p_status, updated_at=now() where id=p_feedback_id;
  insert into public.audit_logs(company_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_company_id,(select auth.uid()),'feedback.status_changed','feedback',p_feedback_id::text,jsonb_build_object('status',p_status));
  return true;
end; $$;

create or replace function public.set_incident_status(p_incident_id uuid, p_status text)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare v_company_id uuid;
begin
  if p_status not in ('new','analyzing','resolved','archived') then raise exception 'INVALID_STATUS'; end if;
  select company_id into v_company_id from public.incidents where id=p_incident_id;
  if v_company_id is null then raise exception 'NOT_FOUND'; end if;
  if not private.has_company_access(v_company_id) then raise exception 'FORBIDDEN'; end if;
  update public.incidents set status=p_status, updated_at=now() where id=p_incident_id;
  insert into public.audit_logs(company_id,actor_user_id,action,entity_type,entity_id,metadata)
  values(v_company_id,(select auth.uid()),'incident.status_changed','incident',p_incident_id::text,jsonb_build_object('status',p_status));
  return true;
end; $$;

-- Visao consolidada do Admin TAJO. Nada desta funcao e liberado para anon.
create or replace function public.admin_companies()
returns table(
  id uuid,
  name text,
  slug text,
  status text,
  plan_name text,
  setup_price numeric,
  monthly_price numeric,
  point_limit integer,
  point_count bigint,
  feedback_count bigint,
  next_due_date date,
  subscription_status text,
  responsible text,
  email text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if not private.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  return query
  select c.id,c.name,c.slug,c.status,
         coalesce(s.plan_name,c.plan_name),coalesce(s.setup_price,c.setup_price),coalesce(s.monthly_price,c.monthly_price),coalesce(s.point_limit,c.point_limit),
         (select count(*) from public.evaluation_points p where p.company_id=c.id and p.active=true),
         (select count(*) from public.feedbacks f where f.company_id=c.id),
         s.next_due_date,s.status,
         cc.name,cc.email,c.created_at
  from public.companies c
  left join public.subscriptions s on s.company_id=c.id
  left join public.company_contacts cc on cc.company_id=c.id and cc.is_primary=true
  order by c.created_at desc;
end; $$;

create or replace function public.admin_create_company_v2(
  p_name text,
  p_slug text,
  p_responsible_name text default null,
  p_responsible_email text default null,
  p_primary_color text default '#0A5CFF',
  p_setup_price numeric default 390.00,
  p_monthly_price numeric default 390.00,
  p_point_limit integer default 12,
  p_billing_day integer default 15
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_result jsonb; v_company_id uuid; v_due date;
begin
  if not private.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  v_result := public.admin_create_company(p_name,p_slug,'Loja Principal','principal',p_primary_color,p_monthly_price,p_setup_price,p_point_limit,p_billing_day);
  v_company_id := (v_result->>'company_id')::uuid;
  if nullif(btrim(coalesce(p_responsible_name,'')),'') is not null then
    insert into public.company_contacts(company_id,name,email,is_primary)
    values(v_company_id,btrim(p_responsible_name),nullif(lower(btrim(coalesce(p_responsible_email,''))),''),true);
  end if;
  v_due := (date_trunc('month', current_date) + interval '1 month')::date + (least(p_billing_day,28)-1);
  update public.subscriptions set next_due_date=v_due where company_id=v_company_id;
  return v_result || jsonb_build_object('next_due_date',v_due);
end; $$;

-- Admin controla faturas sem expor escrita direta.
create or replace function public.admin_upsert_invoice(
  p_company_id uuid,
  p_reference_month date,
  p_amount numeric,
  p_due_date date,
  p_status text default 'open',
  p_paid_at timestamptz default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare v_id uuid;
begin
  if not private.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  if p_status not in ('open','paid','overdue','cancelled') then raise exception 'INVALID_STATUS'; end if;
  insert into public.billing_invoices(company_id,reference_month,amount,due_date,status,paid_at,notes)
  values(p_company_id,date_trunc('month',p_reference_month)::date,p_amount,p_due_date,p_status,p_paid_at,p_notes)
  on conflict(company_id,reference_month) do update set amount=excluded.amount,due_date=excluded.due_date,status=excluded.status,paid_at=excluded.paid_at,notes=excluded.notes,updated_at=now()
  returning id into v_id;
  return v_id;
end; $$;

revoke all on function public.set_feedback_status(uuid,text) from public,anon,authenticated;
revoke all on function public.set_incident_status(uuid,text) from public,anon,authenticated;
revoke all on function public.admin_companies() from public,anon,authenticated;
revoke all on function public.admin_create_company_v2(text,text,text,text,text,numeric,numeric,integer,integer) from public,anon,authenticated;
revoke all on function public.admin_upsert_invoice(uuid,date,numeric,date,text,timestamptz,text) from public,anon,authenticated;

grant execute on function public.set_feedback_status(uuid,text) to authenticated;
grant execute on function public.set_incident_status(uuid,text) to authenticated;
grant execute on function public.admin_companies() to authenticated;
grant execute on function public.admin_create_company_v2(text,text,text,text,text,numeric,numeric,integer,integer) to authenticated;
grant execute on function public.admin_upsert_invoice(uuid,date,numeric,date,text,timestamptz,text) to authenticated;
