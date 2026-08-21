# Registro de Decisões — Aura

Por que o código é como é. Inclui as decisões que **deram errado** e foram revertidas —
são as mais úteis, porque evitam que alguém refaça o mesmo caminho.

Formato: contexto → decisão → consequência.

---

## 1. Tudo em um arquivo só

**Contexto.** O app roda no FlutLab.io, um IDE Flutter no navegador. A especificação do
projeto registra que o FlutLab tem problemas com arquitetura multi-arquivo no navegador e
proíbe imports relativos.

**Decisão.** Todo o app em `lib/main.dart`, com a separação feita por banners de seção em
vez de por pastas.

**Consequência.** 4.774 linhas em um arquivo. Para compensar, a lógica de negócio é
escrita como funções puras que não importam nada do Flutter, e é atacada diretamente pelos
testes. A ordem das seções é significativa: cada uma só depende das anteriores.

---

## 2. `setState` em vez de Provider

**Contexto.** A documentação oficial do projeto registra a justificativa: *"StatefulWidget +
setState (evita riscos de compatibilidade com Provider no FlutLab)"*.

**Decisão.** Estado no `_HomeShellState`, passado para baixo por parâmetro, com callbacks
subindo.

**Consequência.** Nenhum pacote de estado. Em troca, `_HomeShellState` concentra bastante
responsabilidade. Mitigação: `_recordSession` é o **único** ponto de entrada de uma sessão
concluída, e `_applySessions` o único ponto que troca o conjunto de sessões — assim o
estado derivado (pontos, sequência) não tem como divergir.

---

## 3. Armazenamento local, sem backend nem login

**Contexto.** Restrição da atividade, mas também posicionamento: privacidade é um
diferencial declarado do produto para um público jovem.

**Decisão.** `shared_preferences` com JSON. Nenhuma rede.

**Consequência.** O app funciona offline e os dados somem se for desinstalado — o que a tela
Sobre diz explicitamente. Também significa que dado corrompido é fatal se não for tratado;
ver decisão 8.

---

## 4. `fl_chart` fixado na versão 1.0.0 — não em faixa

**Contexto.** O `Get Packages` do FlutLab falhava com `version solving failed`. Reproduzido
localmente instalando o Flutter 3.32.8, a mesma versão do FlutLab.

Eram dois conflitos:

- `shared_preferences` 2.5.4+ exige Dart ≥ 3.9, e o Flutter 3.32 traz Dart 3.8.1.
- `fl_chart` 1.1.1+ exige `vector_math ^2.2.0`, enquanto o `flutter_test` do 3.32 fixa a
  2.1.4.

A leitura óbvia seria descer para a `fl_chart` 1.1.0, a última que declara `^2.1.4`.
**Mas a 1.1.0 não compila:** ela declara `^2.1.4` e mesmo assim chama
`Matrix4.translateByDouble` e `scaleByDouble`, que só existem na 2.2.0. Passa no `pub get`,
passa no `analyze`, e só quebra na compilação.

**Decisão.** `fl_chart: 1.0.0` — pin exato, não faixa. `shared_preferences: ^2.5.3`, com
caret, porque aí o problema é só de SDK e o pub sobe sozinho num ambiente mais novo.

**Consequência.** Uma faixa aberta como `^1.1.0` cairia justamente na versão quebrada, já
que o pub não enxerga erro de compilação. O pin está comentado no `pubspec.yaml` para
ninguém "modernizar" isso de volta sem entender o motivo.

---

## 5. NDK fixada na 27 — e depois revertida

**Contexto.** O build do FlutLab avisa que `shared_preferences_android` exige a NDK
`27.0.12077973`, enquanto o Flutter 3.32 usa a 26.3.11579264. Na época, a hipótese para o
app fechar ao abrir era desalinhamento de memória de 16 KB, exigência do Android 15+ — e a
r27 é a primeira que alinha as libs nativas nesse tamanho.

**Decisão inicial.** Fixar `ndkVersion = "27.0.12077973"`.

