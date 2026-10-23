import { isDemoMode } from '../config.js'
import { supabase } from './supabase.js'
import { demoData, demoPublicContext } from './demo.js'
import { slugify } from './utils.js'

const UI_SESSION='tajo-avalie-ui-session-v2'
let realCache=null

const getUi=()=>{try{return JSON.parse(localStorage.getItem(UI_SESSION)||'null')}catch{return null}}
const setUi=s=>localStorage.setItem(UI_SESSION,JSON.stringify(s))

function normalizeCompany(c,s){ return {...c,plan_name:s?.plan_name||c.plan_name||'Profissional',monthly_price:Number(s?.monthly_price??c.monthly_price??390),setup_price:Number(s?.setup_price??c.setup_price??390),point_limit:Number(s?.point_limit??c.point_limit??12)} }

async function getCompanyData(companyId){
  const today=new Date(), from=new Date(today); from.setDate(from.getDate()-30)
  const fromIso=from.toISOString(), toIso=today.toISOString()
  const [companies,subs,points,employees,feedbacks,incidents,shifts,team,dashboard,topEmployees,pointPerformance,reasons,hourly]=await Promise.all([
    supabase.select('companies',`select=*&id=eq.${companyId}&limit=1`),
    supabase.select('subscriptions',`select=*&company_id=eq.${companyId}&limit=1`),
    supabase.select('v_points_live',`select=*&company_id=eq.${companyId}&order=name.asc`),
    supabase.select('employees',`select=*&company_id=eq.${companyId}&order=name.asc`),
    supabase.select('v_feedback_details',`select=*&company_id=eq.${companyId}&order=created_at.desc&limit=250`),
    supabase.select('v_incident_details',`select=*&company_id=eq.${companyId}&order=created_at.desc&limit=150`),
    supabase.select('shifts',`select=*&company_id=eq.${companyId}&order=started_at.desc&limit=150`),
    supabase.select('v_team_members',`select=*&company_id=eq.${companyId}&order=created_at.asc`),
    supabase.rpc('dashboard_summary',{p_company_id:companyId,p_from:fromIso,p_to:toIso}),
    supabase.rpc('top_employees',{p_company_id:companyId,p_from:fromIso,p_to:toIso,p_min_reviews:1}),
    supabase.rpc('point_performance',{p_company_id:companyId,p_from:fromIso,p_to:toIso}),
    supabase.rpc('reason_stats',{p_company_id:companyId,p_from:fromIso,p_to:toIso}),
    supabase.rpc('hourly_performance',{p_company_id:companyId,p_from:fromIso,p_to:toIso})
  ])
  const company=normalizeCompany(companies?.[0],subs?.[0])
  realCache={company,subscription:subs?.[0]||null,points:points||[],employees:employees||[],feedbacks:feedbacks||[],incidents:incidents||[],shifts:shifts||[],team:team||[],dashboard:dashboard||{},topEmployees:topEmployees||[],pointPerformance:pointPerformance||[],reasons:reasons||[],hourly:hourly||[],history:[4.45,4.52,4.61,4.58,4.68,4.7,Number(dashboard?.average_rating||0)]}
  return realCache
}

