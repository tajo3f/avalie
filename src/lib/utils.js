export const qs = (selector, root = document) => root.querySelector(selector)
export const qsa = (selector, root = document) => [...root.querySelectorAll(selector)]

export function money(value) {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}

export function formatDate(dateLike, options = {}) {
  const date = new Date(dateLike)
  return new Intl.DateTimeFormat('pt-BR', {
    dateStyle: options.dateStyle || 'short',
    timeStyle: options.timeStyle,
  }).format(date)
}

export function formatDateTime(dateLike) {
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
  }).format(new Date(dateLike))
}

export function slugify(value) {
  return value
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

export function uid(prefix = 'id') {
  return `${prefix}-${crypto.randomUUID?.() || Math.random().toString(36).slice(2)}`
}

export function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

export function initials(name = '') {
  return name.split(' ').filter(Boolean).slice(0, 2).map((part) => part[0]).join('').toUpperCase()
}

export function ratingLabel(rating) {
  return ({ 1: 'Péssimo', 2: 'Ruim', 3: 'Regular', 4: 'Bom', 5: 'Excelente' })[rating] || '-'
}

export function scoreTone(score) {
  if (score >= 4.5) return 'success'
  if (score >= 4) return 'positive'
  if (score >= 3.5) return 'warning'
  return 'danger'
}

export function relativeTime(dateLike) {
  const delta = Date.now() - new Date(dateLike).getTime()
  const min = Math.floor(delta / 60000)
  if (min < 1) return 'agora'
  if (min < 60) return `há ${min} min`
  const h = Math.floor(min / 60)
  if (h < 24) return `há ${h}h`
  const d = Math.floor(h / 24)
  return `há ${d}d`
}

export function downloadText(filename, content, mime = 'text/plain;charset=utf-8') {
  const blob = new Blob([content], { type: mime })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = filename
  a.click()
  URL.revokeObjectURL(a.href)
}

export function copyText(value) {
  return navigator.clipboard?.writeText(value)
}

export function pathParts() {
  return location.pathname.split('/').filter(Boolean)
}
