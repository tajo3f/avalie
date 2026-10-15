# Checklist de testes V1

## Público

- [ ] URL de ponto válido abre avaliação.
- [ ] URL inválida não expõe dados internos.
- [ ] Nota 1–5 funciona.
- [ ] Múltiplos motivos funcionam.
- [ ] Comentário é opcional.
- [ ] Comentário respeita 500 caracteres.
- [ ] Avaliação negativa cria ocorrência.
- [ ] Duplo envio rápido é limitado no modo real.

## Painel

- [ ] Login gerente.
- [ ] Login proprietário.
- [ ] Dashboard mobile.
- [ ] Criar ponto respeita limite 12.
- [ ] Criar funcionário.
- [ ] Iniciar turno.
- [ ] Trocar funcionário.
- [ ] Encerrar turno.
- [ ] Avaliação associa turno ativo.
- [ ] Resolver ocorrência.
- [ ] Exportar CSV.

## Segurança

- [ ] Empresa A não lê Empresa B.
- [ ] anon não faz SELECT direto em feedbacks.
- [ ] anon não faz SELECT direto em employees.
- [ ] service_role não existe no frontend.
- [ ] manager não vira admin alterando payload.
- [ ] slug inválido é rejeitado.

## Deploy

- [ ] Deep links funcionam na Vercel.
- [ ] HTTPS.
- [ ] DNS de `avalie.tajodigital.com.br`.
- [ ] Android Chrome.
- [ ] iPhone Safari.
- [ ] Tablet.
- [ ] Desktop.
