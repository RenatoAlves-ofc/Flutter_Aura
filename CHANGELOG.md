# Changelog

Histórico do projeto, do scaffold do FlutLab ao app entregue. Cada bloco corresponde a um
pull request mergeado.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

## [1.6.3] — 2026-08-21

Reposicionamento de copy: performance em vez de bem-estar emocional. Decisão completa em
[`DECISOES.md` §25](docs/DECISOES.md).

### Alterado

- **Discurso do app** — de "bem-estar emocional" para "inteligência de performance pessoal".
  O humor deixa de ser vendido como o produto e passa a ser tratado como o que sempre foi no
  código: um sinal de entrada que prevê desempenho. **É reposicionamento de linguagem, não de
  lógica** — nenhum cálculo, campo de dado ou limiar mudou.
- **Dois títulos de insight**: "Seu humor prevê seu foco" → "Seu estado de entrada prevê seu
  foco"; "Focar muda seu humor" → "Efeito colateral do foco".
- **A ordem das seis descobertas** — `mood_delta`, o único insight estruturalmente sobre
  humor e não sobre desempenho, passou de segundo para penúltimo.
- **O corpo de dois insights** (`mood_duration`, `method`) trocou linguagem de sentimento por
  linguagem de rendimento medido.
- **Pitch do README, `pubspec.yaml` e roteiro de apresentação** — "como você está se
  sentindo" virou "o seu estado de entrada".

## [1.6.2] — 2026-08-21

Só documentação. Documento de produto, que faltava inteiro.

### Adicionado

- **[`docs/PRODUTO.md`](docs/PRODUTO.md)**: problemática, público-alvo, catálogo completo de
  funcionalidades e os códigos de cor. Duas seções **não existiam em lugar nenhum** do
  repositório antes:
  - **A problemática** — zero ocorrências na documentação inteira. Reconstruída a partir das
    decisões registradas e da pesquisa de concorrência, com ressalva no topo pedindo
    conferência contra a especificação original da atividade.
  - **O público-alvo** — só aparecia em duas frases soltas dentro de outros assuntos
    (`DECISOES.md` §3 e `APRESENTACAO.md`), nunca como seção. Agora tem definição, o que ela
    decidiu no produto, e quem explicitamente **não** é o público.

### Corrigido

- **`RELATORIO-E2E.md` dizia "4 de 4 desbloqueadas"** em dois lugares, de quando havia quatro
  descobertas. São seis desde a v1.5.0, e a aba abre em "5 de 6". Corrigido nos dois.

## [1.6.1] — 2026-08-21

Só documentação. Segunda rodada de planejamento, com tudo verificado antes de planejar.

### Adicionado

- **[`docs/PLANO-V2.md`](docs/PLANO-V2.md)**: dez melhorias pedidas, cada uma conferida
  contra o código antes de entrar. Três achados que mudaram o plano:
  - **Trocar de aba mata a sessão em andamento.** O `AnimatedSwitcher` com
    `KeyedSubtree(key: ValueKey(_index))` destrói a `FocusPage` — vai junto o cronômetro, o
    humor inicial, a tarefa vinculada e a nota. É perda de dado, reproduzível em dois toques,
    e o maior risco para a demonstração ao vivo.
  - **O arco-íris dos gráficos sai de uma linha.** As barras de "Humor inicial × duração"
    são pintadas com `moodColors`, que inclui verde e verde-azulado. Todo o resto da aba já
    usa índigo. A inconsistência inteira é `lib/main.dart:3835`.
  - **O inglês dos insights é o nome da aba.** Os textos, os títulos e os dias da semana já
    estão em português; o que está em inglês é o rótulo `'Insights'`.

### Corrigido

- **`ROADMAP.md` §5 dizia algo falso.** Afirmava que a tarefa vinculada "some" depois do
  check de humor. Ela é exibida durante a sessão inteira (`lib/main.dart:2812`) — metade do
  item já estava pronta. A correção ficou registrada como correção, não apagada.

## [1.6.0] — 2026-08-21

Frase do dia — a primeira e única exceção ao "sem rede" do projeto, revertendo o item 4 do
ROADMAP. Decisão completa, com o risco avaliado e o que foi feito para conter ele, em
[`DECISOES.md` §24](docs/DECISOES.md).

### Adicionado

