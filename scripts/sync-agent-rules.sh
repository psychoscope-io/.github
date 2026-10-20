#!/usr/bin/env bash
# Copia os arquivos compartilhados desta organização para cada repositório:
#   agents/rules/*.md        -> .claude/rules/
#   agents/skills/**         -> .claude/skills/
#   devtools/githooks/*      -> .githooks/
#   devtools/scripts/*       -> scripts/
#   devtools/editorconfig    -> .editorconfig
#
#   scripts/sync-agent-rules.sh [--check] <dir-do-repo>...
# --check não escreve nada: sai com 1 se alguma cópia estiver diferente da fonte.
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
[ $# -ge 1 ] || { echo "uso: $0 [--check] <dir-do-repo>..." >&2; exit 2; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# origem (relativa a ROOT) : destino (relativo ao repositório; terminado em / = diretório)
MAPPINGS=(
  "agents/rules:.claude/rules/"
  "agents/skills:.claude/skills/"
  "devtools/githooks:.githooks/"
  "devtools/scripts:scripts/"
  "devtools/editorconfig:.editorconfig"
)
status=0

sync_file() { # origem destino
  if [ "$CHECK" = 1 ]; then
    cmp -s "$1" "$2" || { echo "divergente: $2" >&2; status=1; }
  elif ! cmp -s "$1" "$2" 2>/dev/null; then
    mkdir -p "$(dirname "$2")"
    cp -p "$1" "$2"
    echo "atualizado: $2"
  fi
}

for repo in "$@"; do
  [ -d "$repo" ] || { echo "diretório inexistente: $repo" >&2; exit 2; }
  for m in "${MAPPINGS[@]}"; do
    src="$ROOT/${m%%:*}"; dst="${m#*:}"
    if [ -d "$src" ]; then
      while IFS= read -r -d '' f; do
        sync_file "$f" "$repo/$dst${f#"$src"/}"
      done < <(find "$src" -type f -print0 | sort -z)
    else
      sync_file "$src" "$repo/$dst"
    fi
  done
done
exit $status
