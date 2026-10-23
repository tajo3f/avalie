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
