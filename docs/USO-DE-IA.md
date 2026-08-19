# Uso de IA no desenvolvimento — Aura

Registro de como a inteligência artificial foi usada para construir este projeto, o que ela
fez bem e — a parte que importa mais — **onde ela errou e como os erros foram derrubados**.

Este documento atende ao item "comprovante da interação com IA" do checklist da atividade.
Ele foi escrito como registro de processo, não como propaganda: uma lista só de acertos não
provaria nada sobre o método de trabalho.

---

## 1. O que a IA fez e o que não fez

| Fez | Não fez |
|---|---|
| Escreveu o código a partir da especificação | Definiu o produto, o público-alvo ou o diferencial |
| Escreveu os 70 testes | Testou em aparelho real — só o autor tinha o celular |
| Escreveu esta documentação | Gerou o APK, o QR Code ou os slides |
| Diagnosticou defeitos e propôs correções | Acertou todos os diagnósticos de primeira (ver §3) |

**Dentro do app não há IA nenhuma.** Os "insights" são comparações aritméticas em Dart puro
sobre as sessões salvas — média por faixa de humor, média por dia da semana, média por
método. Nenhuma chamada de rede, nenhuma API, nenhum modelo. A pasta `.claude/` é ferramenta
de desenvolvimento e não é compilada no APK.

Isso é uma escolha de produto defensável e vale dizer na apresentação: um app que promete
privacidade não pode mandar o humor do usuário para um servidor de terceiros para "gerar
insights".

---

## 2. Ferramental

Desenvolvido com **Claude Code**, o agente de linha de comando da Anthropic, com um conjunto
de agents, skills e commands de terceiros instalados no repositório em `.claude/`
(atribuição em [`NOTICE.md`](../NOTICE.md)):

| Categoria | Quantidade | Usados de fato |
|---|---|---|
| Agents | 6 | `flutter-expert`, `code-reviewer`, `error-detective` |
| Skills | 2 | `mobile-development` |
| Commands | 13 conjuntos | `code-review`, `double-check`, `smart-commit` |

Mais as skills nativas `code-review` e `security-review`, aplicadas sobre o `lib/main.dart`
inteiro antes de congelar o código. A revisão apontou **7 problemas, todos válidos e todos
corrigidos** — entre eles a sugestão adaptativa continuar marcada ao trocar de humor, que
aplicaria um método que o usuário nunca chegou a ver.

---

## 3. Onde a IA errou

Três diagnósticos errados, e o que os derrubou em cada caso. Nenhum foi descoberto pela
própria IA sozinha.

### 3.1 O crash do APK — dois diagnósticos errados seguidos

**O que a IA afirmou.** Primeiro, que era falha de *instalação*. Depois, que era
desalinhamento de memória de 16 KB, exigência do Android 15+. Chegou a construir uma
instrumentação global de erros com tela legível para capturar o problema.

**O que provou o contrário.** O teste do autor no aparelho: gerando o APK como `arm`, o app
quebra; como `arm64`, funciona. Simples, direto, e conclusivo.

**Por que a IA errou.** Ela investiu em observabilidade **do lado errado da fronteira**. O
alvo `arm` gera binário de 32 bits e a engine nativa não carrega em aparelho arm64 — o app
morre *antes de qualquer código Dart rodar*. Uma tela de erro escrita em Dart nunca poderia
aparecer. O próprio sintoma ("apareceu a caixa do Android, não a tela do app") já era a prova
de que a falha era nativa, e passou despercebido.

**O que sobrou de bom.** A instrumentação foi mantida, porque protege contra falhas em Dart,
que continuam possíveis. E ao construí-la apareceu um defeito legítimo: os `jsonDecode` do
armazenamento local não tinham `try/catch`, então um único registro malformado deixaria o
app impossível de abrir para sempre.

### 3.2 O pin da NDK

**O que a IA fez.** Fixou `ndkVersion = "27.0.12077973"` como correção do crash, sob a
hipótese dos 16 KB.

**O que derrubou.** A causa real (§3.1). Com ela conhecida, o pin perdeu o benefício e
sobrou o risco: exige aquela NDK instalada no ambiente de build, o que não dá para garantir
no FlutLab — e o APK que funciona foi gerado **sem** o pin.

**Correção.** Revertido. Registrado em [DECISOES.md §5](DECISOES.md) *como reversão*, não
apagado do histórico.

### 3.3 "Os avisos do Analyzer são só ruído"

**O que a IA afirmou.** Que os avisos de lint do FlutLab estavam documentados como esperados
e podiam ser ignorados.

**O que derrubou.** O autor reenviou o print, sem aceitar a resposta.

**O resultado.** A reinvestigação — desta vez rigorosa — mostrou que subir o `flutter_lints`
**não** resolveria, porque as mesmas regras seguem ativas até o `lints` 6.1.0, e achou a
correção certa: `included_file_warning: ignore`, validada com um teste de controle.

> A insistência do autor foi o que produziu a correção. Vale registrar: aceitar a primeira
> resposta da IA teria deixado o defeito no lugar.

### 3.4 Bônus — a revisão automatizada externa também errou

Um bot de revisão de código comentou o PR com 5 apontamentos. **Quatro eram válidos e foram
aplicados**, incluindo um acento faltando ("voce" → "você"). Mas o *código sugerido* por ele
estava errado em três pontos: usava uma assinatura de API que não existe, importava um
pacote inexistente e reproduzia um corpo de método já desatualizado.

Lição registrada: sugestão de IA é hipótese, não patch. Vale para a que escreveu o projeto e
para a que revisou.

---

## 4. O método que funcionou

O que separou os acertos dos erros não foi a qualidade do prompt — foi ter **três camadas
independentes de verificação**, cada uma capaz de derrubar a anterior:

| Camada | O que pegou | O que **não** pegaria |
|---|---|---|
| `analyze` + 70 testes | regras de negócio, serialização, resiliência | qualquer coisa visual |
| Inspeção visual do build web | Resumo incoerente, insight contraditório, sobras do template | qualquer coisa nativa |
| Teste em aparelho real | **o crash do arm/arm64** | detalhe de lógica |

Nenhuma das três é opcional, e a terceira — a única que depende de hardware — foi a que
pegou o defeito mais grave.

Duas práticas adicionais que valeram:

- **Rodar em dois SDKs.** Flutter 3.32.8 (o do FlutLab) e 3.47.0. A versão nova emitiu uma
  asserção de layout que a antiga silencia — e o defeito existia nas duas.
- **Validar teste ao contrário.** Três testes de resiliência foram conferidos removendo
  temporariamente a proteção: os três falham. Sem isso, não há como saber se um teste que
  passa está testando alguma coisa.

---

## 5. O que isso significa para a nota

O trabalho não é "a IA fez". É um ciclo de especificar, gerar, **conferir e derrubar**. Os
três erros da §3 são a evidência de que a conferência aconteceu de verdade: em dois deles
foi o autor, com o celular na mão ou reenviando um print, quem provou que a IA estava errada.

O registro completo dos defeitos, com sintoma e diagnóstico, está no
[relatório ponta a ponta](RELATORIO-E2E.md) §4. As decisões revertidas estão preservadas
como reversões em [DECISOES.md](DECISOES.md), não apagadas.