**Reversão.** A causa real do crash era outra (decisão 6). Com ela conhecida, o pin perdeu o
benefício e sobrou o risco: fixar a 27 exige que o ambiente de build tenha essa NDK
instalada, o que não dá para garantir no FlutLab, e o APK arm64 que funciona no aparelho foi
gerado **sem** o pin. O projeto também não traz nenhuma dependência com código nativo
próprio — as únicas libs `.so` vêm da engine do Flutter, que já cuida do alinhamento.

**Consequência.** Voltou para `flutter.ndkVersion`. O aviso continua aparecendo no FlutLab e
está documentado no README como esperado. Trocar duas linhas de aviso por uma possível
falha de build às vésperas da apresentação não compensava.

---

## 6. O APK precisa ser gerado como `arm64`

**Contexto.** O APK instalava, abria e fechava, com a mensagem genérica do Android
("este app tem um bug") e nenhum stack trace.

**Investigação.** Foi tratado primeiro como falha de instalação, depois como alinhamento de
16 KB. Chegou a ser instalado um capturador global de erros com tela legível — que nunca
apareceu.

**Causa real.** O alvo `android arm` produz binário só de 32 bits (`armeabi-v7a`). Em
aparelho arm64 a engine nativa não carrega, e o app morre **antes de qualquer código Dart
rodar**. Era por isso que a tela de erro em Dart não podia aparecer: o sintoma "apareceu a
caixa do Android e não a tela do app" era, ele próprio, a prova de que a falha era nativa.

**Decisão.** Gerar sempre como **`android arm64`**. Registrado no README, com destaque.

**Consequência.** Instrumentação em Dart é inútil contra falha nativa. Vale lembrar disso
antes de investir em observabilidade do lado errado da fronteira.

---

## 7. Campo `isDemo` no `StudySession`

**Contexto.** A especificação define `StudySession` sem esse campo. Mas o app precisa poder
remover só o dataset de demonstração, sem levar junto as sessões reais do usuário.

**Decisão.** Adicionar `isDemo`, com `false` como padrão no `fromJson`.

**Consequência.** Desvio consciente da especificação, retrocompatível: dados gravados sem o
campo continuam abrindo.

---

## 8. Dado corrompido não pode impedir o app de abrir

**Contexto.** `loadSessions` e `loadTasks` faziam `jsonDecode` sem `try/catch`. Um único
registro malformado no armazenamento local derrubaria o app na inicialização — para sempre,
sem outra saída além de reinstalar.

**Decisão.** `AuraStore._loadList` envolve o decode em `try/catch`, descarta o valor
ilegível e **registra o motivo** em `AuraCrashReport`, que aparece na tela Sobre.

**Consequência.** Descartar em silêncio esconderia do usuário que ele acabou de perder
dados. A tela de erro também ganhou um botão de limpar dados locais, atrás de confirmação,
como última saída.

---

## 9. Sequência e pontos derivados das sessões

**Contexto.** O dataset de demonstração gravava as sessões mas não o estado que elas
implicam. O app abria mostrando "0 dias de sequência" e "0 pontos" ao lado de "20 sessões
totais" e "813 minutos focados".

**Decisão.** `streakFromSessions` reaplica `applyActivity` dia a dia sobre as sessões, e
`pointsFromSessions` calcula os mesmos 10 pontos por sessão que o app credita em uso normal.
O recálculo roda ao semear a demo e ao ligar/desligar ela.

**Consequência.** O estado derivado não tem como divergir do conjunto de sessões. Reaplicar
a regra existente foi preferível a gravar um número escolhido a dedo — que seria mais rápido
e mentiria na primeira vez que a regra mudasse.

---

## 10. A tela de erro não pode depender de ancestrais

**Contexto.** `AuraErrorScreen` é usada como `ErrorWidget.builder`, que o Flutter pode
chamar em qualquer ponto da árvore — inclusive acima do `MaterialApp`, onde não existem
`Directionality`, `MediaQuery` nem `Material`.

**Decisão.** Ela traz os próprios `Directionality` e `Material`, e não usa `Scaffold` nem
`SafeArea`.

**Consequência.** A primeira versão usava `Scaffold` + `SafeArea` + `SelectableText`: teria
lançado ao ser desenhada, virando um laço infinito de erro e escondendo justamente o erro
que veio mostrar. Há um teste que a desenha sem `MaterialApp` em volta para travar isso.

