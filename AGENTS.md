# AGENTS.md — psychoscope-io/.github

Repositório da organização: arquivos de comunidade (`SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, modelos de issue/PR, `profile/README.md`) e a **fonte das regras e skills de agentes** compartilhadas pelos outros repositórios.

## Regras e skills compartilhadas

- `agents/rules/*.md`: regras sempre ativas (fluxo de trabalho, princípios de design, organização do código, testes, git e publicação, segurança, contrato, estilo).
- `agents/skills/<nome>/SKILL.md`: procedimentos sob demanda (revisar PRs do Dependabot, preparar publicação, refatorar sem quebrar).
- Cada repositório recebe uma **cópia** em `.claude/rules/` e `.claude/skills/`. Edite só aqui e sincronize:

```bash
scripts/sync-agent-rules.sh ../psychoscope-proto ../psychoscope-core ../mod-net-sensor
scripts/sync-agent-rules.sh --check ../psychoscope-proto ../psychoscope-core ../mod-net-sensor   # diverge? sai com 1
```

Regras e skills **específicas** de um repositório ficam só nele, com nomes que não colidem com as daqui.

## Ao criar ou editar regras e skills

- Uma regra é uma restrição curta e sempre válida; um procedimento com passos vira skill. Cada arquivo cabe em uma tela.
- Comandos citados devem ter sido executados. Regra que uma ferramenta consegue verificar (CI, hook) deve virar verificação.
- Leia `agents/rules/fluxo-de-trabalho.md` e `git-e-publicacao.md` antes de commitar ou publicar qualquer coisa.
