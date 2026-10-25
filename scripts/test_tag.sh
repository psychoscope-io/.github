#!/usr/bin/env bash
# Testes do tag.sh em repositorios temporarios, cada um com um origin bare local. Nada sai da
# maquina; o cargo e falso (so atualiza a versao do Cargo.lock).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TAG="$HERE/../devtools/scripts/tag.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FALHOU: $*" >&2; exit 1; }

export HOME="$T/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@users.noreply.github.com
export GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@users.noreply.github.com

mkdir -p "$T/fakebin"
cat > "$T/fakebin/cargo" <<'SH'
#!/bin/sh
[ "$1" = update ] || exit 0
v="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)"
sed -i "/^name = \"demo\"/{n;s/^version = .*/version = \"$v\"/}" Cargo.lock
SH
chmod +x "$T/fakebin/cargo"
export PATH="$T/fakebin:$PATH"

# new_repo NOME: origin bare + clone com o tag.sh e um commit inicial ja publicado.
new_repo() {
  git init -q --bare -b main "$T/$1.git"
  git clone -q "$T/$1.git" "$T/$1" 2>/dev/null
  mkdir -p "$T/$1/scripts"
  cp "$TAG" "$T/$1/scripts/tag.sh"
  echo inicial > "$T/$1/f.txt"
  git -C "$T/$1" add -A
  git -C "$T/$1" commit -q -m "feat: inicial"
  git -C "$T/$1" push -q -u origin main
}
commit() { # NOME MENSAGEM
  echo "$RANDOM" >> "$T/$1/f.txt"
  git -C "$T/$1" add -A
  git -C "$T/$1" commit -q -m "$2"
}
tagsh() { # NOME args...: roda o tag.sh dentro do repositorio
  local r="$1"; shift
  (cd "$T/$r" && ./scripts/tag.sh "$@")
}
refuses() { # NOME REGEX args...: deve falhar com a mensagem e sem criar tag
  local r="$1" re="$2" before after; shift 2
  before="$(git -C "$T/$r" tag -l | wc -l)"
  if tagsh "$r" "$@" >"$T/out.txt" 2>"$T/err.txt" </dev/null; then fail "$r: deveria recusar ($re)"; fi
  grep -qE "$re" "$T/err.txt" || { cat "$T/err.txt" >&2; fail "$r: mensagem esperada: $re"; }
  after="$(git -C "$T/$r" tag -l | wc -l)"
  [ "$before" = "$after" ] || fail "$r: recusou mas criou tag"
}
latest_tag() { git -C "$T/$1" describe --tags --abbrev=0; }

new_repo r1

# 1. bump explicito: tag anotada local, com a descricao, sem push
tagsh r1 --bump minor -m "primeira versao" --yes >"$T/o1.txt" 2>/dev/null || fail "bump minor"
[ "$(latest_tag r1)" = v0.1.0 ] || fail "esperava v0.1.0, veio $(latest_tag r1)"
[ "$(git -C "$T/r1" cat-file -t v0.1.0)" = tag ] || fail "a tag deveria ser anotada"
git -C "$T/r1" tag -n1 v0.1.0 | grep -q "primeira versao" || fail "descricao da tag"
grep -q "git push origin main v0.1.0" "$T/o1.txt" || fail "deveria imprimir o comando de push"
[ -z "$(git ls-remote --tags "$T/r1.git")" ] || fail "o tag.sh nao pode fazer push"

# 2. interativo: fix sugere patch (Enter aceita), pede a descricao e confirma
commit r1 "fix: corrige algo"
printf '\numa correcao\ns\n' | (cd "$T/r1" && ./scripts/tag.sh >"$T/o2.txt" 2>&1) || { cat "$T/o2.txt" >&2; fail "interativo fix"; }
[ "$(latest_tag r1)" = v0.1.1 ] || fail "esperava v0.1.1, veio $(latest_tag r1)"
grep -qE '1\) .*v0\.1\.1.*sugerido' "$T/o2.txt" || fail "o fix deveria vir como sugerido"
grep -q "Tag atual: v0.1.0" "$T/o2.txt" || fail "deveria mostrar a tag atual"

# 3. feat sugere minor; incompativel antes da 1.0 tambem sobe o Y; depois da 1.0 sobe o X
commit r1 "feat(x): algo novo"
printf '\nmsg\ns\n' | (cd "$T/r1" && ./scripts/tag.sh >"$T/o3.txt" 2>&1) || fail "interativo feat"
[ "$(latest_tag r1)" = v0.2.0 ] || fail "feat: esperava v0.2.0, veio $(latest_tag r1)"
commit r1 "feat(x)!: muda o contrato"
printf '\nmsg\ns\n' | (cd "$T/r1" && ./scripts/tag.sh >"$T/o3b.txt" 2>&1) || fail "incompativel antes da 1.0"
[ "$(latest_tag r1)" = v0.3.0 ] || fail "incompativel na 0.x: esperava v0.3.0, veio $(latest_tag r1)"
commit r1 "fix: ajuste"
tagsh r1 --bump 1.0.0 -m "estavel" --yes >/dev/null 2>&1 || fail "versao digitada"
commit r1 "feat!: quebra a api"
printf '\nmsg\ns\n' | (cd "$T/r1" && ./scripts/tag.sh >"$T/o3c.txt" 2>&1) || fail "incompativel apos a 1.0"
[ "$(latest_tag r1)" = v2.0.0 ] || fail "incompativel na 1.x: esperava v2.0.0, veio $(latest_tag r1)"
commit r1 "fix: x"
printf '4\nv2.3.4\nmsg\ns\n' | (cd "$T/r1" && ./scripts/tag.sh >"$T/o3d.txt" 2>&1) || fail "opcao 4 (digitar)"
[ "$(latest_tag r1)" = v2.3.4 ] || fail "opcao 4: esperava v2.3.4"

