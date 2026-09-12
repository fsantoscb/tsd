# TSD ERP - DNA Operacional, Funcional e Tecnico

**Sistema:** TSD Production Control  
**Ambiente de producao:** https://tsd-production-control.vercel.app  
**Documento-base:** 12/09/2026  
**Perspectiva:** engenharia de processos, producao, dados e software

---

## 1. Proposito do ERP

O TSD Production Control e a camada de inteligencia e execucao entre o Oracle WMS/ERP, a operacao de fabrica e a gestao. Seu objetivo e transformar eventos, filas e estoques operacionais em uma unica leitura confiavel do fluxo: demanda, picking, impressao, putwall, capacidade, produtividade, planejamento, expedicao e manutencao.

O Oracle permanece como fonte autoritativa e somente leitura para os dados operacionais. O Supabase recebe snapshots e eventos, preserva historico e suporta os dados criados pelo ERP. O frontend organiza essa informacao em decisoes e rotinas de trabalho.

### Principios fundamentais

1. Oracle nunca e alterado pelo ERP.
2. O navegador nunca se conecta diretamente ao Oracle.
3. Identificadores externos sao tratados como texto.
4. Quantidade fisica, peso, garments e prints sao grandezas diferentes.
5. Dados de origem e dados criados pelo planner ficam separados.
6. Todo numero gerencial deve ter fonte, unidade, formula e periodo identificaveis.
7. Dados ausentes nao podem ser apresentados como zero real.
8. Registros nao classificados permanecem visiveis como `UNMAPPED` ou `OTHER`.
9. O nome operacional de cliente vem prioritariamente de `SHIP_TO_NAME`; a interface pode usar o label `Client`.
10. Datas e turnos seguem `Australia/Brisbane`, inclusive operacoes que cruzam meia-noite.

---

## 2. Arquitetura de alto nivel

```text
ORACLE / ISIS
  Orders + Workbank + Stock + Audit + Product
                    |
                    v
LOCAL ORACLE SYNC AGENT
  leitura somente leitura
  credencial no Windows Credential Manager
  normalizacao + validacao + compactacao gzip
                    |
                    v HTTPS autenticado
NEXT.JS INGEST API
  validacao de segredo e payload
  ingestao atomica por batch
                    |
                    v
SUPABASE / POSTGRESQL
  snapshots atuais
  auditoria append-only
  eventos canonicos
  regras e configuracoes
  planejamento e manutencao
  views e funcoes governadas
                    |
                    v
NEXT.JS ERP / VERCEL
  controle + execucao + planejamento
  KPI + capacidade + governanca
  manutencao
```

### Stack

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| Interface | Next.js 15, React 19, TypeScript | Paginas, filtros, acoes e visualizacoes |
| Hospedagem | Vercel | Build, server rendering e deploy de producao |
| Banco | Supabase/PostgreSQL | Persistencia, views, funcoes, RLS e autenticacao |
| Integracao | Node.js, OracleDB, PowerShell | Extracao local do Oracle e envio seguro |
| Contratos | Zod e pacote compartilhado | Validacao consistente entre sync e web |
| Planilhas | XLSX | Importacao Deputy e reconciliacao operacional |
| Agenda local | Windows Task Scheduler | Execucao recorrente do conector Oracle |

---

## 3. Hierarquia funcional do ERP

```text
TSD PRODUCTION CONTROL
|
+-- CONTROL
|   +-- Control Tower
|   +-- Machine Load
|   +-- ERP Performance
|   +-- Production Flow
|   +-- KPI Dashboard
|
+-- EXECUTION
|   +-- Operational Scan
|   +-- UP Workbank
|   +-- DTG Workbank
|   +-- Hold Orders
|   +-- Ready to Lift
|   +-- Close Order
|   +-- Screen Events
|
+-- PLANNING
|   +-- Planning
|   +-- Daily Plans
|   +-- Capacity
|   +-- Labour Dashboard
|   +-- Deputy Imports
|
+-- MAINTENANCE
|   +-- Maintenance Control
|   +-- Assets
|   +-- Work Orders
|
+-- GOVERNANCE
    +-- Production Stages
    +-- Source Data
    +-- Reconciliation
    +-- Sync Status
    +-- KPI Settings
```

