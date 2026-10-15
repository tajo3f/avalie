# Rotas e permissões — TAJO Avalia V1

## Público

| Rota | Login | Função |
|---|---:|---|
| `/:empresa/:ponto` | Não | Enviar avaliação |

## Supermercado

Base: `/:empresa/painel`

| Rota | Proprietário | Gerente |
|---|---:|---:|
| `/painel` | Sim | Sim |
| `/painel/evaluations` | Sim | Sim |
| `/painel/points` | Sim | Sim |
| `/painel/employees` | Sim | Sim |
| `/painel/shifts` | Sim | Sim |
| `/painel/incidents` | Sim | Sim |
| `/painel/ranking` | Sim | Sim |
| `/painel/reports` | Sim | Sim |
| `/painel/qrcodes` | Sim | Sim |
| `/painel/team` | Sim | Futuramente configurável |
| `/painel/settings` | Sim | Parcial no backend real |

## TAJO

| Rota | Admin TAJO |
|---|---:|
| `/admin` | Sim |
| `/admin/clientes` | Sim |
| `/admin/planos` | Sim |
| `/admin/configuracoes` | Sim |

## Observação de segurança

Rotas visíveis no frontend não são autorização. A autorização real deve ser feita no Supabase por RLS e RPCs.
