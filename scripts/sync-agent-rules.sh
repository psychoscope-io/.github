#!/usr/bin/env bash
# Copia as regras e skills compartilhadas (agents/) para .claude/ de cada repositório.
#   scripts/sync-agent-rules.sh [--check] <dir-do-repo>...
# --check não escreve nada: sai com 1 se alguma cópia estiver diferente da fonte.
set -euo pipefail

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
[ $# -ge 1 ] || { echo "uso: $0 [--check] <dir-do-repo>..." >&2; exit 2; }

SRC="$(cd "$(dirname "$0")/../agents" && pwd)"
status=0

for repo in "$@"; do
  [ -d "$repo" ] || { echo "diretório inexistente: $repo" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"             # rules/x.md  ou  skills/y/SKILL.md
    dst="$repo/.claude/$rel"
    if [ "$CHECK" = 1 ]; then
      if ! cmp -s "$f" "$dst"; then echo "divergente: $dst" >&2; status=1; fi
    else
      mkdir -p "$(dirname "$dst")"
      cmp -s "$f" "$dst" 2>/dev/null || { cp "$f" "$dst"; echo "atualizado: $dst"; }
    fi
  done < <(find "$SRC" -type f -name '*.md' -print0 | sort -z)
done
exit $status
