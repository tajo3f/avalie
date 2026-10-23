# TAJO AVALIE — SaaS V2

Sistema multiempresa de avaliação de atendimento e experiência do cliente, pensado inicialmente para supermercados e preparado para outros segmentos.

## Oferta comercial base

- Implantação sugerida: **R$ 390,00**
- Mensalidade sugerida: **R$ 390,00/mês**
- Plano Profissional: **até 12 pontos de avaliação**
- Avaliações ilimitadas
- QR Code / link permanente por ponto
- Dashboard para gerente/proprietário
- Admin TAJO multiempresa

## O que existe nesta versão

### Experiência pública
- URL por empresa e ponto: `/{empresa}/{ponto}`
- Nota de 1 a 5
- Motivos múltiplos
- Comentário opcional
- Envio anônimo
- Anti-spam por nonce anônimo
- Avaliação automaticamente vinculada ao turno ativo
- Avaliação 1 estrela gera ocorrência crítica
- Cluster de avaliações negativas gera ocorrência automática

### Painel do estabelecimento
- Login real via Supabase Auth
- Visão geral e KPIs
- Avaliações e tratamento de status
- Pontos/caixas/setores
- Funcionários
- Turnos
- Ocorrências
- Ranking
- Relatórios
- QR Codes e links permanentes
- Equipe e acessos
- Configurações da experiência
- Visualização do plano e vencimento

### Admin TAJO
- Login separado
- Visão consolidada da base
- Clientes ativos
- MRR
- Pontos ativos
- Pendências
- Cadastro de novo cliente
- Estrutura para recorrência e faturas

## Stack

- Frontend: HTML + CSS + JavaScript ES Modules
- Backend: Supabase
- Banco: PostgreSQL
- Auth: Supabase Auth
- Segurança: RLS + RPCs controladas + schema privado
- Edge Function: convite de usuário
- Hosting recomendado: Vercel

O frontend não depende de React, Next ou npm para funcionar. Isso reduz risco de build e deixa o deploy simples.

## Rodando em modo demonstração

O projeto vem com `demoMode: true` em `src/config.js`.

Abra por um servidor HTTP local ou publique na Vercel. Credenciais:

### Painel do supermercado
- `proprietario@demo.com`
- `gerente@demo.com`
- senha `123456`

### Admin TAJO
- `admin@tajo.com`
- senha `123456`

Exemplos:

- `/mercado-modelo/caixa-01`
- `/mercado-modelo/painel/login`
- `/admin/login`

## Ativando Supabase real

1. Crie um projeto Supabase vazio.
2. Rode `INSTALL_ALL.sql` no SQL Editor, ou use as migrations em `supabase/migrations/`.
3. Crie o primeiro usuário Admin em Authentication > Users.
4. Execute `scripts/BOOTSTRAP_TAJO_ADMIN.sql` com o e-mail correto.
5. Faça deploy da Edge Function `invite-user`.
6. Edite `src/config.js`:

```js
supabaseUrl: 'https://SEU-PROJETO.supabase.co',
supabaseAnonKey: 'SUA_ANON_KEY',
demoMode: false
```

7. Entre em `/admin/login` e crie o primeiro cliente.
8. Convide/vincule o proprietário.

Leia `docs/SETUP_SUPABASE.md` para o passo a passo completo.

## Segurança importante

Nunca coloque a `service_role` no frontend. A chave `anon` é pública por natureza e só é segura porque as tabelas expostas estão protegidas por RLS. A `service_role` é usada somente na Edge Function do Supabase.

## Estrutura

```text
TAJO-Avalie-SaaS-V2/
├── index.html
├── vercel.json
├── public/
├── src/
│   ├── config.js
│   ├── main.js
│   ├── styles.css
│   └── lib/
├── supabase/
│   ├── migrations/
│   ├── functions/
│   ├── tests/
│   └── seed.sql
├── scripts/
├── docs/
└── INSTALL_ALL.sql
```

## Observação sobre QR Code

A interface utiliza QuickChart apenas para renderizar a imagem visual do QR a partir do link público. O link permanente continua sendo controlado pelo TAJO Avalie. Se desejar independência total de terceiro, substitua a renderização por uma Edge Function própria com biblioteca QR.

## Próximas evoluções recomendadas

- cobrança automática via gateway;
- WhatsApp/e-mail para alertas críticos;
- multi-loja avançado por rede;
- relatórios PDF com identidade do supermercado;
- metas de satisfação por unidade;
- webhook para alertas externos;
- API para ERP/PDV;
- domínio personalizado para redes maiores.
