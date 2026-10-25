#!/usr/bin/env bash
# Ambiente de desenvolvimento do Psychoscope: confere as ferramentas, clona, atualiza e compila os
# repositorios irmaos (psychoscope-proto, psychoscope-core, mod-net-sensor e este).
#
#   scripts/dev.sh doctor [--dir DIR]
#   scripts/dev.sh setup  [--dir DIR]
#   scripts/dev.sh update [--dir DIR]
#   scripts/dev.sh build  [--dir DIR]          # binarios em DIR/dist
#   scripts/dev.sh clean  [--dir DIR] [--cargo]
#
# - DIR e a pasta que contem os repositorios (padrao: a pasta acima deste repositorio).
# - setup clona o que faltar (ordem de dependencia: proto, core, sensor), cria o go.work do core
#   apontando para o proto local e ativa os hooks (make hooks).
# - update faz git pull --ff-only em cada repositorio e pula os que tem alteracoes locais.
#   Nunca faz push, tag nem merge.
# - build usa o proto local (local-deps.sh) e chama `make build` do core e do sensor.
# - clean remove DIR/dist; com --cargo, tambem o target/ do sensor.
# - PSYCHOSCOPE_GIT_BASE troca a origem dos clones (padrao https://github.com/psychoscope-io).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${PSYCHOSCOPE_GIT_BASE:-https://github.com/psychoscope-io}"
REPOS=(psychoscope-proto psychoscope-core mod-net-sensor)
DIR="$(dirname "$ROOT")"
CARGO=0
FAILED=0

