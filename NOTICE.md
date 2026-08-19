# Avisos de terceiros

Este repositório redistribui material de terceiros. Este arquivo existe para cumprir a
obrigação de atribuição desse material.

---

## `.claude/` — agents, skills e commands

**Origem:** [`rohitg00/awesome-claude-code-toolkit`](https://github.com/rohitg00/awesome-claude-code-toolkit)
**Licença:** Apache License 2.0
**Texto da licença:** https://www.apache.org/licenses/LICENSE-2.0

O diretório `.claude/` contém arquivos markdown copiados desse repositório e usados como
ferramental de desenvolvimento. Eles **não fazem parte do aplicativo** — nada em `.claude/`
é compilado, empacotado no APK ou executado pelo Aura em tempo de uso.

| Pasta | Itens |
|---|---|
| `.claude/agents/` | 6 — `accessibility-specialist`, `code-reviewer`, `error-detective`, `flutter-expert`, `mobile-developer`, `security-auditor` |
| `.claude/skills/` | 2 — `accessibility-wcag`, `mobile-development` |
| `.claude/commands/` | 13 conjuntos — `a11y-audit`, `bug-detective`, `code-architect`, `dependency-manager`, `doc-forge`, `double-check`, `feature-dev`, `license-checker`, `pr-reviewer`, `refactor-engine`, `responsive-designer`, `security-guidance`, `smart-commit` |

Os arquivos foram copiados **sem modificação de conteúdo**. Foram copiados como markdown,
e não instalados pela marketplace oficial de plugins, porque todas as entradas do manifesto
daquele repositório declaram o campo `source` sem o prefixo exigido pelo schema do CLI, o
que faz a instalação ser rejeitada. O registro está no [`CHANGELOG.md`](CHANGELOG.md), PR #1.

---

## Dependências do pub.dev

Resolvidas pelo `pub` a partir do [`pubspec.yaml`](pubspec.yaml) e **não versionadas** neste
repositório — o código-fonte delas não é redistribuído aqui. Todas são publicadas sob
licenças permissivas (BSD-3-Clause ou MIT):

| Pacote | Uso no Aura |
|---|---|
| `shared_preferences` | armazenamento local das sessões, tarefas e estado |
| `fl_chart` | gráfico de correlação humor × duração e ritmo semanal |
| `percent_indicator` | anel de progresso do cronômetro |
| `cupertino_icons` | ícones |

---

## Sobre o código do Aura

O código do aplicativo em `lib/`, `test/`, `android/`, `ios/` e `web/` é trabalho acadêmico
de autoria própria e **não está coberto por nenhuma licença de código aberto**. Nenhum
arquivo `LICENSE` foi adicionado ao repositório porque isso seria uma escolha de
licenciamento do autor, não uma decorrência da atribuição registrada acima.
