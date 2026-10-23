export const APP_CONFIG = {
  productName: 'TAJO Avalie',
  productTagline: 'Sistema de Avaliação de Serviços',
  companyName: 'TAJO Digital',
  baseDomain: 'avalie.tajodigital.com.br',
  supportEmail: 'joaopaulo@tajodigital.com.br',

  // PREENCHA para usar o Supabase real. A anon key pode ficar no frontend;
  // a segurança é garantida pelas políticas RLS e RPCs do banco.
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabaseAnonKey: 'SUA_CHAVE_ANON_PUBLICA',

  // true = demonstração comercial sem banco. false = Supabase real.
  // Se URL/chave estiverem com placeholder, o sistema entra em demo automaticamente.
  demoMode: true,

  defaultTenantSlug: 'mercado-modelo',
  defaultPointSlug: 'caixa-01',
  setupPrice: 390,
  monthlyPrice: 390,
  pointLimit: 12,
  logoPath: '/public/tajo-avalie-logo-web.png'
}

export function isDemoMode() {
  return APP_CONFIG.demoMode ||
    !APP_CONFIG.supabaseUrl.startsWith('https://') ||
    APP_CONFIG.supabaseUrl.includes('SEU-PROJETO') ||
    APP_CONFIG.supabaseAnonKey.includes('SUA_CHAVE')
}
