# Aura

**Um Pomodoro que aprende com você.**

Em vez de só contar minutos, o Aura cruza como você está se sentindo com quanto tempo
você realmente consegue manter o foco — e devolve isso como descobertas pessoais, não
como pontos genéricos. Sua aura muda com seu estado real. Tudo local, sem login, sem feed.

O diferencial não é o cronômetro: é o **motor de correlação entre humor, duração de foco
e método utilizado**. Todo o resto do app existe para alimentar ou expor esse motor.

---

## O que o app faz

| Aba | Conteúdo |
|---|---|
| **Foco** | Temporizador com 11 métodos de foco, check de humor antes e depois de cada sessão, e vínculo opcional com uma tarefa |
| **Tarefas** | Lista com prioridade (Alta/Média/Baixa), persistida localmente |
| **Insights** | 4 descobertas desbloqueáveis + gráfico de correlação e ritmo semanal |
| **Resumo** | Clima pessoal (a aura), sequência com perdão, pontos e minutos focados |

Mais a tela **Sobre**, com a mensagem de privacidade e o controle do dataset de demonstração.

### Os 11 métodos de foco

Pomodoro Clássico (25/5), Pomodoro Longo (50/10), 52/17, Ciclo Ultradiano (90/20),
Meia Hora Cheia (45/15), Sessão Curta (20/5), Hora Cheia (60/10), Micro-sessão (15/5),
40/20, **Flowtime/Flowmodoro** (contagem progressiva, sem alvo — a pausa sugerida cresce
com o tempo sustentado) e **Personalizado** (durações definidas pelo usuário).

Todos reaproveitam o mesmo temporizador: os métodos são uma lista de dados, não 11 telas.

### Insights desbloqueáveis

Comparações em Dart puro sobre as sessões salvas — sem IA, sem API, sem rede. Cada uma
tem um volume mínimo de dados e aparece bloqueada até lá:

| Descoberta | Mínimo |
|---|---|
| Humor inicial × duração do foco | 5 sessões |
| Diferença entre humor antes e depois | 5 sessões |
| Melhor dia da semana | 7 sessões |
| Método com melhor desempenho | 6 sessões, 2+ métodos repetidos |

### Sequência com perdão

A cada 3 dias seguidos você ganha um token de folga (teto de 3). Se faltar **exatamente
um** dia, o token é gasto automaticamente e a sequência continua de pé. Buracos maiores
reiniciam a contagem.

### Clima pessoal (a aura)

O fundo do app muda conforme as suas sessões recentes, em 4 estados — Radiante, Fluindo,
Nublado e Recolhido — mais o estado neutro de quem ainda não tem dados. Sem assets novos:
só `Container` + `BoxDecoration` com gradiente.

### Dados de demonstração

Na primeira abertura o app semeia 22 sessões fictícias dos últimos 14 dias, para que
nenhuma tela apareça vazia. Elas são geradas com semente fixa (sempre iguais) e podem ser
removidas na tela **Sobre** sem afetar suas sessões reais.

---

## Privacidade

Seus dados de humor não saem do seu celular. O Aura não tem login, não tem servidor e não
tem feed. Tudo fica em `shared_preferences` (armazenamento local do aparelho) e some se
você desinstalar o app.

---

## Como rodar no FlutLab.io

O projeto Flutter fica na **raiz do repositório** (`pubspec.yaml`, `lib/`, `android/`,
`ios/` e `web/` no primeiro nível) — o FlutLab exige isso para importar de um repositório.

**Importando do GitHub:** flutlab.io → **Import from VCS** → **From: GitHub**, com a URL
deste repositório e a branch desejada.

**Ou colando à mão:** crie um **New Project** com o template Flutter básico e substitua o
conteúdo de `pubspec.yaml` e `lib/main.dart` pelos deste projeto.

Nos dois casos: **Get Packages** (equivalente a `flutter pub get`) e então **Run/Build** →
Web para o Hot Preview, ou gere o **APK** para testar no celular via QR Code.

> **Ao gerar o APK, escolha `android arm64`, não `android arm`.** O alvo `arm` produz um
> binário só de 32 bits (`armeabi-v7a`), e celulares novos são arm64 — em vários deles a
> engine do Flutter não carrega, e o app instala mas fecha sozinho ao abrir.

> O GitHub e o FlutLab **não sincronizam automaticamente**. Um push neste repositório não
> aparece sozinho no editor do FlutLab — é preciso reimportar o projeto lá a partir do
> repositório atualizado. Evite editar nos dois lugares ao mesmo tempo.

### Restrições respeitadas pelo código

- **Arquivo único** (`lib/main.dart`), sem imports relativos
- Sem `.withOpacity()` (depreciado) — usa `.withValues(alpha:)`
- Sem `CardTheme`/`CardThemeData` — usa `Container` + `BoxDecoration`
- Dependências enxutas, para não degradar o Hot Preview
- Nada que dependa de câmera, sensores ou notificações locais

### Dependências

`shared_preferences`, `percent_indicator`, `fl_chart`, `cupertino_icons` — todas gratuitas
do pub.dev.

As versões estão presas ao que roda no **Flutter 3.32**, o padrão atual do FlutLab
(o seletor no rodapé do editor também oferece 3.41 e 3.29). Verificado nas duas pontas,
3.32 e 3.47:

- **`shared_preferences: ^2.5.3`** — da 2.5.4 em diante exige Dart ≥ 3.9, e o Flutter 3.32
  traz Dart 3.8.1. O caret deixa o pub subir sozinho num SDK mais novo.
- **`fl_chart: 1.0.0`** — fixado, não em faixa. A 1.1.1+ exige `vector_math ^2.2.0`,
  enquanto o `flutter_test` do 3.32 fixa 2.1.4. A 1.1.0 *declara* `^2.1.4` mas chama
  `Matrix4.translateByDouble`/`scaleByDouble`, que só existem na 2.2.0 — ela resolve e
  passa no `analyze`, e só quebra na compilação. Como o pub não enxerga esse erro, uma
  faixa aberta cairia justamente nessa versão. A 1.0.0 é a mais nova que compila de
  verdade com `vector_math 2.1.4`.

O `pubspec.lock` versionado foi gerado no Flutter 3.32, o menor denominador comum.

---

## Desenvolvimento

```bash
flutter pub get
flutter analyze     # sem issues
flutter test        # 54 testes
flutter run
```

Os testes cobrem a lógica que não aparece na tela e não pode quebrar: a regra de sequência
com perdão, o motor de insights e seus limiares, o clima pessoal, a serialização (incluindo
compatibilidade com dados salvos por versões anteriores), a resiliência a dados corrompidos
no armazenamento local e o dataset de demonstração. Há também um smoke test de interface
que sobe o app e navega por todas as abas.

Testes não olham para a tela, então a interface foi conferida à parte, rodando o build web
num viewport de telefone e inspecionando cada aba — foi assim que apareceram o
`Resumo` incoerente e as sobras de template do FlutLab.

## Roadmap (fora do MVP)

Ritual Semanal de fechamento, Modo Provas, arco fechado por temporada, sugestão adaptativa
de duração, compartilhamento de cartões de insight e onboarding com quiz de expectativa.