---

## 11. `applicationId` trocado, `namespace` mantido

**Contexto.** O projeto vinha com `com.example.aura`, placeholder do template.

**Decisão.** `applicationId = "br.com.renatoalves.aura"`; o `namespace` continua
`com.example.aura`.

**Consequência.** O `applicationId` é a identidade do app no aparelho e na loja; o
`namespace` é quem resolve o `android:name=".MainActivity"` do manifesto. Trocar o namespace
exigiria mover também o pacote Kotlin do `MainActivity`, e errar isso quebra o app na
abertura — exatamente o sintoma que já custou caro neste projeto. O ganho não justificava o
risco a seis dias da apresentação.

---

## 12. Ícone adaptativo, não só os PNGs legados

**Contexto.** Substituir apenas os `mipmap-*/ic_launcher.png` parecia suficiente.

**Decisão.** Adicionar também `mipmap-anydpi-v26/ic_launcher.xml`, com camada de fundo
(degradê em XML) e de frente (PNG transparente com zona segura de 62%).

**Consequência.** Sem o ícone adaptativo, o launcher do Android 8+ encolhe a arte dentro de
um badge branco em vez de mostrá-la como desenhada. O aparelho de teste é Android 16 — isso
apareceria na apresentação.

---

## 13. A sugestão adaptativa não chuta

**Contexto.** Item do roadmap implementado por reaproveitar o motor de correlação.

**Decisões.**

- Exige **2+ sessões** do método na mesma faixa de humor; abaixo disso não mostra nada.
- **Exclui Flowtime e Personalizado**: um não tem duração alvo, o outro depende do que o
  usuário configurou, então recomendá-los por duração média prometeria um número que a
  sessão não cumpre.
- Restringe à faixa de humor, mesmo que o insight de método olhe o histórico todo. São
  perguntas diferentes: "o que funciona quando estou assim" não é "o que funciona no geral".

**Consequência.** Pode haver sugestão enquanto o insight de método ainda está bloqueado, já
que este exige 6 sessões no total. A docstring diz isso explicitamente — uma versão anterior
afirmava que os dois "nunca se contradizem", o que era falso.

---

## 14. Avisos do FlutLab que ficam como estão

**Aviso da NDK** (aba Build): explicado na decisão 5. Ignorado de propósito.

**Aviso do Analyzer** sobre `no_wildcard_variable_uses` e `type_literal_in_constant_pattern`
não serem regras reconhecidas: vem do analisador do FlutLab, não do projeto. As duas regras
seguem na lista ativa do `package:lints` até a 6.1.0, e no mesmo Flutter 3.32.8 nem
`flutter analyze` nem `dart analyze` acusam nada. **Subir o `flutter_lints` não resolveria**
— só trocaria qual pacote lista as mesmas regras.

**Decisão.** `included_file_warning: ignore` no `analysis_options.yaml`, que silencia o
diagnóstico do arquivo incluído sem desligar nenhuma verificação do nosso código. O código
de diagnóstico foi validado com um teste de controle: um nome inexistente faz o analisador
responder `isn't a recognized error code`, e com `included_file_warning` ele não reclama.

---

## 15. Uma única animação contínua no app inteiro

**Contexto.** A interface era estática e a abertura era um corte seco. Adicionar animação era
o pedido; o problema é que animação e suíte de testes se atropelam.

`pumpAndSettle()` avança o relógio do teste até **todas** as animações terminarem. Uma
animação que repete indefinidamente nunca termina, então o teste espera até estourar o
tempo. A suíte usa `pumpAndSettle` em **25 chamadas** — uma animação contínua mal colocada
derruba a suíte inteira, não um teste.

**Decisão.** Só **uma** animação contínua no app: o halo que respira em volta do anel,
enquanto a sessão roda. Todas as outras são finitas — entram, terminam e param.

Três consequências práticas dessa decisão:

