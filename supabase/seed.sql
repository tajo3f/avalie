-- DEMO OPCIONAL PARA AMBIENTE DE DESENVOLVIMENTO.
-- Não é necessário para produção.
insert into public.companies(id,name,slug,logo_text,primary_color,status,plan_name,setup_price,monthly_price,point_limit,billing_day)
values('11111111-1111-1111-1111-111111111111','Supermercado Modelo','mercado-modelo','MM','#0A5CFF','active','Profissional',390,390,12,15)
on conflict(id) do nothing;

insert into public.stores(id,company_id,name,slug)
values('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Loja Principal','principal')
on conflict(id) do nothing;

insert into public.subscriptions(company_id,plan_name,setup_price,monthly_price,point_limit,status,next_due_date)
values('11111111-1111-1111-1111-111111111111','Profissional',390,390,12,'active',current_date+30)
on conflict(company_id) do nothing;

insert into public.company_contacts(company_id,name,email,is_primary)
values('11111111-1111-1111-1111-111111111111','Responsável Demonstração','responsavel@demo.com',true)
on conflict do nothing;

insert into public.evaluation_points(id,company_id,store_id,name,slug,point_type)
values
('30000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 01','caixa-01','Caixa'),
('30000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Caixa 02','caixa-02','Caixa'),
('30000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Açougue','acougue','Açougue')
on conflict(id) do nothing;

insert into public.employees(id,company_id,store_id,name,employee_code,role_name)
values
('40000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Ana Souza','001','Operadora de caixa'),
('40000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Maria Lima','002','Operadora de caixa')
on conflict(id) do nothing;
