# Como contribuir

Obrigado pelo interesse em contribuir com o Psychoscope. Este guia vale para os repositórios `psychoscope-proto`, `psychoscope-core` e `mod-net-sensor`.

Ao participar, você concorda em seguir o [código de conduta](CODE_OF_CONDUCT.md). Vulnerabilidades **não** devem virar issue pública: veja a [política de segurança](SECURITY.md).

## Antes de começar

- Procure uma issue existente antes de abrir outra. Para mudanças grandes, abra uma issue primeiro para alinhar a proposta.
- Contribuições são licenciadas sob Apache-2.0, a mesma licença do projeto.
- Mudanças no contrato (`psychoscope-proto`) devem ser aditivas: nunca reutilize números de campo e nunca mova uma tag já publicada.

## Preparar o ambiente

Clone os repositórios lado a lado, na mesma pasta:

```
psychoscope/
  psychoscope-proto/
  psychoscope-core/
  mod-net-sensor/
```

Ferramentas necessárias:

- **Go**: a versão indicada em `go.mod` do `psychoscope-core` (para o `psychoscope-proto`, a versão do seu `go.mod`).
- **Rust**: toolchain estável com `rustfmt` e `clippy` (`rustup component add rustfmt clippy`).
- **buf** e `protoc-gen-go` (`go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.12`), só para mexer nos arquivos `.proto`.
- **libpcap**: `libpcap-dev` (Debian/Ubuntu) para compilar o sensor.
- **Python 3**, para os scripts de teste de ponta a ponta.
- Ferramentas de qualidade: `shellcheck` e `actionlint` (todos os repositórios), `golangci-lint` v2 e `govulncheck` (core; `go install`), `cargo-deny` (`cargo install cargo-deny --locked`; sensor e crate do proto).

Em cada clone, rode `make hooks` uma vez: ele ativa os hooks de `.githooks/` (`commit-msg` valida a mensagem, `pre-commit` roda as verificações rápidas e `pre-push` valida as mensagens do que será enviado e roda `make check`).

### Dependência local do proto

O core e o sensor dependem do `psychoscope-proto` por tag do GitHub. Para desenvolver com a cópia local (offline, ou antes de publicar uma tag), rode dentro do core ou do sensor:

```bash
source ../psychoscope-proto/scripts/local-deps.sh
```

O script vale só para o shell atual e seus processos filhos. As tags precisam existir no checkout local do proto.

## Rodar os testes

Antes de abrir um pull request, rode `make check` no repositório que você alterou. É o mesmo conjunto do CI: formatação, lint (que falha em qualquer aviso), análise de shell e workflows, auditoria de dependências e testes.

**psychoscope-proto**

```bash
make check                                # buf lint/format, gen sem diff, rustfmt/clippy/cargo deny, shellcheck, actionlint
make breaking AGAINST='.git#tag=v0.2.0'   # compatibilidade com a última tag
```

**psychoscope-core**

```bash
make check                 # gofmt, vet, golangci-lint, shellcheck, actionlint, govulncheck, go test -race
./deploy/test_install.sh   # testes do instalador (sem privilégios)
```

**mod-net-sensor**

```bash
make check               # rustfmt, clippy -D warnings, shellcheck, actionlint, cargo deny, cargo test
scripts/fuzz.sh 30       # opcional; exige nightly e cargo-fuzz
scripts/e2e.sh           # exige ../psychoscope-core
scripts/live_smoke.sh    # captura ao vivo em um namespace; exige unshare e ip
```

## Estilo e escopo

- Siga o estilo do código ao redor (nomes, comentários, idioma). Código novo vem com testes, inclusive casos negativos (falsos positivos, entradas malformadas).
- Mantenha cada pull request focado em uma mudança. Não misture refatoração, formatação em massa e funcionalidade nova.
- Documente comportamento visível ao usuário no README do repositório.

## Commits

- As mensagens seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/): `tipo(escopo): descrição`, com tipo em `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` ou `revert` (`!` marca mudança incompatível). Descrição no imperativo, em minúscula, sem ponto final, com até 72 caracteres (o limite do validador é 100); o corpo explica o porquê, quando não for óbvio.
- O validador (`scripts/check-commit-msg.sh`) roda no hook `commit-msg`, no `pre-push` e no CI; um commit fora do padrão reprova o CI.
- **Não inclua trailers de IA** nas mensagens de commit (por exemplo `Co-Authored-By` de assistentes de código ou linhas "Generated with"). Você é responsável pelo conteúdo que envia, e a autoria do commit deve ser sua.
- Use seu nome e um e-mail de sua escolha; o e-mail `noreply` do GitHub é suficiente.

## Pull requests

1. Faça um fork e crie uma branch a partir de `main`.
2. Garanta que as verificações acima passam localmente.
3. Preencha o modelo do pull request, relacionando a issue quando houver.
4. Responda aos comentários da revisão com novos commits; o histórico é ajustado na hora do merge, se necessário.
