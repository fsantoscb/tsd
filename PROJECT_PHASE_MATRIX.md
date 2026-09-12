# TSD Production Control - Matriz de Fases, Entradas e Saidas

**Atualizado em:** 09/09/2026  
**Objetivo:** mostrar o que entra, o que o sistema faz, o que entrega e como cada subprocesso e validado.  
**Fonte de escopo:** `TSD_Production_Control_SPEC.md` e `IMPLEMENTATION_PLAN.md`.

## 1. Leitura rapida do projeto

| Faixa | Significado | Situacao |
|---|---|---|
| Fases 0-1 | Fundacao tecnica e transporte seguro dos dados | Concluidas e validadas |
| Fases 2-4 | Transformacao dos dados em visibilidade operacional | Concluidas e validadas |
| Fases 5-6 | Planejamento feito pelo usuario e plano diario | Concluidas e validadas |
| Fase 7 | Capacidade, carga e cenarios | Concluida e validada |
| Fase 8 | Motor completo de KPIs | Preparacao documental concluida; implementacao pendente |
| Fases 9-10 | Operacao por QR e preparacao para o piloto | Pendentes |

**Progresso das fases de implementacao:** 8 de 11 fases concluidas (0 a 7).  
**Progresso funcional aproximado:** 73%. A documentacao preparatoria da Fase 8 nao conta como implementacao.

## 2. Fluxo ponta a ponta

```text
Oracle (pedidos, workbank, estoque, auditoria)
  -> Agente local somente leitura
  -> Lotes atomicos no Supabase
  -> Reconciliacao e normalizacao
  -> Motor de etapas produtivas
  -> Workbanks UP e DTG
  -> Planejamento da producao                 [proxima etapa]
  -> Plano diario publicado
  -> Capacidade e cenarios
  -> KPIs e inteligencia operacional
  -> Consulta por QR
  -> Piloto seguro em producao
```

## 3. Matriz executiva das fases

| Fase | Objetivo | Entradas principais | Saidas principais | Estado |
|---|---|---|---|---|
| 0 - Fundacao | Criar a base tecnica segura | SPEC, decisoes arquiteturais, variaveis de ambiente | Monorepo, web, sync, tipos, auth base, testes | CONCLUIDA |
| 1 - Integracao Oracle | Copiar dados operacionais sem escrever no Oracle | Oracle, credencial Windows, consultas legadas | Snapshots atomicos, auditoria incremental, heartbeat | CONCLUIDA |
| 2 - Reconciliacao | Tornar os dados importados inspecionaveis e confiaveis | Ultimo lote completo, totais Oracle/Excel | Telas de fonte, conciliacao e status do sync | CONCLUIDA |
| 3 - Motor de etapas | Traduzir zonas/locais em etapas de producao | Workbank, estoque, regras e mapeamentos | Estagio atual, unidades convertidas, aged orders | CONCLUIDA |
| 4 - Workbanks UP/DTG | Substituir a visibilidade das planilhas principais | Estagios, pedidos, estoque, auditoria, putwall | Filas UP/DTG e detalhe do pedido | CONCLUIDA |
| 5 - Planejamento | Substituir agenda/status livre do Excel | Pedidos das filas, prioridades e decisoes do planner | Data, turno, status, notas, bloqueios e historico | CONCLUIDA |
| 6 - Plano diario | Criar e publicar uma sequencia executavel | Pedidos planejados, turnos, areas, unidades | Planos draft/published/closed e visao do supervisor | CONCLUIDA |
| 7 - Capacidade | Comparar demanda e capacidade configuravel | Planos, backlog, turnos, recursos, taxas, eficiencia | Capacidade, carga, gap, lead relativo e cenarios | CONCLUIDA |
| 8 - KPI Engine | Medir operacao sem fabricar dados | Historico operacional, planos, capacidade e metas | Catalogo, resultados, tendencias, dashboard e Pareto | DOC PRONTA / CODIGO PENDENTE |
| 9 - QR | Dar acesso rapido no chao de fabrica | Pedido/pack ID e contexto operacional | Scan, lookup de putwall e pagina movel | PENDENTE |
| 10 - Piloto | Tornar o produto seguro e operavel | Sistema completo, usuarios e ambiente de fabrica | PWA, servico Windows, seguranca e documentacao | PENDENTE |

## 4. Matriz detalhada por fase e subprocesso

### Fase 0 - Fundacao

