const now = Date.now()
const iso = (offsetMinutes = 0) => new Date(now - offsetMinutes * 60000).toISOString()

export const demoData = {
  company: {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Supermercado Modelo',
    slug: 'supermercado-modelo',
    primaryColor: '#16a34a',
    logoText: 'SM',
    plan: 'Profissional',
    monthlyPrice: 390,
    setupPrice: 390,
    pointLimit: 12,
    status: 'active',
    billingDay: 15,
    usedPoints: 8
  },
  currentUser: {
    id: 'u-owner-01',
    name: 'Marcos Andrade',
    email: 'proprietario@demo.com',
    role: 'owner'
  },
  points: [
    { id: 'p01', name: 'Caixa 01', slug: 'caixa-01', type: 'Caixa', active: true, score: 4.9, reviews: 47, employeeId: 'e01' },
    { id: 'p02', name: 'Caixa 02', slug: 'caixa-02', type: 'Caixa', active: true, score: 4.7, reviews: 39, employeeId: 'e02' },
    { id: 'p03', name: 'Caixa 03', slug: 'caixa-03', type: 'Caixa', active: true, score: 4.5, reviews: 28, employeeId: 'e03' },
    { id: 'p04', name: 'Caixa 04', slug: 'caixa-04', type: 'Caixa', active: true, score: 3.2, reviews: 19, employeeId: 'e04' },
    { id: 'p05', name: 'Caixa 05', slug: 'caixa-05', type: 'Caixa', active: true, score: 4.8, reviews: 34, employeeId: 'e05' },
    { id: 'p06', name: 'Caixa Preferencial', slug: 'caixa-preferencial', type: 'Caixa', active: true, score: 4.6, reviews: 31, employeeId: 'e06' },
    { id: 'p07', name: 'Açougue', slug: 'acougue', type: 'Açougue', active: true, score: 4.7, reviews: 52, employeeId: null },
    { id: 'p08', name: 'Padaria', slug: 'padaria', type: 'Padaria', active: true, score: 4.8, reviews: 45, employeeId: null }
  ],
  employees: [
    { id: 'e01', name: 'Ana Souza', code: '001', role: 'Operadora de caixa', active: true, score: 4.94, reviews: 328 },
    { id: 'e02', name: 'Maria Lima', code: '002', role: 'Operadora de caixa', active: true, score: 4.89, reviews: 287 },
    { id: 'e03', name: 'João Reis', code: '003', role: 'Operador de caixa', active: true, score: 4.82, reviews: 302 },
    { id: 'e04', name: 'Carlos Silva', code: '004', role: 'Operador de caixa', active: true, score: 3.58, reviews: 141 },
    { id: 'e05', name: 'Juliana Martins', code: '005', role: 'Operadora de caixa', active: true, score: 4.77, reviews: 266 },
    { id: 'e06', name: 'Rafael Costa', code: '006', role: 'Operador de caixa', active: true, score: 4.68, reviews: 219 },
    { id: 'e07', name: 'Bruna Alves', code: '007', role: 'Operadora de caixa', active: true, score: 4.55, reviews: 198 },
    { id: 'e08', name: 'Paulo Mendes', code: '008', role: 'Operador de caixa', active: false, score: 4.31, reviews: 87 }
  ],
  shifts: [
    { id: 's01', pointId: 'p01', employeeId: 'e01', startedAt: iso(260), endedAt: null, status: 'active' },
    { id: 's02', pointId: 'p02', employeeId: 'e02', startedAt: iso(240), endedAt: null, status: 'active' },
    { id: 's03', pointId: 'p03', employeeId: 'e03', startedAt: iso(225), endedAt: null, status: 'active' },
    { id: 's04', pointId: 'p04', employeeId: 'e04', startedAt: iso(210), endedAt: null, status: 'active' },
    { id: 's05', pointId: 'p05', employeeId: 'e05', startedAt: iso(190), endedAt: null, status: 'active' },
    { id: 's06', pointId: 'p06', employeeId: 'e06', startedAt: iso(165), endedAt: null, status: 'active' }
  ],
  evaluations: [
    { id: 'AV-1848', pointId: 'p01', employeeId: 'e01', rating: 5, reasons: ['Educação', 'Agilidade'], comment: 'Atendimento excelente e muito rápido.', status: 'resolved', createdAt: iso(12) },
    { id: 'AV-1847', pointId: 'p04', employeeId: 'e04', rating: 1, reasons: ['Atendimento', 'Educação'], comment: 'O atendente respondeu de forma grosseira.', status: 'new', createdAt: iso(18) },
    { id: 'AV-1846', pointId: 'p04', employeeId: 'e04', rating: 2, reasons: ['Tempo de espera'], comment: 'A fila demorou bastante.', status: 'new', createdAt: iso(27) },
    { id: 'AV-1845', pointId: 'p02', employeeId: 'e02', rating: 5, reasons: ['Atendimento'], comment: 'Muito atenciosa.', status: 'resolved', createdAt: iso(39) },
    { id: 'AV-1844', pointId: 'p03', employeeId: 'e03', rating: 4, reasons: ['Agilidade'], comment: '', status: 'resolved', createdAt: iso(53) },
    { id: 'AV-1843', pointId: 'p04', employeeId: 'e04', rating: 2, reasons: ['Tempo de espera', 'Agilidade'], comment: 'Demorou para finalizar a compra.', status: 'analyzing', createdAt: iso(66) },
    { id: 'AV-1842', pointId: 'p05', employeeId: 'e05', rating: 5, reasons: ['Educação', 'Atendimento'], comment: 'Parabéns pelo atendimento.', status: 'resolved', createdAt: iso(88) },
    { id: 'AV-1841', pointId: 'p06', employeeId: 'e06', rating: 4, reasons: ['Organização'], comment: '', status: 'resolved', createdAt: iso(110) },
    { id: 'AV-1840', pointId: 'p07', employeeId: null, rating: 5, reasons: ['Atendimento', 'Agilidade'], comment: 'Açougue muito organizado.', status: 'resolved', createdAt: iso(135) },
    { id: 'AV-1839', pointId: 'p08', employeeId: null, rating: 5, reasons: ['Organização'], comment: 'Produtos muito bons.', status: 'resolved', createdAt: iso(160) }
  ],
  incidents: [
    { id: 'OC-027', severity: 'critical', pointId: 'p04', employeeId: 'e04', title: '3 avaliações negativas em curto período', description: 'Foram detectadas 3 avaliações negativas relacionadas ao Caixa 04.', status: 'new', createdAt: iso(15), feedbackIds: ['AV-1847','AV-1846','AV-1843'], assignee: 'Gerência' },
    { id: 'OC-026', severity: 'warning', pointId: null, employeeId: null, title: 'Tempo de espera aumentou 28%', description: 'O motivo “Tempo de espera” apresentou alta no período atual.', status: 'analyzing', createdAt: iso(72), feedbackIds: ['AV-1846','AV-1843'], assignee: 'Marcos Andrade' },
    { id: 'OC-025', severity: 'info', pointId: 'p06', employeeId: 'e06', title: 'Queda de volume de avaliações', description: 'O ponto recebeu menos avaliações que a média recente.', status: 'resolved', createdAt: iso(1440), feedbackIds: [], assignee: 'Gerência' }
  ],
  team: [
    { id: 'u-owner-01', name: 'Marcos Andrade', email: 'proprietario@demo.com', role: 'Proprietário', active: true },
    { id: 'u-manager-01', name: 'Fernanda Rocha', email: 'gerente@demo.com', role: 'Gerente', active: true }
  ],
  notifications: [
    { id: 'n1', title: 'Avaliação crítica recebida', detail: 'Caixa 04 • Nota 1', createdAt: iso(18), read: false },
    { id: 'n2', title: 'Alerta operacional', detail: 'Tempo de espera aumentou', createdAt: iso(72), read: false },
    { id: 'n3', title: 'Destaque de atendimento', detail: 'Ana atingiu média 4,94', createdAt: iso(180), read: false }
  ],
  history: [4.55, 4.62, 4.48, 4.71, 4.74, 4.69, 4.72],
  hourly: [
    { label: '07–09h', value: 4.8 }, { label: '09–11h', value: 4.7 }, { label: '11–13h', value: 4.4 },
    { label: '13–15h', value: 4.6 }, { label: '15–17h', value: 4.5 }, { label: '17–19h', value: 3.9 }
  ],
  reasons: [
    { label: 'Atendimento', value: 124, trend: 8 }, { label: 'Agilidade', value: 96, trend: 3 },
    { label: 'Educação', value: 82, trend: 5 }, { label: 'Tempo de espera', value: 41, trend: 21 },
    { label: 'Organização', value: 28, trend: -4 }
  ],
  platform: {
    mrr: 1170,
    companies: [
      { id: 'c1', name: 'Supermercado Modelo', slug: 'supermercado-modelo', plan: 'Profissional', points: 8, limit: 12, monthly: 390, status: 'active', responsible: 'Marcos Andrade', email: 'proprietario@demo.com' },
      { id: 'c2', name: 'Mercado Primavera', slug: 'mercado-primavera', plan: 'Profissional', points: 12, limit: 12, monthly: 390, status: 'active', responsible: 'Luciana Santos', email: 'luciana@demo.com' },
      { id: 'c3', name: 'Supermercado Avenida', slug: 'supermercado-avenida', plan: 'Profissional', points: 6, limit: 12, monthly: 390, status: 'pending', responsible: 'André Lopes', email: 'andre@demo.com' }
    ]
  }
}
