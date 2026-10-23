# Migrando do banco V1 para a V2

Se você **já executou as migrations 001 a 006** entregues anteriormente, não rode o `INSTALL_ALL.sql` por cima do banco em produção.

Aplique somente:

```text
supabase/migrations/202610230007_saas_v2.sql
```

Depois publique a Edge Function:

```bash
supabase functions deploy invite-user
```

E execute:

```text
supabase/tests/verify_install_v2.sql
```

A migration V2 adiciona:

- contatos comerciais da empresa;
- faturas/competências;
- Admin TAJO consolidado;
- criação V2 de cliente;
- atualização segura de status de avaliação;
- atualização segura de ocorrências;
- funções administrativas de recorrência.

Nenhuma tabela operacional da V1 é apagada.
