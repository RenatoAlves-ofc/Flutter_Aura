# O Produto — Aura

Documento de produto: **qual problema o Aura resolve, para quem, o que ele faz** e com quais
cores. Os outros documentos descrevem *como* o app foi construído; este descreve *por que ele
existe*.

> ### ⚠️ Uma ressalva de honestidade sobre as duas primeiras seções
>
> A problemática e o público-alvo **não estavam escritos em lugar nenhum do repositório** —
> foram reconstruídos a partir do que está registrado nas decisões de projeto e na pesquisa de
> concorrência. O [`USO-DE-IA.md`](USO-DE-IA.md) diz explicitamente que quem definiu o
> produto, o público-alvo e o diferencial foi **o autor, não a IA**.
>
> **Confira estas duas seções contra a especificação original da atividade** antes de usar em
> slide ou relatório. Se divergirem, o que vale é a especificação — me avise que eu corrijo.

---

## 1. A problemática

**Aplicativos de foco contam minutos. Nenhum deles te conta sobre você.**

Quatro problemas concretos, cada um observado na pesquisa de concorrência registrada no
projeto:

### 1.1 O cronômetro não devolve autoconhecimento

Um Pomodoro comum termina a sessão e mostra um número: *"25 minutos"*. Depois de três meses de
uso, o usuário tem centenas desses números e **nenhuma conclusão** sobre o próprio foco. Ele
não sabe responder por que em alguns dias sustenta 50 minutos e em outros desiste aos 10.

O dado que explicaria isso — **como a pessoa estava quando começou** — não é coletado por
ninguém.

### 1.2 A gamificação genérica premia abrir o app, não mudar de comportamento

Pontos, níveis, medalhas e XP sobem porque o usuário apareceu, não porque ele melhorou. Isso
cria uma métrica que **parece progresso e não é**: a pessoa pode ter 4.000 pontos e continuar
sem saber o que funciona para ela.

Registrado em [`DECISOES.md` §20](DECISOES.md) como o erro que os apps do nicho cometem — e a
razão de o Aura ter recusado XP mesmo quando a pegada de RPG foi pedida.

### 1.3 A sequência rígida pune exatamente quando a vida aperta

Streaks que zeram ao primeiro dia perdido punem o usuário **na semana de prova**, que é
justamente quando ele mais precisa da ferramenta e menos consegue manter a rotina. Perder três
semanas de esforço por um dia é a forma mais rápida de fazer alguém desinstalar.

### 1.4 Categorizar a sessão não responde a pergunta que importa

