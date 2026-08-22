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

# Passagens que registram o estado de uma época levam este marcador no fim da
# linha. Apagar a história para agradar o verificador seria pior do que o erro
# que ele procura — mas o marcador tem que ser posto de propósito, um a um.
HISTORICO="<!-- historico -->"

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

# ------------------------------------------------------- as seis descobertas
# Três documentos ficaram chamando "Seu limite real" de QUINTA descoberta depois
# que "Onde você rende mais" entrou e a empurrou para sexta. Nada pegava isso.
echo "As descobertas:"

qtd=$(sed -n '/^List<Insight> buildInsights/,/^}/p' lib/src/aura_logic.dart \
      | grep -c "^    _insight")
limiares=$(grep -o "const int required = [0-9]\+" lib/src/aura_logic.dart \
           | grep -o "[0-9]\+" | sort -n | tr '\n' ' ')
# Posição de "Seu limite real" na ordem de exibição (não na ordem do arquivo).
fn_teto=$(grep -B3 "const String title = 'Seu limite real'" lib/src/aura_logic.dart \
          | grep -o "_insight[A-Za-z]*" | head -1)
pos=$(sed -n '/^List<Insight> buildInsights/,/^}/p' lib/src/aura_logic.dart \
      | grep "^    _insight" | grep -n "$fn_teto" | cut -d: -f1)

por_extenso() { case "$1" in 4) echo quarta;; 5) echo quinta;; 6) echo sexta;; 7) echo sétima;; *) echo "?";; esac; }
nome_pos=$(por_extenso "$pos")

# Qualquer doc que diga "N descobertas" — por extenso ou algarismo, maiúscula ou
# não — tem o N comparado com a lista real. Listar os valores errados um a um não
# funcionaria: a primeira versão desta conferência não pegou "Cinco" com C
# maiúsculo, e teria deixado passar qualquer número que eu não tivesse previsto.
palavra_num() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    tr*ês|tres) echo 3;; quatro) echo 4;; cinco) echo 5;; seis) echo 6;;
    sete) echo 7;; oito) echo 8;; *) echo "$1";;
  esac
}
citadas=$(grep -rniE "(três|tres|quatro|cinco|seis|sete|oito|[0-9]+) descobertas" --include="*.md" . \
          | grep -v "^\./CHANGELOG.md:" | grep -v "^\./tool/" | grep -v "$HISTORICO" || true)
achou_erro=0
if [ -n "$citadas" ]; then
  while IFS= read -r l; do
    n=$(echo "${l#*:*:}" | grep -oiE "(três|tres|quatro|cinco|seis|sete|oito|[0-9]+) descobertas" \
        | head -1 | sed 's/ descobertas//I')
    n=$(palavra_num "$n")
    if [ "$n" != "$qtd" ]; then aviso "$l  → são ${qtd} descobertas"; achou_erro=1; fi
  done <<< "$citadas"
fi
[ "$achou_erro" -eq 0 ] && ok "nenhum documento contradiz \"${qtd} descobertas\""

# "Seu limite real" tem que ser chamada pela posição certa.
outras=$(por_extenso $((pos - 1)))
teto_errado=$(grep -rn "${outras} descoberta" --include="*.md" . \
              | grep -v "^\./CHANGELOG.md:" | grep -v "^\./tool/" \
              | grep -v "$HISTORICO" || true)
if [ -n "$teto_errado" ]; then
  while IFS= read -r l; do aviso "$l  → \"Seu limite real\" é a ${nome_pos}"; done <<< "$teto_errado"
else
  ok "\"Seu limite real\" é tratada como a ${nome_pos} (${fn_teto})"
fi

# Os seis limiares, como o ARQUITETURA.md os publica.
for n in $limiares; do
  grep -q "| ${n} sessões\|\*\*${n} sessões\*\*\|${n} sessões," docs/ARQUITETURA.md docs/MANUAL-DO-USUARIO.md 2>/dev/null \
    || aviso "limiar de ${n} sessões existe no código e não aparece na documentação"
done
ok "limiares no código: ${limiares}"
echo

# --------------------------------------------- rótulos de aba e nº de métodos
echo "Rótulos de aba e métodos:"
antigos_rotulo=$(grep -rn "aba Insights\|aba Resumo\|tela Resumo" --include="*.md" . \
                 | grep -v "^\./CHANGELOG.md:" | grep -v "^\./tool/" \
                 | grep -v "então chamada" | grep -v "$HISTORICO" || true)
if [ -n "$antigos_rotulo" ]; then
  while IFS= read -r l; do aviso "$l  → as abas são Descobertas e Ficha desde a 1.8.0"; done <<< "$antigos_rotulo"
else
  ok "nenhum documento usa os rótulos antigos das abas"
fi

metodos=$(sed -n '/^const List<FocusMethod> focusMethods/,/^];/p' lib/src/aura_models.dart \
          | grep -c "FocusMethod(")
metodo_errado=$(grep -rn "\(10\|12\|dez\|doze\) métodos" --include="*.md" . \
                | grep -v "^\./CHANGELOG.md:" | grep -v "^\./tool/" | grep -v "$HISTORICO" || true)
if [ -n "$metodo_errado" ]; then
  while IFS= read -r l; do aviso "$l  → são ${metodos} métodos"; done <<< "$metodo_errado"
else
  ok "nenhum documento contradiz \"${metodos} métodos\""
fi
echo

# ------------------------------------------- referências de linha na docs viva
# Todas as 13 do PALETA-DE-CORES.md apodreceram de uma vez com o refactor em
# `part`. Nome de símbolo sobrevive a refactor; número de linha, não.
# PLANO-V2.md é registro histórico e está marcado como tal — fica de fora.
echo "Referências de linha:"
linhas_cru=$(grep -rn "\(lib\|test\)/[a-z_/]*\.dart:[0-9]" --include="*.md" . \
             | grep -v "^\./CHANGELOG.md:" | grep -v "^\./tool/" \
             | grep -v "^\./docs/PLANO-V2.md:" | grep -v "^\./CLAUDE.md:" \
             | grep -v "^\./docs/PALETA-DE-CORES.md:" || true)
if [ -n "$linhas_cru" ]; then
  while IFS= read -r l; do aviso "$l  → cite o símbolo, não a linha"; done <<< "$linhas_cru"
else
  ok "a documentação viva cita símbolos, não linhas"
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
