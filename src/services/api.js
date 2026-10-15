import { APP_CONFIG } from '../config.js'
import { loadData, mutate, setSession, clearSession, getSession } from '../lib/store.js'
import { uid } from '../lib/utils.js'
import { supabaseApi } from './supabase.js'

export const api = {
  getData() { return loadData() },
  session() { return getSession() },
  async signIn(email, password, isAdmin = false) {
    if (!APP_CONFIG.useMocks) {
      await supabaseApi.signIn(email, password)
      const session = { email, role: isAdmin ? 'platform_admin' : 'authenticated' }
      setSession(session)
      return session
    }
    const accepted = isAdmin
      ? email === 'admin@tajo.com' && password === '123456'
      : ['gerente@demo.com', 'proprietario@demo.com'].includes(email) && password === '123456'
    if (!accepted) throw new Error('E-mail ou senha inválidos para a demonstração.')
    const session = { email, role: isAdmin ? 'platform_admin' : (email.startsWith('proprietario') ? 'owner' : 'manager') }
    setSession(session)
    return session
  },
  signOut() { clearSession(); supabaseApi.signOut() },
  async submitFeedback({ companySlug, pointSlug, rating, reasons, comment }) {
    if (!APP_CONFIG.useMocks) {
      return supabaseApi.rpc('submit_feedback', {
        p_company_slug: companySlug,
        p_point_slug: pointSlug,
        p_rating: rating,
        p_reason_codes: reasons,
        p_comment: comment || null,
        p_client_nonce: (() => { let n = localStorage.getItem('tajo-client-nonce'); if (!n) { n = crypto.randomUUID(); localStorage.setItem('tajo-client-nonce', n) } return n })()
      }, { publicCall: true })
    }
    return mutate((data) => {
      const point = data.points.find((p) => p.slug === pointSlug)
      if (!point) throw new Error('Ponto de avaliação não encontrado.')
      const evaluation = {
        id: `AV-${Math.floor(1900 + Math.random() * 8000)}`,
        pointId: point.id,
        employeeId: point.employeeId,
        rating,
        reasons,
        comment,
        status: rating <= 2 ? 'new' : 'resolved',
        createdAt: new Date().toISOString()
      }
      data.evaluations.unshift(evaluation)
      point.reviews += 1
      point.score = Number(((point.score * (point.reviews - 1) + rating) / point.reviews).toFixed(2))
      if (rating <= 2) {
        data.incidents.unshift({
          id: `OC-${Math.floor(30 + Math.random() * 900)}`,
          severity: rating === 1 ? 'critical' : 'warning',
          pointId: point.id,
          employeeId: point.employeeId,
          title: 'Nova avaliação negativa recebida',
          description: `Avaliação ${rating}/5 recebida em ${point.name}.`,
          status: 'new',
          createdAt: new Date().toISOString(),
          feedbackIds: [evaluation.id], assignee: 'Gerência'
        })
      }
      return evaluation
    })
  },
  createPoint(payload) {
    return mutate((data) => {
      if (data.points.length >= data.company.pointLimit) throw new Error('Limite de pontos do plano atingido.')
      const point = { id: uid('point'), active: true, score: 0, reviews: 0, employeeId: null, ...payload }
      data.points.push(point); data.company.usedPoints = data.points.length
      return point
    })
  },
  createEmployee(payload) {
    return mutate((data) => {
      const employee = { id: uid('emp'), active: true, score: 0, reviews: 0, ...payload }
      data.employees.push(employee); return employee
    })
  },
  startShift(pointId, employeeId) {
    return mutate((data) => {
      data.shifts.filter(s => s.pointId === pointId && s.status === 'active').forEach(s => { s.status = 'ended'; s.endedAt = new Date().toISOString() })
      const point = data.points.find(p => p.id === pointId); if (point) point.employeeId = employeeId
      data.shifts.push({ id: uid('shift'), pointId, employeeId, startedAt: new Date().toISOString(), endedAt: null, status: 'active' })
    })
  },
  endShift(shiftId) {
    return mutate((data) => {
      const shift = data.shifts.find(s => s.id === shiftId); if (!shift) return
      shift.status = 'ended'; shift.endedAt = new Date().toISOString()
      const point = data.points.find(p => p.id === shift.pointId); if (point) point.employeeId = null
    })
  },
  updateIncident(id, status) {
    return mutate((data) => { const item = data.incidents.find(i => i.id === id); if (item) item.status = status })
  },
  addTeamMember(payload) {
    return mutate((data) => { data.team.push({ id: uid('user'), active: true, ...payload }) })
  },
  addCompany(payload) {
    return mutate((data) => { data.platform.companies.push({ id: uid('company'), points: 0, limit: 12, monthly: 390, status: 'active', plan: 'Profissional', ...payload }) })
  }
}
