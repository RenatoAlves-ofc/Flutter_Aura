# Convenções do Aura

Instruções para quem trabalha neste repositório — pessoa ou agente. **Cada regra aqui existe
porque a falta dela já custou caro neste projeto**; nenhuma é preferência de estilo.

Contexto: app Flutter de entrega acadêmica, apresentado em **24/08/2026**. Pomodoro que
correlaciona estado de entrada × duração de foco × método.

---

## 1. Não diga que está pronto sem rodar isto

```bash
export PATH=/opt/f332/flutter/bin:$PATH   # 3.32.8 — o SDK do FlutLab
flutter analyze && flutter test

flutter clean                              # OBRIGATÓRIO entre SDKs

export PATH=/opt/flutter/bin:$PATH         # 3.47.0
flutter analyze && flutter test

bash tool/verifica_docs.sh                 # antes de commitar documentação
```

**Os dois SDKs, sempre.** O FlutLab usa a **3.32.8** e é lá que o APK é gerado; o
desenvolvimento local usa a mais nova. Verificar num só já deixou passar defeito.

**O `flutter clean` entre eles não é higiene, é necessidade.** Sem ele o `build/` guarda o
`shaders/ink_sparkle.frag` de um SDK e o outro falha ao carregá-lo, com um erro que não tem
nada a ver com o seu código:

```
Exception: Asset 'shaders/ink_sparkle.frag' manifest could not be decoded:
INVALID_ARGUMENT: Runtime stages buffer failed verification.
```

`rm -rf .dart_tool` **não** resolve — é o `flutter clean` que limpa o `build/`.

> **Isto já foi ignorado.** Dois PRs foram mergeados sem `analyze` nem `test` e deixaram a
> `main` vermelha a dois dias da apresentação. O relatório de handoff dizia, com todas as
> letras, que a suíte não tinha sido rodada. Não repita.

## 2. `pump(Duration)`, não `pumpAndSettle`, com sessão rodando

`pumpAndSettle` roda frames até não sobrar animação. O halo do cronômetro usa
`repeat(reverse: true)` e **nunca termina** — o teste trava com `pumpAndSettle timed out`.

```dart
await tester.pump();                                   // processa o toque
await tester.pump(const Duration(milliseconds: 400));  // avança um tanto fixo
```

Vale **inclusive depois de sair da aba Foco**: o `IndexedStack` envolve cada filho em
`Visibility.maintain`, que tem `maintainSize: true` e por isso **nunca aplica `TickerMode`**.
A aba fica montada fora da tela com o halo ainda respirando. Detalhe em
[`ARQUITETURA.md` §10](docs/ARQUITETURA.md).

## 3. Documentação: cite símbolo, nunca `arquivo:linha`

Escreva `` `kBrandIndigo`, em `lib/src/aura_models.dart` ``. Nunca `lib/main.dart:389`.

O `PALETA-DE-CORES.md` nasceu com 13 referências de linha e **as 13 apodreceram de uma vez**
quando o refactor em `part` moveu os símbolos — cinco apontavam para linhas inexistentes. O
`tool/verifica_docs.sh` agora recusa `arquivo.dart:NNN` (exceto no `PLANO-V2.md`, que é
registro histórico e está marcado como tal).

**Rode `bash tool/verifica_docs.sh` antes de commitar qualquer `.md`.** Ele confere contra o
código: contagem de testes, linhas de `main.dart`, quantidade/limiares/ordem das descobertas,
nomes de aba, contagem de métodos, imagens e links.

## 4. Estrutura: `part`, não `import`

`lib/main.dart` é a biblioteca; `lib/src/aura_models.dart`, `aura_store.dart` e
`aura_logic.dart` são `part` dela. **Não transforme em bibliotecas com `import`** — a
especificação do projeto proíbe imports relativos por restrição do FlutLab, e os testes
importam `package:aura/main.dart` contando com uma única biblioteca.

Estado é `setState` em `_HomeShellState`, passado por parâmetro. **Não introduza Provider,
Bloc ou Riverpod** — é restrição registrada, não gosto.

`_recordSession` é o **único** ponto de entrada de uma sessão concluída, e `_applySessions` o
único que troca o conjunto. Gravar sessão por fora já fez a aba Ficha abrir com "0 dias de
sequência" ao lado de "20 sessões totais".

## 5. Cor: três papéis, e só

| Papel | Quem |
|---|---|
| Estrutura do app | `kBrandIndigo` — marca, botões, anel, números |
| Estado do usuário | `AuraClimate.accent` — fundo, brilho, halo |
| Exceção semântica | onde a cor **é** a informação: `_priorityColor`, `moodColors` |

Cor nova fora desses três papéis é desvio. Inventário completo em
[`PALETA-DE-CORES.md`](docs/PALETA-DE-CORES.md).

## 6. Android: duas armadilhas

**Não fixe `ndkVersion`.** Já foi fixado duas vezes e revertido nas duas. O
`shared_preferences_android` não tem uma linha de código nativo e não declara NDK nenhuma —
o pin não protege `.so` alguma e troca um aviso cosmético por risco de build quebrado.
Deixe `ndkVersion = flutter.ndkVersion` e ignore o aviso vermelho.

**O APK tem que ser `arm64`.** `arm` gera binário de 32 bits e o app fecha ao abrir, sem
stack trace, antes de qualquer código Dart rodar. Foi diagnosticado errado duas vezes.

## 7. Git

- Desenvolva na branch designada. **Nunca faça push direto na `main`.**
- **Não commite `ios/Flutter/Generated.xcconfig` nem `flutter_export_environment.sh`** — a
  troca de SDK reescreve o `FLUTTER_ROOT` neles. `git checkout --` neles antes de commitar.
- Mensagem de commit explica **por quê**, não só o quê. O `CHANGELOG.md` registra também o
  que estava errado antes, inclusive quando fui eu que errei.

## 8. O que não fazer a esta altura

A apresentação é **24/08**. Mudança em `lib/` obriga a **refazer o APK no FlutLab e repetir a
verificação inteira**. Antes de tocar em `lib/`, pergunte se o ganho paga esse ciclo — a
resposta quase sempre é não. Documentação, `docs/` e `tool/` não entram no APK e são seguros.

O que está deliberadamente fora, para não ser "consertado" por engano:

- **`InsightsPage` e `SummaryPage` mantêm os nomes antigos** enquanto as abas se chamam
  Descobertas e Ficha. Renomear é churn sem ganho agora.
- **`namespace` continua `com.example.aura`** — só o `applicationId` mudou. Mexer exigiria
  mover o pacote Kotlin, e errar isso quebra o app na abertura.
- **As chaves de API estão expostas de propósito**, são de tier gratuito sem saldo. Ver
  [`DECISOES.md` §24](docs/DECISOES.md).

## 9. Onde está escrito o resto

| Pergunta | Documento |
|---|---|
| Por que o código é assim? | [`DECISOES.md`](docs/DECISOES.md) — inclui o que deu errado e foi revertido |
| Como está organizado? | [`ARQUITETURA.md`](docs/ARQUITETURA.md) |
| O que falta entregar? | [`ENTREGA.md`](docs/ENTREGA.md) |
| Como buildar o APK? | [`FLUTLAB.md`](docs/FLUTLAB.md) |

**Ao mudar comportamento, atualize a documentação na mesma passada** e rode o
`verifica_docs.sh`. Documentação errada é pior que documentação faltando: ninguém desconfia
dela. Esta rodada existiu para consertar sete afirmações falsas que entraram exatamente assim.
