# Paleta de cores — Aura

Inventário da paleta de cores tal como ela existe hoje: valores exatos, onde cada um aparece
e três coincidências de valor que a regra de cor não previu.

**Não é um plano de mudança.** As três frentes de melhoria de cor — contraste, amplitude dos
climas e modo escuro — estão em [`ROADMAP.md` §1](ROADMAP.md#1-cores), com a análise de custo
e o que cada uma quebra. Este documento não duplica aquela investigação, só a referencia.

> **Aqui se cita arquivo e símbolo, nunca `arquivo:linha`.** Este documento nasceu com 13
> referências de linha e **todas as 13 apodreceram de uma vez** quando o refactor em `part`
> moveu os símbolos para `lib/src/` — cinco delas apontavam para linhas que nem existem mais
> (`lib/main.dart:4402`, num arquivo de 3.434 linhas). Nome de símbolo sobrevive a refactor;
> número de linha não sobrevive nem a um `git commit`. O `tool/verifica_docs.sh` agora recusa
> `arquivo.dart:NNN` na documentação, justamente para isso não voltar.

---

## A regra

[`ARQUITETURA.md` §7](ARQUITETURA.md#7-a-regra-de-cor) explica o porquê. Em três linhas:

```
kBrandIndigo        →  ESTRUTURA DO APP        (marca, botões, anel, números)
AuraClimate.accent  →  ESTADO DO USUÁRIO        (fundo, brilho, halo)
cores semânticas    →  EXCEÇÃO: a cor É a informação (prioridade, humor)
```

Fora desses três papéis, uma cor nova na interface é um desvio da regra.

---

## Índigo — estrutura

| Constante | Local | Valor |
|---|---|---|
| `kBrandIndigo` | `lib/src/aura_models.dart` | `0xFF6C63FF` |
| `colorSchemeSeed` (`ThemeData`) | `lib/main.dart`, em `AuraApp.build` | `0xFF6C63FF` — mesmo tom, semeia toda a paleta derivada do Material 3 (`colorScheme.primary`, `.outline`, `.outlineVariant` etc.) |
| `kSplashGradient` | `lib/main.dart` | `0xFF8B84FF` → `0xFF4A41C7` |

**A abertura nativa usa o mesmo índigo, byte a byte.**
`android/app/src/main/res/drawable/launch_gradient.xml` declara `startColor="#8B84FF"` e
`endColor="#4A41C7"` — os mesmos dois tons de `kSplashGradient`, confirmados um a um. É essa
igualdade que impede a abertura de piscar branco entre a tela nativa e a primeira tela Dart,
defeito corrigido e registrado em [`DECISOES.md` §16](DECISOES.md).

O mesmo gradiente aparece uma terceira vez em
`android/app/src/main/res/drawable/ic_launcher_background.xml` (fundo do ícone adaptativo),
com um comentário no próprio XML: *"Mesmos índigos do símbolo."*

---

## Os 5 climas

`AuraClimate` (`lib/src/aura_logic.dart`) — gradiente de fundo e `accent` de cada estado:

| Clima | Gradiente (início → fim) | Accent |
|---|---|---|
| Aura em branco (neutro) | `0xFFF4F2FB` → `0xFFE8E5F6` | `0xFF6C63FF` (= `kBrandIndigo`) |
| Radiante | `0xFFFFF6DE` → `0xFFFFE0C2` | `0xFFEF9A2E` |
| Fluindo | `0xFFE1F5F1` → `0xFFDCE6FF` | `0xFF2A9D8F` |
| Nublado | `0xFFEDF0F4` → `0xFFDCE2EA` | `0xFF5C6B7A` |
| Recolhido | `0xFFEAE6F2` → `0xFFD9D3E8` | `0xFF6D5B9E` |

Só o clima neutro tem o próprio `accent` igual ao índigo estrutural — os outros quatro têm
`accent` próprio, coerente com "estado do usuário" na regra acima.

**O gradiente neutro é reaproveitado fora do sistema de clima**, como fundo estático de telas
que não têm sessão para calcular um clima: `AuraErrorScreen` e `AboutPage`, ambas em `lib/main.dart`. Não é um sexto clima — é o mesmo par de cores usado como
plano de fundo neutro por padrão.

A amplitude pequena entre os cinco (luminância entre 0,80 e 0,92) já está medida e discutida
em [`ROADMAP.md` §1.2](ROADMAP.md#12-os-climas-se-parecem-demais--e-dá-para-provar).

---

## Cores semânticas

As duas exceções deliberadas da regra:

**Prioridade de tarefa** — `_priorityColor` (`lib/main.dart`, em `_TaskListPageState`):

| Prioridade | Cor |
|---|---|
| Alta | `Colors.red` |
| Média (padrão) | `Colors.orange` |
| Baixa | `Colors.green` |

São as cores nomeadas do Material, não hex do app — únicas exceções à convenção de hex
explícito porque a semântica (perigo/atenção/tranquilo) já é a do próprio nome Material.

**Faces do check de humor** — `moodColors` (`lib/src/aura_models.dart`), lista de 6, índice 0
sem uso (era um placeholder de ícone):

| Índice | Rótulo | Cor |
|---|---|---|
| 0 | (sem uso — ícone placeholder) | `0xFF9E9E9E` |
| 1 | Exausto | `0xFFE57373` |
| 2 | Cansado | `0xFFFFB74D` |
| 3 | Neutro | `0xFFFFD54F` |
| 4 | Bem | `0xFF81C784` |
| 5 | Ótimo | `0xFF4DB6AC` |

---

## Superfícies e texto

| Elemento | Local | Valor |
|---|---|---|
| `AuraCard` (fundo) | `lib/main.dart` | `Colors.white` alpha `0.82` |
| `AuraCard` (sombra) | `lib/main.dart` | `Colors.black` alpha `0.05` |
| `Scaffold` | `lib/main.dart`, em `AuraApp.build` | `scaffoldBackgroundColor: Colors.transparent` — cada tela pinta o próprio gradiente atrás |
| Texto (`bodySmall`, `bodyMedium` etc.) | em todo o arquivo | sem cor explícita — usa os tons derivados do `colorSchemeSeed` pelo Material 3 |

O branco 82% opaco de `AuraCard` é o suspeito principal de contraste insuficiente para texto
secundário sobre ele — ainda **não medido** contra WCAG 2.2. Ver
[`ROADMAP.md` §1.1](ROADMAP.md#11-contraste--a-mais-barata-e-a-única-que-é-defeito).

---

## Duas coincidências de valor

Achadas ao inventariar cada hex do arquivo — nenhuma das duas é reaproveitamento proposital,
e vale registrar para que não sejam confundidas com um mais tarde.

**O teal da pausa do cronômetro é o mesmo hex de "Ótimo".** O modo *break* do cronômetro
(`lib/main.dart`, no `_FocusPageState`) usa `0xFF4DB6AC` — exatamente o valor de
`moodColors[5]`. Nenhuma tela mostra os dois lado a lado hoje, então não é um bug visível,
mas são dois conceitos diferentes (estado do cronômetro vs. faixa de humor) compartilhando um
valor por coincidência, não por regra.

**O amber padrão de `AuraMark` é o mesmo hex de "Neutro".** `AuraMark.ringColor`
(`lib/main.dart`) tem `0xFFFFD54F` como valor default da classe — igual a
`moodColors[3]`. Na prática **todo call site real sobrescreve** esse padrão (o da AppBar usa
`kBrandIndigo`, o da tela de abertura usa o branco de `coreColor`), então o amber nunca chega
a aparecer na tela. O risco é só para o futuro: um novo call site que esqueça de passar
`ringColor` herdaria essa cor por acidente.

---

## Onde a cor não é Dart

Duas frentes fora de `lib/main.dart` que precisam mudar **juntas** com qualquer alteração de
marca — a razão está detalhada em [`ROADMAP.md` §3](ROADMAP.md#3-trocar-a-logo):

| Arquivo | Papel |
|---|---|
| `lib/main.dart` (`kSplashGradient`) | abertura desenhada em Dart, depois que o app sobe |
| `android/app/src/main/res/drawable/launch_gradient.xml` | abertura nativa, antes de qualquer código Dart rodar |

Não há como compartilhar uma constante entre Dart e XML — mudar um sem o outro faz a abertura
piscar, o defeito que a igualdade atual evita (ver §"Índigo — estrutura" acima).

Há uma terceira frente, e ela é a **única cor do app declarada em XML e não em Dart**:

| Arquivo | Cor | Papel |
|---|---|---|
| `android/app/src/main/res/values/colors.xml` | `#F4F2FB` (`aura_window_background`) | a janela **atrás** da interface do Flutter, entre a abertura sair e o primeiro frame |

É o mesmo `0xFFF4F2FB` do primeiro tom do clima neutro, escrito duas vezes — uma em Dart,
outra em XML — pelo mesmo motivo do `kSplashGradient`: não há como compartilhar constante
entre os dois lados. **Mudar o clima neutro sem mudar este XML faz a abertura piscar.**

`values-night/styles.xml` aponta para essa **mesma** cor, sem divergir do tema claro — o que
confirma que **não há modo escuro** hoje, consistente com
[`ROADMAP.md` §1.3](ROADMAP.md#13-modo-escuro--a-mais-cara). Ele já divergiu, e era defeito:
herdava o preto de `Theme.Black.NoTitleBar` e dava um flash preto na abertura em aparelho no
modo escuro ([`DECISOES.md` §26](DECISOES.md)).