| Item | Entrada | Processamento | Saida | Validacao | Estado |
|---|---|---|---|---|---|
| 0.1 Monorepo | SPEC e arquitetura | Separar web, integracao e codigo compartilhado | `apps/web`, `apps/oracle-sync`, `packages/shared` | Projetos compilam juntos | CONCLUIDO |
| 0.2 Aplicacao web | Requisitos de interface | Configurar Next.js, TypeScript e Tailwind | Shell responsivo e navegacao base | Build de producao | CONCLUIDO |
| 0.3 Supabase clients | URL e chaves por ambiente | Separar cliente browser, servidor e admin | Acesso tipado e server-side | Variaveis validadas; segredo fora do browser | CONCLUIDO |
| 0.4 Auth skeleton | Supabase Auth | Criar estrutura de login, sessao e rotas protegidas | Base de autenticacao | Fluxo de sessao validado | CONCLUIDO |
| 0.5 Sync skeleton | Contratos de integracao | Criar comandos e adaptadores sem Oracle ativo | Agente compilavel | Build do conector | CONCLUIDO |
| 0.6 Contratos compartilhados | Formatos de payload | Validar dados com schemas e tipos | Contratos comuns web/sync | Testes unitarios | CONCLUIDO |
| 0.7 Qualidade inicial | Codigo das bases | Configurar lint, typecheck e testes | Pipeline local repetivel | Lint, tipos, testes e build passam | CONCLUIDO |

### Fase 1 - Prova de integracao Oracle

| Item | Entrada | Processamento | Saida | Validacao | Estado |
|---|---|---|---|---|---|
| 1.1 Conexao segura | Credencial Windows e endpoint Oracle | Abrir conexao no agente local somente leitura | Sessao Oracle funcional | Conexao na rede da fabrica; nenhum segredo em log | CONCLUIDO |
| 1.2 Consultas fonte | Views Oracle e logica VBA conhecida | Consultar pedidos, workbank, estoque e auditoria | Registros fonte normalizados | IDs preservados como texto | CONCLUIDO |
| 1.3 Lote atomico | Quatro datasets da mesma rodada | Criar batch, carregar, validar e ativar junto | Snapshot consistente | Lote incompleto vira `failed`, nunca ativo | CONCLUIDO |
| 1.4 Pedidos snapshot | Pedidos Oracle | Normalizar datas, cliente, status e prioridade | `source_orders` | 1.200 registros no lote validado | CONCLUIDO |
| 1.5 Workbank snapshot | Workbank Oracle | Preservar zonas, locais, packs, qty e weight | `source_workbank_items` | 4.846 registros no lote validado | CONCLUIDO |
| 1.6 Estoque snapshot | Estoque Oracle | Preservar pack, local, qty, weight e unidades | `source_stock_items` | 114 registros no lote validado | CONCLUIDO |
| 1.7 Auditoria incremental | Eventos Oracle | Deduplicar e anexar apenas eventos novos | `source_audit_events` | 24 novos eventos no lote validado | CONCLUIDO |
| 1.8 Ingestao protegida | Payload e segredo do agente | Validar schema, autenticacao e tamanho | Endpoints de ingestao protegidos | Rejeicao de segredo/payload invalido | CONCLUIDO |
| 1.9 Heartbeat | Estado do agente | Registrar versao, host, ultimo contato e erro | Status online/offline | Ultima execucao visivel | CONCLUIDO |

### Fase 2 - Reconciliacao das fontes

| Item | Entrada | Processamento | Saida | Validacao | Estado |
|---|---|---|---|---|---|
| 2.1 Autenticacao operacional | Usuario Supabase | Resolver sessao e organizacao | Acesso privado ao aplicativo | Usuario nao autenticado nao acessa dados | CONCLUIDO |
| 2.2 Current Orders | Ultimo snapshot completo | Consultar pedidos atuais | Tela de pedidos fonte | Contagem comparada ao lote | CONCLUIDO |
| 2.3 Current Workbank | Ultimo snapshot completo | Consultar itens atuais | Tela de workbank fonte | Contagem e unidades comparadas | CONCLUIDO |
| 2.4 Current Stock | Ultimo snapshot completo | Consultar estoque atual | Tela de estoque fonte | Contagem e unidades comparadas | CONCLUIDO |
| 2.5 Recent Audit | Eventos append-only | Ordenar eventos recentes | Tela de auditoria | IDs/eventos sem duplicacao | CONCLUIDO |
| 2.6 Sync Status | Batches e heartbeat | Calcular frescor, sucesso e erros | Painel do conector | Ultimo lote e agente coerentes | CONCLUIDO |
| 2.7 Reconciliacao | Totais Oracle/Excel e Supabase | Comparar contagens e semantica quantitativa | Painel de divergencias | Totais-chave conferidos | CONCLUIDO |