---

## 4. DNA de cada modulo

### 4.1 Control Tower - `/`

**Papel:** sala de controle da fabrica.  
**Pergunta respondida:** onde esta o risco operacional agora?

Consolida saude da fonte, qualidade, movimentos novos, pipeline total, awaiting picking, lead projetado, ocupacao de putwall e ordens prontas para lift. Deve priorizar excecao, risco e proxima acao, nao apenas exibir contagens.

### 4.2 Machine Load - `/production/machine-load`

**Papel:** transformar demanda atual e futura em carga de maquina.  
**Escopo:** pronto para imprimir mais previsao de itens aguardando picking.

Regras centrais:

- `Queue = SP11` representa `Awaiting Picking`.
- `Queue = PCOR` representa `Ready to Print`.
- O volume e sempre `SUM(Quantity)` em garments, nunca contagem de linhas ou ordens.
- A previsao parte do dia corrente e avanca pelos dias produtivos habilitados.
- Flags de sabado e domingo alteram a semana para cinco, seis ou sete dias.
- Load versus capacity compara demanda total conhecida com capacidade disponivel.
- Five-day runway projeta a reducao diaria do pipeline completo.

#### Production Mix

O tipo e extraido do texto anterior ao primeiro ` - ` da descricao. A classificacao produtiva separa:

| Grupo | Tipos principais |
|---|---|
| Adult T-shirts | Mens T, Womens T |
| Kids T-shirts | Boys T, Girls T |
| Hoodies / Sweats | Hoody, Hoodie, Zip Hoody, Crew, Raglan, 1/4 Zip, Daybreaker e equivalentes |
| Tanks / Singlets | Mens/Womens Tank ou Singlet |
| Long-sleeve T-shirts | Mens/Womens/Boys/Girls L/S T |
| Dresses | Tipos contendo Dress |
| Totes | Tipos contendo Tote ou Bag |
| Other | Tudo que nao possuir classificacao anterior |

As barras devem ser proporcionais a garments. Ordens e SKUs aparecem apenas como contexto. Cada grupo exibe awaiting picking, ready to print, total e percentual da carga total.

### 4.3 ERP Performance - `/production/performance`

**Papel:** comparar resultado operacional, capacidade e mao de obra por periodo.  
**Dimensoes:** hora, turno, dia, semana, mes, fluxo e labour.

O motor combina eventos canonicos do Oracle com horas aceitas do Deputy. Deve manter unidades explicitas para DTG, UP e Screen Print e permitir a chave `UP / DTG / SCREEN PRINT / ALL`.

#### Produtividade UP

- Fonte de output: auditoria `UP` / `UP_Printed`.
- Streams operacionais: A, B, C e `OTHER`.
- Atribuicao atual: `SHIFT_1 -> A`, `SHIFT_2 -> B`, `SHIFT_3 -> C`.
- Resultado deve reconciliar por data e stream antes de calcular operador/turno.
- Target padrao documentado: 75 garments/hora, sujeito a regra configurada.
- Filtro de data deve limitar tanto output quanto horas e targets do mesmo periodo.

### 4.4 Production Flow - `/production/flow`

**Papel:** mostrar movimento, acumulacao e clearance.  
**Pergunta:** onde o WIP esta entrando, saindo ou parando?

Exibe ocupacao de putwall, posicoes livres, caixas, garments, turnover e movimentos Oracle entre etapas. `Missing source` deve ser tratado como falha de observabilidade, nao como operacao zerada.

### 4.5 KPI Dashboard - `/kpis`

**Papel:** camada governada de indicadores.  
**Componentes:** catalogo, metas, thresholds, resultados, tendencias, qualidade e drill-down.

Objetos principais: `kpi_definitions`, `kpi_targets`, `kpi_rate_rules`, `kpi_results`, `v_kpi_dashboard` e `v_kpi_trends`. O processamento e centralizado pelas funcoes `refresh_kpis` e `apply_kpi_target_status`.

