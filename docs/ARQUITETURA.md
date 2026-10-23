# Arquitetura — TAJO Avalie V2

## Multiempresa

Cada registro operacional carrega `company_id`. O usuário acessa apenas empresas presentes em `company_users`.

```text
TAJO DIGITAL
  └─ Empresa
      ├─ Loja
      ├─ Pontos de avaliação
      ├─ Funcionários
      ├─ Turnos
      ├─ Avaliações
      ├─ Ocorrências
      ├─ Equipe
      └─ Assinatura / Faturas
```

## Perfis

### Platform Admin
Equipe TAJO. Acesso à visão SaaS e funções administrativas.

### Owner
Proprietário do cliente. Pode administrar a empresa e convidar usuários.

### Manager
Gerente. Foco na operação diária.

## QR permanente

O QR aponta para o ponto, não para o funcionário.

```text
/mercado/caixa-04
```

O funcionário é identificado pelo turno ativo. Ao trocar operador, o QR não muda.

O banco mantém aliases de slugs antigos para evitar que uma plaquinha impressa fique inutilizada após renomear um ponto.

## Camadas de segurança

1. Supabase Auth
2. RLS
3. Funções auxiliares no schema `private`
4. RPCs públicas com validação
5. Edge Function com service role somente no servidor
6. Audit logs
7. Rate limit lógico para feedback público

## Recorrência

`subscriptions` guarda o contrato atual.

`billing_invoices` registra competências e vencimentos sem amarrar o produto a um gateway específico.

Isso permite começar com cobrança manual/Pix e integrar um gateway futuramente sem refazer o banco.
