# Registro de Decisões — Aura

Por que o código é como é. Inclui as decisões que **deram errado** e foram revertidas —
são as mais úteis, porque evitam que alguém refaça o mesmo caminho.

Formato: contexto → decisão → consequência.

---

## 1. Tudo em um arquivo só — histórico, depois parcelado

**Contexto.** O app roda no FlutLab.io, um IDE Flutter no navegador. A especificação do
projeto registrava risco com arquitetura multi-arquivo no navegador e proibia imports
relativos.

**Decisão inicial.** Todo o app em `lib/main.dart`, com a separação feita por banners de
seção em vez de por pastas.

**Atualização.** A manutenção de mais de 5 mil linhas no mesmo arquivo ficou cara demais. A
primeira refatoração segura separou o código em arquivos `part`: `main.dart` preserva a
entrada, o shell e as telas, enquanto `lib/src/aura_models.dart`, `lib/src/aura_store.dart`
e `lib/src/aura_logic.dart` guardam modelos, persistência e regras. Como `part` mantém uma
única biblioteca, os testes que importam `package:aura/main.dart` continuam enxergando a
mesma API pública.

**Consequência.** A organização melhora sem uma migração grande para múltiplas bibliotecas.
Se uma instância específica do FlutLab rejeitar arquivos `part`, a contingência é
concatenar os três arquivos de `lib/src/` de volta no `main.dart`, na ordem modelos → store
→ lógica.

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

