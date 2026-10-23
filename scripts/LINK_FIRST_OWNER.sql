-- Use depois de criar a primeira empresa e o usuário proprietário no Authentication.
-- Ajuste COMPANY_SLUG e OWNER_EMAIL.
do $$
declare v_company_id uuid; v_user_id uuid;
begin
  select id into v_company_id from public.companies where slug='COMPANY_SLUG' limit 1;
  select id into v_user_id from auth.users where lower(email)=lower('OWNER_EMAIL') limit 1;
  if v_company_id is null then raise exception 'Empresa não encontrada.'; end if;
  if v_user_id is null then raise exception 'Usuário não encontrado no Authentication.'; end if;
  insert into public.company_users(company_id,user_id,role,active)
  values(v_company_id,v_user_id,'owner',true)
  on conflict(company_id,user_id) do update set role='owner',active=true,updated_at=now();
end $$;