- **Cartão de frase do dia** na aba Resumo: uma frase curta de incentivo, gerada a partir do
  resumo local (classe, clima, contexto, foco do momento) — nunca do humor bruto. Tenta a Groq
  primeiro, a Gemini como reserva; sem resposta das duas, o cartão simplesmente não aparece.
- Uma chamada por usuário por dia — `AuraStore` guarda a frase e a data, evitando repetir a
  requisição a cada abertura de tela.
- `debugDisableDailyLineNetwork`, ligada nos testes de widget para a chamada de rede real
  nunca disparar durante `pumpAndSettle`.
- Dependência nova: `http`. Permissão nova no manifest de release: `INTERNET`.
- 12 testes novos (75 na suíte de lógica, 100 no total): o prompt nunca carrega humor bruto, os
  dois parsers de resposta, e a regra de cache por data.

### Mudou

- A promessa de privacidade do README passou a descrever a exceção com precisão, em vez de um
  "sem rede" que deixou de ser verdade para essa única funcionalidade.

## [1.5.2] — 2026-08-21

Só documentação. O código continua congelado para a apresentação de 24/08.

### Adicionado

- **[`docs/PALETA-DE-CORES.md`](docs/PALETA-DE-CORES.md)**: inventário da paleta atual,
  valor por valor — não um plano de mudança, isso já está no ROADMAP §1. Duas coincidências
  de valor que a regra de cor não previu ficaram registradas: o teal da pausa do cronômetro é
  o mesmo hex de `moodColors[5]` ("Ótimo"), e o amber padrão de `AuraMark` é o mesmo hex de
  `moodColors[3]` ("Neutro") — nenhuma das duas aparece na tela hoje, mas ambas eram
  coincidência, não reaproveitamento deliberado.

## [1.5.1] — 2026-08-20

Só documentação. O código está congelado para a apresentação de 24/08.

### Adicionado

- **[`docs/ROADMAP.md`](docs/ROADMAP.md)**: as cinco melhorias pedidas, cada uma com custo,
  retorno e o que ela quebra. Três coisas que o documento registra e valem citar:
  - **Os climas se parecem demais, e dá para medir**: a luminância dos cinco gradientes fica
    entre 0,80 e 0,92 — amplitude de 0,12. São cinco pastéis quase brancos, e é por isso que
    a aura muda pouco na tela.
  - **`FocusMethod` não tem campo de descrição nenhum.** O app oferece "52/17" e "Ciclo
    Ultradiano" sem explicar o que são, e escolher o método é a primeira decisão que ele
    pede. É o item mais barato e de maior retorno do roadmap.
  - **Frases motivacionais não precisam de API** — e a API contradiria o "sem IA, sem API,
    sem rede" do README, exigiria chave extraível do APK, quebraria o uso offline e ainda
    seria *menos* pessoal que gerar a frase do histórico real do usuário.

## [1.5.0] — 2026-08-20

Personalização — e a descoberta que ela desbloqueia, que é o ponto inteiro.

### Adicionado

- **Tipo de trabalho por sessão** (`contextId`): Acadêmico, Trabalho, Pessoal, Criativo e
  Geral, escolhido em chips no check de humor. Já vem marcado com o do perfil, então quem não
  quiser mudar não toca em nada.
- **"Onde você rende mais"**, a sexta descoberta e o motivo de o campo acima existir: duração
  sustentada e humor final por tipo de trabalho. Exige 8 sessões e 2 contextos com 3+ sessões
  cada. A aba Insights abre em **"5 de 6 desbloqueadas"**.
- **Perfil**: nome, tipo de trabalho principal e *"o que você está focando neste período"* —
  tudo opcional, tudo local, editável pelo lápis na própria ficha. A ficha passou a mostrar
  "Renato · Ritmista · Acadêmico" com a declaração de foco embaixo.
- **Nota curta e opcional** por sessão, no check de humor de antes.
- Onze testes novos, incluindo o que **carrega um JSON no formato antigo** — sem ele, uma
  atualização deixaria sem app quem já tem sessões gravadas. **88 testes**.

### Corrigido

- **O check de humor não tinha rolagem.** Com os chips e o campo novos, mais o cartão de
  sugestão aberto, o conteúdo passava da altura do sheet em 420×940 e apareceria a faixa de
  estouro — na demonstração. Achado pela inspeção visual, porque nenhum teste olha overflow.

### Detalhe que evitou uma regressão silenciosa

