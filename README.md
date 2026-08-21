# Aura

**Um Pomodoro que aprende com você.**

Em vez de só contar minutos, o Aura cruza como você está se sentindo com quanto tempo você
realmente consegue manter o foco — e devolve isso como descobertas pessoais, não como
pontos genéricos. Sua aura muda com seu estado real. Tudo local, sem login, sem feed.

O diferencial não é o cronômetro: é o **motor de correlação entre humor, duração de foco e
método utilizado**. Todo o resto do app existe para alimentar ou expor esse motor.

<p align="center">
  <img src="docs/img/01-foco.png" width="200" alt="Aba Foco">
  <img src="docs/img/03-humor-sugestao.png" width="200" alt="Check de humor com sugestão adaptativa">
  <img src="docs/img/05-insights.png" width="200" alt="Aba Insights">
  <img src="docs/img/06-graficos.png" width="200" alt="Gráfico de correlação">
</p>

---

## Documentação

| Documento | Para quê |
|---|---|
| [**Checklist de entrega**](docs/ENTREGA.md) | O que falta até 24/08, com dono por item |
| [Relatório ponta a ponta](docs/RELATORIO-E2E.md) | O que foi entregue, como foi verificado e quais defeitos apareceram |
| [Arquitetura](docs/ARQUITETURA.md) | Como o código está organizado, com mapa do arquivo e diagramas |
| [Registro de decisões](docs/DECISOES.md) | Por que o código é como é — inclusive o que deu errado e foi revertido |
| [Rodando no FlutLab](docs/FLUTLAB.md) | Importar, buildar o APK e os avisos que são esperados |
| [Manual do usuário](docs/MANUAL-DO-USUARIO.md) | Como usar cada tela |
| [Roteiro de apresentação](docs/APRESENTACAO.md) | Demonstração passo a passo e números para os slides |
| [Uso de IA](docs/USO-DE-IA.md) | Como o projeto foi construído com IA, e onde ela errou |
| [Paleta de cores](docs/PALETA-DE-CORES.md) | Inventário da paleta atual, valor por valor |
| [Roadmap](docs/ROADMAP.md) | As próximas melhorias, com custo e o que cada uma quebra |
| [Changelog](CHANGELOG.md) | Histórico de mudanças |

---

## O que o app faz

| Aba | Conteúdo |
|---|---|
| **Foco** | Cronômetro com 11 métodos, check de humor antes e depois de cada sessão, sugestão adaptativa de método e vínculo opcional com uma tarefa |
| **Tarefas** | Lista com prioridade (Alta/Média/Baixa), persistida localmente |
| **Insights** | 6 descobertas desbloqueáveis + gráfico de correlação e ritmo semanal |
| **Resumo** | Sua ficha (classe e atributos), clima pessoal, sequência com perdão e números |

Mais a tela **Sobre**, com a mensagem de privacidade e o controle do dataset de demonstração.

### Os diferenciais

**Sua ficha.** Uma classe (Maratonista, Ritmista, Sprinter, Explorador) e quatro atributos —
Constância, Recuperação, Amplitude, Profundidade — **todos derivados das suas sessões
reais**. Não existe ponto de experiência nem subir de nível: se o número sobe, é porque o seu
comportamento mudou, não porque você abriu o app.

**Insights desbloqueáveis.** Seis comparações em Dart puro sobre as sessões salvas — sem IA,
sem API, sem rede. Cada uma exige um volume mínimo (5, 5, 7, 6, 8 e 30 sessões) e aparece
bloqueada até lá, dizendo quantas faltam. A quinta é o objetivo de longo prazo e nasce
trancada de propósito.

**Tipo de trabalho, cruzado com humor.** Marcar a categoria da sessão é comum — Forest e
Toggl fazem. Nenhum deles pergunta como você está. O Aura cruza as duas coisas e responde o
que os outros não conseguem: **qual tipo de trabalho te esgota, e por quanto tempo você
aguenta cada um.**

**Seu perfil, opcional e local.** Nome, tipo de trabalho principal e o que você está focando
neste período. Aparece na ficha, pré-marca o check de humor, e o app funciona igual sem nada
preenchido.

**Sugestão adaptativa de método.** Ao informar o humor antes da sessão, o app consulta as
sessões que você começou naquele mesmo estado e sugere o método que historicamente termina
melhor. Sem evidência suficiente, **não sugere nada** em vez de chutar.

**Sequência com perdão.** A cada 3 dias seguidos você ganha um token de folga (teto de 3).
Faltou **exatamente um** dia? O token é gasto sozinho e a sequência continua de pé. A
proposta é acompanhar, não punir.

