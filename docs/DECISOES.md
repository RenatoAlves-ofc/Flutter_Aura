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

**Consequência.** ~3.400 linhas em um arquivo. Para compensar, a lógica de negócio é
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
