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
| ✅ | 100 testes automatizados passando | `flutter test`, em Flutter 3.32.8 e 3.47.0 |
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
> Ele saiu do commit `48b7e72`. Depois dele vieram a **passada de design**, a **ficha de
> personagem**, os **contextos de foco** e agora a **frase do dia** (rede, ver 3.1 abaixo) —
> mudanças que mudam o que aparece na tela e, com a frase do dia, o que o app faz. O APK atual
> mostra uma versão bem anterior.
>
> **Refaça os passos acima** depois de mergear e de colar a chave real (3.1): reimportar no
> FlutLab e gerar como `arm64`. Continua sendo um rebuild só, porque você ainda não tinha
> instalado nenhuma das versões intermediárias.

O que **não** exige gerar o APK de novo é mudança só de documentação — `.md` não entra no
APK. Foi o caso da rodada anterior a esta.

---

## 3. Depende de você — o que falta

### 3.1 Colar a chave real da Groq no código — **bloqueante**

`_kGroqApiKey` em `lib/main.dart` (seção FRASE DO DIA) está em branco de propósito — eu não
tinha uma chave seguindeira para colar (ver [DECISOES.md §24](DECISOES.md)). Sem ela, a
função guarda e devolve `null` antes de tentar qualquer requisição: o app funciona igual, só
que sem o cartão de frase.

- [ ] Gere uma chave **nova** na Groq — não a que foi colada no chat, ela já está exposta por
      outro canal
- [ ] Cole em `_kGroqApiKey`, faça o commit e o push
- [ ] Opcional: se quiser a reserva da Gemini também, gere uma chave nova lá e cole em
      `_kGeminiApiKey` (fica em branco = reserva desativada, só a Groq roda)

Sem este passo, os passos 2 e 3.2 abaixo continuam valendo normalmente — o app não quebra por
faltar chave, só não mostra a frase.

### 3.2 Instalar no celular e conferir cinco coisas — **bloqueante**

É o único item que ainda pode revelar um problema. Faça hoje, não no dia 23.

- [ ] O **ícone do Aura** aparece na tela inicial, não o do Flutter
- [ ] A **abertura é em índigo com a marca** — se piscar branco, o APK é de uma versão antiga
- [ ] As quatro abas abrem com conteúdo (nenhuma vazia)
- [ ] O cronômetro roda, pede o humor antes e depois, e o halo respira em volta do anel
- [ ] Na aba Resumo, a **frase do dia** aparece (com internet e chave colada) — e, tirando a
      internet do aparelho, o app continua abrindo normal, só sem o cartão

Se o app **fechar ao abrir**, o alvo do build foi `arm` e não `arm64`. Confirme abrindo o
próprio arquivo — o procedimento está em [FLUTLAB.md §3.1](FLUTLAB.md): renomeie para `.zip`
e veja se dentro de `lib/` está `arm64-v8a` (certo) ou `armeabi-v7a` (errado).

### 3.3 Salvar o arquivo APK

Guarde o `.apk` fora do FlutLab. No dia da apresentação você não quer depender de um serviço
online estar no ar. É também a hora certa de fazer a conferência da ABI acima, de uma vez.

### 3.4 Gerar e testar o QR Code

Gerado pelo FlutLab junto com o APK. **Teste escaneando com outro aparelho** — um QR Code que
ninguém testou é um QR Code que não funciona.

### 3.5 Comprovante da interação com IA

Item do checklist de ideação. O [USO-DE-IA.md](USO-DE-IA.md) foi escrito para isso: registra
o ferramental, o processo e — principalmente — os três diagnósticos que a IA errou e como
foram derrubados por evidência.

### 3.6 A nova logo — **você pediu para ser lembrado**

Ela está com outra pessoa e **não existe nenhum arquivo no repositório**. Enquanto não
chegar, o item não anda — e ele é dos mais caros: invalida o APK e obriga a refazer todos os
prints da documentação ([`PLANO-V2.md` §11](PLANO-V2.md)).

- [ ] Cobrar a logo com quem está com ela
- [ ] Me mandar o arquivo (PNG grande e quadrado, ou SVG) — eu gero as densidades do Android,
      os 15 PNGs do iOS e a abertura nativa a partir dele

**Se ela não chegar até 23/08, apresente com a atual.** Trocar a logo na véspera obriga a um
rebuild do APK e a recapturar os prints, e não vale o risco.

### 3.7 Slides e ensaio

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
| Frase do dia não aparece na aba Resumo | sem internet no local, ou chave não configurada | Comportamento esperado, não é defeito — o app não mostra erro nenhum, só o cartão some ([DECISOES.md §24](DECISOES.md)) |
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