- O escalonamento do `EntranceFade` sai de um `Interval` na curva, **não** de
  `Future.delayed`. Assim continua sendo uma animação só, finita, e o `pumpAndSettle`
  termina. Com `Future.delayed` seriam N temporizadores soltos, que o teste não enxerga.
- `_breath` é parado em **todos** os pontos onde a sessão para: pausar, reiniciar, fim de
  ciclo e fim de Flowtime. Esquecer um deles deixaria o halo animando fora da sessão.
- Os dois testes que rodam o cronômetro usam `pump(Duration)` no lugar de `pumpAndSettle`.

**Consequência.** Dois testes travam esse comportamento: o halo animando durante a sessão e
parando ao pausar, e a tela de carregamento não deixando animação presa. Sem eles, a próxima
pessoa que adicionar um `repeat()` descobriria o problema como uma suíte inteira travando,
sem pista de qual mudança causou.

**Detalhe que só apareceu ao investigar uma falha:** depois de pausar, o que continuava
animando não era o halo — era o splash de tinta do botão que acabara de ser tocado. O teste
espera esse tempo de propósito, e o comentário no código diz isso, para ninguém "otimizar" a
espera de volta.

---

## 16. A marca desenhada em widgets, não como asset

**Contexto.** A abertura precisa mostrar a marca do Aura em pelo menos dois lugares: a tela
nativa (que só aceita bitmap) e a `AuraLoadingScreen` (que é Flutter).

**Decisão.** `AuraMark` é um `StatelessWidget` que desenha a marca com `Container` e
`BoxDecoration` — halos, anel âmbar e núcleo — recebendo o tamanho por parâmetro. O PNG
existe só onde é obrigatório: o ícone do launcher e a tela nativa de abertura.

**Consequência.** A marca acompanha qualquer tamanho sem perder nitidez e sem multiplicar
arquivos por densidade. E, como a tela nativa e a tela Flutter compartilham o mesmo degradê
(`#8B84FF` → `#4A41C7`, declarado nos dois lados), a passagem de uma para a outra não pisca.

**Limite conhecido.** As duas cores estão declaradas em dois lugares — `kSplashGradient` no
Dart e `launch_gradient.xml` no Android. Não há como compartilhar uma constante entre eles;
mudar uma sem a outra faz a abertura piscar. Está anotado nos dois arquivos.

---

## 17. Índigo é a estrutura; a aura é o estado

**Contexto.** O tema já era sedeado em índigo (`colorSchemeSeed: 0xFF6C63FF`), e o ícone e a
tela de abertura também. Mas a interface era verde-azulada, porque quase todo elemento
colorido usava `climate.accent` — a cor que muda com o estado do usuário. Resultado: o app
parecia trocar de produto entre a abertura e a primeira tela, e a marca do ícone não aparecia
em lugar nenhum depois disso.

Havia ainda uma incoerência maior. A AppBar mostrava `climate.icon`, um símbolo que **muda**
com o clima. O app portanto nunca exibia a própria marca.

**Decisão.** Uma regra, com uma exceção nomeada:

- **`kBrandIndigo` é a estrutura** — marca, anel do cronômetro, botões, números de insight,
  ícones de estatística. Não muda nunca.
- **`AuraClimate.accent` é o estado do usuário** — o gradiente de fundo, o brilho da marca,
  o halo do anel. Só isso.
- **Exceção: cores semânticas**, onde a cor *é* a informação — prioridade de tarefa
  (`_priorityColor`) e faces do check de humor (`moodColors`). Trocá-las apagaria
  significado.

A AppBar passou a mostrar o `AuraMark` — a mesma forma do ícone e da abertura —, com o clima
aparecendo na **cor do brilho** em vez de trocar o símbolo. Identidade constante e sinal de
clima no mesmo elemento.

**Consequência.** A regra é o que torna a interface conferível: qualquer cor fora dessas três
categorias é um desvio, e dá para apontar. Foi assim que sobraram visíveis, depois da
primeira passada, uma estrela âmbar na AppBar e um fogo laranja no cartão de sequência — os
dois últimos resquícios da paleta antiga.

A constante mora em `CONSTANTES DE APOIO` com a regra na própria docstring, porque uma regra
de cor que só existe num documento separado não sobrevive à próxima edição.

