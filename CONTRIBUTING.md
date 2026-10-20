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

### Dependência local do proto

O core e o sensor dependem do `psychoscope-proto` por tag do GitHub. Para desenvolver com a cópia local (offline, ou antes de publicar uma tag), rode dentro do core ou do sensor:

```bash
source ../psychoscope-proto/scripts/local-deps.sh
```

O script vale só para o shell atual e seus processos filhos. As tags precisam existir no checkout local do proto.

## Rodar os testes

Antes de abrir um pull request, rode as verificações do repositório que você alterou. Elas são as mesmas do CI.

**psychoscope-proto**

```bash
make lint            # buf lint
make gen             # regenera gen/go; o diff em gen/ deve estar commitado
make check           # lint + gen + diff de gen/ + rustfmt/clippy do crate Rust
make breaking AGAINST='.git#tag=v0.2.0'   # compatibilidade com a ultima tag
go build ./...
```

**psychoscope-core**

```bash
gofmt -l .           # deve não imprimir nada
go vet ./...
go test -race ./...
go build ./cmd/psychoscope ./cmd/psychoscope-cli
./deploy/test_install.sh   # testes do instalador (sem privilégios)
```

**mod-net-sensor**

```bash
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
cargo test --locked
scripts/fuzz.sh 30       # opcional; exige nightly e cargo-fuzz
scripts/e2e.sh           # exige ../psychoscope-core
scripts/live_smoke.sh    # captura ao vivo em um namespace; exige unshare e ip
```

## Estilo e escopo

- Siga o estilo do código ao redor (nomes, comentários, idioma). Código novo vem com testes, inclusive casos negativos (falsos positivos, entradas malformadas).
- Mantenha cada pull request focado em uma mudança. Não misture refatoração, formatação em massa e funcionalidade nova.
- Documente comportamento visível ao usuário no README do repositório.

## Commits

- Escreva mensagens no imperativo, com um resumo curto na primeira linha e o porquê da mudança no corpo, quando não for óbvio.
- **Não inclua trailers de IA** nas mensagens de commit (por exemplo `Co-Authored-By` de assistentes de código ou linhas "Generated with"). Você é responsável pelo conteúdo que envia, e a autoria do commit deve ser sua.
- Use seu nome e um e-mail de sua escolha; o e-mail `noreply` do GitHub é suficiente.

## Pull requests

1. Faça um fork e crie uma branch a partir de `main`.
2. Garanta que as verificações acima passam localmente.
3. Preencha o modelo do pull request, relacionando a issue quando houver.
4. Responda aos comentários da revisão com novos commits; o histórico é ajustado na hora do merge, se necessário.
