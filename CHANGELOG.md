# Changelog

Histórico do projeto, do scaffold do FlutLab ao app entregue. Cada bloco corresponde a um
pull request mergeado.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

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
