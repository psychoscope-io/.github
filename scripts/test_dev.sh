#!/usr/bin/env bash
# Testes do dev.sh sem rede e sem as ferramentas de verdade: repositorios "remotos" locais
# (bare, via file://), Makefiles falsos e go/cargo/rustc/pkg-config falsos no PATH.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FALHOU: $*" >&2; exit 1; }

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@example.invalid
export GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@example.invalid

# Ferramentas falsas: o teste nao depende do que a maquina tem instalado.
mkdir -p "$T/fakebin"
cat > "$T/fakebin/go" <<'SH'
#!/bin/sh
case "$1" in
  version) echo "go version go${FAKE_GO_VERSION:-1.27.2} linux/amd64" ;;
  work) [ "$2" = init ] && printf 'go 1.27\n' > go.work ;;
esac
exit 0
SH
for t in cargo rustc pkg-config; do printf '#!/bin/sh\nexit 0\n' > "$T/fakebin/$t"; done
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"

# seal NOME: versiona $T/seed/NOME e publica como remoto bare.
seal() {
  git -C "$T/seed/$1" init -q -b main
  git -C "$T/seed/$1" add -A
  git -C "$T/seed/$1" commit -q -m "inicial"
  mkdir -p "$T/remotes"
  git clone -q --bare "$T/seed/$1" "$T/remotes/$1"
}
seed_makefile() { # NOME: Makefile com hooks e build falsos
  mkdir -p "$T/seed/$1"
  printf 'hooks:\n\tgit config core.hooksPath .githooks\nbuild:\n\t./build.sh "%s"\n' "\$(DIST)" > "$T/seed/$1/Makefile"
}
seed_build() { # NOME BINARIO...: build.sh que grava um binario falso por linha de `binaries`
  local n="$1"; shift
  printf '%s\n' "$@" > "$T/seed/$n/binaries"
  cat > "$T/seed/$n/build.sh" <<'SH'
#!/bin/sh
mkdir -p "$1"
while read -r b; do
  printf '#!/bin/sh\necho "%s 1.2.3"\n' "$b" > "$1/$b"
  chmod +x "$1/$b"
done < binaries
SH
  chmod +x "$T/seed/$n/build.sh"
}

seed_makefile psychoscope-proto
mkdir -p "$T/seed/psychoscope-proto/scripts"
printf '# local-deps falso\nexport PSY_LOCAL_DEPS=1\n' > "$T/seed/psychoscope-proto/scripts/local-deps.sh"
seed_build psychoscope-proto
seal psychoscope-proto

seed_makefile psychoscope-core
printf 'module example.com/core\n\ngo 1.26.0\n' > "$T/seed/psychoscope-core/go.mod"
printf 'go.work\n' > "$T/seed/psychoscope-core/.gitignore"
seed_build psychoscope-core psychoscope psychoscope-cli
seal psychoscope-core

seed_makefile mod-net-sensor
seed_build mod-net-sensor mod-net-sensor
seal mod-net-sensor

# Este repositorio (a org) tambem tem remoto, porque o update o inclui.
mkdir -p "$T/seed/psychoscope-github/scripts"
cp "$HERE/dev.sh" "$T/seed/psychoscope-github/scripts/dev.sh"
seal psychoscope-github
mkdir -p "$T/work"
git clone -q "$T/remotes/psychoscope-github" "$T/work/psychoscope-github"
DEV="$T/work/psychoscope-github/scripts/dev.sh"
export PSYCHOSCOPE_GIT_BASE="file://$T/remotes"

# push_remoto NOME ARQUIVO: um commit novo no remoto, vindo de outro clone.
push_remoto() {
  git clone -q "$T/remotes/$1" "$T/pusher-$1"
  echo novo >> "$T/pusher-$1/$2"
  git -C "$T/pusher-$1" add -A
  git -C "$T/pusher-$1" commit -q -m "novo em $1"
  git -C "$T/pusher-$1" push -q origin main
}

# 1. setup clona os tres repositorios, cria o go.work e ativa os hooks; repetir e inofensivo
"$DEV" setup >"$T/o1.txt" 2>&1 || { cat "$T/o1.txt" >&2; fail "setup"; }
for r in psychoscope-proto psychoscope-core mod-net-sensor; do
  [ -d "$T/work/$r/.git" ] || fail "$r nao foi clonado"
  [ "$(git -C "$T/work/$r" config core.hooksPath)" = .githooks ] || fail "hooks nao ativados em $r"
