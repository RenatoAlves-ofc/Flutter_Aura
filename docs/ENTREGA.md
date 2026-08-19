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
| ✅ | 77 testes automatizados passando | `flutter test`, em Flutter 3.32.8 e 3.47.0 |
| ✅ | `flutter analyze` sem nenhum aviso | nos dois SDKs |
| ✅ | App instalado e rodando em celular real | Android 16, APK arm64 — feito com uma versão anterior; o APK final ainda precisa ser instalado, item 3.1 |
| ✅ | Identidade própria: `applicationId`, ícone e abertura | [DECISOES.md §11, §12, §16](DECISOES.md) |
| ✅ | Item de roadmap implementado (sugestão adaptativa) | [RELATORIO-E2E.md §5](RELATORIO-E2E.md) |
| ✅ | Documentação do repositório | este diretório |
| ⚠️ | **APK gerado** | 8,5 MB, alvo `arm64`, do commit `48b7e72`. **Precisa ser refeito** — a passada de design mudou a interface depois dele |

---

## 2. Já feito no FlutLab

Estes quatro saíram da lista em 19/08:

| | Passo | Como se sabe |
|---|---|---|
| ✅ | Merge dos PRs abertos | `main` em `48b7e72` |
| ✅ | Reimportar o projeto no FlutLab | a branch `teste3` do editor está no **mesmo commit** que a `main` |
| ✅ | `Get Packages` | passou — o build não teria começado sem isso |
| ✅ | Gerar o APK como **`android arm64`** | `✓ Built app-release.apk (8.5MB)` e `Build completed successfully` |

> O build cuspiu cerca de 15 stack traces Java no meio do caminho e **mesmo assim deu certo**.
> São do cache compartilhado do FlutLab, não deste projeto — explicação completa em
> [FLUTLAB.md §4.3](FLUTLAB.md). Se acontecer de novo, não é motivo para refazer nada.

> ### ⚠️ Este APK ficou desatualizado
>
> Ele saiu do commit `48b7e72`. Depois dele veio a **passada de design** — marca na AppBar,
> anel do cronômetro, barras comparativas nos insights, fim do espaço morto — que muda o que
> aparece na tela. O APK atual mostra a versão anterior.
>
> **Refaça os passos acima** depois de mergear: reimportar no FlutLab e gerar como `arm64`.
> Continua sendo um rebuild só, porque você ainda não tinha instalado o anterior.

O que **não** exige gerar o APK de novo é mudança só de documentação — `.md` não entra no
APK. Foi o caso da rodada anterior a esta.

---

## 3. Depende de você — o que falta

### 3.1 Instalar no celular e conferir quatro coisas — **bloqueante**

É o único item que ainda pode revelar um problema. Faça hoje, não no dia 23.

- [ ] O **ícone do Aura** aparece na tela inicial, não o do Flutter
- [ ] A **abertura é em índigo com a marca** — se piscar branco, o APK é de uma versão antiga
- [ ] As quatro abas abrem com conteúdo (nenhuma vazia)
- [ ] O cronômetro roda, pede o humor antes e depois, e o halo respira em volta do anel

Se o app **fechar ao abrir**, o alvo do build foi `arm` e não `arm64`. Confirme abrindo o
próprio arquivo — o procedimento está em [FLUTLAB.md §3.1](FLUTLAB.md): renomeie para `.zip`
e veja se dentro de `lib/` está `arm64-v8a` (certo) ou `armeabi-v7a` (errado).

### 3.2 Salvar o arquivo APK

Guarde o `.apk` fora do FlutLab. No dia da apresentação você não quer depender de um serviço
online estar no ar. É também a hora certa de fazer a conferência da ABI acima, de uma vez.

### 3.3 Gerar e testar o QR Code

Gerado pelo FlutLab junto com o APK. **Teste escaneando com outro aparelho** — um QR Code que
ninguém testou é um QR Code que não funciona.

### 3.4 Comprovante da interação com IA

Item do checklist de ideação. O [USO-DE-IA.md](USO-DE-IA.md) foi escrito para isso: registra
o ferramental, o processo e — principalmente — os três diagnósticos que a IA errou e como
foram derrubados por evidência.

### 3.5 Slides e ensaio

Números prontos para copiar em [APRESENTACAO.md §5](APRESENTACAO.md). Roteiro de
demonstração em §2. **Ensaie uma vez cronometrando** — é a única forma de descobrir que a
demonstração não cabe no tempo.

---

## 4. Faça com folga, não na véspera

O passo de maior risco — gerar o APK, que depende de serviço externo e já falhou duas vezes
neste projeto por motivos diferentes — **já está feito**, com folga de 5 dias.

O que sobra de risco está no **3.1**: instalar e conferir. Se o app não abrir, você ainda tem
tempo de refazer o build com o alvo certo. Se deixar para o dia 23, não tem.

---

## 5. Se algo der errado no dia

| Sintoma | Causa | O que fazer |
|---|---|---|
| App fecha ao abrir | APK gerado como `arm` | Refazer como `arm64` |
| Abertura pisca branco | APK de versão anterior à abertura própria | Reimportar do GitHub e gerar de novo |
| Ícone do Flutter na tela inicial | idem | idem |
| Telas vazias | dados de demonstração removidos | Restaurar na tela **Sobre** |
| Insight bloqueado | falta volume de dados | É o comportamento esperado — explique como decisão de produto |
| Não aparece sugestão adaptativa | poucas sessões naquele humor | Tente com **"Ótimo"**, a faixa com mais dados na demonstração |
| Build cheio de stack traces Java | cache do Gradle do FlutLab corrompido | Nada — se terminar com `Build completed successfully`, o APK é válido ([FLUTLAB.md §4.3](FLUTLAB.md)) |

---

## 6. O que ficou de fora, e por quê

Registrado para responder se perguntarem — nenhum destes é acidente:

- **Automação de CI para gerar o APK.** A atividade pede o APK gerado no FlutLab.
- **Itens do roadmap:** Ritual Semanal, Modo Provas, arco por temporada, compartilhamento de
  cartões de insight e onboarding com quiz. Cortados por análise de risco-benefício.
- **`namespace` do Android** continua `com.example.aura`; só o `applicationId` mudou. O
  motivo está em [DECISOES.md §11](DECISOES.md) — mudar o namespace exigiria mover o pacote
  Kotlin, e errar isso quebra o app na abertura.
