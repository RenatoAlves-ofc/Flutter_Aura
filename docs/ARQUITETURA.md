# Arquitetura — Aura

Documento para quem for mexer no código. Descreve como o app está organizado, por onde os
dados passam e onde ficam as regras. Para o *porquê* de cada escolha, veja
[`DECISOES.md`](DECISOES.md).

---

## 1. Arquivo único, e o que isso obriga

Todo o app vive em **`lib/main.dart`** (~3.400 linhas). Não é preferência de estilo: o
FlutLab tem problemas com arquitetura multi-arquivo no navegador, então a especificação
proibiu imports relativos.

Sem pastas para separar responsabilidades, a separação é feita por **faixas do arquivo**,
marcadas com banners. A ordem importa: cada faixa só depende das anteriores.

```
main() + captura de erro + AuraErrorScreen     ← infraestrutura
MODELOS                                        ← dados puros
CONSTANTES DE APOIO                            ← escalas, datas, formatação
PERSISTÊNCIA (shared_preferences)              ← AuraStore
SEQUÊNCIA COM PERDÃO (regra fixa)              ┐
MOTOR DE INSIGHTS (Dart puro)                  │ lógica pura, sem Flutter
SUGESTÃO ADAPTATIVA DE DURAÇÃO                 │ (é o que os testes atacam)
CLIMA PESSOAL (a "aura")                       │
DATASET DE DEMONSTRAÇÃO                        ┘
SHELL PRINCIPAL                                ← estado do app
TELA 1: FOCO / 2: TAREFAS / 3: INSIGHTS / 4: RESUMO / SOBRE
WIDGETS COMPARTILHADOS
```

A faixa do meio é a mais importante: **é lógica pura, sem nenhuma dependência de Flutter**.
Funções que recebem `List<StudySession>` e devolvem números ou objetos de dados. É por isso
que 46 dos 67 testes conseguem rodar sem construir uma única tela.

---

## 2. As quatro camadas

```
┌──────────────────────────────────────────────────────────┐
│  UI          HomeShell → FocusPage / TaskListPage /      │
│              InsightsPage / SummaryPage / AboutPage      │
├──────────────────────────────────────────────────────────┤
│  Lógica      buildInsights · applyActivity ·             │
│  pura        resolveClimate · suggestMethodForMood ·     │
│              streakFromSessions · buildDemoSessions      │
├──────────────────────────────────────────────────────────┤
│  Persistência           AuraStore (shared_preferences)   │
├──────────────────────────────────────────────────────────┤
│  Modelos     StudySession · TaskItem · FocusMethod ·     │
│              StreakState · Insight · AuraClimate         │
└──────────────────────────────────────────────────────────┘
```

A camada de lógica **não conhece** a de persistência: recebe listas prontas. Quem lê do
disco é sempre o `_HomeShellState`, que então passa os dados para baixo. Isso é o que torna
a lógica testável sem `SharedPreferences` mockado.

---

## 3. Estado

`StatefulWidget` + `setState()`, sem pacote de gerenciamento de estado.

O `_HomeShellState` é o dono de tudo que persiste — sessões, tarefas, pontos, sequência — e
passa para as telas por parâmetro, recebendo callbacks de volta:

```
_HomeShellState
├── _sessions, _tasks, _points, _streak
├── _recordSession(StudySession)   ← ponto único de entrada de sessão concluída
├── _addTask / _toggleTask / _removeTask
└── _applySessions(List)           ← troca o conjunto e recalcula o que depende dele
```

`_recordSession` é deliberadamente o **único** caminho por onde uma sessão entra: ele grava,
credita os 10 pontos e atualiza a sequência. Espalhar isso seria a forma mais fácil de a
tela Resumo voltar a ficar incoerente.

---

## 4. Modelo de dados

### `StudySession` — a unidade que alimenta tudo

```dart
DateTime date;
int durationMinutes;
int moodBefore;      // 1..5
int moodAfter;       // 1..5
String? linkedTaskId;
String methodId;
bool isDemo;         // extensão nossa, ver DECISOES.md
```

JSON gravado (note que a chave é `duration`, não `durationMinutes`):

