# Plano V2 — dez melhorias, verificadas contra o código

Segunda rodada de planejamento, pedida em 21/08. Cada item foi **verificado no código antes
de entrar aqui** — dois já estavam feitos (um deles inteiro), e num deles eu tinha escrito
uma afirmação errada no [`ROADMAP.md`](ROADMAP.md), corrigida abaixo.

O tratamento é o mesmo do roadmap anterior: **o que é, o diagnóstico com linha, o plano, o
custo e o que quebra**. Um plano que só lista desejos não ajuda a decidir.

> **A apresentação é 24/08.** Faltam 3 dias, e este documento tem 10 itens. A §12 propõe o
> corte: o que protege a demonstração e o que pode esperar. Não dá para fazer os dez.

---

## 1. Onde cada item está, antes de qualquer coisa

| # | Item | Estado real, verificado |
|---|---|---|
| 1 | Padronizar as cores dos dados | **não feito** — causa isolada, 1 linha |
| 2 | Explicar os métodos de estudo | **não feito** — `FocusMethod` não tem campo de descrição |
| 3 | Frase motivacional após o cronômetro | **motor pronto**, falta a chave e mudar o lugar |
| 4 | Juntar tarefa ao temporizador | **metade já existe** — ver a correção na §5 |
| 5 | Cronômetro em segundo plano | **não feito** — e são **dois** defeitos, não um |
| 6 | Subir o popup | **não feito** — causa isolada, achada |
| 7 | Renomear "Resumo" (RPG) | **não feito** — decidido: **Ficha** |
| 8 | Lugar para editar o perfil | **não feito** — hoje só existe um caminho |
| 9 | Insights em português + humor final | **não feito** — o inglês é o nome da aba |
| 10 | Nova logo | **bloqueado** — o arquivo não existe ainda (§11) |

---

## 2. Cores dos dados — roxo, não verde

**O diagnóstico é uma linha só.** `lib/main.dart:3835`, dentro de `_MoodDurationChart`:

```dart
BarChartRodData(
  toY: e.value,
  width: 22,
  color: moodColors[e.key],   // ← aqui
)
```

`moodColors` é cinza, vermelho, laranja, âmbar, **verde** e **verde-azulado**. Como as barras
são pintadas por faixa de humor, o gráfico vira um arco-íris — e é dele que vem o verde ao
lado do roxo da interface.

**O resto já está certo, e isso importa para o tamanho do conserto.** O gráfico semanal
(`_WeeklyFocusChart`, linhas 3947 e 3951) usa `theme.colorScheme.primary`, derivado do índigo.
As barras comparativas dos insights usam `kBrandIndigo`. Nenhum lugar da aba usa
`climate.accent`. **A inconsistência inteira sai de uma linha.**

**Plano.** A barra passa a ser `kBrandIndigo`. As **faces de humor** do eixo (linha 3818)
continuam coloridas — ali a cor *é* a informação, que é a exceção já registrada em
[`ARQUITETURA.md` §7](ARQUITETURA.md).

O argumento não é estético, é de codificação: **a altura da barra representa a duração, não o
humor.** Quem diz o humor é o eixo, embaixo. Pintar a barra por humor é codificar duas vezes
a mesma coisa — e é justamente isso que produz o arco-íris.

**Custo:** baixo. Uma linha de código, mais recapturar o print `06-graficos.png`.

---

## 3. Explicar os métodos de estudo

**O buraco é real e continua igual.** `FocusMethod` (`lib/main.dart:329`+) tem `id`, `name`,
`focusMinutes`, `breakMinutes`, `isCustom` e `isFlowtime` — **nenhum campo de descrição**.

O app oferece "52/17" e "Ciclo Ultradiano" e não explica nada. Escolher o método é a primeira
decisão que ele pede, e é a única que ele não ajuda a tomar.

**Plano.** Dois campos novos (`description`, `origin`), uma sheet ao tocar no método no
seletor, conteúdo 100% local escrito à mão. Sem dependência nova, sem rede.

**Custo:** baixo-médio — o trabalho é escrever 11 textos bons, não o código.

---

## 4. Frase motivacional depois do cronômetro

**O motor já existe** e foi entregue na v1.6.0: `buildDailyLinePrompt`, `fetchDailyLine`
(Groq com Gemini de reserva), os dois parsers e o cache — tudo em `lib/main.dart:1565`+. Ver
[`DECISOES.md` §24](DECISOES.md).

Faltam **duas coisas diferentes**:

**(a) A chave ainda está em branco.** `_kGroqApiKey` continua vazia — nenhuma das que
circularam no chat foi reaproveitada, de propósito. Sem ela o cartão nunca aparece.

**(b) O lugar.** Hoje o cartão vive na aba Resumo. O pedido é que a frase venha **depois do
cronômetro**, que é o momento de recompensa.

> ### Uma decisão que precisa ser tomada antes de codar
>
> O cache guarda **uma frase por dia** — foi assim que o custo de API ficou desprezível
> (~50 chamadas/dia para 50 pessoas). Se a frase passar a aparecer ao fim de **cada sessão**,
> quem fizer 5 sessões no dia vê **a mesma frase 5 vezes**, o que parece defeito.
>
> As duas saídas: (i) uma frase por sessão, trocando o cache de dia para sessão — ~4× mais
> chamadas, ainda dentro do tier gratuito da Groq (1.000/dia), ou (ii) manter uma por dia e
> mostrá-la só na **primeira** sessão concluída do dia.
>
> **Recomendo (i)**: a frase depois do foco só tem graça se for nova. Mas é escolha sua.

**Custo:** baixo-médio, e depende da chave chegar.

---

## 5. Tarefa junto do temporizador — **eu estava errado no roadmap**

O [`ROADMAP.md`](ROADMAP.md) item 5 diz que a tarefa vinculada *"aparece pouco: dá para
vincular uma tarefa no check de humor, e depois disso ela some"*.

**Isso está errado, e a verificação deste plano é que pegou.** `lib/main.dart:2812`:

```dart
if (linkedTask != null) ...[
  const SizedBox(height: 12),
  Row(... Icon(Icons.link) ... Text(linkedTask.title) ...),
],
```

A tarefa vinculada **é exibida durante a sessão inteira**, embaixo do anel. Metade do item já
estava pronta e eu tinha registrado o contrário.

**O que falta de verdade** é o outro lado: **não dá para concluir a tarefa sem sair da aba
Foco**. `_toggleTask` existe (`lib/main.dart:2051`) mas só está ligado à aba Tarefas
(`lib/main.dart:2129`). O ciclo *escolher → focar → concluir* quebra no último passo.

**Plano.** Passar `onToggleTask` para a `FocusPage` e pôr uma ação de concluir ao lado da
tarefa que já aparece — de preferência no fim da sessão, que é quando a pergunta "terminou?"
faz sentido.

**Custo:** baixo. É passar um callback que já existe e acrescentar um botão.

---

## 6. Cronômetro ao trocar de tela e ao sair do app — **o item mais grave**

São **dois defeitos independentes**, e o primeiro é pior do que o pedido sugere.

### 6.1 Trocar de aba mata a sessão

`lib/main.dart:2250`:

```dart
child: KeyedSubtree(
  key: ValueKey<int>(_index),
  child: pages[_index],
),
```

O `AnimatedSwitcher` troca o widget filho a cada mudança de aba, e a `ValueKey(_index)` faz o
Flutter tratar cada aba como um widget **diferente**. Resultado: sair da aba Foco **destrói o
`_FocusPageState`** — e com ele o `Timer`, os segundos restantes, o humor inicial já
informado, a tarefa vinculada, o contexto e a nota.

**Não é só o cronômetro parar: é perder a sessão em andamento.** Basta tocar em "Tarefas" com
o foco rodando. É reproduzível em dois toques.

> **Isto é um risco direto para a apresentação.** Se durante a demonstração você iniciar o
> cronômetro e passar para outra aba para mostrar algo, a sessão morre na frente da plateia.

### 6.2 Sair do app faz o tempo derreter