---

## 18. A tese do app passou a ser mostrada, não narrada

**Contexto.** O insight principal — o que carrega a tese do produto — dizia "suas sessões
duram em média 40.8 min... caem para 15 min" **dentro de um parágrafo de cinco linhas**. O
app existe para provar uma correlação, e a correlação estava escondida em prosa.

Os quatro cartões de insight também tinham peso visual idêntico, então nenhum vencia.

**Decisão.** `Insight` ganhou um campo opcional `comparison` (`InsightComparison`), e o
cartão desenha **duas barras proporcionais** quando ele existe. O primeiro insight
desbloqueado recebe tratamento de destaque: fundo índigo suave, mais respiro e número maior.

As barras são `Container` com `FractionallySizedBox`, **não** `fl_chart`. É a razão entre
duas larguras; trazer um gráfico completo custaria tempo de quadro numa tela que já desenha
dois gráficos de verdade logo abaixo.

**Consequência.** `InsightComparison.lowRatio` tem piso de `0.08`. Sem ele, uma diferença
extrema renderiza a barra menor com largura quase zero — ela some da tela, e some junto a
comparação que a barra existe para mostrar. Há um teste que trava exatamente esse piso.

O campo é opcional de propósito: os outros três insights não têm duas medidas comparáveis, e
inventar uma para preencher o formato seria pior do que não desenhar nada.

---

## 19. O arquivo único ficou — e por que a crítica a ele é procedente

**Contexto.** `lib/main.dart` tem 4.774 linhas. Em qualquer avaliação de código isso é o
primeiro apontamento, e com razão: arquivo único é prática ruim.

**A crítica está certa no geral.** Num projeto que continuasse, a divisão correta seria por
camada, com a lógica pura virando um pacote próprio, sem nenhuma dependência de Flutter:

```
lib/
├── models/        StudySession · TaskItem · FocusMethod · Insight
├── logic/         applyActivity · buildInsights · resolveClimate · suggestMethodForMood
├── storage/       AuraStore
└── ui/            HomeShell + as 5 telas + widgets compartilhados
```

**Decisão: manter o arquivo único.** Cinco motivos, em ordem de peso:

1. **A especificação da atividade proíbe.** §8 do `INSTRUCOES_PARA_CLAUDE_CODE.md`:
   *"Arquivo único: entregar tudo em `lib/main.dart`, sem imports relativos — o FlutLab tem
   problemas com arquitetura multi-arquivo no navegador."* É restrição declarada do ambiente
   de entrega, não preferência de estilo.

2. **Dividir arquivos não desacopla nada por si só.** Este é o ponto técnico que decide. O
   código **já é em camadas**: a faixa de lógica pura (562–1208) não importa nada do Flutter,
   e 63 dos 88 testes batem nela sem construir uma única tela. Mover esse texto para pastas
   sem mudar quem depende de quem deixaria o grafo de dependências **idêntico** — seria
   movimento, não arquitetura.

3. **O benefício não se realiza dentro da vida útil do projeto.** Separar arquivos paga ao
   longo de meses, com várias pessoas mexendo em paralelo e resolvendo conflitos de merge.
   Aqui é um autor e um prazo fechado.

4. **O problema real que a crítica aponta já tem solução.** Navegar 4.774 linhas é ruim —
   por isso existe o mapa de seções em [`ARQUITETURA.md`](ARQUITETURA.md) §1, com a linha de
   cada faixa e um `grep` que o reconstrói quando as linhas envelhecerem.

5. **Seria a mudança de maior risco por unidade de benefício disponível.** Toca todas as
   linhas do app, obriga a refazer o APK e a reverificar tudo, e o resultado visível para o
   usuário final é exatamente nenhum.

**Consequência.** A divisão está registrada como item de roadmap, não como dívida esquecida.
Se o projeto continuar depois da entrega, o primeiro passo é confirmar se a restrição do
FlutLab ainda é verdade: imports relativos dentro de `lib/` são Dart padrão, e essa proibição
pode ter virado folclore. Dá para testar em uma branch descartável, sem risco para a `main`.

---