# 4. recusas (cada uma sem criar tag)
refuses r1 "nenhum commit novo desde v2.3.4" --bump patch -m x --yes
commit r1 "fix: y"
refuses r1 "v2.0.0 ja existe|tag v2.0.0 ja existe" --bump 2.0.0 -m x --yes
refuses r1 "menor ou igual a maior versao ja criada \(v2.3.4\)" --bump 1.5.0 -m x --yes
refuses r1 "tag v2.3.4 ja existe" --bump 2.3.4 -m x --yes
refuses r1 "versao invalida" --bump 3 -m x --yes
refuses r1 "descricao" --bump patch --yes
echo sujo >> "$T/r1/f.txt"
refuses r1 "alteracoes nao commitadas" --bump patch -m x --yes
git -C "$T/r1" checkout -q f.txt
git -C "$T/r1" switch -q -c outra
refuses r1 "voce esta em 'outra'" --bump patch -m x --yes
git -C "$T/r1" switch -q main

# 5. tag que so existe no origin conta como existente e como a maior
git clone -q "$T/r1.git" "$T/r1-b" 2>/dev/null
git -C "$T/r1-b" tag -a v9.0.0 -m remota
git -C "$T/r1-b" push -q origin v9.0.0
refuses r1 "tag v9.0.0 ja existe|v9.0.0 ja existe" --bump 9.0.0 -m x --yes
refuses r1 "menor ou igual a maior versao ja criada \(v9.0.0\)" --bump 4.0.0 -m x --yes
git -C "$T/r1-b" push -q origin :refs/tags/v9.0.0

# 6. branch atras do origin
echo remoto > "$T/r1-b/remoto.txt"
git -C "$T/r1-b" add -A
git -C "$T/r1-b" commit -q -m "fix: no remoto"
git -C "$T/r1-b" push -q origin main
refuses r1 "atras de origin/main" --bump patch -m x --yes
git -C "$T/r1" pull -q --rebase

# 7. pre-voo: autor sem noreply, diretorio pessoal e segredo no codigo
echo ajuste >> "$T/r1/f.txt"
git -C "$T/r1" add -A
GIT_AUTHOR_EMAIL=pessoa@exemplo.org git -C "$T/r1" commit -q -m "fix: autor pessoal"
refuses r1 "sem e-mail noreply" --bump patch -m x --yes
tagsh r1 --bump patch -m "ignorando o pre-voo" --yes --skip-check >/dev/null 2>&1 || fail "--skip-check deveria permitir"
commit r1 "fix: limpo"
echo "caminho $HOME/dados" > "$T/r1/vazou.txt"; git -C "$T/r1" add -A; git -C "$T/r1" commit -q -m "fix: vaza o diretorio pessoal"
refuses r1 "diretorio pessoal" --bump patch -m x --yes
git -C "$T/r1" reset -q --hard HEAD~1
echo "chave AKIA0123456789ABCDEF" > "$T/r1/vazou.txt"; git -C "$T/r1" add -A; git -C "$T/r1" commit -q -m "fix: vaza um segredo"
refuses r1 "possivel segredo" --bump patch -m x --yes
git -C "$T/r1" reset -q --hard HEAD~1

# 8. repositorio Rust (sensor): o commit de versao vem antes da tag
new_repo r2
cat > "$T/r2/Cargo.toml" <<'TOML'
[package]
name = "demo"
version = "0.3.0"
edition = "2024"

[dependencies]
psychoscope-proto = { git = "https://example.invalid/proto", tag = "v0.4.0", version = "0.1" }
TOML
printf '[[package]]\nname = "demo"\nversion = "0.3.0"\n' > "$T/r2/Cargo.lock"
git -C "$T/r2" add -A
git -C "$T/r2" commit -q -m "chore: cargo"
n="$(git -C "$T/r2" rev-list --count HEAD)"
tagsh r2 --offline --bump 0.3.0 -m "ja coincide" --yes >/dev/null 2>&1 || fail "tag igual ao Cargo.toml"
[ "$(git -C "$T/r2" rev-list --count HEAD)" = "$n" ] || fail "nao deveria criar commit de versao quando o Cargo.toml ja coincide"
commit r2 "fix: corrige"
tagsh r2 --offline --bump patch -m "correcao" --yes >/dev/null 2>&1 || fail "bump no repositorio Rust"
[ "$(latest_tag r2)" = v0.3.1 ] || fail "esperava v0.3.1"
[ "$(git -C "$T/r2" log -1 --format=%s)" = "chore(release): v0.3.1" ] || fail "commit de versao"
grep -q '^version = "0.3.1"' "$T/r2/Cargo.toml" || fail "Cargo.toml nao atualizado"
grep -q 'version = "0.3.1"' "$T/r2/Cargo.lock" || fail "Cargo.lock nao atualizado"
[ "$(git -C "$T/r2" rev-parse "v0.3.1^{commit}")" = "$(git -C "$T/r2" rev-parse HEAD)" ] || fail "a tag deveria apontar para o commit de versao"
[ -z "$(git -C "$T/r2" status --porcelain)" ] || fail "arvore deveria ficar limpa"
[ -z "$(git ls-remote --tags "$T/r2.git")" ] || fail "o tag.sh nao pode fazer push"

echo "tag.sh OK"