done
[ -f "$T/work/psychoscope-core/go.work" ] || fail "go.work nao criado"
[ -z "$(git -C "$T/work/psychoscope-core" status --porcelain)" ] || fail "o go.work deveria ser ignorado pelo git"
"$DEV" setup >"$T/o1b.txt" 2>&1 || fail "setup repetido"
grep -q "ja existe: psychoscope-core" "$T/o1b.txt" || fail "setup repetido deveria reaproveitar os clones"

# 2. doctor: passa com as ferramentas falsas e reprova Go mais antigo que o go.mod do core
"$DEV" doctor >"$T/o2.txt" 2>&1 || fail "doctor"
grep -q "ok: go 1.27.2" "$T/o2.txt" || fail "doctor deveria listar o go"
if FAKE_GO_VERSION=1.20.0 "$DEV" doctor >"$T/o2b.txt" 2>&1; then fail "go antigo deveria reprovar"; fi
grep -q "mais antigo que o go.mod do core exige (1.26.0)" "$T/o2b.txt" || fail "mensagem de go antigo"
mkdir -p "$T/semgo"
if PATH="$T/semgo:/usr/bin:/bin" "$DEV" doctor >"$T/o2c.txt" 2>&1; then fail "sem go deveria reprovar"; fi
grep -q "go nao encontrado" "$T/o2c.txt" || fail "mensagem de go ausente"

# 3. update: avanca o que esta limpo, pula o que tem alteracao local, falha na divergencia
push_remoto psychoscope-core notas.txt
"$DEV" update >"$T/o3.txt" 2>&1 || fail "update"
grep -q "atualizado: psychoscope-core (1 commits novos)" "$T/o3.txt" || fail "update deveria avancar o core"
grep -q "ok: mod-net-sensor ja estava atualizado" "$T/o3.txt" || fail "update deveria reconhecer o sensor atualizado"
push_remoto mod-net-sensor notas.txt
echo local >> "$T/work/mod-net-sensor/binaries"
"$DEV" update >"$T/o3b.txt" 2>&1 || fail "update com repositorio sujo nao deveria falhar"
grep -q "pulado: mod-net-sensor tem alteracoes locais" "$T/o3b.txt" || fail "deveria pular o repositorio sujo"
git -C "$T/work/mod-net-sensor" checkout -q binaries
push_remoto psychoscope-proto notas.txt
echo local > "$T/work/psychoscope-proto/local.txt"
git -C "$T/work/psychoscope-proto" add local.txt
git -C "$T/work/psychoscope-proto" commit -q -m "local"
if "$DEV" update >"$T/o3c.txt" 2>&1; then fail "branch divergente deveria falhar"; fi
grep -q "FALHA: psychoscope-proto nao avancou por fast-forward" "$T/o3c.txt" || fail "mensagem de divergencia"
grep -q "atualizado: mod-net-sensor" "$T/o3c.txt" || fail "a divergencia de um nao deveria impedir os outros"
git -C "$T/work/psychoscope-proto" reset -q --hard origin/main

# 4. build: chama make build do core e do sensor e junta tudo em DIR/dist
"$DEV" build >"$T/o4.txt" 2>&1 || { cat "$T/o4.txt" >&2; fail "build"; }
for b in psychoscope psychoscope-cli mod-net-sensor; do
  [ -x "$T/work/dist/$b" ] || fail "dist/$b nao gerado"
done
grep -q "psychoscope 1.2.3" "$T/o4.txt" || fail "build deveria mostrar as versoes"

# 5. clean
"$DEV" clean --cargo >"$T/o5.txt" 2>&1 || fail "clean"
[ ! -e "$T/work/dist" ] || fail "clean deveria remover dist"
[ -d "$T/work/psychoscope-core" ] || fail "clean nao pode tocar nos repositorios"

# 6. erros claros e --dir
if "$DEV" 2>/dev/null; then fail "sem comando deveria falhar"; fi
if "$DEV" bogus 2>"$T/e6.txt"; then fail "comando desconhecido deveria falhar"; fi
grep -q "comando desconhecido" "$T/e6.txt" || fail "mensagem de comando desconhecido"
if "$DEV" build --dir "$T/vazio" 2>"$T/e6b.txt"; then fail "--dir inexistente deveria falhar"; fi
grep -q "diretorio inexistente" "$T/e6b.txt" || fail "mensagem de --dir inexistente"
"$DEV" setup --dir "$T/outro" >/dev/null 2>&1 || fail "setup --dir"
[ -d "$T/outro/mod-net-sensor/.git" ] || fail "setup --dir deveria clonar no diretorio pedido"

echo "dev.sh OK"
