# Changelog

Histórico do projeto, do scaffold do FlutLab ao app entregue. Cada bloco corresponde a um
pull request mergeado.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

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
