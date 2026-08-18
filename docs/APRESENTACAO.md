# Roteiro de Apresentação — Aura

Apoio para a apresentação de **24/08/2026**. Serve como roteiro de demonstração e checklist
de véspera.

---

## 1. Pitch de abertura (~30 segundos)

> O Aura é um Pomodoro que aprende com você. Em vez de só contar minutos, ele cruza como
> você está se sentindo com quanto tempo você realmente consegue manter o foco — e devolve
> isso como descobertas pessoais, não como pontos genéricos. Sua aura muda com seu estado
> real. Tudo local, sem login, sem feed.

Se puder acrescentar uma frase, use esta: **o diferencial não é o cronômetro, é o motor de
correlação.** Cronômetro tem em qualquer lugar; cruzar humor com desempenho e devolver um
padrão pessoal é o que nenhum concorrente pesquisado entrega junto.

---

## 2. Roteiro de demonstração

Ordem pensada para **construir o argumento**, não para passear pelas telas. Cada passo
prepara o próximo.

### Passo 1 — Abrir o app (aba Foco)

Mostre o seletor com os 11 métodos. Abra a lista e role: Pomodoro Clássico, 52/17, Ciclo
Ultradiano, Flowtime, Personalizado.

> Fale: os 11 métodos são uma lista de dados sobre o mesmo cronômetro, não 11 telas. Só o
> Flowtime é estruturalmente diferente — conta para cima, sem alvo.

### Passo 2 — Tocar em Iniciar → o check de humor

**Este é o momento mais importante da demonstração.** Antes de o cronômetro rodar, o app
pergunta como a pessoa está.

> Fale: é aqui que o Aura deixa de ser um cronômetro. Sem esse dado, não existe correlação
> nenhuma para descobrir depois.

### Passo 3 — Escolher "Ótimo" → a sugestão adaptativa

Ao tocar na face, aparece o cartão de sugestão.

> Fale: ele acabou de olhar o histórico de sessões que começaram com esse mesmo humor e
> está dizendo qual método funcionou melhor **para esta pessoa**, nessas condições. Se não
> houvesse dados suficientes, ele não mostraria nada — o app não chuta.

Esse é o momento em que o pitch "aprende com você" deixa de ser promessa e vira tela.

### Passo 4 — Ir para a aba Insights

Mostre "4 de 4 desbloqueadas". Leia **em voz alta** o primeiro card:

> "Quando você começa animado, suas sessões duram em média X min. Quando começa pra baixo,
> caem para Y min."

> Fale: isso não é um ponto genérico, é uma frase sobre a pessoa. E cada descoberta fica
> bloqueada até haver dados suficientes — uma conclusão tirada de duas sessões não seria uma
> conclusão.

### Passo 5 — Rolar até o gráfico de correlação

As barras sobem junto com o humor inicial.

> Fale: é a tese do app em uma imagem. Quanto melhor a pessoa chega, mais tempo ela
> sustenta — e isso não é força de vontade, é um padrão que dá para observar.

### Passo 6 — Aba Resumo

Aponte o fundo colorido: a aura. Depois a sequência com perdão.

> Fale: a cada 3 dias seguidos ganha-se uma folga. Faltou um dia, a folga é gasta e a
> sequência continua. O público-alvo são estudantes em época de prova — punir quem falhou um
> dia é a forma mais rápida de perder o usuário. A pesquisa de concorrência mostrou que os
> apps do nicho erram exatamente aí.

### Passo 7 — Tela Sobre

Mostre a mensagem de privacidade.

> Fale: os dados de humor não saem do aparelho. Sem login, sem servidor, sem feed. Para um
> público cansado de coleta de dados, isso é posicionamento, não só uma limitação técnica.

### Passo 8 — Fechamento: roadmap

Cite os itens que ficaram de fora **como escolha consciente**, não como falta de tempo:
Ritual Semanal, Modo Provas, arco por temporada, compartilhamento de cartões de insight e
onboarding com quiz.

> Fale: foram cortados por análise de risco-benefício, não por acidente. A sugestão
> adaptativa de duração era um deles, e entrou porque reaproveitava o motor que já existia.

---

## 3. Se sobrar tempo (ou se perguntarem)

**"Como você garantiu que funciona?"**
65 testes automatizados, em dois SDKs diferentes. Mas testes não olham para a tela — a
interface foi conferida separadamente, servindo o build web num viewport de telefone. Foi
essa conferência que achou a tela Resumo abrindo incoerente. Detalhes em
[`RELATORIO-E2E.md`](RELATORIO-E2E.md).

**"Qual foi o problema mais difícil?"**
O APK instalava e fechava ao abrir, sem stack trace. Foi diagnosticado errado duas vezes
antes de descobrirmos que era o alvo de build: `arm` gera binário de 32 bits, e em aparelho
arm64 a engine nativa não carrega. O app morria antes de qualquer código Dart rodar — por
isso nenhuma instrumentação em Dart conseguia capturar. Está em [`DECISOES.md`](DECISOES.md) §6.

**"Por que não usou Provider/Bloc?"**
Restrição do ambiente: `setState` evita riscos de compatibilidade no FlutLab. A mitigação
foi manter a lógica de negócio como funções puras, fora dos widgets — é o que permite testá-la
sem construir tela nenhuma.

**"O dataset de demonstração não é trapaça?"**
Ele é declarado como fictício dentro do próprio app e pode ser removido em um toque na tela
Sobre. Existe para que nenhuma tela apareça vazia numa primeira abertura, que é justamente a
situação de uma apresentação.

---

## 4. Checklist de véspera (23/08)

- [ ] Reimportar o projeto no FlutLab a partir do GitHub — **eles não sincronizam sozinhos**
- [ ] Rodar **Get Packages** e confirmar que passa
- [ ] Gerar o APK com o alvo **`android arm64`**, nunca `arm`
- [ ] Instalar no celular e abrir todas as abas uma vez
- [ ] Conferir que o ícone do Aura aparece na tela inicial (não o do Flutter)
- [ ] **Salvar o arquivo APK** em algum lugar seguro, para não depender do FlutLab no dia
- [ ] Gerar e testar o QR Code
- [ ] Deixar o celular carregado e com brilho alto
- [ ] Ensaiar o roteiro acima uma vez, cronometrando

### Se algo der errado no dia

- **App fecha ao abrir:** o APK foi gerado como `arm`. Refaça como `arm64`.
- **Telas vazias:** os dados de demonstração foram removidos. Restaure na tela Sobre.
- **Insight bloqueado:** falta volume de dados; é o comportamento esperado, e dá para
  explicar isso como decisão de produto.
- **Sem sugestão adaptativa:** não há sessões suficientes naquele humor. Tente com "Ótimo",
  que é a faixa com mais dados no dataset de demonstração.

---

## 5. Números para os slides

| | |
|---|---|
| Métodos de foco | 11 |
| Descobertas desbloqueáveis | 4 |
| Estados da aura | 4 + neutro |
| Testes automatizados | 65 |
| Dependências externas | 4, todas gratuitas |
| Linhas de código | ~3.400, em arquivo único por exigência do FlutLab |
| Backend | nenhum |
