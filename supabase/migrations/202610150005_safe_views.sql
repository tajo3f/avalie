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