O dataset de demonstração ganhou um **gerador de aleatórios próprio** para o contexto.
Sortear do mesmo `Random` deslocaria toda a sequência seguinte, mudando métodos e durações de
todas as sessões — e com elas os números já publicados na documentação e nos prints. Foi
notado porque os números mudaram na tela; com dois geradores, a demonstração voltou a ser
idêntica.

### Sobre o pedido, e o que a pesquisa mudou nele

Categorizar sessão por tag **é table stakes**: Forest, Toggl e Focus To-Do já fazem. Por isso
o campo não entrou sozinho — entrou junto do insight que o transforma em algo que nenhum
concorrente consegue dizer, porque nenhum deles pergunta o humor. Registro em
[`DECISOES.md`](docs/DECISOES.md) §22.

## [1.4.0] — 2026-08-19

O app funcionava, era bonito e estava sem graça. Duas mudanças, e nenhuma delas é enfeite.

### Adicionado

- **Ficha de personagem** na aba Resumo: uma classe (Maratonista, Ritmista, Sprinter,
  Explorador) e quatro atributos — Constância, Recuperação, Amplitude e Profundidade —
  **todos derivados das sessões reais**. `buildCharacterSheet` reaproveita `effectiveStreak`,
  `_moodBucket` e `methodById`; não precisou de dado novo.
- **Quinta descoberta: "Seu limite real"** — acima de quantos minutos as sessões passam a
  terminar pior. Exige 30 sessões e, com as 22 da demonstração, **nasce trancada** mostrando
  "faltam 8". A aba Insights passou a abrir em **"4 de 5 desbloqueadas"**.
- Sete testes novos: classe por método dominante, atributos dentro de 0–100, saturação em 100
  sem estourar a barra, recuperação, ficha sem sessões, a quinta descoberta trancada com o
  dataset demo, e a ficha aparecendo na tela. **77 testes**.

### Alterado

- **O texto dos pontos parou de mentir.** Dizia que eles eram "o combustível"; agora diz que
  são contagem e que o que evolui é a ficha. O README sempre prometeu *"descobertas pessoais,
  não pontos genéricos"* e o app entregava pontos genéricos — a contradição acabou.
- O teste que exigia "nenhuma descoberta trancada" foi reescrito para exigir **exatamente
  uma**. O que era garantia de tela cheia virou garantia de progressão visível.

### O que foi recusado, e por quê

O pedido era "uma pegada de RPG". **XP, níveis e medalhas foram descartados**: seriam a
gamificação genérica contra a qual o produto se posiciona, e a pesquisa de concorrência do
próprio projeto aponta que os apps do nicho erram exatamente aí. Registrado em
[`DECISOES.md`](docs/DECISOES.md) §20.

## [1.3.1] — 2026-08-19

Duas perguntas respondidas por escrito, sem tocar em código.

### Adicionado

- **Decisão 19 — por que o arquivo único ficou.** Registrada com o argumento inteiro,
  inclusive onde a crítica é procedente e qual seria a divisão correta num projeto que
  continuasse. O ponto que decide: o código **já é em camadas**, e mover texto para pastas
  sem mudar o grafo de dependências seria movimento, não arquitetura.
- **A divisão em arquivos entrou no roadmap** do README, como adiamento declarado.
- Duas perguntas prováveis no roteiro de apresentação: o arquivo único e os avisos do build.
- `FLUTLAB.md` §4.1.1: a linha do tree-shaking da fonte de ícones — 1,6 MB para 7 KB — é
  otimização, e aparece junto dos avisos assustando pelo mesmo motivo.

### Alterado

