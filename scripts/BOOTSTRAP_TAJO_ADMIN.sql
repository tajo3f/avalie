-- 1) Primeiro crie o usuário pelo Supabase Dashboard > Authentication > Users.
-- 2) Troque o e-mail abaixo pelo e-mail real do administrador TAJO.
-- 3) Execute este script no SQL Editor.

do $$
declare v_user_id uuid;
begin
  select id into v_user_id from auth.users where lower(email)=lower('SEU_EMAIL_ADMIN@EXEMPLO.COM') limit 1;
  if v_user_id is null then raise exception 'Crie primeiro o usuário no Authentication e ajuste o e-mail deste script.'; end if;
  insert into public.platform_admins(user_id) values(v_user_id) on conflict(user_id) do nothing;
  raise notice 'Admin TAJO habilitado: %',v_user_id;
end $$;
