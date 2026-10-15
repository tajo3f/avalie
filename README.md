# TAJO Avalia — Frontend V1 + Supabase

Versão V1 completa do **TAJO Avalia**, plataforma SaaS da TAJO Digital para avaliações de atendimento em supermercados e outros negócios.

## Modelo comercial definido

- **Implantação:** R$ 390,00
- **Mensalidade:** R$ 390,00/mês
- **Plano Profissional:** até 12 pontos de avaliação
- Avaliações ilimitadas na proposta comercial inicial
- Plaquinhas físicas / impressão são tratadas separadamente

## URLs planejadas

```text
Página pública de um ponto:
https://avalie.tajodigital.com.br/supermercado-modelo/caixa-01

Painel do supermercado:
https://avalie.tajodigital.com.br/supermercado-modelo/painel

Admin TAJO:
https://avalie.tajodigital.com.br/admin
```

## O que já existe neste pacote

### Frontend público

- Tela de avaliação em 3 etapas
- Nota de 1 a 5
- Seleção de motivos
- Comentário opcional
- Tela de sucesso
- Layout mobile-first
- Identidade do estabelecimento
- Fluxo anônimo sem exigir CPF, telefone ou cadastro

### Painel do supermercado

- Login demonstrativo
- Dashboard de indicadores
- Avaliações e detalhes
- Pontos de avaliação
- Funcionários
- Turnos
- Troca de funcionário mantendo o mesmo ponto/QR
- Ocorrências
- Ranking
- Relatórios
- Central de QR Codes / links
- Equipe e acessos
- Configurações e plano
- Pesquisa global
- Notificações
- Responsividade para celular, tablet e computador

### Painel TAJO

- Dashboard da plataforma
- Clientes
- Criação de cliente
- Planos
- MRR demonstrativo
- Pontos contratados/utilizados
- Status comercial
- Configurações gerais

### Modo demonstração

O projeto abre inicialmente com:

```js
useMocks: true
```

em `src/config.js`.

Nesse modo, o frontend funciona usando `localStorage`. As ações abaixo realmente alteram os dados locais:

- enviar avaliação;
- criar ponto;
- cadastrar funcionário;
- iniciar turno;
- encerrar turno;
- trocar funcionário;
- alterar ocorrência;
- adicionar usuário;
- criar cliente pelo Admin TAJO.

Para restaurar os dados de demonstração, abra o console do navegador e execute:

```js
TAJO_AVALIA.resetDemo()
```

## Credenciais de demonstração

### Supermercado

```text
E-mail: gerente@demo.com
Senha: 123456
```

ou:

```text
E-mail: proprietario@demo.com
Senha: 123456
```

### Admin TAJO

```text
E-mail: admin@tajo.com
Senha: 123456
```

> Essas credenciais só são aceitas no modo `useMocks: true`. Não existem no Supabase.

---

# Executar o frontend

A estrutura foi feita como SPA leve usando módulos JavaScript e CSS, com Vite apenas como servidor/build. Não depende de React ou Next.js.

## Requisitos

- Node.js moderno
- npm

## Instalação

```bash
npm install
npm run dev
```

Acesse normalmente:

```text
http://localhost:5173/supermercado-modelo/caixa-01
```

Para o painel:

```text
http://localhost:5173/supermercado-modelo/painel/login
```

Admin:

```text
http://localhost:5173/admin/login
```

## Build

```bash
npm run build
```

Arquivos finais serão gerados em:

```text
dist/
```

---

# Deploy na Vercel

O arquivo `vercel.json` já está incluso para fazer rewrite das rotas da SPA para `index.html`.

Fluxo recomendado:

1. Subir este projeto para um repositório GitHub.
2. Criar projeto na Vercel.
3. Framework preset: **Vite**.
4. Build command: `npm run build`.
5. Output directory: `dist`.
6. Fazer o primeiro deploy.
7. Configurar o domínio `avalie.tajodigital.com.br` na Vercel.
8. Criar o registro DNS solicitado pela Vercel no provedor do domínio.

O frontend foi pensado para evitar a dependência de Next.js e server rendering nesta fase.

---

# Estrutura do projeto

```text
TAJO-Avalia-V1-Full/
├── index.html
├── package.json
├── vercel.json
├── README.md
├── PLANO_IMPLEMENTACAO.md
├── docs/
│   └── ROTAS_E_PERMISSOES.md
├── public/
│   └── logo.svg
├── src/
│   ├── app.js
│   ├── config.js
│   ├── styles.css
│   ├── data/
│   │   └── mock.js
│   ├── lib/
│   │   ├── store.js
│   │   └── utils.js
│   ├── services/
│   │   ├── api.js
│   │   └── supabase.js
│   └── ui/
│       └── components.js
└── supabase/
    ├── config.toml
    └── migrations/
        ├── 202610150001_core_schema.sql
        ├── 202610150002_rls_security.sql
        ├── 202610150003_public_rpc_reporting.sql
        └── 202610150004_seed_demo.sql
```