- **`FLUTLAB.md` §4.1 troca afirmação por prova.** Antes argumentava a partir do projeto ("o
  app não traz dependência com código nativo"). Agora argumenta a partir do plugin que
  dispara o aviso: `shared_preferences_android` **não tem nenhum** `.c`, `.cpp`, `.h`, `.so`,
  `CMakeLists.txt` ou `.mk`, e o `build.gradle` dele nem menciona `ndkVersion` — a exigência
  da 27 vem do AGP 8.12.1 que ele declara, como padrão de versão. É comparação de metadado,
  não problema de compilação.

## [1.3.0] — 2026-08-19

Passada de design. O app funcionava e estava verificado; o que faltava era **coerência
visual** — cada tela foi construída em separado e juntas não formavam um sistema.

### Adicionado

- **Regra de cor explícita**: `kBrandIndigo` é a estrutura do app, `AuraClimate.accent` é o
  estado do usuário, e cores semânticas são a única exceção. Escrita na docstring da
  constante, não só num documento.
- **Barras comparativas** no insight principal (`InsightComparison`): a tese do app deixa de
  ser narrada num parágrafo e passa a ser desenhada. Sem `fl_chart` — é a razão entre duas
  larguras.
- **Hierarquia entre os insights**: o primeiro desbloqueado ganha fundo índigo suave e número
  maior; os outros recuam. Antes os quatro competiam com peso idêntico.
- Três testes novos: as duas médias expostas para desenho, o piso da barra menor, e o insight
  bloqueado não carregando comparação. **70 testes**, em Flutter 3.32.8 e 3.47.0.

### Alterado

- **A AppBar mostra a marca do app.** Era `climate.icon`, um símbolo que mudava com o estado
  — o app nunca exibia a própria marca. Agora é o `AuraMark`, a mesma forma do ícone e da
  abertura, com o clima aparecendo na cor do brilho.
- **O anel do cronômetro virou o elemento herói da tela**, que era justamente o mais apagado
  dela: trilha visível, traço de 14 para 18, raio de 108 para 120, progresso em índigo e o
  tempo em corpo maior com tracking fechado.
- **Fim de ~400 px de espaço morto** nas abas Foco e Resumo.
- **Sistema de ícones unificado**: todos outline, seguindo a regra de cor. Saíram
  `Colors.amber`, `Colors.deepOrange` e `0xFF6D5B9E`.
- Prints da documentação regerados.

### Corrigido

- O halo do anel tinha `alpha 0.10` mesmo com o cronômetro parado. Como a sombra de um
  círculo é preenchida, isso aparecia como um disco esverdeado no miolo do anel. Agora o halo
  só existe enquanto a sessão roda — que é o que ele significa.
- O título do cartão do cronômetro era verde-água enquanto o anel era índigo. Passou a
  acompanhar a cor do anel.

### Nota de entrega

**Isto invalida o APK de 8,5 MB** gerado do commit `48b7e72`. Depois do merge é preciso
reimportar no FlutLab e gerar de novo como `arm64`.

## [1.2.1] — 2026-08-19

O que o build do APK final ensinou. Só documentação.

### Adicionado

- **Como conferir a ABI do APK depois de gerado** ([`FLUTLAB.md`](docs/FLUTLAB.md) §3.1):
  renomear para `.zip` e olhar dentro de `lib/`. O log do build **não** revela o alvo — mostra
  `assembleRelease` para os dois — e o tamanho do arquivo também não. O arquivo revela.
- **Os stack traces de cache do Gradle** ([`FLUTLAB.md`](docs/FLUTLAB.md) §4.3): dezenas de
  `CorruptedCacheException` no `file-access.bin` no meio do build, vindas de um worker
  assíncrono que escreve a contabilidade do cache compartilhado do FlutLab. Não é saída de
  build e não é deste projeto; o sinal que vale é `Build completed successfully` no fim.

### Alterado

- [`ENTREGA.md`](docs/ENTREGA.md) reorganizado: merge, reimportação, `Get Packages` e geração
  do APK saíram da lista de pendências. **Instalar o APK final no celular** passou a ser o
  único item bloqueante.
- O APK final está identificado por commit e tamanho — **`48b7e72`, 8,5 MB, alvo `arm64`** —
  em vez de só "o APK". É o que prova que ele tem a abertura e a animação, e não uma versão
  anterior.

### Corrigido

- A descrição do PR #10 no GitHub afirmava conter dois commits. Continha um: o da animação. A
  passada na documentação era o PR #11.

## [1.2.0] — 2026-08-19

Passada completa na documentação. O código não mudou — só `.md`, um script e uma imagem.

### Adicionado

- **`docs/ENTREGA.md`**: checklist único até 24/08, com dono por item. As pendências estavam
  duplicadas em dois documentos que já divergiam entre si.
- **`docs/FLUTLAB.md`**: importar, buildar como `arm64`, os dois avisos esperados e a razão
  de cada versão travada. Recebeu a profundidade operacional que inchava o README.
- **`docs/USO-DE-IA.md`**: como o projeto foi construído com IA e, principalmente, os três
  diagnósticos que ela errou e o que provou o contrário em cada caso.
- **`NOTICE.md`**: atribuição do material Apache-2.0 vendorizado em `.claude/`, que estava
  sendo redistribuído sem a licença nem o crédito exigidos.
- **`tool/verifica_docs.sh`**: compara os números afirmados na documentação com os reais.
  Validado com teste de controle — pega exatamente o "65 testes" que escapou da rodada
  anterior.
- Mapa navegável de `lib/main.dart` com as linhas dos 15 banners, e dois diagramas Mermaid
  (ciclo de vida de uma sessão e máquina de estados da sequência) em `ARQUITETURA.md`.
- Matriz de rastreabilidade em `RELATORIO-E2E.md`: cada regra do produto → a função que a
  implementa → o teste que a trava.
- Decisões 15 (uma única animação contínua) e 16 (marca desenhada em widgets) em
  `DECISOES.md`.
- Seção da abertura no manual e Passo 0 no roteiro de apresentação, com
  `docs/img/00-abertura.png`.

### Corrigido

- `docs/APRESENTACAO.md` afirmava **65 testes** em dois lugares, um deles a tabela de números
  para os slides. São 67 desde a versão anterior.
- A contagem de linhas de `lib/main.dart` estava errada em quatro documentos: `~3.400` em
  três e `3.438` em um. São **3.684**.

### Alterado

- README reestruturado de 193 para 123 linhas: pitch, prints, índice e os diferenciais —
  incluindo a abertura e a animação, que não apareciam em lugar nenhum dele.

### Registrado

- No web a `AuraLoadingScreen` **não chega a ganhar um quadro**: o armazenamento local
  resolve antes da primeira pintura. Descoberto ao tentar capturá-la em 296 quadros
  seguidos. No Android quem cobre essa janela é a tela nativa, com o mesmo degradê.

## [1.1.0] — 2026-08-18

Camada de animação e abertura própria. O app abria em três telas desconexas — flash branco,
spinner pelado e interface — nenhuma com a identidade do Aura.

### Adicionado

- **Abertura contínua**: tela nativa (Android e iOS) com o índigo e a marca do ícone,
  `AuraLoadingScreen` na mesma cor e dissolvência para a cor da aura do usuário.
- **`AuraMark`**: a marca desenhada em widgets, sem asset — acompanha qualquer tamanho sem
  perder nitidez.
- **Animações finitas**: troca de aba com dissolvência e deslize, entrada escalonada dos
  cards de insight e dos gráficos (`EntranceFade`), barras e linha do `fl_chart` crescendo,
  e progresso suave no anel do cronômetro.
- **Halo que respira** em volta do anel enquanto a sessão roda — a única animação contínua
  do app, parada em todos os pontos onde a sessão para.
- Dois testes que travam esse comportamento: o halo animando durante a sessão e parando ao
  pausar, e a tela de carregamento não deixando animação presa.

### Alterado

- Os dois testes que rodam o cronômetro passaram a usar `pump(Duration)` no lugar de
  `pumpAndSettle`, que esperaria a animação contínua terminar — ou seja, para sempre.

## [1.0.0] — 2026-08-18

Primeira versão completa: MVP entregue, verificado em dois SDKs e rodando em aparelho real.

### Adicionado

- **Sugestão adaptativa de duração** (item do roadmap): ao informar o humor antes da sessão,
  o app sugere o método que historicamente funciona melhor naquele estado, ou não sugere
  nada quando não há evidência suficiente.
- **Ícone próprio**, incluindo ícone adaptativo para Android 8+, no lugar do padrão do
  Flutter.
- **Documentação do repositório**: relatório de verificação ponta a ponta, arquitetura,
  registro de decisões, manual do usuário e roteiro de apresentação.
- Identidade real do app: `applicationId` `br.com.renatoalves.aura` e bundle identifier do
  iOS no lugar dos placeholders do template.

### Corrigido

- `CheckboxListTile` dentro do `AuraCard` não dava retorno visual ao toque, porque o cartão
  é um `Container` com fundo próprio entre ele e o `Material` mais próximo. Detectado por
  uma asserção que só o Flutter 3.47 emite; o defeito existia nas duas versões.
- A sugestão adaptativa continuava marcada ao trocar de humor, o que aplicaria um método que
  o usuário nunca chegou a ver.

---

## PR #8 — 2026-08-18

### Corrigido

- Avisos do Analyzer do FlutLab sobre regras de lint não reconhecidas, silenciados com
  `included_file_warning: ignore`. O código de diagnóstico foi validado com um teste de
  controle. Subir o `flutter_lints` **não** resolveria: as regras seguem ativas no
  `package:lints` até a 6.1.0.
- Acento faltando na descrição do app ("voce" → "você"), apontado em revisão.

## PR #7 — 2026-08-18

Primeira inspeção visual do app rodando. Três problemas que nenhum teste pegaria.

### Corrigido

- Tela Resumo abria incoerente: "0 dias de sequência" e "0 pontos" ao lado de "20 sessões
  totais". Sequência e pontos passam a ser derivados das próprias sessões.
- O insight "Focar muda seu humor" se contradizia (+0.3, 50% das sessões), porque o dataset
  tinha muitas sessões começando no humor máximo, onde a escala trunca o ganho. Agora +0.7 e
  73%.
- Sobras do template do FlutLab visíveis para o usuário: `CFBundleDisplayName` duplicado no
  iOS com "Hello World", `android:label` minúsculo e `hello_world` no título da página web.

### Alterado

- `ndkVersion` volta para a do SDK. O pin na 27 tinha sido adicionado sob uma hipótese que
  se provou errada e virou risco de build sem benefício.

## PR #6 — 2026-08-18

### Corrigido

- Corrupção de dados no armazenamento local era descartada em silêncio; agora é registrada e
  aparece na tela Sobre.
- A tela Sobre exibia erro obsoleto após o usuário limpar os dados.
- O caminho de recuperação podia falhar sozinho, deixando o usuário preso no botão de última
  saída.

## PR #5 — 2026-08-18

### Adicionado

- Captura global de erros (`FlutterError.onError`, `platformDispatcher.onError`,
  `runZonedGuarded`) e tela de erro legível, com texto selecionável.
- `try/catch` na leitura de listas do armazenamento local: antes, um único registro
  malformado deixava o app impossível de abrir para sempre.

## PR #4 — 2026-08-18

### Corrigido

- `Get Packages` falhava no FlutLab. Eram dois conflitos: `shared_preferences` 2.5.4+ exige
  Dart ≥ 3.9 (o Flutter 3.32 traz 3.8.1), e `fl_chart` 1.1.1+ exige `vector_math ^2.2.0`.
  A `fl_chart` foi fixada na 1.0.0 — a 1.1.0 resolve mas **não compila**, então uma faixa
  aberta cairia justamente nela.

## PR #3 — 2026-08-18

### Alterado

- Projeto Flutter movido de `Aura/` para a raiz do repositório. O FlutLab exige o
  `pubspec.yaml` no primeiro nível para importar de um repositório.

## PR #2 — 2026-08-18

Implementação do MVP sobre a base do FocusFlow.

### Adicionado

- `StudySession` com humor antes e depois, método e vínculo com tarefa.
- Check de humor (escala 1–5) antes e depois de cada sessão.
- 11 métodos de foco sobre o mesmo cronômetro, incluindo Flowtime (contagem progressiva) e
  Personalizado.
- Motor de insights em Dart puro, com 4 comparações e limiares de desbloqueio.
- Sequência com perdão: 1 folga a cada 3 dias seguidos, teto de 3.
- Clima pessoal em 4 estados, reagindo às sessões recentes.
- Dataset de demonstração determinístico, removível na tela Sobre.
- Tela Sobre com a mensagem de privacidade.
- Gráficos `fl_chart`: correlação humor × duração e ritmo dos últimos 7 dias.

### Corrigido

- Estouro horizontal na linha de botões do cronômetro em telas estreitas, encontrado por
  rodar os testes de interface em viewport de telefone.

## PR #1 — 2026-08-18

### Adicionado

- Agents, skills e commands em `.claude/`, do `rohitg00/awesome-claude-code-toolkit`
  (Apache-2.0), copiados como arquivos markdown. A marketplace oficial de plugins não pôde
  ser usada: todas as entradas do manifesto têm o campo `source` sem o prefixo exigido pelo
  schema do CLI.
- `.gitignore` de projeto Flutter, que faltava.

---

## Antes do PR #1

O repositório continha apenas o projeto padrão gerado pelo FlutLab — um "Hello World" sem
nenhuma dependência ou lógica do Aura.
