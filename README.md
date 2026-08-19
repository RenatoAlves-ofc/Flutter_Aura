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
| [Changelog](CHANGELOG.md) | Histórico de mudanças |

---

## O que o app faz

| Aba | Conteúdo |
|---|---|
| **Foco** | Cronômetro com 11 métodos, check de humor antes e depois de cada sessão, sugestão adaptativa de método e vínculo opcional com uma tarefa |
| **Tarefas** | Lista com prioridade (Alta/Média/Baixa), persistida localmente |
| **Insights** | 4 descobertas desbloqueáveis + gráfico de correlação e ritmo semanal |
| **Resumo** | Clima pessoal (a aura), sequência com perdão, pontos e minutos focados |

Mais a tela **Sobre**, com a mensagem de privacidade e o controle do dataset de demonstração.

### Os diferenciais

**Insights desbloqueáveis.** Quatro comparações em Dart puro sobre as sessões salvas — sem
IA, sem API, sem rede. Cada uma exige um volume mínimo de dados (5, 5, 7 e 6 sessões) e
aparece bloqueada até lá, dizendo quantas faltam. Uma descoberta tirada de duas sessões não
seria uma descoberta.

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

---

## Privacidade

Seus dados de humor não saem do seu celular. O Aura não tem login, não tem servidor e não
tem feed. Tudo fica em `shared_preferences` (armazenamento local do aparelho) e some se você
desinstalar o app.

Na primeira abertura o app semeia 22 sessões fictícias dos últimos 14 dias, com semente
fixa, para que nenhuma tela apareça vazia. Elas são declaradas como fictícias dentro do app
e podem ser removidas na tela **Sobre**.

---

## Desenvolvimento

```bash
flutter pub get
flutter analyze     # sem issues
flutter test        # 67 testes
flutter run
```

Para rodar ou buildar o APK **no FlutLab**, veja [docs/FLUTLAB.md](docs/FLUTLAB.md) — inclui
os dois avisos que são esperados e por que o APK precisa ser gerado como `arm64`.

O app inteiro vive em **`lib/main.dart`** (3.684 linhas), sem imports relativos, por
exigência do ambiente. O mapa navegável do arquivo está em
[docs/ARQUITETURA.md](docs/ARQUITETURA.md).

Os 67 testes cobrem a lógica que não aparece na tela: a sequência com perdão, o motor de
insights e seus limiares, o clima pessoal, a serialização retrocompatível, a resiliência a
dados corrompidos e o dataset de demonstração. Testes não olham para a tela — a interface
foi conferida à parte, rodando o build web num viewport de telefone.

---

## Roadmap (fora do MVP)

Ritual Semanal de fechamento, Modo Provas, arco fechado por temporada, compartilhamento de
cartões de insight e onboarding com quiz de expectativa.

A **sugestão adaptativa de duração** também estava nesta lista e acabou implementada: ela
reaproveitava o motor de correlação que já existia, então saiu barata.

---

Atribuição de material de terceiros: [`NOTICE.md`](NOTICE.md).