> **Atualização.** "Nenhuma rede" valeu até a frase do dia (§24), a única exceção — e só ela:
> continua verdade para tarefas, sessões, ficha e os seis insights. O motivo da exceção, e o
> que foi feito para conter o risco dela, estão em [§24](#24-a-frase-do-dia--a-reversão-do-sem-api-registrada).

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

## 5. NDK: fixada, revertida, fixada de novo — e revertida de vez

**Contexto.** O build do FlutLab avisa que `shared_preferences_android` exige a NDK
`27.0.12077973`, enquanto o Flutter 3.32 usa a 26.3.11579264. Na época, a hipótese para o
app fechar ao abrir era desalinhamento de memória de 16 KB, exigência do Android 15+ — e a
r27 é a primeira que alinha as libs nativas nesse tamanho.

**Decisão inicial.** Fixar `ndkVersion = "27.0.12077973"`.

**Primeira reversão.** A causa real do crash era outra (decisão 6). Com ela conhecida, o pin
perdeu o benefício e sobrou o risco, então voltou para `flutter.ndkVersion`.

**O pin voltou uma segunda vez** — para "reduzir o ruído vermelho na entrega" — **e foi
revertido de novo em 22/08.** O que decidiu foi a evidência, conferida no
`~/.pub-cache/hosted/pub.dev/shared_preferences_android-2.4.13`:

| O que se procurou | O que se achou |
|---|---|
| `.c`, `.cpp`, `.h`, `.so`, `CMakeLists.txt`, `.mk` | **nada** — o plugin não tem uma linha de código nativo |
| `ndkVersion` no `android/build.gradle` dele | **não existe** — o plugin não declara NDK nenhuma |

**Não existe `.so` do plugin para a NDK proteger.** O aviso é comparação de metadado entre
números de versão declarados, e o pin não muda nada do que entra no APK.

**Decisão atual.** `ndkVersion = flutter.ndkVersion`. O aviso vermelho reaparece e está
documentado como esperado em [FLUTLAB.md §4.1](FLUTLAB.md).

**Por que o ruído cosmético perde para o risco.** Fixar a 27 exige aquela NDK instalada no
ambiente de build — o que não dá para garantir no FlutLab, e sem ela o build **falha antes de
compilar**. O APK que funciona no aparelho foi gerado **sem** o pin. Trocar um aviso que já
está explicado na documentação por uma chance de build quebrado às vésperas da apresentação
não compensa.

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

**Aviso da NDK** (aba Build): a decisão 5 passou a fixar a NDK 27 para silenciar o aviso quando o ambiente a tiver instalada.

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

## 19. O arquivo único foi parcelado em `part`

**Contexto.** `lib/main.dart` passava de 5 mil linhas. Em qualquer avaliação de código isso
é o primeiro apontamento, e com razão: arquivo único é prática ruim.

**Crítica aceita.** A divisão ideal de longo prazo continuaria sendo por camada, com lógica
pura em bibliotecas próprias e UI separada em telas/widgets:

```
lib/
├── models/        StudySession · TaskItem · FocusMethod · Insight
├── logic/         applyActivity · buildInsights · resolveClimate · suggestMethodForMood
├── storage/       AuraStore
└── ui/            HomeShell + as 5 telas + widgets compartilhados
```

**Decisão atual.** Fazer uma etapa intermediária e segura: manter uma única biblioteca Dart,
mas repartir o conteúdo em `part` files. Assim `lib/main.dart` continua sendo a entrada do
app e os testes não mudam de import, enquanto modelos, persistência e lógica saem do arquivo
principal.

**Consequência.** A base fica mais navegável e categorizada sem trocar todo o grafo de
dependências em uma única mudança. A etapa seguinte, se o FlutLab permitir, é transformar os
`part` files em bibliotecas reais com imports explícitos e separar a UI por telas.

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
  mente sobre não haver dado — é o mesmo erro que a aba Ficha já cometeu uma vez (§9).
- **Cada atributo mostra o número real ao lado da barra.** A barra é leitura de relance; sem
  o número ela vira uma escala vaga, que é o problema de metade das fichas de RPG digitais.
  O valor satura em 100 e o número continua sendo dito por inteiro — há teste para isso.

**Os pontos ficaram**, mas pararam de fingir que são o prêmio: o texto da tela agora diz que
eles são contagem e que o que evolui é a ficha.

---

## 21. A quinta descoberta nasce bloqueada <!-- historico -->

> **Esta seção é o registro da época, e os números dela envelheceram de propósito.** <!-- historico -->
> Quando ela foi escrita havia **cinco** descobertas e "Seu limite real" era a quinta. Depois
> entrou **"Onde você rende mais"** (§22), e hoje são **seis**: "Seu limite real" é a
> **sexta**, e a aba abre em **"5 de 6 desbloqueadas"**. A decisão — nascer bloqueada, com 30
> sessões — continua valendo exatamente como está descrita. O que mudou foi só a contagem em
> volta dela.

**Contexto.** Os quatro insights abrem com 5, 5, 7 e 6 sessões. O dataset de demonstração tem
**22** — e havia um teste *garantindo* que os quatro abrissem, para nenhuma tela aparecer
vazia na apresentação.

O efeito colateral passou despercebido por muito tempo: **ninguém nunca via um cartão
trancado.** Nem um usuário novo, nem a plateia do dia da apresentação. A mecânica de
desbloqueio — que a especificação chama de núcleo inegociável — estava construída, testada, e
invisível.

**Decisão.** Uma quinta descoberta, **"Seu limite real"**, exigindo **30 sessões**: acima de <!-- historico -->
quantos minutos as sessões passam a terminar pior. Com as 22 da demonstração ela fica
trancada mostrando *"Faltam 8 sessões para desbloquear"*.

**Por que 30 não é arbitrário.** Uma conclusão sobre *teto* de duração precisa de volume para
não ser ruído: são três faixas de duração comparadas entre si, e o insight exige 3+ sessões
em cada uma. Com pouco dado, uma única sessão longa e ruim decidiria o resultado — diria mais
sobre aquele dia que sobre a pessoa.

**Consequência.** A aba Descobertas passou a abrir em **"4 de 5 desbloqueadas"**, com um cartão
visivelmente trancado e um contador. O app ganhou um "próximo" sem que nada precisasse ser
enfraquecido: a demonstração continua rica, com quatro descobertas abertas. <!-- historico -->

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

## 24. A frase do dia — a reversão do "sem API", registrada

**Contexto.** O item 4 do [`ROADMAP.md`](ROADMAP.md) argumentava **contra** uma frase
motivacional por API, com cinco motivos — contradiz o "sem IA, sem API, sem rede" do README,
chave embutida em app cliente é extraível, quebra o uso offline, a especificação limita
dependências, e uma API sem os dados do usuário devolve motivação genérica. O usuário pediu a
reversão mesmo assim, depois de eu expor três fatos que pioram o risco original:

- **O repositório é público.** Uma chave em `lib/main.dart` fica visível a qualquer pessoa
  assim que o push sai — não "extraível do APK depois que alguém descompilar", e sim visível
  imediatamente, inclusive para bots que varrem pushes públicos atrás de chave de API.
- **O FlutLab não tem mecanismo de build-secret.** `docs/FLUTLAB.md` não menciona
  `--dart-define` nem variável de ambiente em lugar nenhum; o fluxo é só
  Import → Get Packages → Run/Build. Não existe hoje um jeito de manter a chave fora do git e
  ainda buildar pelo caminho que este projeto usa.
- Diante disso, perguntei três vezes antes de codar — se era mesmo para o Aura, como seguir
  com a chave exposta, e se reaproveitava a chave já colada no chat ou uma nova.

**Decisão.**

- **Só chave de tier gratuito, sem saldo vinculado** — Groq e Gemini, nunca DeepSeek ou
  OpenRouter com saldo. O pior caso de a chave vazar (e ela vai vazar, o repo é público) vira
  "a cota estoura e o recurso para de funcionar", nunca uma cobrança.
- **Groq como principal, Gemini como reserva** — não para dividir carga (o cache por dia já
  resolve isso, ver abaixo), mas para resiliência: se a Groq falhar, tenta a Gemini antes de
  desistir. É a ideia original do usuário ("juntar para não bater limite"), restrita às duas
  sem risco financeiro.
- **Uma chamada por usuário por dia, não por abertura de tela.** `AuraStore` guarda a frase e
  a data; se a data salva bate com hoje, nem tenta de novo. Com ~50 usuários isso soma ~50
  chamadas/dia no total — folga confortável mesmo no tier gratuito mais apertado.
- **O prompt manda só o resumo já calculado localmente** (classe, atributo mais forte, clima,
  contexto, foco do momento) — nunca o histórico bruto de humor, sessão por sessão. Minimiza o
  que sai do aparelho, já que a promessa de privacidade está sendo furada de qualquer forma.
- **Falha em silêncio.** Sem evidência (as duas chamadas falharam, ou não há chave
  configurada), o cartão simplesmente não aparece — mesma política de `suggestMethodForMood`.
  Isso importa em especial no dia da apresentação: sem wifi no local, o app precisa continuar
  parecendo inteiro, não expor um erro de rede na frente de quem avalia.
- **A chamada de rede real é desligada nos testes** por uma variável top-level
  (`debugDisableDailyLineNetwork`), ligada no `setUp` de `aura_app_test.dart`. Sem isso, os
  testes que navegam até a aba Ficha disparariam uma requisição de verdade: `pumpAndSettle`
  não espera por ela, o teste terminaria com a requisição pendente, e o card tentaria um
  `setState` numa árvore já descartada.

**O que ficou de fora.** Um proxy de backend segurando a chave do lado do servidor seria a
forma correta de fazer isso — mas é infraestrutura nova, hospedagem, autenticação própria, e
não cabe nos dias que restam até a apresentação. Fica registrado como o próximo passo real,
não como solução aceita.

**Nomes de modelo.** `openai/gpt-oss-20b` (Groq) e `gemini-2.5-flash` (Gemini) — conferidos
por pesquisa em 21/08/2026, porque os dois modelos que eu ia usar de memória (Llama 3.1 8B da
Groq, Gemini 2.0 Flash) tinham sido descontinuados no mesmo ano, em junho. Se a chamada parar
de funcionar um dia, comece verificando se o modelo mudou de novo antes de suspeitar de outra
coisa.

---

## 25. Reposicionamento: performance em vez de bem-estar emocional

**Contexto.** Na preparação da apresentação, as estatísticas de ansiedade que justificariam o
app (48,5%/43,5% dos alunos) não tinham fonte rastreável, e até as alternativas confiáveis
(ACHA-NCHA, JSIHS) puxariam a narrativa para saúde mental — fora do escopo da disciplina, e
um território que abriria a apresentação a perguntas de validação clínica que o projeto não
precisa responder.

**Decisão.** Reposicionar o discurso de "bem-estar emocional" para **"inteligência de
performance pessoal"**. O humor deixa de ser vendido como o produto e passa a ser tratado como
o que sempre foi no código: **um sinal de entrada que prevê desempenho**.

**É reposicionamento de linguagem, não de lógica.** Nenhum cálculo, campo do modelo de dados
ou limiar de desbloqueio mudou — só os textos visíveis ao usuário. `moodBefore`/`moodAfter`
continuam existindo e sendo usados exatamente como antes.

**O que mudou:**

- `_bucketNames`: "começa pra baixo/neutro/animado" → "começa em baixa/neutra/alta energia"
- Título de `mood_duration`: "Seu humor prevê seu foco" → "Seu estado de entrada prevê seu
  foco", e o fecho do corpo trocou "não de força de vontade" por "conforme a condição em que
  você começa a sessão"
- Título de `mood_delta`: "Focar muda seu humor" → **"Efeito colateral do foco"** — entre as
  duas opções levantadas, esta foi a que mais reduz centralidade emocional, porque sinaliza
  estruturalmente que a descoberta é secundária
- Ordem de `buildInsights()`: `mood_delta` passou de segundo para penúltimo — é o único
  insight estruturalmente sobre humor, não sobre desempenho, e agora fica atrás dos que
  vendem rendimento medido
- Corpo de `method`: "te deixa melhor no fim: humor final médio" → "é o que você mais
  sustenta: rendimento médio"
- Pitch do README, do `pubspec.yaml` e do roteiro de apresentação: "como você está se
  sentindo" → "o seu estado de entrada"

**O que ficou como estava, por já estar alinhado.** `_insightWeekday`, `_insightContext` e
`_insightDurationCeiling` (título e corpo) já eram linguagem de desempenho — "dia mais
produtivo", "você sustenta X min", "seu teto de duração". As cinco descrições de
`AuraClimate` também: falam de "sessões terminando bem/mal", que é comportamento observado,
não sentimento narrado.

**O que não foi feito.** Um tooltip de "leitura de prontidão" para o Clima Pessoal foi
cogitado, mas não existe hoje nenhum texto explicativo sobre o Clima Pessoal na tela Sobre ou
em tooltip — só o rótulo "Sua aura hoje" na aba Ficha. Criar um texto novo iria além de
"editar texto existente", e ficou registrado como pendência em aberto, não como feito.

**Consequência.** Dois testes citavam a redação antiga por conteúdo
(no grupo que checa o corpo do insight `mood_duration`, em `test/aura_logic_test.dart` —
as asserções liam `'começa animado'`/`'começa pra baixo'`) e foram atualizados para a nova redação — nenhum teste foi
removido, e nenhum precisou ser criado, porque os `id`s dos insights não mudaram.

**Atualização de 22/08 — a fundamentação chegou, e ela não reverteu esta decisão.** O autor
trouxe as fontes que faltavam: a **Attentional Control Theory** (Eysenck, Derakshan, Santos &
Calvo, em *Emotion*/APA), o relatório **On Edge** (Making Caring Common, Harvard), a pesquisa
**Stress in America** (APA) e a literatura de *dark patterns* sobre *streak anxiety*. Elas
estão agora em [`PRODUTO.md` §1 e §7](PRODUTO.md).

Isso resolve a objeção que originou este reposicionamento — a de que os números não eram
rastreáveis. Mas a **outra** objeção continua de pé, e por isso a decisão fica como está: o
Aura não se apresenta como ferramenta de saúde mental.

O encaixe funcionou porque a fonte principal ajuda dos dois lados: a Attentional Control
Theory é **ciência cognitiva de desempenho**, não clínica. Ela explica por que o estado de
entrada consome memória de trabalho e derruba inibição e flexibilidade cognitiva — ou seja,
**fundamenta exatamente a tese de performance** que este reposicionamento adotou, em vez de
puxar de volta para o território que ele quis evitar. Harvard e APA entram só como contexto da
pressão sobre o público, sem nenhuma afirmação clínica.

---

## 26. A abertura terminava num flash preto em aparelho no modo escuro

O §16 cuidou da **tela de abertura** e concluiu que *"a passagem de uma para a outra não
pisca"*, porque a tela nativa e a tela Flutter compartilham o mesmo degradê. Isso está certo
para o `LaunchTheme` — e é só metade do caminho.

O que o `AndroidManifest.xml` faz depois:

```xml
<meta-data android:name="io.flutter.embedding.android.NormalTheme"
           android:resource="@style/NormalTheme" />
```

Com esse `meta-data`, a `FlutterActivity` **troca de `LaunchTheme` para `NormalTheme` ainda no
`onCreate`**, antes de o Flutter desenhar o primeiro frame. Então quem aparece na tela nesse
intervalo não é o `launch_background` corrigido: é o `windowBackground` do `NormalTheme`.

E os dois `NormalTheme` estavam como vieram do template:

| Arquivo | Parent | `?android:colorBackground` resolve para |
|---|---|---|
| `values/styles.xml` | `Theme.Light.NoTitleBar` | branco |
| `values-night/styles.xml` | `Theme.Black.NoTitleBar` | **preto** |

O caso do modo escuro é o grave. O Aura **não tem tema escuro** — `brightness: Brightness.light`
está fixo no `ThemeData` de `lib/main.dart`, e os cinco climas da aura são todos degradês
claros. Num aparelho em modo escuro a sequência era:

```
índigo (LaunchTheme)  →  PRETO (NormalTheme)  →  app claro (primeiro frame)
```

Um flash preto entre duas telas claras, em cima de uma abertura que existe justamente para a
transição ser contínua. No modo claro o mesmo defeito existe, mas quase não se vê: branco
contra `#F4F2FB` é diferença pequena.

**Decisão:** os dois `NormalTheme` passam a usar `@color/aura_window_background`, novo em
`values/colors.xml`, com o valor `#F4F2FB` — o primeiro tom do degradê do app. A janela atrás
da interface passa a ser a cor do app em vez da cor do tema do sistema, e o modo escuro para
de receber um valor que o app nunca usa.

### O que foi verificado, e o que não foi

**Não vi o flash.** Não há aparelho neste ambiente, e emulador tampouco — o `flutter doctor`
aqui não acha Android SDK nenhum. O que está verificado é a leitura do caminho: o `meta-data`
existe no manifest, os dois parents são os que a tabela acima diz, e o `ThemeData` do app é
claro e fixo.

Isso muda um item do [`ENTREGA.md` §3.2](ENTREGA.md), que dizia:

> A abertura é em índigo com a marca — **se piscar branco, o APK é de uma versão antiga**

O diagnóstico não separava as duas causas. Um APK **correto** podia piscar por causa do
`NormalTheme`, e a conclusão seria refazer o build na véspera à toa. O §3.2 foi reescrito.

**A hora de corrigir era esta.** O APK vai ser refeito de qualquer forma antes da
apresentação; entrando junto, o conserto custa zero. Descoberto depois da instalação, custaria
um ciclo inteiro de reimportar, buildar e instalar de novo.

É também a única mudança fora de `docs/` aceita nesta altura do projeto: é recurso Android,
não toca em `lib/`, e por isso não mexe em nada que os 100 testes cobrem.