usage() { sed -n '2,/^set -euo/{/^set -euo/!p}' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "dev.sh: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }
missing() { echo "FALTA: $*" >&2; FAILED=1; }
warn() { echo "aviso: $*" >&2; }

# O Go de usuario (sem sudo) costuma ficar em ~/.local/go; usa-o quando nao ha go no PATH.
use_local_go() {
  if ! command -v go >/dev/null && [ -d "$HOME/.local/go/bin" ]; then
    export PATH="$HOME/.local/go/bin:$PATH"
  fi
}

# Versao minima do Go: a do go.mod do core (vazio se o core ainda nao foi clonado).
go_required() {
  if [ -f "$DIR/psychoscope-core/go.mod" ]; then awk '$1=="go"{print $2; exit}' "$DIR/psychoscope-core/go.mod"; fi
}

libpcap_available() {
  if pkg-config --exists libpcap 2>/dev/null; then return 0; fi
  if [ -f /usr/include/pcap.h ]; then return 0; fi
  [ -n "${LIBPCAP_LIBDIR:-}" ] && [ -e "$LIBPCAP_LIBDIR/libpcap.so" ]
}

doctor() {
  FAILED=0
  use_local_go
  local t have need
  for t in git make python3 cargo rustc; do
    if command -v "$t" >/dev/null; then ok "$t"; else missing "$t nao encontrado (veja psychoscope-github/CONTRIBUTING.md)"; fi
  done
  if command -v go >/dev/null; then
    have="$(go version | awk '{sub(/^go/, "", $3); print $3}')"
    need="$(go_required)"
    if [ -n "$need" ] && [ "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -n1)" != "$need" ]; then
      missing "go $have e mais antigo que o go.mod do core exige ($need): instale em https://go.dev/dl (ou em ~/.local/go, sem sudo)"
    else
      ok "go $have"
    fi
  else
    missing "go nao encontrado: instale em https://go.dev/dl (ou em ~/.local/go, sem sudo)"
  fi
  if libpcap_available; then
    ok "libpcap"
  else
    missing "libpcap nao encontrada: sudo apt install libpcap-dev (sem sudo: aponte LIBPCAP_LIBDIR para um diretorio com libpcap.so)"
  fi
  for t in shellcheck actionlint golangci-lint govulncheck buf; do
    command -v "$t" >/dev/null || warn "$t nao instalado (so e preciso para make check)"
  done
  command -v cargo-deny >/dev/null || warn "cargo-deny nao instalado (so e preciso para make check): cargo install cargo-deny --locked"
  return "$FAILED"
}

require_repos() {
  local r
  for r in "$@"; do
    [ -d "$DIR/$r/.git" ] || die "$r nao encontrado em $DIR: rode scripts/dev.sh setup"
  done
}

setup() {
  local r
  command -v git >/dev/null || die "git nao encontrado"
  mkdir -p "$DIR"
  for r in "${REPOS[@]}"; do
    if [ -d "$DIR/$r/.git" ]; then
      echo "ja existe: $r"
    else
      echo "clonando $r ..."
      git clone -q "$BASE/$r" "$DIR/$r" || die "falha ao clonar $BASE/$r"
    fi
  done
  doctor || die "corrija as ferramentas acima e rode setup de novo"
  if [ ! -f "$DIR/psychoscope-core/go.work" ]; then
    (cd "$DIR/psychoscope-core" && go work init . ../psychoscope-proto)
    echo "criado psychoscope-core/go.work (ignorado pelo git) apontando para o proto local"
  fi
  for r in "${REPOS[@]}"; do
    if [ -f "$DIR/$r/Makefile" ]; then make -s -C "$DIR/$r" hooks; fi
  done
  echo
  echo "pronto. Proximos passos: scripts/dev.sh build   e, dentro de cada repositorio, make check"
}

update() {
  local d name before after bad=0
  for d in "$DIR/psychoscope-proto" "$DIR/psychoscope-core" "$DIR/mod-net-sensor" "$ROOT"; do
    name="$(basename "$d")"
    if [ ! -d "$d/.git" ]; then echo "ausente: $name (rode scripts/dev.sh setup)"; continue; fi
    if [ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]; then
      echo "pulado: $name tem alteracoes locais (faca commit ou stash antes)"
      continue
    fi
    if ! git -C "$d" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      echo "pulado: $name nao tem branch remota configurada"
      continue
    fi
    before="$(git -C "$d" rev-parse HEAD)"
    if git -C "$d" pull -q --ff-only; then
      after="$(git -C "$d" rev-parse HEAD)"
      if [ "$before" = "$after" ]; then
        echo "ok: $name ja estava atualizado"
      else
        echo "atualizado: $name ($(git -C "$d" rev-list --count "$before..$after") commits novos)"
      fi
    else
      echo "FALHA: $name nao avancou por fast-forward (branch divergente?): resolva a mao" >&2
      bad=1
    fi
  done
  [ "$bad" = 0 ]
}

build() {
  doctor || die "corrija as ferramentas acima antes de compilar"
  require_repos psychoscope-core mod-net-sensor
  if [ -f "$DIR/psychoscope-proto/scripts/local-deps.sh" ]; then
    # shellcheck source=/dev/null
    source "$DIR/psychoscope-proto/scripts/local-deps.sh"
  fi
  mkdir -p "$DIR/dist"
  make -C "$DIR/psychoscope-core" build DIST="$DIR/dist"
  make -C "$DIR/mod-net-sensor" build DIST="$DIR/dist"
  echo
  echo "binarios em $DIR/dist:"
  local b
  for b in psychoscope psychoscope-cli mod-net-sensor; do "$DIR/dist/$b" --version; done
}

clean() {
  if [ -z "$DIR" ] || [ "$DIR" = / ]; then die "diretorio invalido: '$DIR'"; fi
  rm -rf "${DIR:?}/dist"
  echo "removido $DIR/dist"
  if [ "$CARGO" = 1 ] && [ -d "$DIR/mod-net-sensor" ]; then
    (cd "$DIR/mod-net-sensor" && cargo clean)
  fi
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
case "$1" in -h|--help) usage; exit 0 ;; esac
COMMAND="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)   [ $# -ge 2 ] || die "--dir exige um diretorio"; DIR="$2"; shift 2 ;;
    --cargo) CARGO=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "argumento desconhecido: $1" ;;
  esac
done
[ "$COMMAND" = setup ] && mkdir -p "$DIR"
[ -d "$DIR" ] || die "diretorio inexistente: $DIR"
DIR="$(cd "$DIR" && pwd)"

case "$COMMAND" in
  doctor) doctor ;;
  setup)  setup ;;
  update) update ;;
  build)  build ;;
  clean)  clean ;;
  *) usage >&2; die "comando desconhecido: $COMMAND" ;;
esac