---

# Supabase

A pasta `supabase/migrations` já contém uma arquitetura inicial completa.

## Principais tabelas

- `companies`
- `stores`
- `profiles`
- `platform_admins`
- `company_users`
- `employees`
- `evaluation_points`
- `point_slug_aliases`
- `shifts`
- `evaluation_reasons`
- `feedbacks`
- `incidents`
- `incident_feedbacks`
- `internal_notes`
- `notifications`
- `audit_logs`
- `subscriptions`

## Segurança

A arquitetura utiliza Row Level Security (RLS).

O visitante do QR Code **não recebe SELECT direto** nas tabelas da empresa. Em vez disso, o frontend público deve usar RPCs `SECURITY DEFINER` com retorno limitado:

```text
get_public_evaluation_context
submit_feedback
```

A avaliação é associada automaticamente ao turno ativo no ponto. Dessa forma:

```text
Ponto -> Turno ativo -> Funcionário -> Avaliação
```

O QR Code não precisa mudar quando troca o funcionário.

## Anti-spam inicial

`submit_feedback` exige um `client_nonce` anônimo e guarda apenas o SHA-256 desse valor. O mesmo navegador não pode enviar outra avaliação ao mesmo ponto dentro de 2 minutos.

Isso é somente a primeira camada. Antes de escala maior, adicionar Turnstile e rate limit no edge/gateway é recomendado.

---

# Criar projeto Supabase

## 1. Instalar CLI

Use a instalação oficial do Supabase CLI apropriada ao seu ambiente.

## 2. Login

```bash
supabase login
```

## 3. Vincular o projeto

Na raiz deste projeto:

```bash
supabase link
```

Selecione o projeto correto.

## 4. Aplicar migrations

```bash
supabase db push
```

Para ambiente local:

```bash
supabase start
supabase db reset
```

## 5. Criar usuários reais

Crie os usuários pelo Supabase Auth.

Depois associe o UUID do usuário ao supermercado:

```sql
insert into public.company_users(company_id, user_id, role)
values (
  'UUID_DA_EMPRESA',
  'UUID_DO_AUTH_USER',
  'owner'
);
```

Para gerente:

```sql
insert into public.company_users(company_id, user_id, role)
values (
  'UUID_DA_EMPRESA',
  'UUID_DO_AUTH_USER',
  'manager'
);
```

Para transformar uma conta da TAJO em Admin da plataforma:

```sql
insert into public.platform_admins(user_id)
values ('UUID_DO_AUTH_USER');
```

---

# Conectar frontend ao Supabase

Edite `src/config.js`:

```js
export const APP_CONFIG = {
  useMocks: false,
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabaseAnonKey: 'SUA_PUBLISHABLE_ANON_KEY',
  // ...
}
```

A chave pública/publishable pode existir no navegador; **a proteção real é feita pelo RLS**. Nunca coloque `service_role` no frontend.

A camada `src/services/supabase.js` implementa autenticação e acesso RPC/REST sem exigir SDK no frontend.

## O que ainda precisa ser conectado

O modo real já possui a fundação, mas a V1 entregue prioriza frontend + schema. O próximo ciclo deverá substituir, página por página, os dados `localStorage` pelas consultas reais:

1. login real;
2. contexto público do ponto;
3. envio de avaliação;
4. dashboard;
5. avaliações;
6. pontos;
7. funcionários;
8. turnos;
9. ocorrências;
10. equipe;
11. Admin TAJO.

As funções RPC principais já estão nas migrations.

---

# Regra importante de QR Code

A URL pública deve ser amigável:

```text
/supermercado-modelo/caixa-01
```

O banco também mantém `public_code` e a tabela `point_slug_aliases`.

Se no futuro `caixa-01` virar `caixa-preferencial`, podemos manter o slug antigo como alias para que uma plaquinha já impressa não pare de funcionar.

---

# O que propositalmente ficou fora da V1

- cobrança automática;
- integração WhatsApp;
- IA para análise de comentários;
- aplicativo Android/iOS;
- integração com ERP/PDV;
- reconhecimento facial;
- cliente final com conta;
- multi-filial avançado;
- geração final de QR em PNG/SVG no backend;
- sistema de recompensas/pontos para consumidores.

Isso evita transformar a primeira versão em um projeto grande demais antes de validar o produto comercialmente.

---

# LGPD e privacidade

Para a V1:

- não pedir CPF;
- não pedir telefone;
- não pedir nome do cliente;
- comentário deve ser opcional;
- não guardar IP bruto nas tabelas;
- não usar ranking para punição automática;
- definir política de retenção antes de produção;
- criar Termos e Política de Privacidade antes do lançamento comercial.

Este projeto é uma base técnica; revisão jurídica adequada deve ser feita antes de uso comercial em escala.

---

# Próximos passos

Leia `PLANO_IMPLEMENTACAO.md`. Ele contém a ordem recomendada para transformar este frontend demonstrativo no produto conectado e pronto para clientes reais.
