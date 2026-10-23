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