### Fase 3 - Motor de etapas produtivas

| Item | Entrada | Processamento | Saida | Validacao | Estado |
|---|---|---|---|---|---|
| 3.1 Areas produtivas | Fluxo de fabrica | Cadastrar areas e sequencia | `production_areas` | UP, DTG e futuras areas suportadas | CONCLUIDO |
| 3.2 Mapeamentos | Zona/local do Oracle e regras VBA | Aplicar exact/contains/starts/ends por prioridade | `production_stage_mappings` | Casos conhecidos chegam ao estagio correto | CONCLUIDO |
| 3.3 Conversao quantitativa | `source_qty`, `source_weight` e regra legada | Calcular `production_units` sem perder valores crus | `quantity_conversion_rules` | Resultado reconciliado com Excel | CONCLUIDO |
| 3.4 Resumo por pedido | Pedidos, workbank e estoque | Consolidar etapa atual e quantidades | `v_order_stage_summary` | DTG 70 e UP 17 no recorte validado | CONCLUIDO |
| 3.5 Locais desconhecidos | Valores sem regra | Classificar explicitamente | Estado `UNMAPPED` | Nenhum valor desconhecido some silenciosamente | CONCLUIDO |
| 3.6 Pedidos antigos | Datas de recebimento/eventos | Calcular idade e faixas | Aged orders | Dias conferidos com fonte | CONCLUIDO |

### Fase 4 - Workbanks UP e DTG

| Item | Entrada | Processamento | Saida | Validacao | Estado |
|---|---|---|---|---|---|
| 4.1 Regra UP | Estoque atual e VBA `Status_UP` | Filtrar `LOCATION = UNDERPRINT`; contar caixas e somar `WEIGHT` como pecas | Fila UP | Caixas e pecas reconciliadas com o snapshot Oracle | CONCLUIDO |
| 4.2 Regra DTG | Workbank atual, zona `DTGS` e `IS_PRODUCT.PROD_X_5` | Cada linha vale 1 garment; `PROD_X_5` define prints por garment e `1 / 2` vale 2 | Fila DTG com garments e prints separados | Garments = unidades; prints reconciliados sem valores ausentes | CONCLUIDO |
| 4.3 Putwall | Estoque/local `PWL1` | Associar locais ao pedido | Visibilidade de putwall | Caso conhecido conferido | CONCLUIDO |
| 4.4 Busca e filtros | Texto, status, prioridade e aged | Aplicar filtros server-side | Lista operacional reduzida | Resultados e totais coerentes | CONCLUIDO |
| 4.5 Paginacao | Resultado filtrado | Paginar preservando filtros | Navegacao por paginas | Pagina e total coerentes | CONCLUIDO |
| 4.6 Detalhe do pedido | Numero do pedido | Reunir order, workbank, stock e audit | Visao consolidada | Pedido 130136657 conferido nas quatro fontes | CONCLUIDO |
| 4.7 Interface somente leitura | Dados operacionais | Exibir sem alterar fonte ou planejamento | Telas `/production/up` e `/production/dtg` | 13 testes, typecheck e build aprovados | CONCLUIDO |

