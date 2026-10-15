export const APP_CONFIG = {
  // true = frontend funciona completo com dados locais demonstrativos.
  // false = usa os endpoints do Supabase configurados abaixo.
  useMocks: true,
  supabaseUrl: '',
  supabaseAnonKey: '',
  defaultTenantSlug: 'supermercado-modelo',
  appName: 'TAJO Avalia',
  supportEmail: 'joaopaulo@tajodigital.com.br',
  plan: {
    name: 'Profissional',
    monthlyPrice: 390,
    setupPrice: 390,
    pointLimit: 12
  }
}
