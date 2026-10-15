-- Dados iniciais neutros para desenvolvimento.
-- Em produção, você pode manter apenas os motivos globais e remover o cliente de demonstração.

insert into public.evaluation_reasons(company_id,code,label,sort_order)
values
  (null,'atendimento','Atendimento',10),
  (null,'agilidade','Agilidade',20),
  (null,'educacao','Educação',30),
  (null,'tempo-espera','Tempo de espera',40),
  (null,'organizacao','Organização',50),
  (null,'resolucao','Resolução do problema',60),
  (null,'outro','Outro',999)
on conflict (company_id,code) do nothing;

insert into public.companies(id,name,slug,logo_text,primary_color,status,plan_name,setup_price,monthly_price,point_limit,billing_day)
values('11111111-1111-1111-1111-111111111111','Supermercado Modelo','supermercado-modelo','SM','#16a34a','active','Profissional',390,390,12,15)
on conflict (id) do nothing;

insert into public.stores(id,company_id,name,slug)
values('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Loja Principal','principal')
on conflict (id) do nothing;

insert into public.subscriptions(company_id,plan_name,setup_price,monthly_price,point_limit,status)
values('11111111-1111-1111-1111-111111111111','Profissional',390,390,12,'active')
on conflict (company_id) do nothing;

insert into public.evaluation_points(id,company_id,store_id,name,slug,point_type)
values
('30000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 01','caixa-01','Caixa'),
('30000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 02','caixa-02','Caixa'),
('30000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 03','caixa-03','Caixa'),
('30000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 04','caixa-04','Caixa'),
('30000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Açougue','acougue','Açougue'),
('30000000-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Padaria','padaria','Padaria')
on conflict (id) do nothing;

insert into public.employees(id,company_id,store_id,name,employee_code,role_name)
values
('40000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Ana Souza','001','Operadora de caixa'),
('40000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Maria Lima','002','Operadora de caixa'),
('40000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','João Reis','003','Operador de caixa'),
('40000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Carlos Silva','004','Operador de caixa')
on conflict (id) do nothing;