### Fase 5 - Planejamento da producao

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 5.1 Metadados do pedido | `order_no` Oracle | Criar registro app-owned sem duplicar fonte | `production_orders` | Unicidade por organizacao + pedido | PENDENTE |
| 5.2 Prioridade do planner | Prioridade fonte e decisao do planner | Guardar override separadamente | `planner_priority` e prioridade efetiva documentada | Nunca sobrescrever `source_priority` | PENDENTE |
| 5.3 Data planejada | Pedido selecionado e data | Validar e persistir compromisso | `planned_date` | Data nao fica escondida em texto livre | PENDENTE |
| 5.4 Turno planejado | Data e shift template | Vincular pedido ao turno | `planned_shift_id` | Turno valido para a organizacao | PENDENTE |
| 5.5 Status controlado | Acao do planner | Transicionar entre estados permitidos | `unplanned/planned/ready/in_progress/blocked/waiting/completed/cancelled` | Transicoes e permissoes testadas | PENDENTE |
| 5.6 Instrucoes e notas | Orientacao operacional | Separar instrucao especial de nota interna | `special_instruction` e `planner_note` | Campos independentes e auditaveis | PENDENTE |
| 5.7 Bloqueios | Motivo informado | Marcar bloqueio e justificativa | `blocked`, `blocked_reason` | Bloqueado exige motivo; desbloqueio fica no historico | PENDENTE |
| 5.8 Historico | Alteracoes de planejamento | Registrar antes/depois, autor e horario | Trilha de auditoria do planner | Todas as mudancas relevantes rastreaveis | PENDENTE |
| 5.9 Acoes em massa | Selecao de varios pedidos | Aplicar data, turno, prioridade ou status em lote | Planejamento em massa | Operacao atomica e resultado por item | PENDENTE |
| 5.10 UI de planejamento | Filas UP/DTG e metadados | Editar individualmente e em massa | Fluxo substituto do Excel | Planner agenda sem usar status livre da planilha | PENDENTE |

**Entrada da Fase 5:** tudo o que foi validado nas Fases 1-4, mais decisoes humanas do planner.  
**Saida da Fase 5:** pedidos enriquecidos com planejamento, ainda sem formar um plano diario sequenciado.  
**Limite:** os dados Oracle continuam somente leitura; somente os metadados do aplicativo sao gravados.

### Fase 6 - Plano diario de producao

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 6.1 Cabecalho do plano | Data, turno e area | Criar plano com ciclo de vida | `production_plans` | Um plano consistente por contexto definido | PENDENTE |
| 6.2 Itens do plano | Pedidos planejados | Inserir pedido, unidades e responsavel | `production_plan_items` | Referencias e unidades validas | PENDENTE |
| 6.3 Sequenciamento | Itens selecionados | Ordenar execucao | Sequencia operacional | Sem posicoes duplicadas | PENDENTE |
| 6.4 Draft | Plano em construcao | Permitir revisao sem publicar | Estado `draft` | Nao aparece como ordem oficial ao supervisor | PENDENTE |
| 6.5 Publish | Plano revisado | Congelar/publicar versao operacional | Estado `published` | Supervisor recebe a sequencia correta | PENDENTE |
| 6.6 Close | Plano executado/encerrado | Fechar e preservar historico | Estado `closed` | Plano nao sofre alteracao indevida | PENDENTE |
| 6.7 Supervisor view | Plano publicado | Exibir sequencia, instrucao e progresso | Tela operacional diaria | Manager planeja UP/DTG sem Excel | PENDENTE |

### Fase 7 - Capacidade e cenarios

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 7.1 Shift templates | Horarios e regras locais | Configurar turnos, inclusive madrugada | Turnos reutilizaveis | Producao cruza meia-noite corretamente | CONCLUIDO |
| 7.2 Capacity profiles | Area, recursos, horas, taxa e eficiencia | Aplicar `recursos x horas x taxa x eficiencia` | Capacidade configuravel | Nenhuma premissa hardcoded | CONCLUIDO |
| 7.3 Scenario builder | Variacoes de equipe/maquinas/horas | Recalcular dinamicamente | Cenario comparavel e salvavel | Reproduz cenarios do Excel | CONCLUIDO |
| 7.4 Capacidade diaria | Perfis e calendario | Agregar por data/area/turno | Capacidade do dia | Formula e agregacao testadas | CONCLUIDO |
| 7.5 Capacidade semanal | Capacidades diarias | Agregar periodo | Capacidade semanal | Soma por turnos/dias coerente | CONCLUIDO |
| 7.6 Carga | Backlog/plano em unidades | Comparar demanda com capacidade | Percentual de carga | Denominador zero tratado | CONCLUIDO |
| 7.7 Gap | Demanda e capacidade | Calcular excesso ou folga | Capacity gap | Sinal e unidade conferidos | CONCLUIDO |
| 7.8 Lead relativo | Backlog e capacidade efetiva | Estimar dias/turnos para limpar fila | Relative lead | Reconciliado com regra legada | CONCLUIDO |

