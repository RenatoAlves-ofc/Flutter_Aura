# Roadmap — Aura

Cinco melhorias planejadas depois da entrega de 24/08, mais os itens que a especificação
mandou não codar.

Cada uma tem o mesmo tratamento: **o que é, por que vale, quanto custa e o que quebra**. Um
roadmap que só lista desejos não ajuda ninguém a decidir — o que decide é o custo.

> **Existe uma rodada de planejamento mais nova.** O [`PLANO-V2.md`](PLANO-V2.md) tem dez
> itens pedidos em 21/08, cada um verificado contra o código — e corrige um erro que este
> documento tinha no item 5. Leia os dois: este tem o raciocínio de cores e métodos que
> continua valendo; o outro tem o que vem agora.

> **O código está congelado para a apresentação — com uma exceção.** O item 4 (frase do dia)
> foi implementado antes de 24/08 por pedido explícito do usuário, revertendo a recusa que
> este documento originalmente registrava para ele — a decisão completa está em
> [`DECISOES.md` §24](DECISOES.md). Os outros quatro itens continuam só planejados. O que
> falta até 24/08 está em [`ENTREGA.md`](ENTREGA.md) e depende de acesso ao FlutLab e ao
> aparelho — inclusive um novo rebuild do APK, já que o 4 mudou o código.

---

## Visão geral

| # | Item | Custo | Retorno | Invalida o APK? |
|---|---|---|---|---|
| 2 | Explicar os métodos de estudo | **baixo** | **alto** | não |
| 4 | Frase do dia — **implementado, com API** (ver DECISOES.md §24) | baixo | médio | **sim** |
| 5 | Tarefa presente durante a sessão | médio | médio | não |
| 1 | Cores: contraste, climas e modo escuro | **alto** | alto | **sim** |
| 3 | Trocar a logo | médio | baixo | **sim** |

A ordem da tabela é a recomendada: começa pelo que rende mais por linha de código e termina
pelo que obriga a refazer o APK e todos os prints da documentação.

---

## 1. Cores

Três frentes distintas, com custos muito diferentes. Vale tratá-las separadamente em vez de
como um item só de "melhorar as cores".

### 1.1 Contraste — a mais barata, e a única que é defeito

As outras duas são melhorias; esta pode ser **defeito de acessibilidade**. O suspeito
principal é `bodySmall` sobre o `AuraCard`, que é branco com `alpha 0.82` — texto secundário
claro sobre fundo translúcido claro.

**Plano:** medir cada par texto/fundo contra a WCAG 2.2 (mínimo **4.5:1** para texto normal,
3:1 para texto grande) e corrigir o que não passar. É medição, não gosto: ou o número passa
ou não passa.

**Custo:** baixo. Ajuste de tons, sem mexer em estrutura.

### 1.2 Os climas se parecem demais — e dá para provar

A aura é um diferencial do produto, e ela muda pouco na tela. O motivo não é impressão:
medindo a **luminância relativa** do primeiro tom de cada gradiente (`lib/main.dart`, linhas
1478–1522):

| Clima | Luminância inicial | Final |
|---|---:|---:|
| Radiante | 0,924 | 0,785 |
| Aura em branco | 0,897 | 0,798 |
| Fluindo | 0,877 | 0,790 |
| Nublado | 0,869 | 0,755 |
| Recolhido | 0,805 | 0,672 |

Os cinco vivem entre **0,80 e 0,92** — amplitude de **0,12**. São cinco pastéis quase
brancos, e por isso trocar de clima quase não se nota.

**Plano:** abrir a faixa. Manter Radiante claro e deixar Recolhido descer de verdade, para a
diferença ser perceptível sem virar tema escuro. A regra de cor de
[`ARQUITETURA.md`](ARQUITETURA.md) §7 continua valendo — o que muda é a amplitude, não o
significado.

**Custo:** baixo-médio. Recapturar os prints, porque o fundo aparece em todos.

### 1.3 Modo escuro — a mais cara

É o pedido mais comum em app de foco, e casa com estudar à noite.

**Não é trocar uma flag.** O app tem cor decidida em vários lugares que assumem fundo claro:

