import { escapeHtml, initials, relativeTime, scoreTone } from '../lib/utils.js'

export const icons = {
  home: '⌂', reviews: '★', points: '⌖', users: '◉', shifts: '⇄', incidents: '!', ranking: '♛', reports: '▤', qr: '▦', team: '♟', settings: '⚙', bell: '●', search: '⌕', logout: '↪', admin: '◆'
}

export function badge(text, tone = 'neutral') {
  return `<span class="badge badge-${tone}">${escapeHtml(text)}</span>`
}

export function statCard({ label, value, meta = '', icon = '•', tone = 'neutral' }) {
  return `<article class="stat-card">
    <div class="stat-icon tone-${tone}">${icon}</div>
    <div><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>${meta ? `<small>${meta}</small>` : ''}</div>
  </article>`
}

export function avatar(name, size = '') {
  return `<span class="avatar ${size}">${initials(name)}</span>`
}

export function emptyState(title, text, action = '') {
  return `<div class="empty-state"><div class="empty-icon">◇</div><h3>${escapeHtml(title)}</h3><p>${escapeHtml(text)}</p>${action}</div>`
}

export function pageHeader(title, subtitle, actions = '') {
  return `<div class="page-header"><div><h1>${escapeHtml(title)}</h1><p>${escapeHtml(subtitle || '')}</p></div><div class="page-actions">${actions}</div></div>`
}

export function topbar(data, title = '') {
  const unread = data.notifications.filter(n => !n.read).length
  return `<header class="topbar">
    <button class="icon-btn mobile-menu" data-action="toggle-menu" aria-label="Abrir menu">☰</button>
    <div class="topbar-title"><strong>${escapeHtml(title || data.company.name)}</strong><span>TAJO Avalia</span></div>
    <div class="topbar-search"><span>⌕</span><input id="global-search" placeholder="Pesquisar caixa, funcionário ou avaliação..." /></div>
    <button class="icon-btn notification-btn" data-action="notifications">♢${unread ? `<b>${unread}</b>` : ''}</button>
    <div class="user-chip">${avatar(data.currentUser.name)}<div><strong>${escapeHtml(data.currentUser.name)}</strong><span>${data.currentUser.role === 'owner' ? 'Proprietário' : 'Gerente'}</span></div></div>
  </header>`
}

export function tenantSidebar(data, active) {
  const items = [
    ['dashboard','Visão Geral','home'], ['evaluations','Avaliações','reviews'], ['points','Pontos','points'], ['employees','Funcionários','users'], ['shifts','Turnos','shifts'], ['incidents','Ocorrências','incidents'],
    ['ranking','Ranking','ranking'], ['reports','Relatórios','reports'], ['qrcodes','QR Codes','qr'], ['team','Equipe','team'], ['settings','Configurações','settings']
  ]
  const slug = data.company.slug
  return `<aside class="sidebar" id="sidebar">
    <div class="brand"><span class="brand-mark">✓</span><div><strong>TAJO</strong><span>AVALIA</span></div></div>
    <div class="sidebar-company"><span class="company-logo">${escapeHtml(data.company.logoText || 'SM')}</span><div><strong>${escapeHtml(data.company.name)}</strong><span>Plano ${escapeHtml(data.company.plan)}</span></div></div>
    <nav>${items.map(([key,label,icon]) => {
      const section = ['dashboard','evaluations','points','employees','shifts','incidents'].includes(key) ? 'OPERAÇÃO' : ['ranking','reports'].includes(key) ? 'ANÁLISE' : 'GESTÃO'
      return `${(['dashboard','ranking','qrcodes'].includes(key)) ? `<small class="nav-section">${section}</small>` : ''}<a data-link href="/${slug}/painel${key === 'dashboard' ? '' : `/${key}`}" class="${active===key?'active':''}"><span>${icons[icon]}</span>${label}${key==='incidents' ? `<em>${data.incidents.filter(i=>i.status!=='resolved').length}</em>`:''}</a>`
    }).join('')}</nav>
    <div class="sidebar-footer"><button data-action="logout"><span>${icons.logout}</span>Sair</button><small>TAJO Digital • v1.0</small></div>
  </aside>`
}

