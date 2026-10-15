# TAJO Avalia — Plano de Implementação

Este documento define a ordem recomendada para sair da V1 demonstrativa e chegar à primeira versão comercial.

## Objetivo da primeira versão comercial

Entregar um SaaS onde:

1. A TAJO cria um supermercado.
2. O proprietário recebe acesso.
3. O supermercado cria até 12 pontos.
4. Cada ponto possui URL/QR permanente.
5. O gerente cadastra funcionários.
6. O gerente associa funcionário ao ponto por turno.
7. O cliente avalia sem login.
8. A avaliação chega imediatamente ao painel.
9. Avaliações críticas geram ocorrência.
10. O proprietário acompanha indicadores, ranking e relatórios.

---

# FASE 1 — Infraestrutura

## Supabase

- Criar projeto de produção.
- Não reutilizar banco de outro SaaS da TAJO.
- Aplicar migrations pelo CLI.
- Verificar RLS tabela por tabela.
- Criar usuário Admin TAJO.
- Adicionar o UUID em `platform_admins`.
- Testar RPCs públicos sem sessão.
- Testar que usuário de Empresa A não acessa Empresa B.

### Testes obrigatórios de segurança

- `anon` não consegue listar `feedbacks`.
- `anon` não consegue listar `employees`.
- `anon` só consegue receber contexto público pela RPC.
- `manager` só vê empresa associada.
- `owner` só vê empresa associada.
- Admin TAJO consegue administrar tenants.
- `service_role` nunca aparece no frontend.

---

# FASE 2 — Autenticação real

Substituir o login mock pela autenticação Supabase.

## Proprietário

Pode:

- ver tudo da própria empresa;
- gerenciar equipe;
- configurar empresa;
- visualizar relatórios;
- gerenciar pontos e funcionários.

## Gerente

Pode:

- ver dashboard;
- ver avaliações;
- gerenciar funcionários;
- gerenciar pontos;
- gerenciar turnos;
- tratar ocorrências;
- ver ranking e relatórios operacionais.

Avaliar depois se configurações comerciais ficam exclusivas do proprietário.

---

# FASE 3 — Fluxo público real

Usar:

```text
get_public_evaluation_context
```

para carregar:

- nome do supermercado;
- logo;
- cor;
- ponto;
- motivos ativos.

No envio:

```text
submit_feedback
```

A função deve determinar internamente:

- empresa;
- ponto;
- turno;
- funcionário;
- rating;
- motivos;
- comentário;
- ocorrência automática quando necessário.

O navegador nunca deve enviar `employee_id` como fonte de verdade.

---

# FASE 4 — Dashboard real

Conectar:

```text
dashboard_summary
```

Adicionar RPCs para:

- série histórica de nota;
- distribuição por nota;
- motivos mais mencionados;
- desempenho por ponto;
- horário crítico;
- comparação período anterior.

Não fazer agregações pesadas no navegador quando o volume crescer.

---

# FASE 5 — Pontos

## Regras

- plano Profissional: 12 pontos;
- limite deve ser validado no banco;
- slug único por empresa;
- não reutilizar slug removido sem cuidado;
- manter aliases para QR já impresso;
- preferir desativar a apagar pontos com histórico.

## Tipos iniciais

- Caixa
- Açougue
- Padaria
- Hortifruti
- Atendimento
- Delivery
- Outro

---

# FASE 6 — Funcionários e turnos

Um QR pertence ao ponto, não ao funcionário.

Exemplo:

```text
/mercado-x/caixa-04
```

O gerente inicia:

```text
Caixa 04 -> Maria -> 07:00
```

Na troca:

```text
Turno Maria encerrado
Turno Carlos iniciado
QR permanece igual
```

O banco impede dois turnos ativos simultâneos no mesmo ponto e também evita que o mesmo funcionário esteja em dois pontos ao mesmo tempo.

---

# FASE 7 — Ocorrências

## V1

Criar ocorrência automática quando:

- avaliação = 1 estrela;
- 3 ou mais avaliações <= 2 no mesmo ponto em 1 hora.

## Depois

Adicionar regras configuráveis:

- média abaixo de X;
- alta de reclamação de fila;
- ponto sem avaliações;
- funcionário com tendência negativa;
- avaliação com palavras críticas.

Evitar decisões disciplinares automáticas.

---

# FASE 8 — QR Code final

A tela V1 contém uma prévia visual.

Para produção, implementar geração real de:

- PNG;
- SVG;
- lote ZIP;
- versão pronta para impressão.

O conteúdo do QR deve ser somente a URL permanente.

Exemplo:

```text
https://avalie.tajodigital.com.br/mercado-x/caixa-01
```

Nunca colocar informações do funcionário dentro do QR.

---

# FASE 9 — Admin TAJO

O Admin TAJO precisa conseguir:

- criar empresa;
- definir slug;
- definir limite;
- definir mensalidade;
- visualizar status;
- suspender painel;
- alterar plano;
- visualizar uso;
- adicionar proprietário inicial;
- acompanhar MRR;
- registrar vencimento.

A cobrança automática não é necessária para o primeiro cliente.

---

# FASE 10 — Deploy

## Vercel

Domínio:

```text
avalie.tajodigital.com.br
```

Checklist:

- build concluído;
- rotas SPA funcionando diretamente por URL;
- favicon;
- title/description;
- HTTPS ativo;
- domínio validado;
- Supabase configurado;
- CORS/origens revisadas;
- nenhum segredo privado no bundle.

---

# FASE 11 — Primeiro cliente piloto

Antes de vender em escala:

- cadastrar um estabelecimento piloto;
- criar 2–4 pontos primeiro;
- testar 50+ avaliações;
- simular troca de funcionário;
- simular avaliação crítica;
- validar fluxo de gerente;
- validar experiência do QR em Android e iPhone;
- observar se cliente entende a escala de avaliação;
- testar velocidade usando 4G.

Depois expandir para os 12 pontos.

---

# FASE 12 — Comercial

Oferta inicial:

```text
TAJO Avalia — Plano Profissional
Implantação: R$ 390,00
Mensalidade: R$ 390,00
Até 12 pontos de avaliação
```

A comunicação deve vender resultado:

- identificar problemas antes de perder cliente;
- entender horários críticos;
- reconhecer bons atendimentos;
- acompanhar reclamações;
- transformar opinião em decisão.

Não vender como “um QR Code de avaliação”.

---

# Backlog pós-V1

Prioridade alta:

- notificações em tempo real;
- QR real PNG/SVG;
- exportação PDF;
- exportação XLSX;
- múltiplas unidades;
- histórico de auditoria visível;
- política de retenção;
- recuperação de senha;
- convite de usuários.

Prioridade média:

- WhatsApp para alertas;
- relatório agendado;
- comparação entre lojas;
- meta de satisfação;
- NPS separado;
- categorias por setor.

Futuro:

- IA para resumir comentários;
- detecção de temas;
- previsão de risco de queda de satisfação;
- integrações com ERP/PDV.
