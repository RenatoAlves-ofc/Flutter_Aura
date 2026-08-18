# Relatório de Verificação Ponta a Ponta — Aura

**Data:** 18 de agosto de 2026
**Repositório:** `github.com/RenatoAlves-ofc/Flutter_Aura`
**Ambiente alvo:** FlutLab.io — Flutter 3.32 (Dart 3.8.1)

> Este relatório substitui a Seção 9 ("Estado Atual do Projeto — Auditoria Ponta a Ponta")
> da `Aura_Documentacao_Oficial.docx`, que foi escrita em **17/08**, antes de qualquer
> código existir, e afirma que o repositório contém apenas o projeto padrão do FlutLab.
> Aquela leitura não vale mais.

---

## 1. Veredito

O MVP está **completo e verificado**. Os 8 itens da Definição de Pronto foram cumpridos,
incluindo o único que dependia de hardware real — o app instalado e rodando em um celular
Android 16.

| | |
|---|---|
| Linhas em `lib/main.dart` | 3.438 |
| Testes automatizados | 67 (46 de lógica, 21 de interface) |
| `flutter analyze` | sem nenhum aviso |
| SDKs verificados | Flutter 3.32.8 (o do FlutLab) e 3.47.0 |
| Métodos de foco | 11, incluindo Flowtime |
| Dependências externas | 4, todas gratuitas do pub.dev |

---

## 2. Definição de Pronto, item a item

Cada item aponta para a evidência que o sustenta. Nenhuma linha desta tabela é uma
afirmação de que "deve funcionar": todas apontam para um teste que roda, um print da tela
ou o teste feito no aparelho.

| # | Item | Situação | Evidência |
|---|---|---|---|
| 1 | Escolher um método entre os 11 e rodar uma sessão completa | ✅ | Teste `métodos de foco são os 11 prometidos`; testes de interface `o app abre na aba Foco com o método padrão` e `trocar para Flowtime muda o cronômetro para contagem crescente`; print `01-foco.png` |
| 2 | Humor registrado antes e depois da sessão | ✅ | Teste de interface `tocar em Iniciar pede o humor antes de rodar o cronômetro`, que verifica também que o botão Confirmar só libera após escolher; prints `02-humor.png` e `03-humor-sugestao.png` |
| 3 | Ao menos 1 insight exibindo comparação real | ✅ | Os **4** insights abrem com o dataset de demonstração — o print `05-insights.png` mostra "4 de 4 desbloqueadas · 22 sessões registradas". Grupo de testes `motor de insights` (6 testes) cobre os limiares |
| 4 | Gráfico de correlação em `fl_chart` sem erro | ✅ | Teste de interface `a aba Insights renderiza os gráficos com o dataset demo`, que rola até cada gráfico e confirma `BarChart` e `LineChart` na árvore; print `06-graficos.png` |
| 5 | Clima Pessoal mudando entre pelo menos 2 estados | ✅ | Grupo `clima pessoal` (4 testes) cobre os 4 estados; observado na prática: os prints mostram **Radiante** (dourado) antes de um ajuste no dataset e **Fluindo** (verde-azulado) depois |
| 6 | Sequência não quebra ao faltar um dia | ✅ | Teste `faltar exatamente um dia com token guardado não quebra a sequência`, mais 7 outros no grupo `sequência com perdão` cobrindo teto de tokens, buraco grande e duas sessões no mesmo dia |
| 7 | APK builda no FlutLab e abre em celular real | ✅ | Build do APK no FlutLab (8,3 MB) e instalação em aparelho **Android 16**. Exige o alvo **`android arm64`** — ver Seção 4 |
| 8 | Nenhuma tela vazia na primeira abertura | ✅ | Dataset de demonstração de 22 sessões semeado no primeiro uso; grupo `dataset de demonstração` (7 testes) garante volume, determinismo e variedade de métodos; conferido em todas as abas nos prints |

**Além do escopo do MVP:** um item da Seção 3.1 (roadmap) foi implementado — a
**sugestão adaptativa de duração**, descrita na Seção 5 — e o app recebeu uma camada de
animação e uma abertura própria, descritas na Seção 6.

---

## 3. Como o projeto foi verificado

Testes automatizados não olham para a tela, e compilar não é o mesmo que funcionar. Por
isso a verificação tem três camadas independentes, e cada uma pegou defeitos que as outras
não pegariam.

### 3.1 Análise estática e testes