### Fase 8 - KPI Engine e inteligencia operacional

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 8.0 Data readiness | Catalogo de 125 KPIs e fontes disponiveis | Classificar fonte e dependencia | `KPI_DATA_READINESS.md` | 125/125 classificados | CONCLUIDO (DOC) |
| 8.1 Catalogo KPI | Definicoes aprovadas | Cadastrar formula, unidade, direcao, frequencia e owner | `kpi_definitions` | Todo KPI da SPEC existe | PENDENTE |
| 8.2 Metas e thresholds | Decisoes de gestao | Versionar target/warning/critical por dimensao | `kpi_targets` | Nada hardcoded na UI | PENDENTE |
| 8.3 Motor de calculo | Eventos, snapshots, planos e capacidade | Calcular apenas com dados validos | Resultados centralizados | Formula, zero, ausente e stale testados | PENDENTE |
| 8.4 Resultados | Numerador, denominador e dimensoes | Persistir valor, alvo, status e qualidade | `kpi_results` | Drill-down reproduz o valor | PENDENTE |
| 8.5 Agregacoes | Resultados/raw history | Agregar por periodo e dimensao | Diario, turno, semana e mes | Resumos reproduziveis | PENDENTE |
| 8.6 Atribuicao de turno | Evento e shift template | Resolver `production_date`, inclusive madrugada | Dimensao temporal correta | Testes cross-midnight | PENDENTE |
| 8.7 Dashboard | KPIs ativos e configuracao | Exibir conjunto de gestao sem consultar Oracle | Painel executivo | KPIs indisponiveis nao fabricam valores | CONCLUIDO |
| 8.8 Detalhe e tendencia | Historico e filtros | Comparar periodos e decompor dimensoes | Pagina por KPI | Filtros persistem ate a fonte | CONCLUIDO |
| 8.9 Pareto | Razoes de perdas/problemas | Ordenar impacto e acumulado | Paretos operacionais | Percentual acumulado correto | CONCLUIDO |
| 8.10 Qualidade dos dados | Frescor e completude | Classificar VALID/PARTIAL/STALE/NO_DATA | Sinal explicito de confiabilidade | OEE espera todos os componentes | CONCLUIDO |
| 8.11 Reconciliacao Excel | Historico equivalente | Comparar valores e tolerancias | Relatorio de conciliacao | Diferencas documentadas | CONCLUIDO |

**Observacao:** a Fase 8 foi concluida e validada. O catalogo governa 125 KPIs; 10 estao ativos com dados disponiveis e 115 permanecem visiveis aguardando fonte, sem valores fabricados. Calculos atuais, metas, qualidade, Pareto, detalhe e agregacoes diaria/semanal/mensal estao operacionais.

### Fase 9 - QR e scan operacional

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 9.1 Scan de pedido | QR/codigo do pedido | Interpretar identificador como texto | Abertura do pedido | Pedido real 130135089 validado sem perda de digitos | CONCLUIDO |
| 9.2 Scan de pack | Pack ID | Consultar contexto atual | Detalhe do pack | Pack real 393006020117195427 preservado como string e associado ao pedido | CONCLUIDO |
| 9.3 Putwall lookup | Pedido/pack | Resolver local PWL atual | Instrucao de putwall | Locais PWL conferidos no snapshot; ausencia tambem e explicita | CONCLUIDO |
| 9.4 QR display | Payload aprovado | Gerar QR operacional | Codigo legivel | Payload TSD:ORDER e imagem QR gerados; leitura por software validada | CONCLUIDO |
| 9.5 Mobile workflow | Camera/tela pequena | Otimizar scan e detalhe | Fluxo movel | Fluxo responsivo implementado; teste fisico de camera dispensado por decisao operacional, mantendo leitor e digitacao | CONCLUIDO |
| 9.6 Mapeamento operacional por item | Ordem, produto, grupo, PROD_X_5, pack e localizacao | Cruzar o snapshot por ordem/produto e classificar etapa e Adults/Kids | Mapa de itens com garments, prints, pack e local atual | Ordem real 130135089 validada: 7 linhas, PUTWALL e DTG, grupo DTG_2, WOMENS como ADULTS e DTG sempre 1 garment | CONCLUIDO |

**Limite:** consultar e orientar; nao fechar pedido nem escrever no Oracle.

### Fase 10 - Hardening e piloto

