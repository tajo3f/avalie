const now=Date.now(), iso=(m=0)=>new Date(now-m*60000).toISOString()

export const demoData={
  company:{id:'11111111-1111-1111-1111-111111111111',name:'Supermercado Modelo',slug:'mercado-modelo',logo_url:null,primary_color:'#0A5CFF',feedback_question:'Como foi seu atendimento?',feedback_subtitle:'Sua opinião leva poucos segundos e chega direto à gestão.',thank_you_message:'Obrigado por compartilhar sua experiência.',comments_enabled:true,status:'active',plan_name:'Profissional',monthly_price:390,setup_price:390,point_limit:12,billing_day:15},
  subscription:{plan_name:'Profissional',monthly_price:390,setup_price:390,point_limit:12,status:'active',next_due_date:new Date(now+12*86400000).toISOString().slice(0,10)},
  currentUser:{id:'demo-owner',full_name:'Marcos Andrade',email:'proprietario@demo.com',role:'owner',is_platform_admin:false},
  points:[
    {id:'p01',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa 01',slug:'caixa-01',point_type:'Caixa',active:true,employee_id:'e01',employee_name:'Ana Souza',score:4.9,reviews:47},
    {id:'p02',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa 02',slug:'caixa-02',point_type:'Caixa',active:true,employee_id:'e02',employee_name:'Maria Lima',score:4.7,reviews:39},
    {id:'p03',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa 03',slug:'caixa-03',point_type:'Caixa',active:true,employee_id:'e03',employee_name:'João Reis',score:4.5,reviews:28},
    {id:'p04',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa 04',slug:'caixa-04',point_type:'Caixa',active:true,employee_id:'e04',employee_name:'Carlos Silva',score:3.2,reviews:19},
    {id:'p05',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa 05',slug:'caixa-05',point_type:'Caixa',active:true,employee_id:'e05',employee_name:'Juliana Martins',score:4.8,reviews:34},
    {id:'p06',company_id:'11111111-1111-1111-1111-111111111111',name:'Caixa Preferencial',slug:'caixa-preferencial',point_type:'Caixa',active:true,employee_id:'e06',employee_name:'Rafael Costa',score:4.6,reviews:31},
    {id:'p07',company_id:'11111111-1111-1111-1111-111111111111',name:'Açougue',slug:'acougue',point_type:'Açougue',active:true,employee_id:null,employee_name:null,score:4.7,reviews:52},
    {id:'p08',company_id:'11111111-1111-1111-1111-111111111111',name:'Padaria',slug:'padaria',point_type:'Padaria',active:true,employee_id:null,employee_name:null,score:4.8,reviews:45}
  ],
  employees:[
    {id:'e01',name:'Ana Souza',employee_code:'001',role_name:'Operadora de caixa',active:true,score:4.94,reviews:328},
    {id:'e02',name:'Maria Lima',employee_code:'002',role_name:'Operadora de caixa',active:true,score:4.89,reviews:287},
    {id:'e03',name:'João Reis',employee_code:'003',role_name:'Operador de caixa',active:true,score:4.82,reviews:302},
    {id:'e04',name:'Carlos Silva',employee_code:'004',role_name:'Operador de caixa',active:true,score:3.58,reviews:141},
    {id:'e05',name:'Juliana Martins',employee_code:'005',role_name:'Operadora de caixa',active:true,score:4.77,reviews:266},
    {id:'e06',name:'Rafael Costa',employee_code:'006',role_name:'Operador de caixa',active:true,score:4.68,reviews:219},
    {id:'e07',name:'Bruna Alves',employee_code:'007',role_name:'Operadora de caixa',active:true,score:4.55,reviews:198}
  ],
  shifts:[
    {id:'s01',point_id:'p01',employee_id:'e01',started_at:iso(260),ended_at:null,status:'active'},
    {id:'s02',point_id:'p02',employee_id:'e02',started_at:iso(240),ended_at:null,status:'active'},
    {id:'s03',point_id:'p03',employee_id:'e03',started_at:iso(225),ended_at:null,status:'active'},
    {id:'s04',point_id:'p04',employee_id:'e04',started_at:iso(210),ended_at:null,status:'active'},
    {id:'s05',point_id:'p05',employee_id:'e05',started_at:iso(190),ended_at:null,status:'active'}
  ],
  feedbacks:[
    {id:'AV-1848',point_id:'p01',point_name:'Caixa 01',employee_id:'e01',employee_name:'Ana Souza',rating:5,reason_codes:['educacao','agilidade'],comment:'Atendimento excelente e muito rápido.',status:'resolved',created_at:iso(12)},
    {id:'AV-1847',point_id:'p04',point_name:'Caixa 04',employee_id:'e04',employee_name:'Carlos Silva',rating:1,reason_codes:['atendimento','educacao'],comment:'O atendente respondeu de forma grosseira.',status:'new',created_at:iso(18)},
    {id:'AV-1846',point_id:'p04',point_name:'Caixa 04',employee_id:'e04',employee_name:'Carlos Silva',rating:2,reason_codes:['tempo-espera'],comment:'A fila demorou bastante.',status:'new',created_at:iso(27)},
    {id:'AV-1845',point_id:'p02',point_name:'Caixa 02',employee_id:'e02',employee_name:'Maria Lima',rating:5,reason_codes:['atendimento'],comment:'Muito atenciosa.',status:'resolved',created_at:iso(39)},
    {id:'AV-1844',point_id:'p03',point_name:'Caixa 03',employee_id:'e03',employee_name:'João Reis',rating:4,reason_codes:['agilidade'],comment:null,status:'resolved',created_at:iso(53)},
    {id:'AV-1843',point_id:'p04',point_name:'Caixa 04',employee_id:'e04',employee_name:'Carlos Silva',rating:2,reason_codes:['tempo-espera','agilidade'],comment:'Demorou para finalizar a compra.',status:'analyzing',created_at:iso(66)},
    {id:'AV-1842',point_id:'p05',point_name:'Caixa 05',employee_id:'e05',employee_name:'Juliana Martins',rating:5,reason_codes:['educacao','atendimento'],comment:'Parabéns pelo atendimento.',status:'resolved',created_at:iso(88)}
  ],
  incidents:[
    {id:'OC-027',severity:'critical',point_id:'p04',point_name:'Caixa 04',employee_id:'e04',employee_name:'Carlos Silva',title:'Avaliações negativas recorrentes',description:'Foram detectadas 3 avaliações negativas em curto período.',status:'new',created_at:iso(15)},
    {id:'OC-026',severity:'warning',point_id:null,point_name:null,employee_id:null,employee_name:null,title:'Tempo de espera aumentou',description:'O motivo “Tempo de espera” apresentou alta no período atual.',status:'analyzing',created_at:iso(72)},
    {id:'OC-025',severity:'info',point_id:'p06',point_name:'Caixa Preferencial',employee_id:'e06',employee_name:'Rafael Costa',title:'Queda de volume de avaliações',description:'O ponto recebeu menos avaliações que a média recente.',status:'resolved',created_at:iso(1440)}
  ],
  team:[
    {id:'tm1',user_id:'demo-owner',full_name:'Marcos Andrade',email:'proprietario@demo.com',role:'owner',active:true},
    {id:'tm2',user_id:'demo-manager',full_name:'Fernanda Rocha',email:'gerente@demo.com',role:'manager',active:true}
  ],
  dashboard:{average_rating:4.72,evaluations:186,positive_percent:94,negative_count:7,open_incidents:2},
  topEmployees:[
    {employee_id:'e01',employee_name:'Ana Souza',average_rating:4.94,review_count:328,positive_percent:98},
    {employee_id:'e02',employee_name:'Maria Lima',average_rating:4.89,review_count:287,positive_percent:97},
    {employee_id:'e03',employee_name:'João Reis',average_rating:4.82,review_count:302,positive_percent:96},
    {employee_id:'e05',employee_name:'Juliana Martins',average_rating:4.77,review_count:266,positive_percent:95}
  ],
  pointPerformance:[],
  reasons:[{reason_code:'atendimento',reason_label:'Atendimento',mention_count:124},{reason_code:'agilidade',reason_label:'Agilidade',mention_count:96},{reason_code:'educacao',reason_label:'Educação',mention_count:82},{reason_code:'tempo-espera',reason_label:'Tempo de espera',mention_count:41},{reason_code:'organizacao',reason_label:'Organização',mention_count:28}],
  hourly:[{hour_of_day:8,average_rating:4.8,review_count:38},{hour_of_day:10,average_rating:4.7,review_count:46},{hour_of_day:12,average_rating:4.4,review_count:51},{hour_of_day:14,average_rating:4.6,review_count:43},{hour_of_day:16,average_rating:4.5,review_count:55},{hour_of_day:18,average_rating:3.9,review_count:61}],
  history:[4.55,4.62,4.48,4.71,4.74,4.69,4.72],
  platform:{companies:[
    {id:'c1',name:'Supermercado Modelo',slug:'mercado-modelo',plan_name:'Profissional',point_count:8,point_limit:12,monthly_price:390,status:'active',responsible:'Marcos Andrade',email:'proprietario@demo.com',created_at:iso(50000)},
    {id:'c2',name:'Mercado Primavera',slug:'mercado-primavera',plan_name:'Profissional',point_count:12,point_limit:12,monthly_price:390,status:'active',responsible:'Luciana Santos',email:'luciana@demo.com',created_at:iso(40000)},
    {id:'c3',name:'Supermercado Avenida',slug:'supermercado-avenida',plan_name:'Profissional',point_count:6,point_limit:12,monthly_price:390,status:'pending',responsible:'André Lopes',email:'andre@demo.com',created_at:iso(20000)}
  ]}
}

export const demoReasons=[{code:'atendimento',label:'Atendimento'},{code:'agilidade',label:'Agilidade'},{code:'educacao',label:'Educação'},{code:'tempo-espera',label:'Tempo de espera'},{code:'organizacao',label:'Organização'},{code:'resolucao',label:'Resolução do problema'},{code:'outro',label:'Outro'}]

export function demoPublicContext(companySlug,pointSlug){
  const p=demoData.points.find(x=>x.slug===pointSlug)
  if(!p || !['mercado-modelo','supermercado-modelo'].includes(companySlug)) throw new Error('Ponto de avaliação não encontrado.')
  return {company:{id:demoData.company.id,name:demoData.company.name,slug:companySlug,logo_url:null,logo_text:'MM',primary_color:demoData.company.primary_color,feedback_question:demoData.company.feedback_question,feedback_subtitle:demoData.company.feedback_subtitle,thank_you_message:demoData.company.thank_you_message,comments_enabled:true},point:{id:p.id,name:p.name,slug:p.slug,type:p.point_type},reasons:demoReasons}
}