## 20. Ficha de personagem em vez de XP

**Contexto.** O app estava sem graça, e o diagnóstico apontou motivos concretos, não falta de
enfeite:

- **Tudo estava no passado.** Havia **uma única** string em todo o app apontando para frente
  (`"Faltam N sessões para desbloquear"`), e ela nunca aparecia — ver decisão 21.
- **Os pontos não compravam nada.** `_points` só era incrementado e exibido. Pior: o README
  afirma que o diferencial são *"descobertas pessoais, não pontos genéricos"*, e o app
  entregava exatamente pontos genéricos. Contradizia o próprio posicionamento.
- **Nada ali era identidade.** "Minha sequência é 13" não é algo que se conte a alguém.

O pedido foi "uma pegada mais voltada a RPG". Isso se divide em duas coisas opostas.

**O que foi recusado.** XP, níveis, medalhas e avatar. Seria a gamificação genérica contra a
qual o produto se posiciona — e a pesquisa de concorrência do próprio projeto aponta que os
apps do nicho erram justamente aí. Somar XP por cima de um app de correlação de humor
deixaria o Aura *mais* parecido com os concorrentes, não menos, e contradiria o pitch em
dobro.

**Decisão.** Uma **ficha de personagem em que nenhum número é inventado**. Classe e atributos
saem das mesmas contas que já alimentam os insights: método dominante, sequência efetiva,
percentual de sessões que terminam melhor, diferença de duração entre faixas de humor e maior
sessão sustentada.

A frase que isso libera na apresentação é o ponto inteiro:
> Outros apps te dão XP por existir. O Aura te dá uma ficha que é medição do seu
> comportamento — se ela sobe, é porque você mudou, não porque você abriu o app.

**Consequência.** A ficha **reforça** o diferencial em vez de diluí-lo, e não custou dado
novo: `buildCharacterSheet` reaproveita `effectiveStreak`, `_moodBucket` e `methodById`.

Dois detalhes que decorrem da escolha:

- **Sem sessões, a ficha diz isso** em vez de mostrar quatro barras zeradas. Barra zerada
  mente sobre não haver dado — é o mesmo erro que a tela Resumo já cometeu uma vez (§9).
- **Cada atributo mostra o número real ao lado da barra.** A barra é leitura de relance; sem
  o número ela vira uma escala vaga, que é o problema de metade das fichas de RPG digitais.
  O valor satura em 100 e o número continua sendo dito por inteiro — há teste para isso.

**Os pontos ficaram**, mas pararam de fingir que são o prêmio: o texto da tela agora diz que
eles são contagem e que o que evolui é a ficha.

---

## 21. A quinta descoberta nasce bloqueada

**Contexto.** Os quatro insights abrem com 5, 5, 7 e 6 sessões. O dataset de demonstração tem
**22** — e havia um teste *garantindo* que os quatro abrissem, para nenhuma tela aparecer
vazia na apresentação.

O efeito colateral passou despercebido por muito tempo: **ninguém nunca via um cartão
trancado.** Nem um usuário novo, nem a plateia do dia da apresentação. A mecânica de
desbloqueio — que a especificação chama de núcleo inegociável — estava construída, testada, e
invisível.

**Decisão.** Uma quinta descoberta, **"Seu limite real"**, exigindo **30 sessões**: acima de
quantos minutos as sessões passam a terminar pior. Com as 22 da demonstração ela fica
trancada mostrando *"Faltam 8 sessões para desbloquear"*.

**Por que 30 não é arbitrário.** Uma conclusão sobre *teto* de duração precisa de volume para
não ser ruído: são três faixas de duração comparadas entre si, e o insight exige 3+ sessões
em cada uma. Com pouco dado, uma única sessão longa e ruim decidiria o resultado — diria mais
sobre aquele dia que sobre a pessoa.

**Consequência.** A aba Insights passou a abrir em **"4 de 5 desbloqueadas"**, com um cartão
visivelmente trancado e um contador. O app ganhou um "próximo" sem que nada precisasse ser
enfraquecido: a demonstração continua rica, com quatro descobertas abertas.