### 4.6 Operational Scan - `/scan`

**Papel:** acesso rapido no chao de fabrica por ordem ou pack.  
**Formatos canonicos:** `TSD:ORDER:<id>` e `TSD:PACK:<id>`.

O parser remove caracteres de controle, limita tamanho e aceita somente identificadores seguros. A consulta deve levar ao contexto operacional sem permitir alteracao no Oracle.

### 4.7 UP Workbank - `/production/up`

**Papel:** fila operacional de underprint.  
**Fonte principal:** estoque atual com `LOCATION = UNDERPRINT`.

- Caixas sao packs distintos.
- Garments sao `production_units`, derivados do peso quando a regra operacional exigir.
- Ordenacao usa prioridade e idade.
- Cliente exibido usa Ship To.

### 4.8 DTG Workbank - `/production/dtg`

**Papel:** controlar ordens DTG abertas e sua idade de fluxo.  
**Fonte principal:** workbank na zona `DTGS`, enriquecido por produto e auditoria.

- Cada linha DTGS representa um garment.
- Prints por garment vem de `IS_PRODUCT.PROD_X_5`.
- Valor `1 / 2` representa dois prints.
- `First Pick` vem do primeiro evento `data audit completed` aplicavel.
- `First Print` e `Last Print` vem dos eventos de impressao.
- `Pick Days` mede do primeiro pick ate agora.
- `Print Days` mede do primeiro print ate agora.
- Ordens em impressao aparecem primeiro, ordenadas por `Last Print`.
- Ordens `Not Started` aparecem depois, ordenadas por due date.

### 4.9 Hold Orders - `/production/hold-orders`

**Papel:** identificar ordens abertas bloqueadas no workbank.  
**Regra:** `Queue = HOLD` e numero da ordem iniciado por `130`.

Saida minima: ordem, Client baseado em Ship To e To Location.

### 4.10 Ready to Lift - `/production/ready-to-lift`

**Papel:** identificar ordens DTG fisicamente prontas ou quase prontas na putwall.

Regras:

- Fonte de ready: Stock Enquiry / estoque atual.
- `ZONE = PWL1`.
- A ordem esta no campo `PRODUCT` com `#` no inicio.
- O local da putwall vem de `LOCATION`.
- Varias linhas da mesma ordem significam varios packs/localizacoes.
- Total da ordem e o somatorio de `production_units` de todas as linhas.
- `Ready to Lift`: ordem com zero garments to print.
- `On Process`: DTG iniciado e ainda nao finalizado, limitado a menos de 10 garments to print.
- Cliente exibido usa Ship To.

### 4.11 Close Order - `/production/close-order`

**Papel:** apoiar fechamento fisico com labels calculadas.  
**Saida:** ordem, Client/Ship To, screen, to-pack e codigos de fechamento derivados do produto, ordem e pack.

### 4.12 Screen Events - `/production/screen-events`

**Papel:** registrar e acompanhar eventos controlados de Screen Print.  
**Natureza:** dado criado no ERP, auditavel e separado da fonte Oracle.

### 4.13 Planning - `/production/planning`

**Papel:** enriquecer pedidos Oracle com decisoes do planner sem alterar a fonte.

Campos governados incluem data planejada, turno, prioridade efetiva, status, bloqueio, motivo, instrucao especial e notas. Mudancas passam pela funcao `apply_production_planning` e geram historico.

### 4.14 Daily Plans - `/production/plans`

**Papel:** transformar pedidos planejados em sequencia executavel.  
**Ciclo:** `draft -> published -> closed`.

O plano possui cabecalho, itens, sequencia, area, turno, unidades e historico. As funcoes de banco criam plano, adicionam/atualizam itens e controlam transicoes.

### 4.15 Capacity - `/production/capacity`

**Papel:** calcular capacidade configuravel e comparar com demanda.  
**Formula-base:** recursos x horas x taxa x eficiencia.

