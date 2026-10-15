-- TAJO Avalia V1 - Public RPCs + reporting functions

create or replace function public.get_public_evaluation_context(
  p_company_slug text,
  p_point_slug text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_company public.companies;
  v_point public.evaluation_points;
  v_reasons jsonb;
begin
  select * into v_company from public.companies
  where slug = p_company_slug and status = 'active';
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;

  select * into v_point from public.evaluation_points
  where company_id = v_company.id and slug = p_point_slug and active = true;

  if not found then
    select p.* into v_point
    from public.point_slug_aliases a
    join public.evaluation_points p on p.id = a.point_id
    where a.company_id = v_company.id and a.old_slug = p_point_slug and p.active = true;
  end if;
  if not found then raise exception 'POINT_NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('code',r.code,'label',r.label) order by r.sort_order, r.label),'[]'::jsonb)
  into v_reasons
  from public.evaluation_reasons r
  where r.active = true and (r.company_id is null or r.company_id = v_company.id);

  return jsonb_build_object(
    'company', jsonb_build_object('id',v_company.id,'name',v_company.name,'slug',v_company.slug,'logo_url',v_company.logo_url,'logo_text',v_company.logo_text,'primary_color',v_company.primary_color),
    'point', jsonb_build_object('id',v_point.id,'name',v_point.name,'slug',v_point.slug,'type',v_point.point_type),
    'reasons', v_reasons
  );
end;
$$;

create or replace function public.submit_feedback(
  p_company_slug text,
  p_point_slug text,
  p_rating integer,
  p_reason_codes text[] default '{}',
  p_comment text default null,
  p_client_nonce text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company public.companies;
  v_point public.evaluation_points;
  v_shift public.shifts;
  v_feedback public.feedbacks;
  v_nonce_hash text;
  v_recent_count integer;
  v_negative_hour integer;
  v_incident_id uuid;
begin
  if p_rating not between 1 and 5 then raise exception 'INVALID_RATING'; end if;
  if p_comment is not null and char_length(p_comment) > 500 then raise exception 'COMMENT_TOO_LONG'; end if;
  if p_client_nonce is null or char_length(p_client_nonce) < 8 then raise exception 'CLIENT_NONCE_REQUIRED'; end if;

  select * into v_company from public.companies where slug = p_company_slug and status = 'active';
  if not found then raise exception 'COMPANY_NOT_FOUND'; end if;

  select * into v_point from public.evaluation_points
  where company_id = v_company.id and slug = p_point_slug and active = true;
  if not found then
    select p.* into v_point from public.point_slug_aliases a
    join public.evaluation_points p on p.id = a.point_id
    where a.company_id = v_company.id and a.old_slug = p_point_slug and p.active = true;
  end if;
  if not found then raise exception 'POINT_NOT_FOUND'; end if;

  v_nonce_hash := encode(digest(p_client_nonce, 'sha256'),'hex');
  select count(*) into v_recent_count from public.feedbacks f
    where f.point_id = v_point.id and f.client_nonce_hash = v_nonce_hash and f.created_at > now() - interval '2 minutes';
  if v_recent_count > 0 then raise exception 'RATE_LIMITED'; end if;

  select * into v_shift from public.shifts s
    where s.point_id = v_point.id and s.status = 'active'
    order by s.started_at desc limit 1;

  insert into public.feedbacks(company_id,store_id,point_id,shift_id,employee_id,rating,reason_codes,comment,client_nonce_hash,status)
  values(v_company.id,v_point.store_id,v_point.id,v_shift.id,v_shift.employee_id,p_rating,coalesce(p_reason_codes,'{}'),nullif(trim(p_comment),''),v_nonce_hash,case when p_rating <= 2 then 'new' else 'resolved' end)
  returning * into v_feedback;

  if p_rating = 1 then
    insert into public.incidents(company_id,store_id,point_id,employee_id,severity,incident_type,title,description,status,source)
    values(v_company.id,v_point.store_id,v_point.id,v_shift.employee_id,'critical','rating_1','Avaliação crítica recebida','Uma avaliação de 1/5 foi recebida em '||v_point.name||'.','new','automatic')
    returning id into v_incident_id;
    insert into public.incident_feedbacks(incident_id,feedback_id) values(v_incident_id,v_feedback.id);
  elsif p_rating = 2 then
    select count(*) into v_negative_hour from public.feedbacks f
      where f.point_id = v_point.id and f.rating <= 2 and f.created_at > now() - interval '1 hour';
    if v_negative_hour >= 3 then
      insert into public.incidents(company_id,store_id,point_id,employee_id,severity,incident_type,title,description,status,source)
      values(v_company.id,v_point.store_id,v_point.id,v_shift.employee_id,'critical','negative_cluster','3 ou mais avaliações negativas em 1 hora','O sistema detectou recorrência de avaliações negativas em '||v_point.name||'.','new','automatic')
      returning id into v_incident_id;
      insert into public.incident_feedbacks(incident_id,feedback_id)
      select v_incident_id, f.id from public.feedbacks f
      where f.point_id = v_point.id and f.rating <= 2 and f.created_at > now() - interval '1 hour'
      on conflict do nothing;
    end if;
  end if;

  return jsonb_build_object('ok',true,'feedback_id',v_feedback.id,'received_at',v_feedback.created_at);
end;
$$;

revoke all on function public.get_public_evaluation_context(text,text) from public;
revoke all on function public.submit_feedback(text,text,integer,text[],text,text) from public;
grant execute on function public.get_public_evaluation_context(text,text) to anon, authenticated;
grant execute on function public.submit_feedback(text,text,integer,text[],text,text) to anon, authenticated;

create or replace function public.dashboard_summary(
  p_company_id uuid,
  p_from timestamptz default date_trunc('day', now()),
  p_to timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.has_company_access(p_company_id) then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'average_rating', coalesce(round(avg(f.rating)::numeric,2),0),
    'evaluations', count(*),
    'positive_percent', coalesce(round((count(*) filter(where f.rating >= 4)::numeric / nullif(count(*),0))*100,1),0),
    'negative_count', count(*) filter(where f.rating <= 2),
    'open_incidents', (select count(*) from public.incidents i where i.company_id=p_company_id and i.status in ('new','analyzing'))
  ) into v_result
  from public.feedbacks f
  where f.company_id = p_company_id and f.created_at between p_from and p_to;
  return v_result;
end;
$$;
grant execute on function public.dashboard_summary(uuid,timestamptz,timestamptz) to authenticated;

create or replace function public.top_employees(
  p_company_id uuid,
  p_from timestamptz default date_trunc('month',now()),
  p_to timestamptz default now(),
  p_min_reviews integer default 20
)
returns table(employee_id uuid, employee_name text, average_rating numeric, review_count bigint)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.has_company_access(p_company_id) then raise exception 'FORBIDDEN'; end if;
  return query
  select e.id,e.name,round(avg(f.rating)::numeric,2),count(*)
  from public.feedbacks f join public.employees e on e.id=f.employee_id
  where f.company_id=p_company_id and f.created_at between p_from and p_to and f.employee_id is not null
  group by e.id,e.name having count(*) >= p_min_reviews
  order by avg(f.rating) desc, count(*) desc;
end;
$$;
grant execute on function public.top_employees(uuid,timestamptz,timestamptz,integer) to authenticated;

create or replace function public.start_shift(p_point_id uuid, p_employee_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_store_id uuid;
  v_shift_id uuid;
begin
  select company_id,store_id into v_company_id,v_store_id from public.evaluation_points where id=p_point_id and active=true;
  if v_company_id is null or not public.has_company_access(v_company_id) then raise exception 'FORBIDDEN'; end if;
  if not exists(select 1 from public.employees e where e.id=p_employee_id and e.company_id=v_company_id and e.active=true) then raise exception 'EMPLOYEE_NOT_AVAILABLE'; end if;

  update public.shifts set status='ended',ended_at=now(),ended_by=auth.uid() where point_id=p_point_id and status='active';
  update public.shifts set status='ended',ended_at=now(),ended_by=auth.uid() where employee_id=p_employee_id and status='active';

  insert into public.shifts(company_id,store_id,point_id,employee_id,started_by)
  values(v_company_id,v_store_id,p_point_id,p_employee_id,auth.uid()) returning id into v_shift_id;
  return v_shift_id;
end;
$$;
grant execute on function public.start_shift(uuid,uuid) to authenticated;

create or replace function public.end_shift(p_shift_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_company_id uuid;
begin
  select company_id into v_company_id from public.shifts where id=p_shift_id;
  if v_company_id is null or not public.has_company_access(v_company_id) then raise exception 'FORBIDDEN'; end if;
  update public.shifts set status='ended',ended_at=now(),ended_by=auth.uid() where id=p_shift_id and status='active';
  return found;
end;
$$;
grant execute on function public.end_shift(uuid) to authenticated;