`lib/main.dart:2444`:

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  ...
  setState(() => _secondsLeft--);
});
```

O tempo restante é um **contador decrementado a cada tique**, não um horário de término. Não
existe `WidgetsBindingObserver` nem `didChangeAppLifecycleState` em lugar nenhum do arquivo —
conferido, zero ocorrências. Quando o Android suspende o app, os tiques param ou são
estrangulados, e o cronômetro **atrasa em relação ao relógio real**.

### Plano

| Defeito | Correção | Dependência nova? |
|---|---|---|
| 6.1 trocar de aba | tirar o estado do cronômetro de dentro da `FocusPage` — subir para o `_HomeShellState`, que sobrevive à troca | não |
| 6.2 sair do app | guardar o **horário de término** (`DateTime`) e recalcular o restante a partir do relógio, com um `WidgetsBindingObserver` para recalcular ao voltar | não |

**O que este plano deliberadamente NÃO faz: notificar com o app fechado.** Isso exigiria
serviço em primeiro plano ou notificação local — pacote novo **com código nativo**, que é
exatamente o risco que a [`FLUTLAB.md` §4.1](FLUTLAB.md) documenta e que já custou caro neste
projeto uma vez. A correção acima resolve o que foi pedido ("mudar a tela e sair da
aplicação") **sem nenhuma dependência nova**.

**Custo:** médio-alto, e é o maior deste plano. Mexe no estado da tela mais importante do app
e exige testes novos. **Também é o de maior retorno**, porque é o único que conserta perda de
dado real.

---

## 7. Subir o popup

**Causa achada.** Os dois `showModalBottomSheet` (`lib/main.dart:1882` e `2553`) usam:

```dart
isScrollControlled: true,
backgroundColor: Colors.transparent,
```

…e **nenhuma restrição de altura**. Com `isScrollControlled: true`, o sheet passa a poder
ocupar a tela toda, mas **só cresce até o tamanho do conteúdo** — que é uma `Column` com
`mainAxisSize: min`. Sem altura mínima, ele se encolhe e fica colado no rodapé, com a metade
de cima da tela vazia. É por isso que abre baixo.

**Plano.** Dar uma altura inicial ao sheet — `heightFactor` em torno de 0,7 (ou
`DraggableScrollableSheet` com `initialChildSize`), mais `useSafeArea: true`. Vale aplicar aos
**dois** sheets, o de humor e o de perfil, que têm o mesmo problema.

**Custo:** baixo.

---

## 8. "Resumo" vira **Ficha**

Escolhido entre as opções: é a palavra que o app **já usa dentro da própria aba** ("Sua
ficha"), é o termo de RPG de mesa em português, e cabe na barra de navegação.

**Onde encostar:**

| Lugar | Ocorrências |
|---|---|
| `lib/main.dart:2268` | o rótulo da aba |
| `test/aura_app_test.dart:102, 128, 143` | três `tap(find.text('Resumo'))` — **quebram** se o rótulo mudar sem ajustar |
| `docs/*.md` | várias — o `verifica_docs.sh` não checa texto de aba, então essa parte é manual |

**Custo:** baixo, mas **não é só uma string**: três testes e a documentação vão junto.

---

## 9. Um lugar melhor para editar o perfil

**Hoje existe um caminho só.** O lápis no cartão da ficha, em dois estados
(`lib/main.dart:4769` e `4796`) — os dois dentro da aba Resumo. Para mexer no perfil é preciso
saber que ele mora lá dentro.

**Plano.** Acrescentar um caminho que se ache sem procurar — um ícone na `AppBar` (que já
existe e já tem o ícone de "Sobre" ao lado) é o mais barato e o mais convencional. O lápis da
ficha **fica**: ele é bom quando você já está olhando a ficha.

**Custo:** baixo. O `_editProfile` já existe e já é chamado de fora da página.

---

## 10. Insights em português, e o humor final

Duas coisas diferentes no mesmo pedido.

### 10.1 O inglês é o nome da aba

Procurei texto em inglês na aba inteira: os títulos e corpos dos seis insights estão em
português, e os dias da semana também (`weekdayShort`/`weekdayLong`, `lib/main.dart:477`).

**O que está em inglês é o rótulo da aba: `'Insights'`** (`lib/main.dart:2266`).

**A tradução já está escrita no resto do projeto.** O README fala em *"Seis **descobertas**"*
e a própria aba abre com *"5 de 6 **desbloqueadas**"*. O nome português natural é
**Descobertas** — não é traduzir, é usar a palavra que o app já usa.

Encosta em `test/aura_app_test.dart:83, 161`, mesmo caso do item 8.

### 10.2 Falta o humor final nos gráficos

**Existem exatamente dois gráficos:**

| Gráfico | Título | O que mostra |
|---|---|---|
| `_MoodDurationChart` (3724) | "Humor inicial × duração do foco" | barras: duração média por faixa de humor **inicial** |
| `_WeeklyFocusChart` (3852) | "Últimos 7 dias" | linha: minutos por dia |

**O humor final não aparece em nenhum gráfico** — só dentro do texto de um insight. O dado
existe (`moodAfter` é gravado em toda sessão), mas nunca vira imagem.

**Plano.** Um gráfico que ponha **humor inicial e humor final lado a lado** por faixa — é
exatamente a tese do produto ("o contraste entre antes e depois") e hoje ela é só narrada. Um
`BarChart` com duas barras por grupo resolve, reaproveitando a estrutura do
`_MoodDurationChart`.

Manter separado do gráfico de duração, **não** empilhar as três variáveis num gráfico só:
humor é escala de 1 a 5 e duração é minutos — eixos diferentes, e juntar os dois num eixo
mente sobre a escala.

**Custo:** médio.

---

## 11. A nova logo — **bloqueado, e é você quem destrava**

> ## ⚠️ LEMBRETE: a logo está com outra pessoa
>
> Você pediu para eu te lembrar disso, e este é o lembrete: **não existe nenhum arquivo de
> logo nova no repositório**, e o `pubspec.yaml` não tem seção `assets:`. Enquanto o arquivo
> não chegar, este item não sai do lugar.
>
> **Quando a logo chegar, me mande o arquivo** (PNG grande e quadrado, ou SVG) que eu gero o
> resto.

**O que vai precisar mudar quando ela chegar** — são mais lugares do que parece:

| Onde | O que é |
|---|---|
| `mipmap-anydpi-v26/ic_launcher.xml` | ícone adaptativo do Android 8+ |
| `mipmap-*/ic_launcher.png` | 5 densidades legadas |
| `drawable-*/launch_image.png` | 5 densidades da abertura nativa |
| `ios/.../AppIcon.appiconset/` | 15 PNGs, sem canal alfa |
| `AuraMark` | a marca **desenhada em código**, sem asset |
| `kSplashGradient` **e** `launch_gradient.xml` | as duas cores da abertura, que mudam **juntas** |

A armadilha continua a mesma do roadmap anterior: as duas últimas linhas são a mesma cor
declarada em Dart e em XML, sem como compartilhar constante. Mudar uma sem a outra faz a
abertura piscar — o defeito que a v1.1.0 corrigiu ([`DECISOES.md` §16](DECISOES.md)).

**Custo:** médio, **invalida o APK** e obriga a refazer todos os prints da documentação.

---

## 12. O corte: o que dá para fazer em 3 dias

Você ainda precisa, fora do código: colar a chave da API, gerar o APK, instalar, testar o QR
Code com outro aparelho, montar os slides e ensaiar cronometrando
([`ENTREGA.md`](ENTREGA.md)). Isso não é pouco.

### Recomendado antes de 24/08

Cinco itens, escolhidos por **risco à demonstração** e custo baixo:

| # | Item | Por que entra |
|---|---|---|
| 6 | **Cronômetro ao trocar de aba** | é perda de dado, e pode quebrar a demonstração ao vivo |
| 2 | Cores dos dados | uma linha, e some a mistura roxo/verde |
| 7 | Subir o popup | baixo, e o check de humor é o passo mais importante da demonstração |
| 8 | "Resumo" → **Ficha** | baixo, e reforça a tese de RPG que você vai apresentar |
| 10.1 | "Insights" → **Descobertas** | baixo, mesma passada de rótulo do anterior |

Os itens 8 e 10.1 mexem nos mesmos testes — vale fazer os dois de uma vez.

### Depois da apresentação

| # | Item | Por quê espera |
|---|---|---|
| 3 | Explicar os métodos | o valor está em escrever 11 textos bons, e texto apressado fica ruim |
| 4 | Frase depois do cronômetro | depende da chave e de uma decisão de produto (§4) |
| 5 | Concluir tarefa na aba Foco | melhoria real, mas ninguém sente falta numa demonstração |
| 10.2 | Gráfico de humor final | médio, e o insight já narra a mesma coisa em texto |
| 11 | Nova logo | **bloqueado** até o arquivo chegar, e invalida o APK e os prints |

### Uma observação sobre o item 6.2

A parte de "sair do app" (relógio de parede) é mais cara que a de trocar de aba e **não
aparece numa demonstração de 10 minutos**. Se o tempo apertar, dá para fazer só a 6.1 e deixar
a 6.2 para depois — a 6.1 sozinha já elimina o risco de quebrar ao vivo.

---

## 13. O que **não** entra, e por quê

- **Notificação com o app fechado** (§6): exigiria pacote com código nativo, o risco que a
  `FLUTLAB.md` §4.1 documenta. A correção proposta resolve o pedido sem isso.
- **Modo escuro, contraste e amplitude dos climas**: continuam no
  [`ROADMAP.md` §1](ROADMAP.md), sem mudança. O item 2 deste plano é outra coisa — é
  consistência de cor **nos dados**, não o tema.
- **Dividir o `main.dart`**: segue adiada por restrição do ambiente
  ([`DECISOES.md` §19](DECISOES.md)).