Suporta profiles, regras por recurso, layouts de staffing, cenarios, overrides legados, turnos que cruzam meia-noite e comparacao carga versus capacidade.

### 4.16 Labour - `/production/labour`

**Papel:** converter timesheets do Deputy em horas produtivas utilizaveis.  
**Fluxo:** upload XLSX/CSV -> validacao -> timezone -> deduplicacao -> segmentos -> mapeamento por area -> aceite.

Separar obrigatoriamente paid hours, productive hours, regular hours e overtime. Horas ausentes nao devem ser inferidas silenciosamente.

### 4.17 Maintenance - `/maintenance`

**Papel:** controlar ativos, falhas, downtime e execucao corretiva.

#### Assets - `/maintenance/assets`

Cadastro por organizacao com codigo, nome, local, criticidade, status e atividade. Estados: `operational`, `down`, `maintenance`, `standby`, `retired`.

#### Work Orders - `/maintenance/work-orders`

Fluxo: `open -> in_progress -> waiting_parts/waiting_external -> completed`, com opcao de cancelamento. Abertura pode iniciar downtime e marcar o ativo como down. Conclusao exige resolution, encerra downtime ativo e devolve o ativo a operational quando nao existir outra parada aberta.

Dados obrigatorios de rastreabilidade: solicitante, data, problema, prioridade, ativo, mudancas de status, causa raiz, resolucao, inicio e conclusao.

### 4.18 Governance

| Pagina | Papel |
|---|---|
| Production Stages | Ver areas, regras de mapeamento, conversoes e `UNMAPPED` |
| Source Data | Inspecionar orders, workbank, stock e audit sem transformacao oculta |
| Reconciliation | Comparar batches e totais de origem com as views correntes |
| Sync Status | Ver heartbeat, ultimo lote, volume, falhas e freshness |
| KPI Settings | Governar definicoes, metas e thresholds |

---

## 5. DNA dos dados

### 5.1 Fontes Oracle

| Dataset | Origem funcional | Chaves e campos essenciais | Tipo de carga |
|---|---|---|---|
| Orders | Pedidos abertos | order_no, dates, status, priority, customer, ship_to_name, site | Snapshot |
| Workbank | Trabalho em fila | order_no, zones, locations, packs, product, qty, weight, queue, task | Snapshot |
| Stock | Posicao fisica | product, pack_id, location, zone, qty, weight | Snapshot |
| Audit | Movimentos realizados | audit_id, order, user, locations, packs, product, timestamp, queue/task | Incremental append-only |
| Product | Regra do item | product code, description, `PROD_X_5` | Join na extracao |

### 5.2 Camadas de banco

#### Camada 1 - Controle de ingestao

- `organizations`
- `sync_batches`
- `sync_agent_heartbeat`

#### Camada 2 - Dados fonte

- `source_orders`
- `source_workbank_items`
- `source_stock_items`
- `source_audit_events`
- `v_latest_completed_batch`
- `v_current_orders`
- `v_current_workbank`
- `v_current_stock`

#### Camada 3 - Semantica produtiva

- `production_areas`
- `production_stage_mappings`
- `quantity_conversion_rules`
- `production_events`
- `v_order_stage_summary`
- `v_up_operational_orders`
- `v_dtg_operational_orders`
- `v_dtg_order_history`
- `v_up_operator_daily_productivity`

#### Camada 4 - Planejamento e capacidade

- `production_orders`
- `production_order_history`
- `production_plans`
- `production_plan_items`
- `production_plan_history`
- `shift_templates`
- `shift_rules`
- `capacity_profiles`
- `resource_capacity_rules`
- `capacity_scenarios`
- `capacity_scenario_lines`
- `capacity_legacy_overrides`
- `staffing_layouts`
- `staffing_layout_lines`

#### Camada 5 - Labour e KPI

- `deputy_import_batches`
- `deputy_raw_timesheets`
- `deputy_area_mappings`
- `labour_segments`
- `kpi_definitions`
- `kpi_targets`
- `kpi_rate_rules`
- `kpi_results`

#### Camada 6 - Manutencao

