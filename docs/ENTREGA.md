# Checklist de Entrega — Aura

**Apresentação: 24/08/2026.** Este é o único lugar onde as pendências ficam registradas.
Os outros documentos apontam para cá em vez de repetir listas que divergem entre si.

Cada item tem um **dono**. O que está marcado como *feito* está feito e verificado — a
evidência está no [relatório ponta a ponta](RELATORIO-E2E.md).

---

## 1. Pronto (não depende de mais nada)

| | Item | Evidência |
|---|---|---|
| ✅ | Os 8 itens da Definição de Pronto | [RELATORIO-E2E.md §2](RELATORIO-E2E.md), item a item |
| ✅ | 67 testes automatizados passando | `flutter test`, em Flutter 3.32.8 e 3.47.0 |
| ✅ | `flutter analyze` sem nenhum aviso | nos dois SDKs |
| ✅ | App instalado e rodando em celular real | Android 16, APK arm64 |
| ✅ | Identidade própria: `applicationId`, ícone e abertura | [DECISOES.md §11, §12, §16](DECISOES.md) |
| ✅ | Item de roadmap implementado (sugestão adaptativa) | [RELATORIO-E2E.md §5](RELATORIO-E2E.md) |
| ✅ | Documentação do repositório | este diretório |

---

## 2. Depende de você — em ordem

### 2.1 Fazer o merge do PR aberto

O PR da abertura e das animações precisa entrar na `main` **antes** de reimportar no
FlutLab. Sem isso, o passo seguinte traz uma versão sem a abertura.

### 2.2 Reimportar o projeto no FlutLab

> **O GitHub e o FlutLab não sincronizam sozinhos.** Um push neste repositório não aparece
> no editor do FlutLab. É preciso reimportar.

O projeto que está hoje no seu FlutLab é **anterior** a várias entregas. Reimportar não é
opcional: sem isso, nada deste repositório chega ao APK.

Passo a passo em [FLUTLAB.md](FLUTLAB.md).

### 2.3 Rodar `Get Packages` e confirmar que passa

Se falhar, é conflito de versão de dependência — a explicação completa e a razão dos pins
estão em [FLUTLAB.md](FLUTLAB.md#dependências-e-por-que-estão-travadas).

### 2.4 Gerar o APK como `android arm64`

> **Nunca `android arm`.** O alvo `arm` gera binário só de 32 bits, e no seu aparelho o app
> instala e fecha sozinho ao abrir. Foi o defeito mais caro do projeto — [DECISOES.md §6](DECISOES.md).

### 2.5 Instalar no celular e conferir quatro coisas

- [ ] O **ícone do Aura** aparece na tela inicial, não o do Flutter
- [ ] A **abertura é em índigo com a marca** — se piscar branco, o APK é de uma versão antiga
- [ ] As quatro abas abrem com conteúdo (nenhuma vazia)
- [ ] O cronômetro roda e pede o humor antes e depois

### 2.6 Salvar o arquivo APK

Guarde o `.apk` fora do FlutLab. No dia da apresentação você não quer depender de um serviço
online estar no ar.

### 2.7 Gerar e testar o QR Code

Gerado pelo FlutLab junto com o APK. **Teste escaneando com outro aparelho** — um QR Code
que ninguém testou é um QR Code que não funciona.

### 2.8 Comprovante da interação com IA

Item do checklist de ideação. O [USO-DE-IA.md](USO-DE-IA.md) foi escrito para isso: registra
o ferramental, o processo e — principalmente — os três diagnósticos que a IA errou e como
foram derrubados por evidência.

### 2.9 Slides e ensaio

Números prontos para copiar em [APRESENTACAO.md §5](APRESENTACAO.md). Roteiro de
demonstração em §2. **Ensaie uma vez cronometrando** — é a única forma de descobrir que a
demonstração não cabe no tempo.

---

## 3. Faça com folga, não na véspera

O único passo com risco real é o **2.4** (gerar o APK), porque depende de um serviço externo
e já falhou duas vezes neste projeto por motivos diferentes. Gere o APK **até 22/08**, para
sobrar dia útil caso algo quebre.

---

## 4. Se algo der errado no dia

| Sintoma | Causa | O que fazer |
|---|---|---|
| App fecha ao abrir | APK gerado como `arm` | Refazer como `arm64` |
| Abertura pisca branco | APK de versão anterior à abertura própria | Reimportar do GitHub e gerar de novo |
| Ícone do Flutter na tela inicial | idem | idem |
| Telas vazias | dados de demonstração removidos | Restaurar na tela **Sobre** |
| Insight bloqueado | falta volume de dados | É o comportamento esperado — explique como decisão de produto |
| Não aparece sugestão adaptativa | poucas sessões naquele humor | Tente com **"Ótimo"**, a faixa com mais dados na demonstração |

---

## 5. O que ficou de fora, e por quê

Registrado para responder se perguntarem — nenhum destes é acidente:

- **Automação de CI para gerar o APK.** A atividade pede o APK gerado no FlutLab.
- **Itens do roadmap:** Ritual Semanal, Modo Provas, arco por temporada, compartilhamento de
  cartões de insight e onboarding com quiz. Cortados por análise de risco-benefício.
- **`namespace` do Android** continua `com.example.aura`; só o `applicationId` mudou. O
  motivo está em [DECISOES.md §11](DECISOES.md) — mudar o namespace exigiria mover o pacote
  Kotlin, e errar isso quebra o app na abertura.
