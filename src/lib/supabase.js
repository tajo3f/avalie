import { APP_CONFIG } from '../config.js'

const TOKEN_KEY='tajo-avalie-supabase-session-v2'

const baseHeaders = () => ({ apikey: APP_CONFIG.supabaseAnonKey, 'Content-Type':'application/json' })
const readToken = () => { try { return JSON.parse(localStorage.getItem(TOKEN_KEY)||'null') } catch { return null } }
const writeToken = t => localStorage.setItem(TOKEN_KEY, JSON.stringify(t))


function adoptHashSession(){
  if(!location.hash || !location.hash.includes('access_token=')) return null
  const hp=new URLSearchParams(location.hash.slice(1)); const access_token=hp.get('access_token'), refresh_token=hp.get('refresh_token'), expires_in=Number(hp.get('expires_in')||3600), token_type=hp.get('token_type')||'bearer'
  if(!access_token) return null
  const t={access_token,refresh_token,expires_in,token_type,expires_at:Math.floor(Date.now()/1000)+expires_in,type:hp.get('type')||null}; writeToken(t); return t
}

async function parse(res){ const text=await res.text(); let body=null; try{body=text?JSON.parse(text):null}catch{body=text}; if(!res.ok){ const err=new Error(body?.message||body?.error_description||body?.hint||`Erro ${res.status}`); err.status=res.status; err.body=body; throw err } return body }

async function refreshIfNeeded(){
  let t=readToken(); if(!t?.refresh_token) return t
  const expiresAt=t.expires_at || (t.expires_in ? Math.floor(Date.now()/1000)+t.expires_in : 0)
  if(expiresAt && expiresAt-Date.now()/1000 > 90) return t
  const res=await fetch(`${APP_CONFIG.supabaseUrl}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers:baseHeaders(),body:JSON.stringify({refresh_token:t.refresh_token})})
  const fresh=await parse(res); fresh.expires_at=Math.floor(Date.now()/1000)+(fresh.expires_in||3600); writeToken(fresh); return fresh
}

async function request(path,{method='GET',body,auth=true,headers={}}={}){
  const token=auth ? await refreshIfNeeded() : null
  const res=await fetch(`${APP_CONFIG.supabaseUrl}${path}`,{method,headers:{...baseHeaders(),...(token?.access_token?{Authorization:`Bearer ${token.access_token}`}:{...(!auth?{}:{})}),...headers},body:body===undefined?undefined:JSON.stringify(body)})
  return parse(res)
}

export const supabase = {
  session: readToken,
  adoptHashSession,
  async signIn(email,password){
    const res=await fetch(`${APP_CONFIG.supabaseUrl}/auth/v1/token?grant_type=password`,{method:'POST',headers:baseHeaders(),body:JSON.stringify({email,password})})
    const t=await parse(res); t.expires_at=Math.floor(Date.now()/1000)+(t.expires_in||3600); writeToken(t); return t
  },
  async signOut(){ try{await request('/auth/v1/logout',{method:'POST'})}catch{} localStorage.removeItem(TOKEN_KEY) },
  async recover(email){ return request('/auth/v1/recover',{method:'POST',auth:false,body:{email,redirect_to:`${location.origin}/nova-senha`}}) },
  async updatePassword(password){ return request('/auth/v1/user',{method:'PUT',body:{password}}) },
  rpc(name,args={},publicCall=false){ return request(`/rest/v1/rpc/${name}`,{method:'POST',auth:!publicCall,body:args}) },
  select(table,query=''){ return request(`/rest/v1/${table}${query?`?${query}`:''}`) },
  insert(table,payload){ return request(`/rest/v1/${table}`,{method:'POST',headers:{Prefer:'return=representation'},body:payload}) },
  update(table,filter,payload){ return request(`/rest/v1/${table}?${filter}`,{method:'PATCH',headers:{Prefer:'return=representation'},body:payload}) },
  del(table,filter){ return request(`/rest/v1/${table}?${filter}`,{method:'DELETE',headers:{Prefer:'return=minimal'}}) },
  invoke(functionName,payload){ return request(`/functions/v1/${functionName}`,{method:'POST',body:payload}) }
}