O teste que antes exigia "nenhuma trancada" foi reescrito para exigir **exatamente uma**, com
o `id` e o número que falta. O que era garantia de tela cheia virou garantia de progressão
visível.

---

## 22. Contexto de foco e o insight que o consome entram juntos

**Contexto.** O pedido era personalização: deixar a pessoa marcar se a sessão é acadêmica,
de trabalho, pessoal.

A pesquisa mostrou que **isso é table stakes, não diferencial**. O
[Forest](https://forestapp.cc/) tem tags (Study, Work, Writing) com filtro de analytics, o
[Toggl Track](https://toggl.com/track/focused-work/) tem projetos e tags, o Focus To-Do tem
projetos. Um seletor de "Acadêmico / Pessoal" sozinho **empata** com o mercado.

O que nenhum deles faz é cruzar a categoria com o humor. Todos respondem *"onde foi o meu
tempo"*. Nenhum responde:

> **Qual tipo de trabalho me esgota, e por quanto tempo eu aguento cada um.**

**Decisão.** O campo `contextId` e o insight *"Onde você rende mais"* entram **na mesma
mudança**, nunca separados. Separados, o campo é commodity e o insight é impossível.

O insight exige **8 sessões e 2 contextos com 3+ sessões cada**: comparar tipos de trabalho
com base em uma ou duas tentativas diria mais sobre aqueles dias que sobre a pessoa.

**Consequência.** Isto é o que o Aura tem de mais difícil de copiar — não porque a conta seja
complexa, mas porque exige o check de humor, que os concorrentes não pedem. A frase de
apresentação sai pronta: *"o Forest te diz onde o seu tempo foi; o Aura te diz qual trabalho
te custa caro"*.

**Dois detalhes que decorrem:**

- **`geral` é o padrão e o destino dos dados antigos.** Quem já tem o app instalado tem
  sessões gravadas sem este campo, e chamá-las de "Geral" é honesto — de fato não se sabe o
  que elas eram. Há um teste que carrega um JSON no formato antigo, porque este é o risco
  real de qualquer campo novo.
- **O dataset de demonstração ganhou um gerador de aleatórios próprio** (`ctxRnd`). Sortear o
  contexto do mesmo `rnd` deslocaria toda a sequência seguinte, mudando métodos e durações de
  todas as sessões — e com elas os números já publicados na documentação e nos prints. Com
  dois geradores, acrescentar o contexto não altera nada do que já existia.

---

## 23. Onde o perfil e a nota moram

**Contexto.** O pedido incluía descrever "o que está sendo ou será feito". Isso pode virar
duas coisas diferentes, e as duas foram implementadas por motivos distintos.

**Decisão.**

- **No perfil, uma declaração de foco atual** — *"o que você está focando neste período"*,
  ex.: "TCC sobre visão computacional". Um campo só, que aparece na ficha e dá contexto ao
  app inteiro sem repetir a aba Tarefas.
- **Por sessão, uma nota curta e opcional** — no check de humor de **antes**, junto dos chips
  de contexto.

**O perfil se edita a partir da própria ficha**, por um lápis no cartão, e não numa tela de
configurações escondida: ele é parte da ficha, e é ali que ele aparece. O botão existe também
no estado vazio da ficha — sem ele, alguém sem sessão nenhuma não teria como preencher o
perfil.

**Consequência, e o cuidado com atrito.** O momento de começar a focar é o pior lugar
possível para exigir digitação. Por isso:

- os chips **já vêm com o contexto do perfil marcado** — zero toque para quem não quer mudar;
- a nota é opcional e some do registro se ficar em branco;
- o check de humor **de depois não pergunta nada disso**: a pessoa acabou de focar, e pedir
  texto ali cobraria no momento de alívio.

**Um defeito que isso quase criou.** O `_MoodSheet` era um `Column(mainAxisSize: min)` **sem
rolagem**. Com os chips e o campo novos, mais o cartão de sugestão aberto, o conteúdo passa
da altura do sheet em 420×940 — e apareceria a faixa amarela e preta de estouro, na
demonstração. Virou `SingleChildScrollView`; a inspeção visual foi o que pegou isso, porque
nenhum teste olha para overflow.