export const api={
  demo:isDemoMode,
  uiSession:getUi,
  async signIn(email,password,{admin=false,tenantSlug=null}={}){
    if(isDemoMode()){
      const ok=admin ? (email==='admin@tajo.com'&&password==='123456') : (['proprietario@demo.com','gerente@demo.com'].includes(email)&&password==='123456')
      if(!ok) throw new Error('Credenciais inválidas para a demonstração.')
      const session=admin?{email,role:'platform_admin',isPlatformAdmin:true}:{email,role:email.startsWith('proprietario')?'owner':'manager',companyId:demoData.company.id,companySlug:'mercado-modelo',isPlatformAdmin:false}
      setUi(session); return session
    }
    await supabase.signIn(email,password)
    const ctx=await supabase.rpc('get_my_context',{})
    if(admin){ if(!ctx?.is_platform_admin){await supabase.signOut(); throw new Error('Este usuário não possui acesso ao Admin TAJO.')} const s={email,role:'platform_admin',isPlatformAdmin:true}; setUi(s); return s }
    const memberships=ctx?.memberships||[]
    const member=memberships.find(m=>!tenantSlug||m.company_slug===tenantSlug) || memberships[0]
    if(!member){ await supabase.signOut(); throw new Error('Sua conta não está vinculada a nenhum estabelecimento.') }
    const s={email,role:member.role,companyId:member.company_id,companySlug:member.company_slug,companyName:member.company_name,isPlatformAdmin:false,profile:ctx.profile}; setUi(s); return s
  },
  async signOut(){ localStorage.removeItem(UI_SESSION); realCache=null; if(!isDemoMode()) await supabase.signOut() },
  async recover(email){ if(isDemoMode()) return true; return supabase.recover(email) },
  async publicContext(companySlug,pointSlug){ return isDemoMode()?demoPublicContext(companySlug,pointSlug):supabase.rpc('get_public_evaluation_context',{p_company_slug:companySlug,p_point_slug:pointSlug},true) },
  async submitFeedback({companySlug,pointSlug,rating,reasons,comment}){
    if(isDemoMode()) return {feedback_id:`demo-${Date.now()}`,received_at:new Date().toISOString()}
    let nonce=localStorage.getItem('tajo-evaluation-nonce-v2'); if(!nonce){nonce=crypto.randomUUID();localStorage.setItem('tajo-evaluation-nonce-v2',nonce)}
    return supabase.rpc('submit_feedback',{p_company_slug:companySlug,p_point_slug:pointSlug,p_rating:rating,p_reason_codes:reasons,p_comment:comment||null,p_client_nonce:nonce},true)
  },
  async companyData(force=false){ if(isDemoMode()) return structuredClone(demoData); const s=getUi(); if(!s?.companyId) throw new Error('Sessão sem empresa vinculada.'); if(realCache&&!force)return realCache; return getCompanyData(s.companyId) },
  async refresh(){ return this.companyData(true) },
  async createPoint({name,type='Caixa',slug}){ if(isDemoMode()){demoData.points.push({id:`p${Date.now()}`,name,slug:slug||slugify(name),point_type:type,active:true,employee_id:null,employee_name:null,score:0,reviews:0});return} const s=getUi(); await supabase.insert('evaluation_points',{company_id:s.companyId,name,slug:slug||slugify(name),point_type:type,active:true}); return this.refresh() },
  async createEmployee({name,code,role}){ if(isDemoMode()){demoData.employees.push({id:`e${Date.now()}`,name,employee_code:code||null,role_name:role||null,active:true,score:0,reviews:0});return} const s=getUi(); await supabase.insert('employees',{company_id:s.companyId,name,employee_code:code||null,role_name:role||null,active:true}); return this.refresh() },
  async startShift(pointId,employeeId){ if(isDemoMode()){ demoData.shifts.filter(x=>x.point_id===pointId&&x.status==='active').forEach(x=>{x.status='ended';x.ended_at=new Date().toISOString()}); demoData.shifts.push({id:`s${Date.now()}`,point_id:pointId,employee_id:employeeId,started_at:new Date().toISOString(),ended_at:null,status:'active'}); return } await supabase.rpc('start_shift',{p_point_id:pointId,p_employee_id:employeeId}); return this.refresh() },
  async endShift(shiftId){ if(isDemoMode()){const s=demoData.shifts.find(x=>x.id===shiftId);if(s){s.status='ended';s.ended_at=new Date().toISOString()}return} await supabase.rpc('end_shift',{p_shift_id:shiftId}); return this.refresh() },
  async setFeedbackStatus(id,status){ if(isDemoMode()){const f=demoData.feedbacks.find(x=>x.id===id);if(f)f.status=status;return} await supabase.rpc('set_feedback_status',{p_feedback_id:id,p_status:status}); return this.refresh() },
  async setIncidentStatus(id,status){ if(isDemoMode()){const i=demoData.incidents.find(x=>x.id===id);if(i)i.status=status;return} await supabase.rpc('set_incident_status',{p_incident_id:id,p_status:status}); return this.refresh() },
  async updateCompany(payload){ if(isDemoMode()){Object.assign(demoData.company,payload);return} const s=getUi(); await supabase.update('companies',`id=eq.${s.companyId}`,payload); return this.refresh() },
  async inviteUser({email,fullName,role}){ if(isDemoMode()){demoData.team.push({id:`tm${Date.now()}`,full_name:fullName,email,role,active:true});return} const s=getUi(); return supabase.invoke('invite-user',{company_id:s.companyId,email,full_name:fullName,role}) },
  async adminCompanies(){ if(isDemoMode()) return demoData.platform.companies; return supabase.rpc('admin_companies',{}) },
  async adminCreateCompany(payload){ if(isDemoMode()){const c={id:`c${Date.now()}`,name:payload.name,slug:payload.slug||slugify(payload.name),plan_name:'Profissional',point_count:0,point_limit:payload.point_limit||12,monthly_price:payload.monthly_price||390,status:'active',responsible:payload.responsible,email:payload.email,created_at:new Date().toISOString()};demoData.platform.companies.unshift(c);return c} return supabase.rpc('admin_create_company_v2',{p_name:payload.name,p_slug:payload.slug||slugify(payload.name),p_responsible_name:payload.responsible||null,p_responsible_email:payload.email||null,p_primary_color:'#0A5CFF',p_setup_price:payload.setup_price||390,p_monthly_price:payload.monthly_price||390,p_point_limit:payload.point_limit||12,p_billing_day:payload.billing_day||15}) }
}
