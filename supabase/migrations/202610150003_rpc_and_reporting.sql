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