export function adminSidebar(active) {
  const items = [['admin-dashboard','Visão Geral','home','/admin'],['admin-clients','Clientes','users','/admin/clientes'],['admin-plans','Planos','reports','/admin/planos'],['admin-settings','Configurações','settings','/admin/configuracoes']]
  return `<aside class="sidebar" id="sidebar">
    <div class="brand"><span class="brand-mark">✓</span><div><strong>TAJO</strong><span>AVALIA</span></div></div>
    <div class="sidebar-company admin"><span class="company-logo">T3F</span><div><strong>TAJO Digital</strong><span>Administração</span></div></div>
    <nav><small class="nav-section">PLATAFORMA</small>${items.map(([key,label,icon,href])=>`<a data-link href="${href}" class="${active===key?'active':''}"><span>${icons[icon]}</span>${label}</a>`).join('')}</nav>
    <div class="sidebar-footer"><button data-action="logout"><span>${icons.logout}</span>Sair</button><small>TAJO Digital • Admin</small></div>
  </aside>`
}

export function shell({ data, active, content, admin = false, title = '' }) {
  return `<div class="app-shell">${admin ? adminSidebar(active) : tenantSidebar(data, active)}<div class="app-main">${topbar(data, title)}<main class="content">${content}</main></div><div class="menu-backdrop" data-action="toggle-menu"></div></div>`
}

export function ratingStars(value) {
  return `<span class="rating-stars">${'★'.repeat(Math.round(value))}${'☆'.repeat(5-Math.round(value))}</span>`
}

export function scorePill(value) {
  return `<span class="score-pill ${scoreTone(Number(value))}">★ ${Number(value).toFixed(1)}</span>`
}

export function notificationsPanel(data) {
  return `<div class="drawer" id="drawer"><div class="drawer-head"><div><strong>Notificações</strong><span>${data.notifications.filter(n=>!n.read).length} não lidas</span></div><button class="icon-btn" data-action="close-drawer">×</button></div><div class="drawer-list">${data.notifications.map(n=>`<div class="notification ${n.read?'':'unread'}"><span></span><div><strong>${escapeHtml(n.title)}</strong><p>${escapeHtml(n.detail)}</p><small>${relativeTime(n.createdAt)}</small></div></div>`).join('')}</div></div><div class="drawer-backdrop" data-action="close-drawer"></div>`
}

export function modal({ title, body, footer = '', wide = false }) {
  return `<div class="modal-backdrop" data-action="close-modal"><div class="modal ${wide?'modal-wide':''}" role="dialog" onclick="event.stopPropagation()"><div class="modal-head"><h2>${escapeHtml(title)}</h2><button class="icon-btn" data-action="close-modal">×</button></div><div class="modal-body">${body}</div>${footer?`<div class="modal-footer">${footer}</div>`:''}</div></div>`
}

export function lineChart(values, labels = ['Seg','Ter','Qua','Qui','Sex','Sáb','Dom']) {
  const width=720, height=210, pad=24
  const min = Math.min(...values)-.15, max=Math.max(...values)+.15
  const pts=values.map((v,i)=>`${pad+i*(width-pad*2)/(values.length-1)},${height-pad-((v-min)/(max-min))*(height-pad*2)}`).join(' ')
  return `<div class="line-chart"><svg viewBox="0 0 ${width} ${height}" preserveAspectRatio="none"><line x1="${pad}" y1="${height-pad}" x2="${width-pad}" y2="${height-pad}" class="grid-line"/><polyline points="${pts}" class="chart-line" fill="none"/>${values.map((v,i)=>{const [x,y]=pts.split(' ')[i].split(',');return `<circle cx="${x}" cy="${y}" r="5" class="chart-dot"><title>${v.toFixed(2)}</title></circle>`}).join('')}</svg><div class="chart-labels">${labels.map(l=>`<span>${l}</span>`).join('')}</div></div>`
}
