#!/usr/bin/env bash
# Confere se os números afirmados na documentação ainda batem com o repositório.
#
# Existe porque já falhou: uma rodada de correção passou por três documentos e esqueceu
# o docs/APRESENTACAO.md, que ficou afirmando "65 testes" depois de a suíte ir para 67 —
# e esse número ia direto para o slide.
#
# Uso:  bash tool/verifica_docs.sh
# Sai com 1 se achar divergência, para poder ser usado antes de um commit.

set -u
cd "$(dirname "$0")/.." || exit 1

falhas=0
aviso() { echo "  ✗ $1"; falhas=$((falhas + 1)); }
ok()    { echo "  ✓ $1"; }

# ---------------------------------------------------------------- números reais
linhas=$(wc -l < lib/main.dart | tr -d ' ')
logica=$(grep -c "^\s*test(" test/aura_logic_test.dart)
interface=$(grep -c "testWidgets(" test/aura_app_test.dart)
total=$((logica + interface))

echo "Repositório: ${linhas} linhas em lib/main.dart, ${total} testes (${logica} + ${interface})"
echo

# ------------------------------------------------------- contagem de testes
echo "Contagem de testes:"
# Só números de dois dígitos: "6 testes" e "7 testes" são tamanhos de grupo, legítimos.
# O CHANGELOG fica de fora das duas conferências numéricas: o trabalho dele é justamente
# registrar estados passados, inclusive os números que estavam errados.
antigos=$(grep -rn "[0-9][0-9]\+ testes" --include="*.md" . \
          | grep -v "^\./tool/" \
          | grep -v "^\./CHANGELOG.md:" \
          | grep -v "${total} testes" || true)
if [ -n "$antigos" ]; then
  echo "$antigos" | while read -r l; do aviso "$l"; done
  falhas=1
else
  ok "toda menção a \"N testes\" diz ${total}"
fi
echo

# ------------------------------------------- números dentro de célula de tabela
# A conferência acima exige a palavra "testes" logo depois do número, e por isso
# não enxerga a linha de tabela `| Testes automatizados | 101 (75 de lógica...) |`
# — que é justamente a de onde saem os slides. Passou despercebido até 22/08, com
# 101 em dois documentos e a suíte em 100. Estas conferências olham a célula.
echo "Números nas tabelas de resumo:"

# Cada linha vem como arquivo:linha:conteúdo; a decomposição (74 + 26) também é conferida.
linhas_teste=$(grep -rn "^| Testes automatizados |" --include="*.md" . \
               | grep -v "^\./CHANGELOG.md:" || true)
if [ -z "$linhas_teste" ]; then
  aviso "nenhuma linha \"| Testes automatizados |\" encontrada — a conferência virou letra morta"
else
  while IFS= read -r l; do
    # Tira o prefixo "arquivo:linha:" antes de ler os números, senão o número da
    # linha entra na conta e a conferência compara a coisa errada.
    nums=$(echo "${l#*:*:}" | grep -o "[0-9]\+")
    t=$(echo "$nums" | sed -n '1p'); a=$(echo "$nums" | sed -n '2p'); b=$(echo "$nums" | sed -n '3p')
    if [ "$t" = "$total" ] && [ "$a" = "$logica" ] && [ "$b" = "$interface" ]; then
      ok "${l%%:*} diz ${total} (${logica} + ${interface})"
    else
      aviso "$l  → deveria ser ${total} (${logica} + ${interface})"
    fi
  done <<< "$linhas_teste"
fi

# Dependências externas: tudo em `dependencies:` do pubspec menos o SDK do Flutter.
deps=$(sed -n '/^dependencies:/,/^dev_dependencies:/p' pubspec.yaml \
       | grep "^  [a-z_]\+:" | grep -cv "^  flutter:")
linhas_dep=$(grep -rn "^| Dependências externas |" --include="*.md" . \
             | grep -v "^\./CHANGELOG.md:" || true)
if [ -z "$linhas_dep" ]; then
  aviso "nenhuma linha \"| Dependências externas |\" encontrada"
else
  while IFS= read -r l; do
    n=$(echo "${l#*:*:}" | grep -o "| [0-9]\+" | head -1 | tr -dc '0-9')
    if [ "$n" = "$deps" ]; then
      ok "${l%%:*} diz ${deps} dependências"
    else
      aviso "$l  → o pubspec.yaml tem ${deps}"
    fi
  done <<< "$linhas_dep"
fi
echo

# --------------------------------------------------------- contagem de linhas
echo "Contagem de linhas de lib/main.dart:"
formatado=$(printf "%d" "$linhas" | sed 's/\(.\)\(...\)$/\1.\2/')
soltos=$(grep -rn "[0-9]\.[0-9]\{3\} linhas" --include="*.md" . \
         | grep -v "^\./tool/" \
         | grep -v "^\./CHANGELOG.md:" \
         | grep -v "${formatado}" || true)
if [ -n "$soltos" ]; then
  echo "$soltos" | while read -r l; do aviso "$l"; done
  falhas=1
else
  ok "toda menção a linhas diz ${formatado}"
fi
echo

# ------------------------------------------------------------ imagens citadas
echo "Imagens referenciadas:"
faltando=0
for img in $(grep -oh "img/[a-z0-9-]*\.png" README.md docs/*.md | sort -u); do
  alvo="docs/${img}"
  [ -f "$alvo" ] || { aviso "referenciada mas não existe: $alvo"; faltando=1; }
done
[ "$faltando" -eq 0 ] && ok "todas existem em docs/img/"
echo

# --------------------------------------------------------------- links locais
echo "Links entre documentos:"
quebrados=0
for f in README.md CHANGELOG.md NOTICE.md docs/*.md; do
  dir=$(dirname "$f")
  for alvo in $(grep -oh "](\([A-Za-z0-9_./-]*\.md\))" "$f" 2>/dev/null | sed 's/^](//;s/)$//'); do
    [ -f "$dir/$alvo" ] || { aviso "$f apontando para $alvo"; quebrados=1; }
  done
done
[ "$quebrados" -eq 0 ] && ok "todos resolvem"
echo

if [ "$falhas" -eq 0 ]; then
  echo "Documentação consistente com o repositório."
  exit 0
fi
echo "Divergências encontradas. Corrija antes de commitar."
exit 1