- `AuraCard` é `Colors.white.withValues(alpha: 0.82)` — some no escuro
- os cinco gradientes de clima são pastéis claros, e teriam que ganhar um par escuro
- `AuraMark` recebe `glowColor` e `coreColor` calibrados para fundo claro
- a abertura nativa (`launch_gradient.xml`) é índigo fixo, e não sabe o tema do sistema
- **todos os prints** da documentação seriam refeitos, ou duplicados

**Plano:** cada cor vira token com par claro/escuro, e a regra do §7 ganha uma terceira
coluna. Fazer isso **depois** de 1.1 e 1.2, porque corrigir contraste e amplitude no tema
claro primeiro evita retrabalhar os dois temas.

**Custo:** alto. É o maior item deste roadmap.

---

## 2. Explicar os métodos de estudo

**Este é o de melhor relação custo-benefício, e o buraco é real.** `FocusMethod`
(`lib/main.dart`, linha 337) tem `id`, `name`, `focusMinutes`, `breakMinutes`, `isCustom` e
`isFlowtime` — **nenhum campo de descrição**.

Ou seja: o app oferece "52/17" e "Ciclo Ultradiano" e não explica **nada**. Quem nunca ouviu
falar não tem como escolher, e escolher o método é a primeira decisão que o app pede.

**Plano:**

- Dois campos novos em `FocusMethod`: `description` (para quem funciona, o que esperar) e
  `origin` (de onde o método vem)
- Uma tela ou sheet ao tocar no método no seletor, mostrando os dois
- Conteúdo **100% local**, escrito à mão. Sem dependência nova, sem rede

**Por que vale mais do que parece:** o app se propõe a ensinar a pessoa sobre o próprio foco.
Oferecer 11 métodos sem explicar nenhum contradiz isso. E é conteúdo que envelhece bem.

**Custo:** baixo. Não toca em `android/` nem em `ios/`, então **não invalida o APK** por si
só.

---

## 3. Trocar a logo

Sem objeção de mérito — identidade visual é escolha do autor. O que o roadmap precisa
registrar é **onde ela aparece**, porque são mais lugares do que parece:

| Onde | O que é |
|---|---|
| `mipmap-anydpi-v26/ic_launcher.xml` | ícone adaptativo do Android 8+ |
| `mipmap-*/ic_launcher.png` | 5 densidades legadas |
| `drawable-*/launch_image.png` | 5 densidades da abertura nativa |
| `ios/.../AppIcon.appiconset/` | 15 PNGs, sem canal alfa |
| `AuraMark` | a marca desenhada em widgets, sem asset |
| `kSplashGradient` **e** `launch_gradient.xml` | as duas cores da abertura |

**A armadilha:** as duas últimas linhas precisam mudar **juntas**. São a mesma cor declarada
em dois lugares — Dart e XML — e não há como compartilhar constante entre eles. Mudar uma sem
a outra faz a abertura piscar, que é justamente o defeito que a v1.1.0 corrigiu
([`DECISOES.md`](DECISOES.md) §16).

**Custo:** médio, e **invalida o APK**.

---

## 4. Frase do dia — implementada, com API (revertido em relação a este documento)

> **Este item foi implementado depois de escrito**, revertendo a recusa abaixo. O usuário
> pediu explicitamente, mesmo depois de eu expor os riscos — a decisão completa, com o que
> mudou e o que foi mantido, está em [`DECISOES.md` §24](DECISOES.md). Os motivos abaixo
> continuam registrados como o argumento que quase venceu, não apagados.

O pedido original dizia "precisa de API". **Não precisava — e a API saía cara em mais de um
sentido.**

### Por que não a API

| Custo | Detalhe |
|---|---|
| **Contradiz o produto** | o README promete *"sem IA, sem API, sem rede"*, a tela Sobre promete privacidade, e o [`USO-DE-IA.md`](USO-DE-IA.md) argumenta que um app que promete privacidade não pode mandar o humor do usuário para um servidor de terceiros |
| **Segurança** | chave de API embutida em app cliente é extraível do APK |
| **Disponibilidade** | para de funcionar offline — justamente quando a pessoa senta para focar sem distração |
| **Escopo** | a especificação limita as dependências do projeto |
| **E não seria mais pessoal** | um modelo genérico, sem os dados do usuário, devolve motivação genérica |

