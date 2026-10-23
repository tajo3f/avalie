export const $ = (s, root=document) => root.querySelector(s)
export const $$ = (s, root=document) => [...root.querySelectorAll(s)]
export const esc = (v='') => String(v).replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))
export const slugify = (s='') => s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/[^a-z0-9]+/g,'-').replace(/(^-|-$)/g,'')
export const money = v => new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v||0))
export const dt = v => v ? new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short'}).format(new Date(v)) : '—'
export const dateOnly = v => v ? new Intl.DateTimeFormat('pt-BR',{dateStyle:'short'}).format(new Date(v)) : '—'
export const pct = v => `${Number(v||0).toLocaleString('pt-BR',{maximumFractionDigits:1})}%`
export const clamp = (n,min,max) => Math.max(min,Math.min(max,n))
export const pathParts = () => location.pathname.split('/').filter(Boolean).map(decodeURIComponent)
export const uid = p => `${p}-${crypto.randomUUID().slice(0,8)}`
export const sleep = ms => new Promise(r=>setTimeout(r,ms))
export const ratingLabel = n => ({1:'Péssimo',2:'Ruim',3:'Regular',4:'Bom',5:'Excelente'})[Number(n)] || '—'
export const ratingEmoji = n => ({1:'😡',2:'😕',3:'😐',4:'🙂',5:'🤩'})[Number(n)] || '⭐'
export const ago = value => {
  if(!value) return '—'; const d=(Date.now()-new Date(value).getTime())/1000
  if(d<60) return 'agora'; if(d<3600) return `há ${Math.floor(d/60)} min`; if(d<86400) return `há ${Math.floor(d/3600)} h`; return `há ${Math.floor(d/86400)} d`
}
export const toast = (message,type='success') => {
  const old=$('.toast'); if(old) old.remove();
  const el=document.createElement('div'); el.className=`toast ${type}`; el.textContent=message; document.body.append(el); setTimeout(()=>el.remove(),3200)
}
export const copy = async text => { try { await navigator.clipboard.writeText(text); toast('Copiado para a área de transferência.') } catch { toast('Não foi possível copiar.','error') } }
export const download = (name, text, type='text/plain;charset=utf-8') => { const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([text],{type})); a.download=name; a.click(); setTimeout(()=>URL.revokeObjectURL(a.href),1000) }
export const csvEscape = v => `"${String(v??'').replaceAll('"','""')}"`
export const publicUrl = (companySlug, pointSlug) => `${location.origin}/${companySlug}/${pointSlug}`
export const qs = obj => Object.entries(obj).filter(([,v])=>v!==undefined&&v!==null&&v!=='').map(([k,v])=>`${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&')
