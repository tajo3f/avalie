-- TAJO AVALIE SaaS V2 - INSTALL_ALL.sql
-- Execute em projeto Supabase NOVO/Vazio, uma única vez.

-- ============================================================
-- FILE: 202610150001_schema.sql
-- ============================================================
-- TAJO Avalie V2 base - 001 Core schema
-- PostgreSQL / Supabase

create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  logo_url text,
  logo_text text,
  primary_color text not null default '#0A5CFF' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  timezone text not null default 'America/Sao_Paulo',
  feedback_question text not null default 'Como foi seu atendimento?' check (char_length(feedback_question) between 5 and 160),
  feedback_subtitle text not null default 'Sua opinião ajuda a melhorar sua experiência aqui.' check (char_length(feedback_subtitle) between 0 and 240),
  thank_you_message text not null default 'Obrigado por compartilhar sua experiência.' check (char_length(thank_you_message) between 2 and 240),
  comments_enabled boolean not null default true,
  status text not null default 'active' check (status in ('active','pending','suspended','cancelled')),
  plan_name text not null default 'Profissional',
  setup_price numeric(10,2) not null default 390.00 check (setup_price >= 0),
  monthly_price numeric(10,2) not null default 390.00 check (monthly_price >= 0),
  point_limit integer not null default 12 check (point_limit > 0),
  billing_day integer not null default 15 check (billing_day between 1 and 28),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, slug)
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, slug),
  unique(id, company_id)
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.company_users (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, user_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict
);

create index if not exists company_users_user_idx on public.company_users(user_id) where active = true;
create index if not exists company_users_company_idx on public.company_users(company_id) where active = true;

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  name text not null check (char_length(name) between 2 and 120),
  employee_code text,
  role_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_code),
  unique(id, company_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict
);

create index if not exists employees_company_active_idx on public.employees(company_id, active, name);

create table if not exists public.evaluation_points (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  name text not null check (char_length(name) between 2 and 100),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  point_type text not null default 'Caixa' check (char_length(point_type) between 2 and 60),
  public_code uuid not null default gen_random_uuid() unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, slug),
  unique(id, company_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict
);

create index if not exists evaluation_points_company_active_idx on public.evaluation_points(company_id, active, name);