**Clima pessoal.** O fundo do app inteiro muda conforme suas sessões recentes, em 4 estados
mais o neutro. Sem assets: `Container` + `BoxDecoration` com gradiente.

**Abertura e animação.** A abertura é contínua — a tela nativa já traz o índigo e a marca do
Aura, e dissolve na cor da sua aura. As animações são todas finitas, exceto uma: o halo que
respira em volta do anel enquanto a sessão roda.

**11 métodos de foco.** Pomodoro Clássico (25/5), Pomodoro Longo (50/10), 52/17, Ciclo
Ultradiano (90/20), Meia Hora Cheia (45/15), Sessão Curta (20/5), Hora Cheia (60/10),
Micro-sessão (15/5), 40/20, **Flowtime** (contagem progressiva, sem alvo) e
**Personalizado**. Todos reaproveitam o mesmo cronômetro: são uma lista de dados, não 11
telas.

**Frase do dia.** Uma frase curta de incentivo, escrita a partir do seu resumo — classe,
clima, contexto, foco do momento — nunca do histórico de humor bruto. É a única parte do app
que fala com a internet; o motivo e o que isso muda estão na seção **Privacidade**, abaixo.
Sem chave configurada, sem resposta das duas tentativas, ou sem internet, o cartão
simplesmente não aparece — o app continua funcionando igual.

---

## Privacidade

O Aura não tem login, não tem feed, e a esmagadora maioria do app é local: tarefas, sessões,
ficha, insights, clima — tudo fica em `shared_preferences` (armazenamento do aparelho) e some
se você desinstalar o app.

**Uma exceção, deliberada e pequena: a frase do dia fala com um provedor de IA.** Ela manda um
resumo curto (classe, clima, contexto, foco do momento) para gerar uma frase de incentivo —
nunca o humor bruto, sessão por sessão. Chave de tier gratuito, sem conta paga vinculada; sem
resposta, o cartão não aparece, sem erro visível. O porquê da reversão do "sem rede" original
e o que foi feito para conter o risco estão em
[`docs/DECISOES.md` §24](docs/DECISOES.md#24-a-frase-do-dia--a-reversão-do-sem-api-registrada).
Todo o resto do app — inclusive os seis insights — continua 100% local, sem exceção.

Na primeira abertura o app semeia 22 sessões fictícias dos últimos 14 dias, com semente
fixa, para que nenhuma tela apareça vazia. Elas são declaradas como fictícias dentro do app
e podem ser removidas na tela **Sobre**.

---

## Desenvolvimento

```bash
flutter pub get
flutter analyze     # sem issues
flutter test        # 100 testes
flutter run
```

Para rodar ou buildar o APK **no FlutLab**, veja [docs/FLUTLAB.md](docs/FLUTLAB.md) — inclui
os dois avisos que são esperados e por que o APK precisa ser gerado como `arm64`.

O app inteiro vive em **`lib/main.dart`** (5.059 linhas), sem imports relativos, por
exigência do ambiente. O mapa navegável do arquivo está em
[docs/ARQUITETURA.md](docs/ARQUITETURA.md).

Os 100 testes cobrem a lógica que não aparece na tela: a sequência com perdão, o motor de
insights e seus limiares, o clima pessoal, a serialização retrocompatível, a resiliência a
dados corrompidos e o dataset de demonstração. Testes não olham para a tela — a interface
foi conferida à parte, rodando o build web num viewport de telefone.

---

## Roadmap

O planejamento completo das próximas melhorias — **com custo, retorno e o que cada uma
quebra** — está em [docs/ROADMAP.md](docs/ROADMAP.md):

| Melhoria | Custo |
|---|---|
| Explicar os 11 métodos de estudo dentro do app | baixo |
| Frase do dia, gerada dos seus próprios dados | baixo |
| Tarefa presente durante a sessão | médio |
| Cores: contraste, amplitude dos climas e modo escuro | alto |
| Trocar a logo | médio |

Mais os itens que a especificação mandou não codar — Ritual Semanal, Modo Provas, arco por
temporada, compartilhamento de cartões e onboarding com quiz — e a **divisão do `main.dart`
em vários arquivos**, adiada por restrição do ambiente de entrega
([docs/DECISOES.md](docs/DECISOES.md) §19).

A **sugestão adaptativa de duração** também estava nessa lista e acabou implementada: ela
reaproveitava o motor de correlação que já existia, então saiu barata.

---

Atribuição de material de terceiros: [`NOTICE.md`](NOTICE.md).