| Item | Entrada | Processamento | Saida esperada | Validacao de aceite | Estado |
|---|---|---|---|---|---|
| 10.1 RLS e permissoes | Perfis e tabelas | Revisar politicas por organizacao/papel | Isolamento de dados | Testes positivos e negativos | PENDENTE |
| 10.2 Seguranca | Endpoints, segredos e logs | Revisar autenticacao, exposicao e abuso | Superficie endurecida | Segredos ausentes de cliente/log | PENDENTE |
| 10.3 Performance | Volume real e consultas | Medir e otimizar indices/queries | Tempos operacionais aceitaveis | Metas de resposta documentadas | PENDENTE |
| 10.4 Frescor e qualidade | Heartbeat, batches e fontes | Alertar stale/partial/failure | Avisos operacionais | Dados antigos nunca parecem atuais | PENDENTE |
| 10.5 Reconciliacao final | Oracle, Excel e aplicativo | Executar comparacoes de aceite | Evidencia do piloto | Tolerancias aprovadas | PENDENTE |
| 10.6 Backup e recuperacao | Banco e configuracao | Definir politica e restauracao | Plano de continuidade | Restore testado | PENDENTE |
| 10.7 Deploy | Web, Supabase e DNS/ambiente | Publicar configuracao controlada | Aplicacao acessivel | Smoke test no ambiente alvo | PENDENTE |
| 10.8 Servico do conector | Agente validado | Instalar como Windows Service | Sync automatico | Reinicio e recuperacao testados | PENDENTE |
| 10.9 PWA | Web responsiva | Configurar instalacao/cache seguro | Aplicativo instalavel | Desktop e mobile validados | PENDENTE |
| 10.10 Documentacao e treinamento | Fluxos finais | Criar runbooks e instrucoes | Operacao sustentavel | Usuarios-chave executam os fluxos | PENDENTE |

## 5. Dependencias entre as proximas fases

| Fase | Depende de | Por que |
|---|---|---|
| 5 | 0-4 | O planner precisa de pedidos e estagios confiaveis |
| 6 | 5 | Um plano diario e composto por pedidos ja planejados |
| 7 | 3, 5 e 6 | Capacidade precisa de areas, demanda planejada e turnos |
| 8 | 1-7 conforme cada KPI | Cada KPI so ativa quando suas fontes forem autoritativas |
| 9 | 2-4 | Scan precisa localizar pedido, pack e putwall confiavelmente |
| 10 | 0-9 | O piloto endurece e operacionaliza o produto completo |

## 6. O que esta pronto para uso agora

| Capacidade atual | Resultado |
|---|---|
| Sincronizar Oracle -> Supabase | Disponivel e validado, somente leitura |
| Ver pedidos/workbank/estoque/auditoria fonte | Disponivel |
| Ver saude e ultimo sync | Disponivel |
| Ver etapa produtiva consolidada | Disponivel |
| Ver fila UP | Disponivel |
| Ver fila DTG e progresso | Disponivel |
| Ver detalhe completo de um pedido | Disponivel |
| Planejar data, turno, prioridade e bloqueio | Ainda nao disponivel; Fase 5 |
| Publicar plano diario | Ainda nao disponivel; Fase 6 |
| Calcular capacidade/cenarios | Disponivel e validado |
| Consultar KPIs completos | Disponivel; catalogo, dashboard, detalhe, tendencias, metas, qualidade e Pareto validados |
| Usar QR no chao de fabrica | Pedido, pack, putwall, mapa por item e QR disponiveis; opera por leitor, digitacao ou camera opcional |
| Operar como piloto endurecido/PWA | Ainda nao disponivel; Fase 10 |

## 7. Gate para iniciar a Fase 5

Antes de codificar, a Fase 5 deve confirmar:

| Decisao | Definicao proposta |
|---|---|
| Dono dos dados | Oracle continua dono do pedido; Supabase e dono apenas do planejamento |
| Campos editaveis | prioridade do planner, data, turno, status, instrucoes, notas e bloqueio |
| Auditoria | registrar usuario, horario, campo, valor anterior e novo |
| Acoes em massa | data, turno, prioridade e status, com resultado atomico |
| Permissao | planner/manager edita; demais perfis conforme politica a definir |
| Saida de aceite | planner substitui o agendamento textual do Excel pelo fluxo estruturado |

## 8. Regra de conclusao para todas as fases restantes

Uma fase so muda para `CONCLUIDA` quando:

1. As migrations necessarias foram aplicadas.
2. Implicacoes de seguranca e dados foram tratadas.
3. O fluxo funcional foi implementado de ponta a ponta.
4. Os testes automatizados relevantes passaram.
5. Typecheck, lint e production build passaram.
6. A reconciliacao com Oracle/Excel foi feita quando aplicavel.
7. O plano e esta matriz foram atualizados.
8. A proxima fase ainda nao foi iniciada sem registrar o aceite da fase atual.
