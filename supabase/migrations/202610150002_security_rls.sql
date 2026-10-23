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
