# Rodando no FlutLab.io — Aura

O FlutLab é o ambiente exigido pela atividade: um IDE Flutter que roda no navegador. Ele
impõe restrições reais ao projeto, e este documento reúne tudo que é preciso saber para
buildar sem surpresa.

Para rodar localmente (`flutter run`), nada aqui é necessário — veja o
[README](../README.md#desenvolvimento).

---

## 1. Estrutura que o FlutLab exige

O projeto Flutter fica na **raiz do repositório**: `pubspec.yaml`, `lib/`, `android/`,
`ios/` e `web/` no primeiro nível.

Isso não é estilo. O importador do FlutLab procura o `pubspec.yaml` no primeiro nível e
falha com *"The following file is required for a Flutter project: pubspec.yaml"* se ele
estiver dentro de uma subpasta. O projeto já esteve em `Aura/` e precisou ser movido.

---

## 2. Importar do GitHub

1. flutlab.io → **Import from VCS** → **From: GitHub**
2. URL deste repositório, e a branch desejada
3. **Get Packages** (equivalente ao `flutter pub get`)
4. **Run/Build** → Web para o Hot Preview, ou **APK** para o celular

**Alternativa sem VCS:** crie um **New Project** com o template Flutter básico e substitua
o conteúdo de `pubspec.yaml` e `lib/main.dart` pelos deste repositório. Como o app é um
arquivo único, isso funciona — mas você perde `android/` e `ios/`, e com eles o ícone e a
abertura própria.

> ### O GitHub e o FlutLab não sincronizam sozinhos
>
> Um push neste repositório **não** aparece no editor do FlutLab. É preciso reimportar o
> projeto a partir do repositório atualizado.
>
> E evite editar nos dois lugares ao mesmo tempo: o FlutLab não faz merge, então a próxima
> reimportação descarta o que você tiver editado só lá.

---

## 3. Gerar o APK — sempre `arm64`

> ## ⚠️ Escolha `android arm64`, nunca `android arm`
>
> O alvo `arm` produz um binário só de 32 bits (`armeabi-v7a`). Celulares novos são arm64, e
> em vários deles a engine nativa do Flutter não carrega: **o app instala, abre e fecha
> sozinho**, com a mensagem genérica do Android e nenhum stack trace.
>
> Foi o defeito mais caro deste projeto, e foi diagnosticado errado duas vezes antes de o
> teste no aparelho provar a causa. O registro completo está em
> [DECISOES.md §6](DECISOES.md) e [RELATORIO-E2E.md §4.1](RELATORIO-E2E.md).

O APK arm64 gerado assim tem cerca de **8,5 MB**.

### 3.1 Como conferir a ABI depois de gerado

O log do build **não** diz qual alvo foi usado — ele mostra só `Running Gradle task
'assembleRelease'`, igual para os dois. E o tamanho do arquivo não distingue: `arm` e `arm64`
saem parecidos.

Quem responde é o próprio APK. Renomeie o `.apk` para `.zip`, abra, e olhe dentro de `lib/`:

| O que tem em `lib/` | Significado |
|---|---|
| `arm64-v8a/` | **correto** — 64 bits |
| `armeabi-v7a/` | **errado** — é o alvo `arm`; o app instala e fecha ao abrir |

Vale fazer isso uma vez, na hora de guardar o arquivo. Encerra uma dúvida que já custou dias
neste projeto, e leva menos de um minuto.

---

## 4. Três coisas que o FlutLab mostra e não são problema

Nenhuma das três impede o build, e nenhuma é problema deste projeto. As duas primeiras são
avisos; a terceira parece um desastre e não é.

### 4.1 Aba Build — aviso sobre a NDK

O FlutLab avisa que `shared_preferences_android` exige a NDK `27.0.12077973`, enquanto o
projeto usa a `flutter.ndkVersion` (26.3.11579264 no Flutter 3.32).

**É intencional.** O app não traz nenhuma dependência com código nativo próprio, então as
únicas libs `.so` do APK vêm da engine do Flutter, que já cuida do alinhamento. Fixar a 27
exigiria essa NDK instalada no ambiente de build, o que não dá para garantir no FlutLab — e
o APK que funciona no aparelho foi gerado **sem** o pin.

O pin chegou a ser aplicado e foi revertido; o histórico está em [DECISOES.md §5](DECISOES.md).

### 4.2 Aba Analyzer — regras de lint "não reconhecidas"

O Analyzer do FlutLab acusa `no_wildcard_variable_uses` e `type_literal_in_constant_pattern`
como regras não reconhecidas.

**Vem do analisador do FlutLab, não do projeto.** As duas regras seguem ativas no
`package:lints` até a 6.1.0, e aqui, no mesmo Flutter 3.32.8, nem `flutter analyze` nem
`dart analyze` emitem qualquer aviso. **Subir o `flutter_lints` não resolve** — só troca a
versão do pacote que lista exatamente as mesmas regras.

O `analysis_options.yaml` traz `included_file_warning: ignore`, que silencia o diagnóstico
do arquivo incluído sem desligar nenhuma verificação do nosso código. O código de
diagnóstico foi validado com um teste de controle — [DECISOES.md §14](DECISOES.md).

### 4.3 Uma pilha de stack traces Java no meio do build

Este é o mais assustador dos três, e o mais inofensivo. No meio do
`Running Gradle task 'assembleRelease'` podem aparecer **dezenas de exceções Java** como esta,
repetidas:

```
Failed to execute org.gradle.cache.internal.AsyncCacheAccessDecoratedCache$$Lambda...
org.gradle.api.UncheckedIOException: Could not add entry '/var/workspace/.gradle/caches/...'
    to cache file-access.bin (/var/workspace/.gradle/caches/journal-1/file-access.bin).
Caused by: org.gradle.cache.internal.btree.CorruptedCacheException:
    Corrupted IndexBlock 632126 found in cache '.../journal-1/file-access.bin'.
```

**Por que não é fatal.** Olhe de onde as exceções vêm: `AsyncCacheAccessDecoratedCache` →
`ExclusiveCacheAccessingWorker`. É um worker **assíncrono**, e o `file-access.bin` que ele não
consegue escrever é o *journal* do cache — o arquivo de contabilidade que o Gradle usa para
decidir o que expirar. **Não é saída de build.** O Gradle registra a falha do worker e segue
compilando.

Repare também nos caminhos citados: `/var/workspace/.gradle/caches/...`. É o cache
compartilhado da máquina do FlutLab que está corrompido, não nada deste repositório — nenhuma
entrada citada é código do Aura.

**Como saber se deu certo mesmo assim.** Ignore o meio e vá para o fim do log. Se aparecerem
estas duas linhas, o APK é válido:

```
✓ Built build/app/outputs/flutter-apk/app-release.apk (8.5MB)
✔️ Build completed successfully.
```

Foi exatamente o que aconteceu no build do APK final: ~15 stack traces, e o APK saiu inteiro.

**Se um dia falhar de verdade por causa disso**, a saída é **reimportar o projeto** — um
workspace novo vem com cache novo. Não mexa no `build.gradle.kts`: o problema não está lá, e
alterar o build sob uma hipótese errada já custou caro neste projeto uma vez
([DECISOES.md §5](DECISOES.md)).

---

## 5. Dependências, e por que estão travadas

Quatro pacotes, todos gratuitos do pub.dev: `shared_preferences`, `percent_indicator`,
`fl_chart` e `cupertino_icons`. Dependências enxutas são uma exigência prática do FlutLab —
mais que isso degrada o Hot Preview.

As versões estão presas ao que roda no **Flutter 3.32**, o padrão atual do FlutLab (o
seletor no rodapé do editor também oferece 3.41 e 3.29). Verificado nas duas pontas, 3.32 e
3.47:

### `shared_preferences: ^2.5.3`

Da 2.5.4 em diante exige **Dart ≥ 3.9**, e o Flutter 3.32 traz Dart 3.8.1. O caret é
deliberado: o problema é só de SDK, então o pub sobe sozinho num ambiente mais novo.

### `fl_chart: 1.0.0` — pin exato, não faixa

Este merece atenção, porque a leitura óbvia leva à versão errada.

- A **1.1.1+** exige `vector_math ^2.2.0`, enquanto o `flutter_test` do 3.32 fixa a 2.1.4.
  Conflito visível: o `pub get` falha e você percebe.
- A **1.1.0** *declara* `^2.1.4` e por isso **resolve** — mas chama
  `Matrix4.translateByDouble` e `scaleByDouble`, que só existem na 2.2.0. Ela passa no
  `pub get`, passa no `analyze`, e **só quebra na compilação**.

Como o pub não enxerga erro de compilação, uma faixa aberta como `^1.1.0` cairia justamente
na versão quebrada. A 1.0.0 é a mais nova que compila de verdade com `vector_math 2.1.4`, e
o pin está comentado no `pubspec.yaml` para ninguém "modernizar" isso sem entender o motivo.

O `pubspec.lock` versionado foi gerado no Flutter 3.32, o menor denominador comum.

---

## 6. Restrições do FlutLab respeitadas pelo código

| Restrição | Como aparece no código |
|---|---|
| Arquivo único, sem imports relativos | tudo em `lib/main.dart` |
| Sem `.withOpacity()` (depreciado) | `.withValues(alpha:)` em todo lugar |
| Sem `CardTheme`/`CardThemeData` | `AuraCard` é `Container` + `BoxDecoration` |
| Dependências enxutas | 4 pacotes |
| Nada de câmera, sensores ou notificações | nenhum item do MVP depende disso |

Também foram evitados `DropdownButtonFormField` (a API mudou entre versões) e
`Iterable.firstOrNull`, ambos por compatibilidade com SDKs mais antigos que o FlutLab pode
estar rodando.

O impacto arquitetural dessas restrições está em [ARQUITETURA.md](ARQUITETURA.md); o
*porquê* de cada uma, em [DECISOES.md](DECISOES.md).
