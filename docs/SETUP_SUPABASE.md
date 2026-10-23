# Configuração do Supabase — TAJO Avalie V2

## 1. Criar projeto

Crie um projeto novo no Supabase. Guarde:

- Project URL
- anon / publishable key

**Nunca exponha a service_role no frontend.**

## 2. Instalar banco

Opção rápida:

1. Supabase > SQL Editor
2. New query
3. Cole todo o `INSTALL_ALL.sql`
4. Execute

Opção com CLI:

```bash
supabase link --project-ref SEU_PROJECT_REF
supabase db push --dry-run
supabase db push
```

## 3. Criar Admin TAJO

No Dashboard:

Authentication > Users > Add user

Crie seu usuário administrativo.

Depois abra `scripts/BOOTSTRAP_TAJO_ADMIN.sql`, troque o e-mail e execute.

## 4. Deploy da função de convite

Com Supabase CLI:

```bash
supabase functions deploy invite-user
```

A função usa automaticamente as variáveis de ambiente fornecidas pelo Supabase, incluindo `SUPABASE_SERVICE_ROLE_KEY`. Ela nunca envia essa chave ao navegador.

## 5. Configurar URL de autenticação

Authentication > URL Configuration

Site URL:

```text
https://avalie.tajodigital.com.br
```

Redirect URLs sugeridas:

```text
https://avalie.tajodigital.com.br/**
http://localhost:*/**
```

## 6. Configurar frontend

Edite `src/config.js`:

```js
supabaseUrl: 'https://xxxx.supabase.co',
supabaseAnonKey: 'eyJ...',
demoMode: false
```

A anon key pode estar no frontend. O que não pode estar no frontend é a `service_role`.

## 7. Criar primeiro cliente

Acesse:

```text
/admin/login
```

Crie a empresa. O banco cria:

- empresa;
- loja principal;
- assinatura;
- contato principal;
- vencimento inicial.

Depois, vincule ou convide o proprietário.

## 8. URL do cliente

Exemplo:

```text
/mercado-central/painel/login
```

Pontos:

```text
/mercado-central/caixa-01
/mercado-central/caixa-02
/mercado-central/acougue
```

## 9. Como a avaliação é salva

O visitante não recebe acesso direto à tabela `feedbacks`.

Fluxo:

```text
QR -> página pública -> RPC submit_feedback -> valida empresa/ponto
-> aplica anti-spam -> encontra turno ativo -> salva avaliação
-> cria ocorrência automática quando necessário
```

## 10. Teste pós-instalação

Execute:

```text
supabase/tests/verify_install_v2.sql
```

Depois teste manualmente:

1. login Admin;
2. criação de empresa;
3. acesso do proprietário;
4. criação de ponto;
5. criação de funcionário;
6. início de turno;
7. avaliação pública;
8. avaliação aparecendo no painel;
9. nota 1 gerando ocorrência;
10. encerramento do turno.