```json
{
  "date": "2026-08-18T14:30:00.000",
  "duration": 52,
  "moodBefore": 3,
  "moodAfter": 5,
  "linkedTaskId": "task_1755526200000000",
  "methodId": "52_17",
  "isDemo": false
}
```

`fromJson` é **retrocompatível de propósito**: `methodId` ausente vira
`pomodoro_classico` e `isDemo` ausente vira `false`, para que dados gravados por versões
anteriores continuem abrindo. O mesmo vale para `TaskItem`, que sintetiza um `id` quando o
registro salvo não tem um.

### Chaves no `shared_preferences`

| Chave | Conteúdo |
|---|---|
| `tasks` | lista de `TaskItem` em JSON |
| `sessions` | lista de `StudySession` em JSON |
| `points` | inteiro |
| `streak`, `forgivenessTokens`, `streakRunLength`, `lastActiveDay` | estado da sequência |
| `demoSeeded` | se o dataset de demonstração já foi semeado |
| `selectedMethodId` | último método escolhido |
| `customFocusMinutes`, `customBreakMinutes` | durações do método Personalizado |

Leitura de listas passa por `AuraStore._loadList`, que envolve o `jsonDecode` em
`try/catch`, descarta o valor ilegível e registra o motivo. Sem isso, um único registro
malformado deixa o app impossível de abrir para sempre.

---

## 5. As regras de negócio

### Motor de insights

`buildInsights(sessions)` devolve sempre 4 objetos `Insight`. Cada um tem um volume mínimo
de dados; abaixo dele o card aparece bloqueado, mostrando quantas sessões faltam — o
bloqueio é a própria mecânica, não um erro.

| Insight | Cálculo | Mínimo |
|---|---|---|
| Humor prevê foco | duração média por faixa de `moodBefore` | 5 sessões, 2+ faixas |
| Focar muda humor | média de `moodAfter - moodBefore` | 5 sessões |
| Melhor dia | minutos totais por dia da semana | 7 sessões |
| Método que sustenta | `moodAfter` médio por `methodId` | 6 sessões, 2+ métodos com 2+ sessões |

Faixas de humor (`_moodBucket`): **1-2** baixo, **3** neutro, **4-5** alto.

### Sequência com perdão

`applyActivity(prev, now)` é uma função pura de transição:

- mesma data → nada muda (a sequência conta dias, não sessões)
- dia seguinte → sequência cresce
- faltou **exatamente um** dia **e** há token → gasta o token, sequência sobrevive
- qualquer outro buraco → recomeça do 1

A cada 3 dias acumulados ganha-se 1 token, com teto de 3.

`effectiveStreak(state, now)` existe porque guardar o número no disco não basta: se o
usuário sumiu por vários dias, a sequência já está quebrada mesmo sem nenhuma sessão nova
ter sido registrada.

`streakFromSessions(sessions)` reconstrói o estado aplicando `applyActivity` dia a dia — é
o que mantém a tela Resumo coerente quando o dataset de demonstração é ligado ou desligado.

### Clima pessoal

`resolveClimate(sessions)` olha só as **3 sessões mais recentes** e calcula a média de
`moodAfter`:

| Média | Estado |
|---|---|
| ≥ 4.2 | Radiante |
| ≥ 3.4 | Fluindo |
| ≥ 2.4 | Nublado |
| < 2.4 | Recolhido |
| sem sessões | Aura em branco |

Olhar só as recentes é intencional: a aura reflete o estado atual, não a média histórica.
O gradiente é aplicado no fundo do app inteiro, com `AnimatedContainer`, então a mudança é
visível em todas as abas.

### Sugestão adaptativa

`suggestMethodForMood(sessions, mood)` filtra as sessões da mesma faixa de humor, exige 2+
sessões por método e devolve o de melhor `moodAfter` médio — desempate por maior duração
sustentada. Devolve `null` quando não há evidência. Flowtime e Personalizado são excluídos.

### Dataset de demonstração

`buildDemoSessions()` gera 22 sessões dos últimos 14 dias com `math.Random(7)` — **semente
fixa**, para a apresentação ser sempre idêntica. Os dados carregam de propósito a
correlação que o app promete descobrir: quem começa com humor melhor escolhe métodos mais
longos e sustenta mais tempo.