- `maintenance_assets`
- `maintenance_work_orders`
- `maintenance_downtime_events`
- `maintenance_work_order_history`

---

## 6. Linhagem de uma ordem

```text
ORDER_NO no Oracle
  -> source_orders
  -> ship_to_name, due date, prioridade e status
  -> source_workbank_items
       -> zona atual
       -> local origem/destino
       -> garment e prints
       -> queue e task
  -> source_stock_items
       -> pack e posicao fisica
       -> underprint ou putwall
  -> source_audit_events
       -> primeiro pick
       -> primeiro/ultimo print
       -> movimentos e operador
  -> production stage engine
  -> UP/DTG/Hold/Ready-to-Lift
  -> production planning
  -> daily plan
  -> capacity and KPI
  -> close/dispatch context
```

---

## 7. Dicionario de metricas criticas

| Metrica | Definicao correta | Nao confundir com |
|---|---|---|
| Garments | Quantidade fisica de pecas | Linhas, SKUs, caixas ou prints |
| Prints | Soma dos lados/impressoes exigidas por garment | Garments |
| Orders | Ordens distintas | Linhas do workbank |
| SKUs | Produtos distintos | Quantidade fisica |
| Boxes | Packs distintos | Localizacoes |
| Putwall locations | Locais PWL1 distintos | Packs ou ordens |
| Production volume | `SUM(quantity)` | `COUNT(*)` |
| Pipeline | Ready to print + previsao awaiting picking | Somente fila PCOR |
| Occupancy | Posicoes ocupadas / capacidade de posicoes | Quantidade de garments |
| Output | Evento concluido e reconciliado da area | Movimentacao intermediaria |
| Productivity | Output / productive hours | Output / paid hours sem regra |
| Efficiency | Output / target do mesmo periodo e dimensao | Comparacao com target fixo incorreto |
| Downtime | Tempo entre inicio e fim da parada | Tempo total da work order |

---

## 8. Regras de qualidade e reconciliacao

### Controles de entrada

- Payload validado por schema.
- Segredo de ingestao obrigatorio.
- Batch completo antes de se tornar corrente.
- Audit deduplicado por identificador/hash.
- Cursor de auditoria so avanca depois de ingestao aceita.
- IDs preservados como string.
- Quantity vazia, zero ou negativa deve gerar alerta quando for volume produtivo.
- Description vazia deve gerar alerta no Production Mix.
- Tipo novo sem regra permanece em `OTHER` e gera alerta de classificacao.

### Controles de operacao

- Freshness superior ao limite deve aparecer como stale.
- Falha de fonte deve aparecer como missing source, nunca como zero confirmado.
- Totais devem fechar entre card, grafico, tabela e drill-down.
- Filtros devem atuar sobre numerador, denominador e target.
- Data selecionada deve usar o mesmo timezone em toda a cadeia.
- Toda agregacao deve declarar unidade e granularidade.

---

## 9. Seguranca e governanca

- Oracle e acessado com usuario somente leitura.
- Credencial Oracle fica no Windows Credential Manager.
- Chave `service_role` existe somente no servidor.
- Browser usa sessao Supabase e nunca recebe segredo administrativo.
- Rotas privadas exigem usuario autenticado.
- `ADMIN_EMAIL` restringe o acesso operacional configurado.
- Tabelas app-owned usam RLS e grants controlados.
- Funcoes sensiveis de manutencao usam `security definer` e sao executadas apenas pelo servidor.
- Alteracoes de planejamento, plano e manutencao possuem historico.
- Dados Oracle importados nao devem ser sobrescritos por decisoes humanas.

---

## 10. Hierarquia tecnica do repositorio