create table if not exists public.point_slug_aliases (
  id uuid primary key default gen_random_uuid(),
  point_id uuid not null,
  company_id uuid not null references public.companies(id) on delete cascade,
  old_slug text not null check (old_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_at timestamptz not null default now(),
  unique(company_id, old_slug),
  foreign key (point_id, company_id) references public.evaluation_points(id, company_id) on delete cascade
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  point_id uuid not null,
  employee_id uuid not null,
  started_by uuid references auth.users(id) on delete set null,
  ended_by uuid references auth.users(id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active' check (status in ('active','ended','cancelled')),
  created_at timestamptz not null default now(),
  unique(id, company_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict,
  foreign key (point_id, company_id) references public.evaluation_points(id, company_id) on delete restrict,
  foreign key (employee_id, company_id) references public.employees(id, company_id) on delete restrict,
  check (
    (status = 'active' and ended_at is null)
    or (status in ('ended','cancelled') and ended_at is not null)
  )
);

create unique index if not exists shifts_one_active_per_point_idx
  on public.shifts(point_id) where status = 'active';
create unique index if not exists shifts_one_active_per_employee_idx
  on public.shifts(employee_id) where status = 'active';
create index if not exists shifts_company_started_idx on public.shifts(company_id, started_at desc);

create table if not exists public.evaluation_reasons (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null check (code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  label text not null check (char_length(label) between 2 and 80),
  active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists evaluation_reasons_global_code_uidx
  on public.evaluation_reasons(code) where company_id is null;
create unique index if not exists evaluation_reasons_company_code_uidx
  on public.evaluation_reasons(company_id, code) where company_id is not null;

create table if not exists public.feedbacks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  point_id uuid not null,
  shift_id uuid,
  employee_id uuid,
  rating smallint not null check (rating between 1 and 5),
  reason_codes text[] not null default '{}'::text[],
  comment text check (comment is null or char_length(comment) <= 500),
  client_nonce_hash text,
  status text not null default 'new' check (status in ('new','analyzing','resolved','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id, company_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict,
  foreign key (point_id, company_id) references public.evaluation_points(id, company_id) on delete restrict,
  foreign key (shift_id, company_id) references public.shifts(id, company_id) on delete restrict,
  foreign key (employee_id, company_id) references public.employees(id, company_id) on delete restrict
);

create index if not exists feedbacks_company_created_idx on public.feedbacks(company_id, created_at desc);
create index if not exists feedbacks_point_created_idx on public.feedbacks(point_id, created_at desc);
create index if not exists feedbacks_employee_created_idx on public.feedbacks(employee_id, created_at desc) where employee_id is not null;
create index if not exists feedbacks_rating_created_idx on public.feedbacks(company_id, rating, created_at desc);
create index if not exists feedbacks_nonce_created_idx on public.feedbacks(point_id, client_nonce_hash, created_at desc) where client_nonce_hash is not null;

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid,
  point_id uuid,
  employee_id uuid,
  severity text not null check (severity in ('info','warning','critical')),
  incident_type text not null default 'feedback' check (char_length(incident_type) between 2 and 60),
  title text not null check (char_length(title) between 2 and 180),
  description text,
  status text not null default 'new' check (status in ('new','analyzing','resolved','archived')),
  assignee_user_id uuid references auth.users(id) on delete set null,
  source text not null default 'automatic' check (source in ('automatic','manual')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(id, company_id),
  foreign key (store_id, company_id) references public.stores(id, company_id) on delete restrict,
  foreign key (point_id, company_id) references public.evaluation_points(id, company_id) on delete restrict,
  foreign key (employee_id, company_id) references public.employees(id, company_id) on delete restrict
);

create index if not exists incidents_company_status_idx on public.incidents(company_id, status, created_at desc);
create index if not exists incidents_point_created_idx on public.incidents(point_id, created_at desc) where point_id is not null;

create table if not exists public.incident_feedbacks (
  incident_id uuid not null references public.incidents(id) on delete cascade,
  feedback_id uuid not null references public.feedbacks(id) on delete cascade,
  primary key (incident_id, feedback_id)
);

create table if not exists public.internal_notes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  feedback_id uuid,
  incident_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (num_nonnulls(feedback_id, incident_id) = 1),
  foreign key (feedback_id, company_id) references public.feedbacks(id, company_id) on delete cascade,
  foreign key (incident_id, company_id) references public.incidents(id, company_id) on delete cascade
);

create index if not exists internal_notes_company_created_idx on public.internal_notes(company_id, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 180),
  detail text,
  kind text not null default 'info' check (kind in ('info','success','warning','critical')),
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_unread_idx on public.notifications(user_id, created_at desc) where read_at is null;

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  company_id uuid references public.companies(id) on delete set null,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_company_created_idx on public.audit_logs(company_id, created_at desc);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.companies(id) on delete cascade,
  plan_name text not null default 'Profissional',
  setup_price numeric(10,2) not null default 390.00 check (setup_price >= 0),
  monthly_price numeric(10,2) not null default 390.00 check (monthly_price >= 0),
  point_limit integer not null default 12 check (point_limit > 0),
  status text not null default 'active' check (status in ('trial','active','past_due','suspended','cancelled')),
  next_due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Função genérica para updated_at. Não é SECURITY DEFINER.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Recria triggers de updated_at de forma idempotente.
do $$
declare
  t text;
begin
  foreach t in array array['companies','stores','profiles','company_users','employees','evaluation_points','evaluation_reasons','feedbacks','incidents','subscriptions']
  loop
    execute format('drop trigger if exists %I_set_updated_at on public.%I', t, t);
    execute format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- Evita reutilizar um slug antigo de outro ponto e quebrar QR Codes já impressos.
create or replace function private.validate_point_slug()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists(
    select 1
    from public.point_slug_aliases a
    where a.company_id = new.company_id
      and a.old_slug = new.slug
      and a.point_id is distinct from new.id
  ) then
    raise exception 'POINT_SLUG_RESERVED_BY_ALIAS';
  end if;

  -- Se o próprio ponto voltar a usar um slug antigo, o alias deixa de ser necessário.
  delete from public.point_slug_aliases a
  where a.company_id = new.company_id
    and a.old_slug = new.slug
    and a.point_id = new.id;

  return new;
end;
$$;

drop trigger if exists evaluation_points_validate_slug on public.evaluation_points;
create trigger evaluation_points_validate_slug
before insert or update of slug, company_id on public.evaluation_points
for each row execute function private.validate_point_slug();

-- Mantém URL antiga funcionando quando o slug de um ponto muda.
create or replace function private.capture_point_slug_alias()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.slug is distinct from new.slug then
    insert into public.point_slug_aliases(point_id, company_id, old_slug)
    values(old.id, old.company_id, old.slug)
    on conflict (company_id, old_slug) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists evaluation_points_capture_slug_alias on public.evaluation_points;
create trigger evaluation_points_capture_slug_alias
after update of slug on public.evaluation_points
for each row execute function private.capture_point_slug_alias();

-- Limite do plano é imposto no banco, inclusive ao reativar ponto.
create or replace function public.enforce_point_limit()
returns trigger
language plpgsql
as $$
declare
  v_limit integer;
  v_count integer;
begin
  if new.active is not true then
    return new;
  end if;

  select coalesce(s.point_limit, c.point_limit)
    into v_limit
  from public.companies c
  left join public.subscriptions s on s.company_id = c.id
  where c.id = new.company_id;

  if v_limit is null then
    raise exception 'COMPANY_NOT_FOUND';
  end if;

  select count(*)
    into v_count
  from public.evaluation_points p
  where p.company_id = new.company_id
    and p.active = true
    and p.id is distinct from new.id;

  if v_count >= v_limit then
    raise exception 'POINT_LIMIT_REACHED';
  end if;

  return new;
end;
$$;

drop trigger if exists evaluation_points_enforce_limit on public.evaluation_points;
create trigger evaluation_points_enforce_limit
before insert or update of active, company_id on public.evaluation_points
for each row execute function public.enforce_point_limit();

-- ============================================================
-- FILE: 202610150002_security_rls.sql
-- ============================================================
-- TAJO Avalie V2 base - 002 Security, RLS and auth bootstrap

-- SECURITY DEFINER helpers live outside exposed public schema.
create or replace function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.platform_admins pa
    where pa.user_id = (select auth.uid())
  );
$$;

create or replace function private.has_company_access(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin()
    or exists(
      select 1
      from public.company_users cu
      where cu.company_id = p_company_id
        and cu.user_id = (select auth.uid())
        and cu.active = true
    );
$$;

create or replace function private.has_company_role(p_company_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin()
    or exists(
      select 1
      from public.company_users cu
      where cu.company_id = p_company_id
        and cu.user_id = (select auth.uid())
        and cu.active = true
        and cu.role = any(p_roles)
    );
$$;

create or replace function private.can_view_profile(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id = (select auth.uid())
    or private.is_platform_admin()
    or exists(
      select 1
      from public.company_users mine
      join public.company_users theirs on theirs.company_id = mine.company_id
      where mine.user_id = (select auth.uid())
        and mine.active = true
        and theirs.user_id = p_user_id
        and theirs.active = true
    );
$$;

create or replace function private.is_note_owner(p_note_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.internal_notes n
    where n.id = p_note_id
      and n.created_by = (select auth.uid())
  );
$$;

-- Sincroniza auth.users -> public.profiles.
create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(user_id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email
  )
  on conflict (user_id) do update
    set email = excluded.email,
        full_name = case
          when public.profiles.full_name = '' then excluded.full_name
          else public.profiles.full_name
        end,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email, raw_user_meta_data on auth.users
for each row execute function private.handle_new_auth_user();

-- Backfill de usuários já existentes.
insert into public.profiles(user_id, full_name, email)
select u.id, coalesce(u.raw_user_meta_data->>'full_name',''), u.email
from auth.users u
on conflict (user_id) do update set email = excluded.email;

-- RLS em todas as tabelas expostas.
alter table public.companies enable row level security;
alter table public.stores enable row level security;
alter table public.profiles enable row level security;
alter table public.platform_admins enable row level security;
alter table public.company_users enable row level security;
alter table public.employees enable row level security;
alter table public.evaluation_points enable row level security;
alter table public.point_slug_aliases enable row level security;
alter table public.shifts enable row level security;
alter table public.evaluation_reasons enable row level security;
alter table public.feedbacks enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_feedbacks enable row level security;
alter table public.internal_notes enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;
alter table public.subscriptions enable row level security;

-- Remove privilégios amplos antes de conceder o mínimo necessário.
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
revoke usage on schema private from public, anon;
revoke execute on all functions in schema private from public, anon, authenticated;

grant usage on schema public to anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_platform_admin() to authenticated;
grant execute on function private.has_company_access(uuid) to authenticated;
grant execute on function private.has_company_role(uuid,text[]) to authenticated;
grant execute on function private.can_view_profile(uuid) to authenticated;
grant execute on function private.is_note_owner(uuid) to authenticated;

-- Policies: profiles.
drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
for select to authenticated
using ((select private.can_view_profile(user_id)));

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update to authenticated
using (user_id = (select auth.uid()) or (select private.is_platform_admin()))
with check (user_id = (select auth.uid()) or (select private.is_platform_admin()));

-- Platform admins can only read admin membership through client API.
drop policy if exists platform_admins_select on public.platform_admins;
create policy platform_admins_select on public.platform_admins
for select to authenticated
using (user_id = (select auth.uid()) or (select private.is_platform_admin()));

-- Companies.
drop policy if exists companies_select on public.companies;
create policy companies_select on public.companies
for select to authenticated
using ((select private.has_company_access(id)));

drop policy if exists companies_insert_admin on public.companies;
create policy companies_insert_admin on public.companies
for insert to authenticated
with check ((select private.is_platform_admin()));

drop policy if exists companies_update on public.companies;
create policy companies_update on public.companies
for update to authenticated
using ((select private.has_company_role(id, array['owner']::text[])))
with check ((select private.has_company_role(id, array['owner']::text[])));

drop policy if exists companies_delete_admin on public.companies;
create policy companies_delete_admin on public.companies
for delete to authenticated
using ((select private.is_platform_admin()));

-- Stores: everyone in company reads; only owner/admin changes store structure.
drop policy if exists stores_select on public.stores;
create policy stores_select on public.stores
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists stores_insert on public.stores;
create policy stores_insert on public.stores
for insert to authenticated
with check ((select private.has_company_role(company_id, array['owner']::text[])));

drop policy if exists stores_update on public.stores;
create policy stores_update on public.stores
for update to authenticated
using ((select private.has_company_role(company_id, array['owner']::text[])))
with check ((select private.has_company_role(company_id, array['owner']::text[])));

-- Company users.
drop policy if exists company_users_select on public.company_users;
create policy company_users_select on public.company_users
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists company_users_insert on public.company_users;
create policy company_users_insert on public.company_users
for insert to authenticated
with check ((select private.has_company_role(company_id, array['owner']::text[])));

drop policy if exists company_users_update on public.company_users;
create policy company_users_update on public.company_users
for update to authenticated
using ((select private.has_company_role(company_id, array['owner']::text[])))
with check ((select private.has_company_role(company_id, array['owner']::text[])));

-- Employees are soft-deleted via active=false.
drop policy if exists employees_select on public.employees;
create policy employees_select on public.employees
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists employees_insert on public.employees;
create policy employees_insert on public.employees
for insert to authenticated
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

drop policy if exists employees_update on public.employees;
create policy employees_update on public.employees
for update to authenticated
using ((select private.has_company_role(company_id, array['owner','manager']::text[])))
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

-- Evaluation points are soft-deleted via active=false.
drop policy if exists points_select on public.evaluation_points;
create policy points_select on public.evaluation_points
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists points_insert on public.evaluation_points;
create policy points_insert on public.evaluation_points
for insert to authenticated
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

drop policy if exists points_update on public.evaluation_points;
create policy points_update on public.evaluation_points
for update to authenticated
using ((select private.has_company_role(company_id, array['owner','manager']::text[])))
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

-- Slug aliases: read only from client; writes happen via trigger.
drop policy if exists aliases_select on public.point_slug_aliases;
create policy aliases_select on public.point_slug_aliases
for select to authenticated
using ((select private.has_company_access(company_id)));

-- Shifts: read only directly. Start/end goes through RPCs.
drop policy if exists shifts_select on public.shifts;
create policy shifts_select on public.shifts
for select to authenticated
using ((select private.has_company_access(company_id)));

-- Reasons: global + tenant reasons are readable. Tenant edits are restricted.
drop policy if exists reasons_select on public.evaluation_reasons;
create policy reasons_select on public.evaluation_reasons
for select to authenticated
using (company_id is null or (select private.has_company_access(company_id)));

drop policy if exists reasons_insert on public.evaluation_reasons;
create policy reasons_insert on public.evaluation_reasons
for insert to authenticated
with check (
  (company_id is null and (select private.is_platform_admin()))
  or (company_id is not null and (select private.has_company_role(company_id, array['owner','manager']::text[])))
);

drop policy if exists reasons_update on public.evaluation_reasons;
create policy reasons_update on public.evaluation_reasons
for update to authenticated
using (
  (company_id is null and (select private.is_platform_admin()))
  or (company_id is not null and (select private.has_company_role(company_id, array['owner','manager']::text[])))
)
with check (
  (company_id is null and (select private.is_platform_admin()))
  or (company_id is not null and (select private.has_company_role(company_id, array['owner','manager']::text[])))
);

-- Feedback: staff can read; updates limited at grant level to status only.
drop policy if exists feedbacks_select on public.feedbacks;
create policy feedbacks_select on public.feedbacks
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists feedbacks_update on public.feedbacks;
create policy feedbacks_update on public.feedbacks
for update to authenticated
using ((select private.has_company_role(company_id, array['owner','manager']::text[])))
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

-- Incidents.
drop policy if exists incidents_select on public.incidents;
create policy incidents_select on public.incidents
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists incidents_update on public.incidents;
create policy incidents_update on public.incidents
for update to authenticated
using ((select private.has_company_role(company_id, array['owner','manager']::text[])))
with check ((select private.has_company_role(company_id, array['owner','manager']::text[])));

-- Incident relation: read only directly.
drop policy if exists incident_feedbacks_select on public.incident_feedbacks;
create policy incident_feedbacks_select on public.incident_feedbacks
for select to authenticated
using (
  exists(
    select 1 from public.incidents i
    where i.id = incident_id
      and (select private.has_company_access(i.company_id))
  )
);

-- Internal notes.
drop policy if exists notes_select on public.internal_notes;
create policy notes_select on public.internal_notes
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists notes_insert on public.internal_notes;
create policy notes_insert on public.internal_notes
for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (select private.has_company_role(company_id, array['owner','manager']::text[]))
);

drop policy if exists notes_update_own on public.internal_notes;
create policy notes_update_own on public.internal_notes
for update to authenticated
using ((select private.is_note_owner(id)) and (select private.has_company_access(company_id)))
with check (created_by = (select auth.uid()) and (select private.has_company_access(company_id)));

-- Notifications: only target user can see/mark read; platform admin can see all.
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
for select to authenticated
using (
  (user_id = (select auth.uid()) and (select private.has_company_access(company_id)))
  or (select private.is_platform_admin())
);

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
for update to authenticated
using (user_id = (select auth.uid()) and (select private.has_company_access(company_id)))
with check (user_id = (select auth.uid()) and (select private.has_company_access(company_id)));

-- Audit logs: tenant access is read-only; platform admin naturally passes helper.
drop policy if exists audit_select on public.audit_logs;
create policy audit_select on public.audit_logs
for select to authenticated
using (
  (company_id is not null and (select private.has_company_access(company_id)))
  or (company_id is null and (select private.is_platform_admin()))
);

-- Subscription: tenant reads, only platform admin writes.
drop policy if exists subscriptions_select on public.subscriptions;
create policy subscriptions_select on public.subscriptions
for select to authenticated
using ((select private.has_company_access(company_id)));

drop policy if exists subscriptions_insert_admin on public.subscriptions;
create policy subscriptions_insert_admin on public.subscriptions
for insert to authenticated
with check ((select private.is_platform_admin()));

drop policy if exists subscriptions_update_admin on public.subscriptions;
create policy subscriptions_update_admin on public.subscriptions
for update to authenticated
using ((select private.is_platform_admin()))
with check ((select private.is_platform_admin()));

-- Table grants: defense in depth + RLS.
grant select on public.profiles to authenticated;
grant update(full_name) on public.profiles to authenticated;
grant select on public.platform_admins to authenticated;
grant select, insert, update, delete on public.companies to authenticated;
grant select, insert, update on public.stores to authenticated;
grant select, insert, update on public.company_users to authenticated;
grant select, insert, update on public.employees to authenticated;
grant select, insert, update on public.evaluation_points to authenticated;
grant select on public.point_slug_aliases to authenticated;
grant select on public.shifts to authenticated;
grant select, insert, update on public.evaluation_reasons to authenticated;
grant select on public.feedbacks to authenticated;
grant update(status) on public.feedbacks to authenticated;
grant select on public.incidents to authenticated;
grant update(status, assignee_user_id, resolved_at) on public.incidents to authenticated;
grant select on public.incident_feedbacks to authenticated;
grant select, insert on public.internal_notes to authenticated;
grant update(body) on public.internal_notes to authenticated;
grant select on public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;
grant select on public.audit_logs to authenticated;
grant select, insert, update on public.subscriptions to authenticated;

-- ============================================================
-- FILE: 202610150003_rpc_and_reporting.sql
-- ============================================================
-- TAJO Avalie V2 base - 003 Public RPCs, authenticated actions and reports

create or replace function public.get_my_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile jsonb;
  v_memberships jsonb;
  v_is_admin boolean;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select jsonb_build_object(
    'user_id', p.user_id,
    'full_name', p.full_name,
    'email', p.email
  ) into v_profile
  from public.profiles p
  where p.user_id = v_uid;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'company_id', cu.company_id,
        'company_name', c.name,
        'company_slug', c.slug,
        'store_id', cu.store_id,
        'role', cu.role,
        'active', cu.active
      ) order by c.name
    ),
    '[]'::jsonb
  ) into v_memberships
  from public.company_users cu
  join public.companies c on c.id = cu.company_id
  where cu.user_id = v_uid and cu.active = true;

  v_is_admin := private.is_platform_admin();

  return jsonb_build_object(
    'profile', coalesce(v_profile, '{}'::jsonb),
    'is_platform_admin', v_is_admin,
    'memberships', v_memberships
  );
end;
$$;

create or replace function public.get_public_evaluation_context(
  p_company_slug text,
  p_point_slug text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_company public.companies%rowtype;
  v_point public.evaluation_points%rowtype;
  v_reasons jsonb;
begin
  select * into v_company
  from public.companies c
  where c.slug = p_company_slug
    and c.status = 'active';

  if not found then
    raise exception 'COMPANY_NOT_FOUND';
  end if;

  select * into v_point
  from public.evaluation_points p
  where p.company_id = v_company.id
    and p.slug = p_point_slug
    and p.active = true;

  if not found then
    select p.* into v_point
    from public.point_slug_aliases a
    join public.evaluation_points p on p.id = a.point_id
    where a.company_id = v_company.id
      and a.old_slug = p_point_slug
      and p.active = true;
  end if;

  if not found then
    raise exception 'POINT_NOT_FOUND';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object('code', r.code, 'label', r.label)
      order by r.sort_order, r.label
    ),
    '[]'::jsonb
  ) into v_reasons
  from public.evaluation_reasons r
  where r.active = true
    and (r.company_id is null or r.company_id = v_company.id);

  return jsonb_build_object(
    'company', jsonb_build_object(
      'id', v_company.id,
      'name', v_company.name,
      'slug', v_company.slug,
      'logo_url', v_company.logo_url,
      'logo_text', v_company.logo_text,
      'primary_color', v_company.primary_color,
      'feedback_question', v_company.feedback_question,
      'feedback_subtitle', v_company.feedback_subtitle,
      'thank_you_message', v_company.thank_you_message,
      'comments_enabled', v_company.comments_enabled
    ),
    'point', jsonb_build_object(
      'id', v_point.id,
      'name', v_point.name,
      'slug', v_point.slug,
      'type', v_point.point_type
    ),
    'reasons', v_reasons
  );
end;
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
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company public.companies%rowtype;
  v_point public.evaluation_points%rowtype;
  v_shift_id uuid;
  v_employee_id uuid;
  v_feedback_id uuid;
  v_received_at timestamptz;
  v_nonce_hash text;
  v_recent_count integer;
  v_negative_hour integer;
  v_incident_id uuid;
  v_reason text;
  v_clean_comment text;
begin
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'INVALID_RATING';
  end if;

  if p_client_nonce is null or char_length(p_client_nonce) < 8 or char_length(p_client_nonce) > 200 then
    raise exception 'CLIENT_NONCE_REQUIRED';
  end if;

  if cardinality(coalesce(p_reason_codes, '{}'::text[])) > 8 then
    raise exception 'TOO_MANY_REASONS';
  end if;

  v_clean_comment := nullif(btrim(coalesce(p_comment, '')), '');
  if v_clean_comment is not null and char_length(v_clean_comment) > 500 then
    raise exception 'COMMENT_TOO_LONG';
  end if;

  select * into v_company
  from public.companies c
  where c.slug = p_company_slug
    and c.status = 'active';

  if not found then
    raise exception 'COMPANY_NOT_FOUND';
  end if;

  if v_company.comments_enabled is false then
    v_clean_comment := null;
  end if;

  select * into v_point
  from public.evaluation_points p
  where p.company_id = v_company.id
    and p.slug = p_point_slug
    and p.active = true;

  if not found then
    select p.* into v_point
    from public.point_slug_aliases a
    join public.evaluation_points p on p.id = a.point_id
    where a.company_id = v_company.id
      and a.old_slug = p_point_slug
      and p.active = true;
  end if;

  if not found then
    raise exception 'POINT_NOT_FOUND';
  end if;

  foreach v_reason in array coalesce(p_reason_codes, '{}'::text[])
  loop
    if not exists(
      select 1
      from public.evaluation_reasons r
      where r.code = v_reason
        and r.active = true
        and (r.company_id is null or r.company_id = v_company.id)
    ) then
      raise exception 'INVALID_REASON';
    end if;
  end loop;

  -- O nonce não identifica a pessoa; é apenas um identificador local anti-spam.
  v_nonce_hash := pg_catalog.md5(p_client_nonce);

  select count(*) into v_recent_count
  from public.feedbacks f
  where f.point_id = v_point.id
    and f.client_nonce_hash = v_nonce_hash
    and f.created_at > now() - interval '90 seconds';

  if v_recent_count > 0 then
    raise exception 'RATE_LIMITED';
  end if;

  select s.id, s.employee_id
    into v_shift_id, v_employee_id
  from public.shifts s
  where s.point_id = v_point.id
    and s.status = 'active'
  order by s.started_at desc
  limit 1;

  insert into public.feedbacks(
    company_id,
    store_id,
    point_id,
    shift_id,
    employee_id,
    rating,
    reason_codes,
    comment,
    client_nonce_hash,
    status
  ) values (
    v_company.id,
    v_point.store_id,
    v_point.id,
    v_shift_id,
    v_employee_id,
    p_rating,
    coalesce(p_reason_codes, '{}'::text[]),
    v_clean_comment,
    v_nonce_hash,
    case when p_rating <= 2 then 'new' else 'resolved' end
  )
  returning id, created_at into v_feedback_id, v_received_at;

  -- 1 estrela gera ocorrência crítica imediata.
  if p_rating = 1 then
    insert into public.incidents(
      company_id, store_id, point_id, employee_id,
      severity, incident_type, title, description, status, source
    ) values (
      v_company.id, v_point.store_id, v_point.id, v_employee_id,
      'critical', 'rating_1', 'Avaliação crítica recebida',
      'Uma avaliação de 1/5 foi recebida em ' || v_point.name || '.',
      'new', 'automatic'
    ) returning id into v_incident_id;

    insert into public.incident_feedbacks(incident_id, feedback_id)
    values(v_incident_id, v_feedback_id);
  end if;

  -- Cluster: 3 ou mais avaliações 1-2 estrelas em 1 hora.
  if p_rating <= 2 then
    select count(*) into v_negative_hour
    from public.feedbacks f
    where f.point_id = v_point.id
      and f.rating <= 2
      and f.created_at > now() - interval '1 hour';

    if v_negative_hour >= 3
       and not exists(
         select 1
         from public.incidents i
         where i.point_id = v_point.id
           and i.incident_type = 'negative_cluster'
           and i.status in ('new','analyzing')
           and i.created_at > now() - interval '1 hour'
       ) then
      insert into public.incidents(
        company_id, store_id, point_id, employee_id,
        severity, incident_type, title, description, status, source
      ) values (
        v_company.id, v_point.store_id, v_point.id, v_employee_id,
        'critical', 'negative_cluster', 'Avaliações negativas recorrentes',
        'O sistema detectou 3 ou mais avaliações negativas em 1 hora em ' || v_point.name || '.',
        'new', 'automatic'
      ) returning id into v_incident_id;

      insert into public.incident_feedbacks(incident_id, feedback_id)
      select v_incident_id, f.id
      from public.feedbacks f
      where f.point_id = v_point.id
        and f.rating <= 2
        and f.created_at > now() - interval '1 hour'
      on conflict do nothing;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'feedback_id', v_feedback_id,
    'received_at', v_received_at
  );
end;
$$;

create or replace function public.start_shift(p_point_id uuid, p_employee_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_store_id uuid;
  v_employee_store_id uuid;
  v_shift_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select p.company_id, p.store_id
    into v_company_id, v_store_id
  from public.evaluation_points p
  where p.id = p_point_id
    and p.active = true;

  if v_company_id is null
     or not private.has_company_role(v_company_id, array['owner','manager']::text[]) then
    raise exception 'FORBIDDEN';
  end if;

  select e.store_id into v_employee_store_id
  from public.employees e
  where e.id = p_employee_id
    and e.company_id = v_company_id
    and e.active = true;

  if not found then
    raise exception 'EMPLOYEE_NOT_AVAILABLE';
  end if;

  if v_employee_store_id is not null
     and v_store_id is not null
     and v_employee_store_id <> v_store_id then
    raise exception 'EMPLOYEE_WRONG_STORE';
  end if;

  update public.shifts
  set status = 'ended', ended_at = now(), ended_by = (select auth.uid())
  where point_id = p_point_id and status = 'active';

  update public.shifts
  set status = 'ended', ended_at = now(), ended_by = (select auth.uid())
  where employee_id = p_employee_id and status = 'active';

  insert into public.shifts(
    company_id, store_id, point_id, employee_id, started_by
  ) values (
    v_company_id, v_store_id, p_point_id, p_employee_id, (select auth.uid())
  ) returning id into v_shift_id;

  return v_shift_id;
end;
$$;

create or replace function public.end_shift(p_shift_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select s.company_id into v_company_id
  from public.shifts s
  where s.id = p_shift_id;

  if v_company_id is null
     or not private.has_company_role(v_company_id, array['owner','manager']::text[]) then
    raise exception 'FORBIDDEN';
  end if;

  update public.shifts
  set status = 'ended', ended_at = now(), ended_by = (select auth.uid())
  where id = p_shift_id and status = 'active';

  return found;
end;
$$;

create or replace function public.dashboard_summary(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()),
  p_to timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not private.has_company_access(p_company_id) then
    raise exception 'FORBIDDEN';
  end if;

  if p_to < p_from then
    raise exception 'INVALID_PERIOD';
  end if;

  select jsonb_build_object(
    'average_rating', coalesce(round(avg(f.rating)::numeric, 2), 0),
    'evaluations', count(*),
    'positive_percent', coalesce(
      round((count(*) filter (where f.rating >= 4)::numeric / nullif(count(*), 0)) * 100, 1),
      0
    ),
    'negative_count', count(*) filter (where f.rating <= 2),
    'open_incidents', (
      select count(*)
      from public.incidents i
      where i.company_id = p_company_id
        and i.status in ('new','analyzing')
    )
  ) into v_result
  from public.feedbacks f
  where f.company_id = p_company_id
    and f.created_at >= p_from
    and f.created_at <= p_to;

  return v_result;
end;
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
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_company_access(p_company_id) then
    raise exception 'FORBIDDEN';
  end if;

  return query
  select
    e.id,
    e.name,
    round(avg(f.rating)::numeric, 2),
    count(*),
    round((count(*) filter (where f.rating >= 4)::numeric / count(*)) * 100, 1)
  from public.feedbacks f
  join public.employees e on e.id = f.employee_id
  where f.company_id = p_company_id
    and f.created_at between p_from and p_to
    and f.employee_id is not null
  group by e.id, e.name
  having count(*) >= greatest(p_min_reviews, 1)
  order by avg(f.rating) desc, count(*) desc;
end;
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
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_company_access(p_company_id) then
    raise exception 'FORBIDDEN';
  end if;

  return query
  select
    p.id,
    p.name,
    p.point_type,
    coalesce(round(avg(f.rating)::numeric, 2), 0),
    count(f.id),
    count(f.id) filter (where f.rating <= 2)
  from public.evaluation_points p
  left join public.feedbacks f
    on f.point_id = p.id
   and f.created_at between p_from and p_to
  where p.company_id = p_company_id
    and p.active = true
  group by p.id, p.name, p.point_type
  order by avg(f.rating) nulls last, count(f.id) desc;
end;
$$;

create or replace function public.reason_stats(
  p_company_id uuid,
  p_from timestamptz default date_trunc('month', now()),
  p_to timestamptz default now()
)
returns table(reason_code text, reason_label text, mention_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_company_access(p_company_id) then
    raise exception 'FORBIDDEN';
  end if;

  return query
  with expanded as (
    select unnest(f.reason_codes) as code
    from public.feedbacks f
    where f.company_id = p_company_id
      and f.created_at between p_from and p_to
  )
  select
    e.code,
    coalesce(
      (select r.label
       from public.evaluation_reasons r
       where r.code = e.code
         and (r.company_id = p_company_id or r.company_id is null)
       order by (r.company_id is not null) desc
       limit 1),
      e.code
    ) as label,
    count(*)
  from expanded e
  group by e.code
  order by count(*) desc, e.code;
end;
$$;

create or replace function public.hourly_performance(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()) - interval '30 days',
  p_to timestamptz default now()
)
returns table(hour_of_day integer, average_rating numeric, review_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_timezone text;
begin
  if not private.has_company_access(p_company_id) then
    raise exception 'FORBIDDEN';
  end if;

  select c.timezone into v_timezone
  from public.companies c
  where c.id = p_company_id;

  return query
  select
    extract(hour from (f.created_at at time zone v_timezone))::integer,
    round(avg(f.rating)::numeric, 2),
    count(*)
  from public.feedbacks f
  where f.company_id = p_company_id
    and f.created_at between p_from and p_to
  group by 1
  order by 1;
end;
$$;

-- Restrict function execution explicitly. SECURITY DEFINER is never left public.
revoke all on function public.get_my_context() from public, anon, authenticated;
revoke all on function public.get_public_evaluation_context(text,text) from public, anon, authenticated;
revoke all on function public.submit_feedback(text,text,integer,text[],text,text) from public, anon, authenticated;
revoke all on function public.start_shift(uuid,uuid) from public, anon, authenticated;
revoke all on function public.end_shift(uuid) from public, anon, authenticated;
revoke all on function public.dashboard_summary(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.top_employees(uuid,timestamptz,timestamptz,integer) from public, anon, authenticated;
revoke all on function public.point_performance(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.reason_stats(uuid,timestamptz,timestamptz) from public, anon, authenticated;
revoke all on function public.hourly_performance(uuid,timestamptz,timestamptz) from public, anon, authenticated;

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

-- ============================================================
-- FILE: 202610150004_management_automation.sql
-- ============================================================
-- TAJO Avalie V2 base - 004 Management RPCs, notifications, auditing and defaults

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
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid;
  v_store_id uuid;
begin
  if not private.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  if p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'INVALID_SLUG';
  end if;

  insert into public.companies(
    name, slug, primary_color, status, plan_name,
    setup_price, monthly_price, point_limit, billing_day
  ) values (
    p_name, p_slug, p_primary_color, 'active', 'Profissional',
    p_setup_price, p_monthly_price, p_point_limit, p_billing_day
  ) returning id into v_company_id;

  insert into public.stores(company_id, name, slug)
  values(v_company_id, p_store_name, p_store_slug)
  returning id into v_store_id;

  insert into public.subscriptions(
    company_id, plan_name, setup_price, monthly_price, point_limit, status
  ) values (
    v_company_id, 'Profissional', p_setup_price, p_monthly_price, p_point_limit, 'active'
  );

  insert into public.audit_logs(company_id, actor_user_id, action, entity_type, entity_id, metadata)
  values(
    v_company_id,
    (select auth.uid()),
    'company.created',
    'company',
    v_company_id::text,
    jsonb_build_object('slug', p_slug, 'store_id', v_store_id)
  );

  return jsonb_build_object(
    'company_id', v_company_id,
    'store_id', v_store_id,
    'slug', p_slug
  );
end;
$$;

create or replace function public.add_company_user_by_email(
  p_company_id uuid,
  p_email text,
  p_role text,
  p_store_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_membership_id uuid;
begin
  if p_role not in ('owner','manager') then
    raise exception 'INVALID_ROLE';
  end if;

  if not private.has_company_role(p_company_id, array['owner']::text[]) then
    raise exception 'FORBIDDEN';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(p_email)
  limit 1;

  if v_user_id is null then
    raise exception 'USER_NOT_FOUND';
  end if;

  if p_store_id is not null and not exists(
    select 1 from public.stores s
    where s.id = p_store_id and s.company_id = p_company_id
  ) then
    raise exception 'INVALID_STORE';
  end if;

  insert into public.company_users(company_id, store_id, user_id, role, active)
  values(p_company_id, p_store_id, v_user_id, p_role, true)
  on conflict (company_id, user_id)
  do update set
    store_id = excluded.store_id,
    role = excluded.role,
    active = true,
    updated_at = now()
  returning id into v_membership_id;

  insert into public.audit_logs(company_id, actor_user_id, action, entity_type, entity_id, metadata)
  values(
    p_company_id,
    (select auth.uid()),
    'company_user.upserted',
    'company_user',
    v_membership_id::text,
    jsonb_build_object('user_id', v_user_id, 'email', p_email, 'role', p_role)
  );

  return v_membership_id;
end;
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
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  if p_status not in ('trial','active','past_due','suspended','cancelled') then
    raise exception 'INVALID_STATUS';
  end if;

  update public.subscriptions s
  set status = p_status,
      monthly_price = coalesce(p_monthly_price, s.monthly_price),
      setup_price = coalesce(p_setup_price, s.setup_price),
      point_limit = coalesce(p_point_limit, s.point_limit),
      next_due_date = coalesce(p_next_due_date, s.next_due_date)
  where s.company_id = p_company_id;

  if not found then
    raise exception 'SUBSCRIPTION_NOT_FOUND';
  end if;

  update public.companies c
  set monthly_price = coalesce(p_monthly_price, c.monthly_price),
      setup_price = coalesce(p_setup_price, c.setup_price),
      point_limit = coalesce(p_point_limit, c.point_limit),
      status = case
        when p_status in ('suspended','cancelled') then 'suspended'
        when c.status = 'suspended' and p_status in ('active','trial') then 'active'
        else c.status
      end
  where c.id = p_company_id;

  insert into public.audit_logs(company_id, actor_user_id, action, entity_type, entity_id, metadata)
  values(
    p_company_id,
    (select auth.uid()),
    'subscription.updated',
    'subscription',
    p_company_id::text,
    jsonb_build_object('status', p_status, 'monthly_price', p_monthly_price, 'point_limit', p_point_limit)
  );

  return true;
end;
$$;

-- Resolve timestamps consistently.
create or replace function private.sync_incident_resolution()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'resolved' and old.status is distinct from 'resolved' then
    new.resolved_at := coalesce(new.resolved_at, now());
  elsif new.status <> 'resolved' then
    new.resolved_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists incidents_sync_resolution on public.incidents;
create trigger incidents_sync_resolution
before update of status on public.incidents
for each row execute function private.sync_incident_resolution();

-- Every new incident creates notifications for active owners/managers.
create or replace function private.notify_incident_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications(
    company_id, user_id, title, detail, kind, entity_type, entity_id
  )
  select
    new.company_id,
    cu.user_id,
    new.title,
    new.description,
    case when new.severity = 'critical' then 'critical' else 'warning' end,
    'incident',
    new.id
  from public.company_users cu
  where cu.company_id = new.company_id
    and cu.active = true;

  return new;
end;
$$;

drop trigger if exists incidents_notify_users on public.incidents;
create trigger incidents_notify_users
after insert on public.incidents
for each row execute function private.notify_incident_created();

-- Audit shifts without exposing direct writes to audit_logs.
create or replace function private.audit_shift_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs(company_id, actor_user_id, action, entity_type, entity_id, metadata)
    values(
      new.company_id,
      coalesce(new.started_by, (select auth.uid())),
      'shift.started',
      'shift',
      new.id::text,
      jsonb_build_object('point_id', new.point_id, 'employee_id', new.employee_id)
    );
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'active' and new.status <> 'active' then
    insert into public.audit_logs(company_id, actor_user_id, action, entity_type, entity_id, metadata)
    values(
      new.company_id,
      coalesce(new.ended_by, (select auth.uid())),
      'shift.ended',
      'shift',
      new.id::text,
      jsonb_build_object('point_id', new.point_id, 'employee_id', new.employee_id, 'status', new.status)
    );
  end if;

  return new;
end;
$$;

drop trigger if exists shifts_audit_insert on public.shifts;
create trigger shifts_audit_insert
after insert on public.shifts
for each row execute function private.audit_shift_changes();

drop trigger if exists shifts_audit_update on public.shifts;
create trigger shifts_audit_update
after update of status on public.shifts
for each row execute function private.audit_shift_changes();

-- Default reasons shared by every tenant.
insert into public.evaluation_reasons(company_id, code, label, sort_order)
values
  (null, 'atendimento', 'Atendimento', 10),
  (null, 'agilidade', 'Agilidade', 20),
  (null, 'educacao', 'Educação', 30),
  (null, 'tempo-espera', 'Tempo de espera', 40),
  (null, 'organizacao', 'Organização', 50),
  (null, 'resolucao', 'Resolução do problema', 60),
  (null, 'outro', 'Outro', 999)
on conflict do nothing;

revoke all on function public.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) from public, anon, authenticated;
revoke all on function public.add_company_user_by_email(uuid,text,text,uuid) from public, anon, authenticated;
revoke all on function public.admin_set_subscription(uuid,text,numeric,numeric,integer,date) from public, anon, authenticated;

grant execute on function public.admin_create_company(text,text,text,text,text,numeric,numeric,integer,integer) to authenticated;
grant execute on function public.add_company_user_by_email(uuid,text,text,uuid) to authenticated;
grant execute on function public.admin_set_subscription(uuid,text,numeric,numeric,integer,date) to authenticated;

-- ============================================================
-- FILE: 202610150005_safe_views.sql
-- ============================================================
-- TAJO Avalie V2 base - 005 Safe views for frontend consumption

create or replace view public.v_points_live
with (security_invoker = true)
as
select
  p.id,
  p.company_id,
  p.store_id,
  p.name,
  p.slug,
  p.point_type,
  p.public_code,
  p.active,
  p.created_at,
  p.updated_at,
  s.id as active_shift_id,
  s.started_at as shift_started_at,
  e.id as employee_id,
  e.name as employee_name,
  e.role_name as employee_role
from public.evaluation_points p
left join public.shifts s
  on s.point_id = p.id
 and s.status = 'active'
left join public.employees e
  on e.id = s.employee_id;

create or replace view public.v_feedback_details
with (security_invoker = true)
as
select
  f.id,
  f.company_id,
  f.store_id,
  st.name as store_name,
  f.point_id,
  p.name as point_name,
  p.slug as point_slug,
  p.point_type,
  f.shift_id,
  f.employee_id,
  e.name as employee_name,
  f.rating,
  f.reason_codes,
  f.comment,
  f.status,
  f.created_at,
  f.updated_at
from public.feedbacks f
join public.evaluation_points p on p.id = f.point_id
left join public.stores st on st.id = f.store_id
left join public.employees e on e.id = f.employee_id;

create or replace view public.v_incident_details
with (security_invoker = true)
as
select
  i.id,
  i.company_id,
  i.store_id,
  st.name as store_name,
  i.point_id,
  p.name as point_name,
  i.employee_id,
  e.name as employee_name,
  i.severity,
  i.incident_type,
  i.title,
  i.description,
  i.status,
  i.assignee_user_id,
  pr.full_name as assignee_name,
  i.source,
  i.created_at,
  i.resolved_at,
  i.updated_at
from public.incidents i
left join public.stores st on st.id = i.store_id
left join public.evaluation_points p on p.id = i.point_id
left join public.employees e on e.id = i.employee_id
left join public.profiles pr on pr.user_id = i.assignee_user_id;

create or replace view public.v_team_members
with (security_invoker = true)
as
select
  cu.id,
  cu.company_id,
  cu.store_id,
  cu.user_id,
  p.full_name,
  p.email,
  cu.role,
  cu.active,
  cu.created_at,
  cu.updated_at
from public.company_users cu
join public.profiles p on p.user_id = cu.user_id;

revoke all on public.v_points_live from anon, authenticated;
revoke all on public.v_feedback_details from anon, authenticated;
revoke all on public.v_incident_details from anon, authenticated;
revoke all on public.v_team_members from anon, authenticated;

grant select on public.v_points_live to authenticated;
grant select on public.v_feedback_details to authenticated;
grant select on public.v_incident_details to authenticated;
grant select on public.v_team_members to authenticated;

-- ============================================================
-- FILE: 202610150006_private_function_hardening.sql
-- ============================================================
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

-- ============================================================
-- FILE: 202610230007_saas_v2.sql
-- ============================================================
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