`flutter analyze` sem avisos e a suíte completa rodando em **dois** SDKs: o 3.32.8, que é o
que o FlutLab usa, e o 3.47.0. Rodar nos dois não é redundância — foi assim que apareceu
uma asserção de layout que só a versão nova emite (Seção 4).

Os 67 testes cobrem deliberadamente a lógica que **não aparece na tela** e por isso não
seria pega por inspeção visual: a regra de sequência com perdão, os limiares de desbloqueio
dos insights, o clima pessoal, a serialização retrocompatível e a resiliência a dados
corrompidos.

Três testes de resiliência foram validados ao contrário: removendo temporariamente a
proteção, os três falham. Isso evita a armadilha de testes que passam de qualquer jeito.

### 3.2 Inspeção visual

O build web foi servido localmente e navegado num viewport de telefone (420×940), com
captura de cada aba. Foi essa camada que revelou:

- um estouro horizontal na linha de botões do cronômetro, quando o rótulo vira
  "Iniciar pausa";
- a tela Resumo abrindo incoerente, com "0 dias de sequência" e "0 pontos" ao lado de
  "20 sessões totais";
- o insight de humor se contradizendo, com "+0.3" e 50% das sessões;
- sobras do template do FlutLab: `hello_world` no título da página e "Hello World" como
  nome do app no iOS.

Nenhum desses seria detectado por `analyze` ou pelos testes.

### 3.3 Teste em aparelho real

O APK gerado no FlutLab foi instalado num Android 16. Foi essa camada que revelou o
problema mais grave do projeto, descrito a seguir.

---

## 4. Defeitos encontrados e resolvidos

Registro honesto do que quebrou e como foi diagnosticado. Vários custaram tempo por terem
sido investigados na direção errada primeiro.

### 4.1 O app instalava e fechava ao abrir

**Sintoma:** o Android exibia "aura fechou porque este app tem um bug", sem stack trace.

**Diagnóstico errado inicial:** foi tratado como falha de instalação, e depois como possível
desalinhamento de memória de 16 KB (Android 15+). Chegou a ser instrumentado um capturador
global de erros com tela de erro legível — que **nunca apareceu**.

**Causa real:** o APK fora gerado com o alvo `android arm`, que produz binário só de 32 bits
(`armeabi-v7a`). Em aparelho arm64, a engine nativa do Flutter não carrega e o app morre
antes de qualquer código Dart rodar — e é exatamente por isso que a tela de erro em Dart não
podia aparecer. O próprio sintoma "apareceu a caixa do Android, não a tela do app" era a
prova de que a falha era nativa.

**Correção:** gerar o APK como **`android arm64`**. Confirmado pelo usuário: com `arm`
quebra, com `arm64` funciona.

**Consequência:** a instrumentação de erro, embora não fosse a solução, foi mantida — ela
protege contra falhas em Dart, que continuam possíveis. E rendeu uma correção legítima: os
`jsonDecode` do armazenamento local não tinham `try/catch`, então um único registro
malformado deixava o app impossível de abrir para sempre, sem outra saída além de
reinstalar.

### 4.2 `Get Packages` falhava no FlutLab

Dois conflitos de dependência, não um:

- `shared_preferences` 2.5.4+ exige Dart ≥ 3.9; o Flutter 3.32 traz Dart 3.8.1.
- `fl_chart` 1.1.1+ exige `vector_math ^2.2.0`, e o `flutter_test` do 3.32 fixa a 2.1.4.

O segundo tem uma armadilha: a versão 1.1.0 **declara** `^2.1.4` e por isso resolve, mas
chama `Matrix4.translateByDouble`, que só existe na 2.2.0. Ela passa no `pub get` e no
`analyze`, e só falha na compilação — então uma faixa aberta como `^1.1.0` cairia
exatamente nessa versão quebrada. Daí o pin exato em `fl_chart: 1.0.0`.

### 4.3 FlutLab não achava o projeto

A importação falhava com "The following file is required for a Flutter project:
pubspec.yaml". O FlutLab procura o `pubspec.yaml` no primeiro nível do repositório, e o
projeto estava dentro de uma pasta `Aura/`. Resolvido movendo o projeto para a raiz.

### 4.4 Estouro de layout no cronômetro

A linha com "Iniciar" e "Reiniciar" estourava horizontalmente em 420 px de largura quando o
rótulo virava "Iniciar pausa". Apareceu porque o teste de interface roda em viewport de
telefone. Resolvido trocando `Row` por `Wrap`.

### 4.5 Resumo incoerente na primeira abertura