```text
C:\TSD Production Control Full
|
+-- apps
|   +-- web
|   |   +-- app                 rotas Next.js e server actions
|   |   +-- components          shell e componentes operacionais
|   |   +-- lib                 motores, consultas e regras server-side
|   |   +-- public              ativos estaticos/PWA
|   +-- oracle-sync
|       +-- src                 conexao, leitura, mapping e sync
|       +-- scripts             PowerShell, backfill e validacoes
|       +-- __tests__           contratos do conector
|
+-- packages
|   +-- shared
|       +-- src                 schemas e calculos compartilhados
|       +-- __tests__           paridade e regras centrais
|
+-- supabase
|   +-- migrations              evolucao versionada do banco
|
+-- docs                        documentacao operacional e tecnica
+-- deploy                      recursos de instalacao/publicacao
+-- package.json                comandos do monorepo
+-- pnpm-workspace.yaml         composicao do workspace
```

### Responsabilidade dos principais arquivos de `lib`

| Arquivo | Dominio |
|---|---|
| `source-data.ts` | Fonte, workbanks, detalhe, ready-to-lift e fechamento |
| `stage-engine.ts` | Etapas e aging |
| `machine-load.ts` | Carga, runway e forecast |
| `production-mix.ts` | Tipo e grupo produtivo |
| `planning.ts` / `planning-rules.ts` | Planejamento e validacoes |
| `daily-plans.ts` / `daily-plan-rules.ts` | Plano diario e ciclo de vida |
| `capacity.ts` / `capacity-rules.ts` | Capacidade e cenarios |
| `deputy.ts` / `deputy-import.ts` | Importacao de horas |
| `labour-dashboard.ts` | Horas e segmentos |
| `erp-kpis.ts` / `kpis.ts` | Calculo e leitura de KPI |
| `up-productivity.ts` | Output UP por data/stream |
| `flow-dashboard.ts` | Fluxo e putwall |
| `maintenance.ts` | Ativos, work orders e downtime |
| `reconciliation.ts` | Freshness e reconciliacao |
| `ship-to.ts` | Resolucao uniforme do Client exibido |
| `operational-scan.ts` / `scan-rules.ts` | Consulta por QR/codigo |

---

## 11. Ciclos operacionais ponta a ponta

### Ciclo diario de producao

1. Agente local coleta Oracle.
2. API cria batch atomico no Supabase.
3. Views correntes passam a apontar para o ultimo batch completo.
4. Motor de etapas classifica UP, DTG e excecoes.
5. Control Tower identifica risco e carga.
6. Planner define prioridades, data e turno.
7. Daily Plan transforma selecao em sequencia oficial.
8. Capacity confirma se recursos atendem a demanda.
9. Execucao gera novos eventos Oracle.
10. Performance e KPI medem o realizado.
11. Reconciliation confirma se fonte, calculo e interface fecham.

### Ciclo de manutencao

1. Ativo e cadastrado com criticidade e local.
2. Operacao reporta problema.
3. Se a maquina parou, downtime inicia imediatamente.
4. Work order entra como open.
5. Tecnico move para in progress.
6. Esperas sao classificadas como parts ou external.
7. Causa raiz e resolucao sao registradas.
8. Conclusao encerra downtime.
9. Ativo retorna a operational se nao houver outra parada.
10. Historico preserva responsavel, horario e transicoes.

---

## 12. Estado atual e maturidade

### Implementado e publicado

- Integracao Oracle read-only e batches Supabase.
- Source data, sync status e reconciliation.
- Motor de etapas e workbanks UP/DTG.
- Putwall, hold, ready-to-lift, close order e scan.
- Machine Load, runway e Production Mix.
- Planejamento, planos diarios e capacidade.
- Deputy, labour, eventos canonicos e KPI dashboard.
- Produtividade UP por auditoria.
- Modulo corretivo de manutencao.
- Navegacao funcional consolidada no ERP.

### Pontos que exigem estabilizacao continua

- Reconciliacao automatica de cada KPI com amostra Oracle/Excel.
- Retencao e manutencao das tabelas grandes de snapshot.
- Monitoramento de tamanho, dead tuples e consumo do Supabase.
- Alertas proativos de sync parado, source stale e batch divergente.
- Governanca formal de targets por vigencia.
- Cadastro inicial e taxonomia real dos ativos de manutencao.
- Permissoes por papel, area e responsabilidade, alem de lista administrativa simples.
- Validacao operacional em dispositivos moveis no chao de fabrica.