### O que fazer no lugar (não foi o que aconteceu — ver DECISOES.md §24)

**O app já escreve frases pessoais.** Os insights são exatamente isso: frases tiradas do
comportamento real. Uma "frase do dia" do mesmo motor é mais pessoal do que qualquer API
conseguiria ser sem receber os dados do usuário:

> *"Você sustenta 40 min quando começa animado — e hoje você começou animado."*
>
> *"Terça é o seu melhor dia. Hoje é terça."*
>
> *"Faltam 8 sessões para você descobrir seu limite real."*

**Plano:** uma função pura `buildDailyLine(sessions, profile, now)` que escolhe entre alguns
moldes conforme o que os dados sustentam, e devolve `null` quando não há evidência — a mesma
política de `suggestMethodForMood`, que prefere não dizer nada a chutar.

**Custo:** baixo. Reaproveita `buildInsights`, `buildCharacterSheet` e `resolveClimate`, e é
lógica pura — testável sem construir tela.

> Esta alternativa **não foi construída**. O usuário pediu a reversão do "sem API" mesmo
> depois de eu apresentar os cinco motivos acima, mais dois que só apareceram ao investigar a
> viabilidade técnica (repositório público, FlutLab sem mecanismo de build-secret). A versão
> implementada tenta Groq e Gemini, chave de tier gratuito, cache de uma chamada por dia — o
> desenho completo, com o que foi feito para conter o risco, está em
> [`DECISOES.md` §24](DECISOES.md).

---

## 5. Tarefa presente durante a sessão

> ### ⚠️ Correção: metade deste item já estava pronta
>
> O parágrafo abaixo dizia que a tarefa vinculada *"some"* depois do check de humor. **Isso
> estava errado.** A verificação feita para o [`PLANO-V2.md`](PLANO-V2.md) mostrou que ela
> **é exibida durante a sessão inteira**, embaixo do anel (`_FocusPageState`, no bloco que
> usa `_linkedTaskId` — ícone de link + título em itálico). O que falta é só a outra metade: concluir a tarefa sem sair da
> aba Foco. O texto original fica abaixo, não apagado, porque o erro foi meu e o registro
> serve para isso.

Hoje `linkedTaskId` existe e aparece pouco: dá para vincular uma tarefa no check de humor, e
depois disso ela some. A aba Tarefas e a aba Foco quase não se falam.

**Plano:** a tarefa vinculada fica visível durante a sessão, e dá para concluí-la sem sair da
aba Foco — fechando o ciclo *escolher → focar → concluir* num lugar só.

**Uma medição antes de codar.** A v1.5.0 trouxe `contextId` e `note` por sessão, que já
cobrem parte do "o que estou fazendo". Antes de expandir o vínculo com tarefas, vale conferir
se o resultado não é **três conceitos disputando a mesma pergunta**: a tarefa, o contexto e a
nota. Pode ser que a resposta certa seja unificar, não somar.

**Custo:** médio. Mexe no estado da `FocusPage` e no fluxo de conclusão de tarefa, que hoje
vive só na `TaskListPage`.

---

## Itens da especificação que seguem fora

Cortados por análise de risco-benefício no início do projeto, e citados nos slides como
roadmap:

- Ritual Semanal de fechamento ("Encontro de Domingo")
- Modo Provas (tema sazonal)
- Arco Fechado por Temporada, com retrospectiva
- Compartilhamento de cartões de insight — exigiria `screenshot` + `share_plus`, risco
  técnico alto no FlutLab
- Onboarding com quiz de expectativa

A **Sugestão Adaptativa de Duração** também estava nesta lista e acabou implementada na
v1.0.0: reaproveitava o motor de correlação que já existia, então saiu barata.

E a **divisão do `main.dart` em vários arquivos**, adiada por restrição declarada do ambiente
de entrega — o porquê inteiro está em [`DECISOES.md`](DECISOES.md) §19.
