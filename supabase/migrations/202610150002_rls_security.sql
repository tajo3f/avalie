-- TAJO Avalia V1 - Row Level Security

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(select 1 from public.platform_admins pa where pa.user_id = auth.uid());
$$;

create or replace function public.has_company_access(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_admin() or exists(
    select 1 from public.company_users cu
    where cu.company_id = p_company_id and cu.user_id = auth.uid() and cu.active = true
  );
$$;

create or replace function public.has_company_role(p_company_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_admin() or exists(
    select 1 from public.company_users cu
    where cu.company_id = p_company_id and cu.user_id = auth.uid() and cu.active = true and cu.role = any(p_roles)
  );
$$;

grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.has_company_access(uuid) to authenticated;
grant execute on function public.has_company_role(uuid,text[]) to authenticated;

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

-- Perfis: cada usuário vê/edita apenas o próprio perfil; admin vê todos.
create policy profiles_select_self on public.profiles for select to authenticated
  using (user_id = auth.uid() or public.is_platform_admin());
create policy profiles_update_self on public.profiles for update to authenticated
  using (user_id = auth.uid() or public.is_platform_admin())
  with check (user_id = auth.uid() or public.is_platform_admin());

create policy platform_admins_select_self on public.platform_admins for select to authenticated
  using (user_id = auth.uid() or public.is_platform_admin());

-- Tenant tables
create policy companies_select on public.companies for select to authenticated using (public.has_company_access(id));
create policy companies_update_owner on public.companies for update to authenticated
  using (public.has_company_role(id, array['owner'])) with check (public.has_company_role(id, array['owner']));

create policy stores_all on public.stores for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));

create policy company_users_select on public.company_users for select to authenticated using (public.has_company_access(company_id));
create policy company_users_insert_owner on public.company_users for insert to authenticated with check (public.has_company_role(company_id,array['owner']));
create policy company_users_update_owner on public.company_users for update to authenticated using (public.has_company_role(company_id,array['owner'])) with check (public.has_company_role(company_id,array['owner']));
create policy company_users_delete_owner on public.company_users for delete to authenticated using (public.has_company_role(company_id,array['owner']));

create policy employees_all on public.employees for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy points_all on public.evaluation_points for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy aliases_all on public.point_slug_aliases for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy shifts_all on public.shifts for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy reasons_all on public.evaluation_reasons for all to authenticated
  using (company_id is null or public.has_company_access(company_id)) with check (company_id is null or public.has_company_access(company_id));
create policy feedbacks_all on public.feedbacks for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy incidents_all on public.incidents for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy incident_feedbacks_select on public.incident_feedbacks for select to authenticated
  using (exists(select 1 from public.incidents i where i.id = incident_id and public.has_company_access(i.company_id)));
create policy incident_feedbacks_write on public.incident_feedbacks for all to authenticated
  using (exists(select 1 from public.incidents i where i.id = incident_id and public.has_company_access(i.company_id)))
  with check (exists(select 1 from public.incidents i where i.id = incident_id and public.has_company_access(i.company_id)));
create policy notes_all on public.internal_notes for all to authenticated
  using (public.has_company_access(company_id)) with check (public.has_company_access(company_id));
create policy notifications_select on public.notifications for select to authenticated
  using (public.has_company_access(company_id) and (user_id is null or user_id = auth.uid()));
create policy notifications_update on public.notifications for update to authenticated
  using (public.has_company_access(company_id) and (user_id is null or user_id = auth.uid()))
  with check (public.has_company_access(company_id) and (user_id is null or user_id = auth.uid()));
create policy audit_select on public.audit_logs for select to authenticated using (company_id is null and public.is_platform_admin() or public.has_company_access(company_id));
create policy subscriptions_select on public.subscriptions for select to authenticated using (public.has_company_access(company_id));

-- Admin TAJO pode administrar empresas e assinaturas.
create policy companies_admin_insert on public.companies for insert to authenticated with check (public.is_platform_admin());
create policy companies_admin_delete on public.companies for delete to authenticated using (public.is_platform_admin());
create policy subscriptions_admin_all on public.subscriptions for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Grants mínimos. RLS continua sendo a barreira real para usuários autenticados.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.companies, public.stores, public.profiles, public.company_users,
  public.employees, public.evaluation_points, public.point_slug_aliases, public.shifts, public.evaluation_reasons,
  public.feedbacks, public.incidents, public.incident_feedbacks, public.internal_notes, public.notifications,
  public.subscriptions to authenticated;
grant select on public.audit_logs, public.platform_admins to authenticated;