---

## 13. Lacunas recomendadas por engenharia de processos

### Prioridade 1 - Confiabilidade

1. Criar painel de saude de dados com SLA de sync, volume esperado e divergencia.
2. Implantar politica de retencao para snapshots e rotina de vacuum/monitoramento.
3. Criar testes de reconciliacao diarios por area e unidade.
4. Registrar versao da regra usada em cada resultado calculado.
5. Bloquear KPI quando fonte, target ou denominador estiver invalido.

### Prioridade 2 - Controle da producao

1. Criar Andon digital de bloqueios e paradas.
2. Separar backlog, WIP, waiting e completed por aging.
3. Medir tempo de fila e tempo de processo por etapa.
4. Criar alertas de due date em risco baseados em capacidade restante.
5. Medir aderencia ao plano: planejado versus sequencia realmente executada.
6. Criar matriz de skills do operador para alimentar cenarios de capacidade.

### Prioridade 3 - Manutencao industrial

1. Adicionar manutencao preventiva por calendario e horimetro.
2. Criar planos de tarefa e checklists por tipo de ativo.
3. Controlar pecas de reposicao, minimo, consumo e lead time.
4. Medir MTBF, MTTR, disponibilidade e Pareto de falhas.
5. Relacionar downtime ao impacto em capacidade e due dates.
6. Permitir anexos/fotos e aprovacao de retorno ao servico.

### Prioridade 4 - Gestao e melhoria continua

1. Criar OEE onde existirem availability, performance e quality confiaveis.
2. Implantar Pareto de perdas por maquina, produto, turno e causa.
3. Criar cost of delay e impacto financeiro de backlog/parada.
4. Registrar plano de acao com owner, prazo, evidencia e eficacia.
5. Criar rotina diaria SQDC: Safety, Quality, Delivery e Cost.
6. Comparar forecast, plano, realizado e desvio por horizonte.

---

## 14. Ownership recomendado

| Dominio | Dono do processo | Dono do dado | Frequencia de revisao |
|---|---|---|---|
| Source/Sync | TI / Sistemas | Oracle + Integration Owner | Diario |
| Production Flow | Production Manager | Supervisores de area | Por turno |
| Planning | Planner / PCP | Planner | Diario |
| Capacity | Production Engineering | Engenharia + PCP | Semanal e por mudanca |
| Labour | Operations / Payroll | Deputy Owner | Diario/semanal |
| KPI | Process Engineering | KPI Owner nomeado | Semanal/mensal |
| Maintenance | Maintenance Manager | Tecnicos e lideres | Diario |
| Data Quality | ERP Product Owner | Data Steward | Diario |

---

## 15. Regra de evolucao do ERP

Toda nova tela, coluna, KPI ou automacao deve responder antes da implementacao:

1. Qual decisao operacional ela suporta?
2. Qual e a fonte autoritativa?
3. Qual e a unidade?
4. Qual e a granularidade?
5. Qual periodo e timezone se aplicam?
6. Quais filtros alteram o resultado?
7. Como o valor sera reconciliado?
8. O que acontece quando o dado estiver ausente ou stale?
9. Quem e o owner da regra?
10. Como a mudanca fica auditavel?

Se qualquer resposta estiver indefinida, a funcionalidade deve permanecer identificada como provisoria e nao deve ser usada como indicador oficial.

---

## 16. Definicao sintetica do DNA

```text
FONTE CONFIAVEL
  + SEMANTICA DE PRODUCAO
  + FLUXO FISICO VISIVEL
  + PLANEJAMENTO GOVERNADO
  + CAPACIDADE CONFIGURAVEL
  + EXECUCAO AUDITAVEL
  + MANUTENCAO CONECTADA
  + KPI RECONCILIADO
  = TSD ERP
```

O ERP deve funcionar como um sistema nervoso da fabrica: captar os sinais do Oracle, entender onde cada ordem esta, antecipar carga e risco, orientar a proxima acao, medir o resultado real e preservar a historia necessaria para melhorar o processo.
