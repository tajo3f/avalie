# QA Report — TAJO Avalie SaaS V2

Validações executadas antes do empacotamento:

- sintaxe de todos os módulos JavaScript com `node --check`;
- imports locais verificados e existentes;
- `vercel.json` validado como JSON;
- rotas estáticas e assets respondendo via servidor HTTP local;
- 7 migrations presentes na ordem esperada;
- `INSTALL_ALL.sql` reconstruído a partir das migrations finais;
- RPCs V2 verificadas no instalador (`admin_create_company_v2`, `admin_companies`, `set_feedback_status`, `set_incident_status`);
- busca por service-role secreta embutida: nenhuma chave encontrada;
- logo original, logo otimizada e favicon presentes.

Limite do ambiente de QA: o navegador headless desta sessão bloqueou navegação para hosts locais por política administrativa. Por isso a validação visual automatizada completa não foi possível aqui; a aplicação foi validada estruturalmente e por servidor HTTP/checagem de assets e módulos.