---

## 6. Tratamento de erro

`main()` instala três camadas antes de subir o app:

- `FlutterError.onError` — erros de build/layout
- `platformDispatcher.onError` — erros assíncronos
- `runZonedGuarded` — o que escapar dos dois

Tudo é registrado em `AuraCrashReport`, e o último erro aparece na tela **Sobre** — erros
assíncronos não derrubam mais o app, e por isso mesmo passariam despercebidos.

`AuraErrorScreen` é usada em três lugares: como `ErrorWidget.builder`, como tela quando o
app não sobe, e quando a carga inicial falha. Por isso ela **traz os próprios
`Directionality` e `Material`** e não usa `Scaffold` nem `SafeArea`: uma tela de erro que
depende de ancestrais lança ao ser desenhada e vira um laço infinito, escondendo justamente
o erro que veio mostrar.

---

## 7. Animação, e a restrição que ela impõe aos testes

O app tem **uma única animação contínua**: o halo que respira em volta do anel, enquanto a
sessão roda. Todas as outras são finitas — entram, terminam e param.

Isso não é preferência estética, é uma restrição de teste. `pumpAndSettle()` espera **todas**
as animações acabarem; qualquer animação que repete infinitamente faz o teste esperar para
sempre. Como 25 chamadas da suíte usam `pumpAndSettle`, uma animação contínua mal colocada
derruba a suíte inteira.

| Onde | O quê | Duração |
|---|---|---|
| Abertura | tela nativa → `AuraLoadingScreen` → app | dissolvência de 450 ms |
| Marca do Aura | entrada com escala e opacidade | 520 ms |
| Troca de aba | dissolvência com deslize curto | 260 ms |
| Cards de insight e gráficos | entrada escalonada, via `EntranceFade` | 620 ms, atraso por índice |
| Gráficos `fl_chart` | barras e linha crescendo | 750 ms |
| Anel do cronômetro | progresso suave entre segundos | 300 ms |
| Aura (fundo) | transição entre climas | 700 ms |
| **Halo do anel** | **respira — contínua** | 2600 ms, alternando |

O escalonamento do `EntranceFade` sai de um `Interval` na curva, **não** de
`Future.delayed`: assim continua sendo uma animação só, finita, e o `pumpAndSettle` termina.

`_breath` é parado em todos os pontos onde a sessão para — pausar, reiniciar, fim de ciclo
e fim de Flowtime. Os dois testes que rodam o cronômetro usam `pump(Duration)` no lugar de
`pumpAndSettle`, e há um teste que verifica justamente isto: o halo anima durante a sessão
e para ao pausar.

## 8. Restrições do FlutLab respeitadas pelo código

| Restrição | Como aparece no código |
|---|---|
| Arquivo único, sem imports relativos | tudo em `lib/main.dart` |
| Sem `.withOpacity()` (depreciado) | `.withValues(alpha:)` em todo lugar |
| Sem `CardTheme`/`CardThemeData` | `AuraCard` é `Container` + `BoxDecoration` |
| Dependências enxutas | 4 pacotes; mais que isso degrada o Hot Preview |
| Nada de câmera, sensores ou notificações | nenhum item do MVP depende disso |

Também foram evitados `DropdownButtonFormField` (a API mudou entre versões) e
`Iterable.firstOrNull`, ambos por compatibilidade com SDKs mais antigos que o FlutLab pode
estar rodando.

---

## 9. Testes

```bash
flutter test          # 67 testes
```

| Arquivo | Testes | Foco |
|---|---|---|
| `test/aura_logic_test.dart` | 46 | lógica pura: sequência, insights, sugestão, clima, dataset, serialização |
| `test/aura_app_test.dart` | 21 | interface: navegação, fluxo de humor, gráficos, animação, resiliência, tela de erro |

Os testes de interface rodam num viewport de telefone (420×940) em vez do padrão 800×600 —
foi assim que apareceu um estouro de layout que o padrão escondia.

Testes **não** cobrem aparência. A interface foi conferida separadamente, servindo o build
web e navegando com captura de tela; ver [`RELATORIO-E2E.md`](RELATORIO-E2E.md) §3.2.
