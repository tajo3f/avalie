import { APP_CONFIG } from '../config.js'

const TOKEN_KEY = 'tajo-avalia-supabase-token'

function headers(auth = true) {
  const token = JSON.parse(localStorage.getItem(TOKEN_KEY) || 'null')
  return {
    apikey: APP_CONFIG.supabaseAnonKey,
    'Content-Type': 'application/json',
    ...(auth && token?.access_token ? { Authorization: `Bearer ${token.access_token}` } : {})
  }
}

async function request(path, options = {}) {
  if (!APP_CONFIG.supabaseUrl || !APP_CONFIG.supabaseAnonKey) {
    throw new Error('Supabase não configurado. Edite src/config.js ou mantenha useMocks=true.')
  }
  const res = await fetch(`${APP_CONFIG.supabaseUrl}${path}`, {
    ...options,
    headers: { ...headers(options.auth !== false), ...(options.headers || {}) }
  })
  const text = await res.text()
  const body = text ? JSON.parse(text) : null
  if (!res.ok) throw new Error(body?.message || body?.error_description || `Erro ${res.status}`)
  return body
}

export const supabaseApi = {
  async signIn(email, password) {
    const token = await request('/auth/v1/token?grant_type=password', {
      method: 'POST', auth: false, body: JSON.stringify({ email, password })
    })
    localStorage.setItem(TOKEN_KEY, JSON.stringify(token))
    return token
  },
  signOut() { localStorage.removeItem(TOKEN_KEY) },
  session() { return JSON.parse(localStorage.getItem(TOKEN_KEY) || 'null') },
  rpc(name, args = {}, { publicCall = false } = {}) {
    return request(`/rest/v1/rpc/${name}`, {
      method: 'POST', auth: !publicCall, body: JSON.stringify(args)
    })
  },
  select(table, query = '*') {
    return request(`/rest/v1/${table}?select=${encodeURIComponent(query)}`, { method: 'GET' })
  },
  insert(table, payload) {
    return request(`/rest/v1/${table}`, {
      method: 'POST',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(payload)
    })
  },
  update(table, id, payload) {
    return request(`/rest/v1/${table}?id=eq.${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(payload)
    })
  }
}
