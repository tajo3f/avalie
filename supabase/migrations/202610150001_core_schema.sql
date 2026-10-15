-- TAJO Avalia V1 - Core Schema
-- Execute via Supabase CLI (supabase db push). Evite alterações manuais em produção.

create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  logo_url text,
  logo_text text,
  primary_color text not null default '#16a34a' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  status text not null default 'active' check (status in ('active','pending','suspended','cancelled')),
  plan_name text not null default 'Profissional',
  setup_price numeric(10,2) not null default 390.00 check (setup_price >= 0),
  monthly_price numeric(10,2) not null default 390.00 check (monthly_price >= 0),
  point_limit integer not null default 12 check (point_limit > 0),
  billing_day integer not null default 15 check (billing_day between 1 and 28),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  slug text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(company_id, slug)
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
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
  store_id uuid references public.stores(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(company_id, user_id)
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  name text not null check (char_length(name) between 2 and 120),
  employee_code text,
  role_name text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, employee_code)
);

create table if not exists public.evaluation_points (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  name text not null check (char_length(name) between 2 and 100),
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  point_type text not null default 'Caixa' check (char_length(point_type) <= 60),
  public_code uuid not null default gen_random_uuid() unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, slug)
);

create table if not exists public.point_slug_aliases (
  id uuid primary key default gen_random_uuid(),
  point_id uuid not null references public.evaluation_points(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  old_slug text not null,
  created_at timestamptz not null default now(),
  unique(company_id, old_slug)
);

create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  point_id uuid not null references public.evaluation_points(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete restrict,
  started_by uuid references auth.users(id) on delete set null,
  ended_by uuid references auth.users(id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active' check (status in ('active','ended','cancelled')),
  check ((status = 'active' and ended_at is null) or status <> 'active')
);

create unique index if not exists shifts_one_active_per_point_idx
  on public.shifts(point_id) where status = 'active';
create unique index if not exists shifts_one_active_per_employee_idx
  on public.shifts(employee_id) where status = 'active';

create table if not exists public.evaluation_reasons (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete cascade,
  code text not null,
  label text not null,
  active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  unique(company_id, code)
);

create table if not exists public.feedbacks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  point_id uuid not null references public.evaluation_points(id) on delete restrict,
  shift_id uuid references public.shifts(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  reason_codes text[] not null default '{}',
  comment text check (comment is null or char_length(comment) <= 500),
  client_nonce_hash text,
  status text not null default 'new' check (status in ('new','analyzing','resolved','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists feedbacks_company_created_idx on public.feedbacks(company_id, created_at desc);
create index if not exists feedbacks_point_created_idx on public.feedbacks(point_id, created_at desc);
create index if not exists feedbacks_employee_created_idx on public.feedbacks(employee_id, created_at desc);
create index if not exists feedbacks_rating_created_idx on public.feedbacks(rating, created_at desc);
create index if not exists feedbacks_nonce_created_idx on public.feedbacks(client_nonce_hash, created_at desc) where client_nonce_hash is not null;

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  point_id uuid references public.evaluation_points(id) on delete set null,
  employee_id uuid references public.employees(id) on delete set null,
  severity text not null check (severity in ('info','warning','critical')),
  incident_type text not null default 'feedback',
  title text not null,
  description text,
  status text not null default 'new' check (status in ('new','analyzing','resolved','archived')),
  assignee_user_id uuid references auth.users(id) on delete set null,
  source text not null default 'automatic' check (source in ('automatic','manual')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.incident_feedbacks (
  incident_id uuid not null references public.incidents(id) on delete cascade,
  feedback_id uuid not null references public.feedbacks(id) on delete cascade,
  primary key (incident_id, feedback_id)
);

create table if not exists public.internal_notes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  feedback_id uuid references public.feedbacks(id) on delete cascade,
  incident_id uuid references public.incidents(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (feedback_id is not null or incident_id is not null)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  detail text,
  kind text not null default 'info',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

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

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null unique references public.companies(id) on delete cascade,
  plan_name text not null default 'Profissional',
  setup_price numeric(10,2) not null default 390.00,
  monthly_price numeric(10,2) not null default 390.00,
  point_limit integer not null default 12,
  status text not null default 'active' check (status in ('trial','active','past_due','suspended','cancelled')),
  next_due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger companies_set_updated_at before update on public.companies for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger employees_set_updated_at before update on public.employees for each row execute function public.set_updated_at();
create trigger points_set_updated_at before update on public.evaluation_points for each row execute function public.set_updated_at();
create trigger feedbacks_set_updated_at before update on public.feedbacks for each row execute function public.set_updated_at();
create trigger incidents_set_updated_at before update on public.incidents for each row execute function public.set_updated_at();
create trigger subscriptions_set_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(user_id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email)
  on conflict (user_id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert or update of email on auth.users
for each row execute function public.handle_new_auth_user();

create or replace function public.enforce_point_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_count integer;
begin
  select coalesce(s.point_limit, c.point_limit)
    into v_limit
  from public.companies c
  left join public.subscriptions s on s.company_id = c.id
  where c.id = new.company_id;

  select count(*) into v_count
  from public.evaluation_points p
  where p.company_id = new.company_id and p.active = true;

  if new.active = true and v_count >= v_limit then
    raise exception 'POINT_LIMIT_REACHED';
  end if;
  return new;
end;
$$;

create trigger evaluation_points_enforce_limit
before insert on public.evaluation_points
for each row execute function public.enforce_point_limit();