O dataset de demonstração gravava as sessões mas não o estado que elas implicam. O app
abria com "0 dias de sequência", "0 folgas" e "0 pontos" ao lado de "20 sessões totais" e
"813 minutos focados". Resolvido derivando sequência e pontos das próprias sessões, com
`streakFromSessions` reaplicando a mesma regra dia a dia.

### 4.6 Splash invisível no cartão de sugestão

Só o Flutter 3.47 emite a asserção: `CheckboxListTile` pinta fundo e splash no `Material`
mais próximo, e o `AuraCard` é um `Container` com fundo próprio no meio do caminho. O toque
ficava sem retorno visual **nas duas versões** — apenas a mais nova avisa. Resolvido com um
`Material` transparente em volta.

---

## 5. Além do MVP: sugestão adaptativa de duração

Item da Seção 3.1 (roadmap) implementado por reaproveitar o motor que já existia.

Ao escolher o humor antes da sessão, o app consulta o histórico de sessões iniciadas
naquela mesma faixa de humor e sugere o método que historicamente termina melhor,
informando quanto tempo o usuário costuma sustentar e com que humor termina. Aceitar é
opcional.

Decisões que valem registro:

- **Não sugere sem evidência.** Exige pelo menos 2 sessões do método naquela faixa; abaixo
  disso não mostra nada, em vez de chutar.
- **Não sugere Flowtime nem Personalizado.** Um não tem duração alvo, o outro depende da
  configuração do usuário — recomendá-los por duração média prometeria um número que a
  sessão não cumpriria.
- **Não contradiz a aba Insights.** Usa o mesmo mínimo por método do insight "o método que
  mais te sustenta", mas restrito à faixa de humor, porque a pergunta é outra: não é "o que
  funciona no geral", é "o que funciona quando estou assim".

---

## 6. Abertura e animação

O app abria em três telas desconexas: flash branco da tela nativa, um `CircularProgressIndicator`
pelado e então a interface. Nenhuma delas com a identidade do Aura.

A abertura passou a ser contínua: a tela nativa (Android e iOS) usa o mesmo índigo e a mesma
marca do ícone, a `AuraLoadingScreen` continua exatamente nessa cor, e ela se dissolve na cor
da aura do usuário.

Sobre a camada de animação, uma restrição valeu mais que qualquer escolha estética:
`pumpAndSettle()` espera **todas** as animações terminarem, e a suíte o usa em 25 lugares.
Uma animação que repete infinitamente trava o teste até estourar o tempo.

Por isso o app tem **uma única animação contínua** — o halo respirando em volta do anel,
restrito à sessão em andamento, que é a tela onde o usuário fica mais tempo parado olhando.
Todo o resto é finito: entra, termina e para.

Os dois testes que rodam o cronômetro passaram a usar `pump(Duration)` no lugar de
`pumpAndSettle`, e dois testes novos travam esse comportamento: um verifica que o halo anima
durante a sessão e para ao pausar; o outro, que a tela de carregamento não deixa animação
presa — o que quebraria toda a suíte.

Um detalhe que só apareceu ao investigar uma falha: depois de pausar, o que continuava
animando não era o halo, era o splash de tinta do próprio botão tocado. O teste espera esse
tempo de propósito, e diz isso no comentário.

## 7. O que fica fora e por quê

- **Build de APK neste repositório:** não há automação de CI. O APK é gerado no FlutLab,
  como a atividade exige.
- **Itens da Seção 3.1 não implementados:** Ritual Semanal, Modo Provas, arco por temporada,
  compartilhamento de cartões e onboarding com quiz seguem como roadmap.
- **`namespace` do Android continua `com.example.aura`.** Só o `applicationId` foi trocado
  para `br.com.renatoalves.aura`. Mudar o `namespace` exigiria mover o pacote Kotlin do
  `MainActivity`, e errar isso quebra o app na abertura — risco desnecessário a seis dias da
  apresentação, sem ganho visível.

---

## 8. Pendências para a entrega

| Item | Responsável | Observação |
|---|---|---|
| Reimportar o projeto no FlutLab | Usuário | GitHub e FlutLab não sincronizam sozinhos; sem isso nada deste repositório chega ao APK |
| Gerar o APK final como **`android arm64`** | Usuário | Guardar o arquivo com antecedência, para não depender do FlutLab no dia |
| QR Code para a apresentação | Usuário | Gerado pelo FlutLab junto com o APK |
| Comprovante da interação com IA | Usuário | Item do checklist de ideação que estava em 50% |
| Slides e ensaio do pitch | Usuário | Roteiro sugerido em [`APRESENTACAO.md`](APRESENTACAO.md) |