Marcar a sessão como "estudo" ou "trabalho" já existe no mercado — o [Forest](https://forestapp.cc/)
tem tags com analytics, o [Toggl Track](https://toggl.com/track/focused-work/) tem projetos e
tags, o Focus To-Do tem projetos. **Nenhum deles pergunta como você está.**

Sem o humor, a categoria diz *onde* você gastou tempo, mas nunca *qual tipo de trabalho te
esgota* — que é a pergunta que muda uma decisão de rotina.

---

## 2. Público-alvo

**Estudantes, com ênfase em período de provas e trabalhos de entrega.**

| Dimensão | Definição |
|---|---|
| **Quem** | Estudantes de ensino médio e superior, público jovem |
| **Momento de uso** | Sessões de estudo individuais, em especial em época de prova e entrega |
| **Dor principal** | Foco irregular e sem explicação: rende muito num dia e nada no outro, sem saber por quê |
| **Contexto de aparelho** | Celular Android pessoal, muitas vezes sem internet estável |
| **Sensibilidade declarada** | Público cansado de coleta de dados — privacidade é diferencial, não detalhe técnico |

### O que isso decidiu no produto

O público não é decoração de slide: três decisões saíram diretamente dele.

| Decisão | Por causa de quê |
|---|---|
| **Sequência com perdão** ([`DECISOES.md`](DECISOES.md)) | punir quem falhou um dia na semana de prova perde o usuário |
| **Tudo local, sem login nem feed** ([`DECISOES.md` §3](DECISOES.md)) | privacidade como posicionamento para público jovem |
| **Recusa de XP e medalhas** ([`DECISOES.md` §20](DECISOES.md)) | o público-alvo já reconhece gamificação vazia |

### Quem **não** é o público

Registrado para a decisão ficar clara: o Aura **não** mira equipes, gestão de tempo
corporativa, nem faturamento por hora — que é o território do Toggl. Não há colaboração, não
há relatório para terceiros, e não há exportação. É uma ferramenta de uma pessoa só,
para ela mesma.

---

## 3. Funcionalidades

Estado **atual**, verificado no código. Onde uma mudança está planejada mas não feita, está
marcado.

### 3.1 Aba Foco

| Funcionalidade | Detalhe |
|---|---|
| **Cronômetro** | Anel de progresso com halo que respira enquanto a sessão roda |
| **11 métodos de foco** | Pomodoro Clássico (25/5), Pomodoro Longo (50/10), 52/17, Ciclo Ultradiano (90/20), Meia Hora Cheia (45/15), Sessão Curta (20/5), Hora Cheia (60/10), Micro-sessão (15/5), 40/20, **Flowtime** (contagem crescente, sem alvo) e **Personalizado** |
| **Check de humor antes** | Escala de 1 a 5, com face e rótulo (Exausto → Ótimo) |
| **Check de humor depois** | A mesma escala ao fim da sessão — o contraste alimenta os insights |
| **Sugestão adaptativa de método** | Consulta as sessões que começaram no mesmo humor e sugere o método que historicamente termina melhor. **Sem evidência suficiente, não sugere nada** |
| **Tipo de trabalho por sessão** | 5 contextos: Acadêmico, Trabalho, Pessoal, Criativo, Geral. Já vem marcado com o do perfil |
| **Nota curta e opcional** | Uma linha sobre o que está sendo feito, no check de antes |
| **Vínculo com tarefa** | Uma tarefa pendente pode ser ligada à sessão e fica visível durante todo o foco |
| **Pausa automática** | Ao fim do foco, o método inicia o intervalo correspondente |

### 3.2 Aba Tarefas

| Funcionalidade | Detalhe |
|---|---|
| **Lista de tarefas** | Criar, concluir e remover |
| **Prioridade** | Alta, Média e Baixa, com marcador colorido |
| **Persistência local** | Sobrevive ao fechamento do app |

### 3.3 Aba Insights

> A aba se chama **"Insights"** hoje. A troca para **"Descobertas"** está planejada em
> [`PLANO-V2.md` §10](PLANO-V2.md) e ainda não foi feita.

**Seis descobertas desbloqueáveis**, todas em Dart puro sobre as sessões salvas — sem IA, sem
rede. Cada uma exige um volume mínimo e aparece **bloqueada até lá, dizendo quantas faltam**:

| # | Descoberta | Exige | O que responde |
|---|---|---:|---|
| 1 | **Seu estado de entrada prevê seu foco** | 5 sessões | quanto o estado inicial muda o tempo que você sustenta |
| 2 | **Seu melhor dia da semana** | 7 sessões | em que dia você rende mais |
| 3 | **O método que mais te sustenta** | 6 sessões | qual método funciona para você, não em geral |
| 4 | **Onde você rende mais** | 8 sessões | qual **tipo de trabalho** te esgota e por quanto tempo você aguenta cada um |
| 5 | **Efeito colateral do foco** | 5 sessões | com que frequência a sessão te devolve melhor do que te encontrou |
| 6 | **Seu limite real** | **30 sessões** | acima de quantos minutos suas sessões passam a terminar pior |

> A ordem acima é a mesma em que o app exibe as descobertas — `buildInsights()` deixa a
> descoberta sobre humor (a única estruturalmente emocional, não de desempenho) no penúltimo
> lugar de propósito. Ver [`DECISOES.md` §25](DECISOES.md).

A sexta **nasce trancada de propósito**: com as 22 sessões do dataset de demonstração ela
mostra "faltam 8", que é como a mecânica de desbloqueio fica visível.

**Dois gráficos:**

| Gráfico | Mostra |
|---|---|
| Humor inicial × duração do foco | barras: duração média por faixa de humor inicial |
| Últimos 7 dias | linha: minutos focados por dia |

> Um gráfico com o **humor final** está planejado ([`PLANO-V2.md` §10.2](PLANO-V2.md)) e ainda
> não existe — hoje o humor final aparece só dentro do texto de uma descoberta.

### 3.4 Aba Resumo

> A aba se chama **"Resumo"** hoje. A troca para **"Ficha"** está decidida em
> [`PLANO-V2.md` §8](PLANO-V2.md) e ainda não foi feita.

| Funcionalidade | Detalhe |
|---|---|
| **Ficha de personagem** | Uma **classe** — Maratonista (50+ min), Ritmista (25–45), Sprinter (≤20), Explorador (Flowtime) — e **quatro atributos**, todos derivados das sessões reais |
| ↳ Constância | sequência atual, com as folgas já descontadas |
| ↳ Recuperação | % das sessões que terminam melhor do que começaram |
| ↳ Amplitude | quanto o humor inicial move a sua duração |
| ↳ Profundidade | a maior sessão que você sustentou |
| **Perfil** | Nome, tipo de trabalho principal e "o que você está focando neste período" — tudo opcional, editável pelo lápis na ficha |
| **Frase do dia** | Frase curta de incentivo gerada do seu resumo. Única parte do app que usa rede — ver §4 |
| **Clima pessoal (a aura)** | O fundo do app inteiro muda conforme as sessões recentes: Radiante, Fluindo, Nublado, Recolhido, mais o neutro |
| **Sequência com perdão** | A cada 3 dias seguidos, 1 folga (teto de 3). Faltou **exatamente um** dia? A folga é gasta sozinha e a sequência continua |
| **Números** | Pontos (10 por sessão, 5 por tarefa), sessões hoje, sessões totais, minutos focados |

**Nenhum atributo da ficha é ponto de experiência.** Não existe subir de nível: se o número
sobe, é porque o comportamento mudou.

### 3.5 Tela Sobre

| Funcionalidade | Detalhe |
|---|---|
| **Mensagem de privacidade** | O que fica no aparelho e o que sai dele |
| **Dataset de demonstração** | 22 sessões fictícias dos últimos 14 dias, com semente fixa, removíveis em um toque |
| **Último erro registrado** | Se algo falhou, o texto aparece aqui e pode ser copiado |

### 3.6 Transversais

| Funcionalidade | Detalhe |
|---|---|
| **Abertura contínua** | A tela nativa já traz o índigo e a marca, e dissolve na cor da sua aura — sem piscar branco |
| **Animações finitas** | Todas terminam, exceto uma: o halo que respira durante a sessão |
| **Resiliência a dado corrompido** | Um registro malformado é descartado e registrado, em vez de impedir o app de abrir |
| **Retrocompatibilidade** | Dados gravados por versões anteriores continuam abrindo |

---

## 4. Privacidade — o que sai do aparelho

| O que | Sai do aparelho? |
|---|---|
| Sessões, humor, tarefas, ficha, perfil, insights, clima | **não** — `shared_preferences`, armazenamento local |
| Login, servidor, feed, exportação | **não existem** |
| **Frase do dia** | **sim** — manda um resumo curto (classe, clima, contexto, foco do momento) para a Groq, com a Gemini de reserva. **Nunca o humor bruto, sessão por sessão** |

A exceção da frase do dia foi uma reversão deliberada de "sem rede", com o risco avaliado e
registrado em [`DECISOES.md` §24](DECISOES.md). Sem internet ou sem chave, o cartão
simplesmente não aparece e o resto do app funciona igual.

---

## 5. As cores

O inventário completo, com **todos os códigos hex e onde cada um aparece**, está em
[`PALETA-DE-CORES.md`](PALETA-DE-CORES.md) — inclusive duas coincidências de valor registradas
lá. A regra que decide qual cor usar onde está em [`ARQUITETURA.md` §7](ARQUITETURA.md).

Referência rápida das principais:

### Marca e estrutura

| Cor | Código | Onde |
|---|---|---|
| Índigo da marca | `#6C63FF` | marca, botões, anel do cronômetro, números de insight, atributos da ficha |
| Abertura (início) | `#8B84FF` | gradiente da tela de abertura, em Dart e no XML nativo |
| Abertura (fim) | `#4A41C7` | idem |

### Os 5 climas (o fundo do app)

| Clima | Gradiente | Destaque |
|---|---|---|
| Aura em branco | `#F4F2FB` → `#E8E5F6` | `#6C63FF` |
| Radiante | `#FFF6DE` → `#FFE0C2` | `#EF9A2E` |
| Fluindo | `#E1F5F1` → `#DCE6FF` | `#2A9D8F` |
| Nublado | `#EDF0F4` → `#DCE2EA` | `#5C6B7A` |
| Recolhido | `#EAE6F2` → `#D9D3E8` | `#6D5B9E` |

### Faces do check de humor

| Humor | Código |
|---|---|
| Exausto | `#E57373` |
| Cansado | `#FFB74D` |
| Neutro | `#FFD54F` |
| Bem | `#81C784` |
| Ótimo | `#4DB6AC` |

### Prioridade de tarefa

| Prioridade | Cor |
|---|---|
| Alta | vermelho (`Colors.red`) |
| Média | laranja (`Colors.orange`) |
| Baixa | verde (`Colors.green`) |

> **Uma inconsistência conhecida:** as barras do gráfico "Humor inicial × duração" são
> pintadas com as cores de humor acima, o que mistura verde e roxo na mesma tela. A correção
> está planejada em [`PLANO-V2.md` §2](PLANO-V2.md) e ainda não foi feita.

---

## 6. O que o Aura **não** faz

Registrado para responder se perguntarem — nenhum destes é acidente:

- **Não tem login nem conta.** Nenhum cadastro, nenhuma senha.
- **Não tem feed nem comparação social.** Ninguém vê a sua ficha.
- **Não tem XP, níveis nem medalhas.** Recusado de propósito ([`DECISOES.md` §20](DECISOES.md)).
- **Não bloqueia apps nem monitora o uso do celular.** É um Pomodoro, não um vigia.
- **Não exporta relatório.** Os dados são para o usuário, dentro do app.
- **Não tem notificação com o app fechado.** Exigiria pacote com código nativo, um risco
  documentado em [`FLUTLAB.md` §4.1](FLUTLAB.md).
