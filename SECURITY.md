# Política de segurança

Esta política vale para todos os repositórios da organização psychoscope-io: `psychoscope-proto`, `psychoscope-core` e `mod-net-sensor`.

## Como reportar uma vulnerabilidade

**Não abra uma issue pública, um pull request nem uma discussão para relatar uma vulnerabilidade.**

Use o reporte privado de vulnerabilidades do GitHub (*GitHub Private Vulnerability Reporting*):

1. Abra a aba **Security** do repositório afetado.
2. Clique em **Report a vulnerability** (em "Advisories").
3. Descreva o problema com o máximo de detalhe possível.

Inclua, se puder:

- o repositório, a versão (tag ou commit) e o ambiente em que o problema ocorre;
- os passos para reproduzir, de preferência com uma prova de conceito mínima;
- o impacto esperado (por exemplo: execução de código, negação de serviço, elevação de privilégio, vazamento de dados);
- uma sugestão de correção, se houver.

Se o botão de reporte privado não aparecer no repositório, abra uma issue pública pedindo apenas que o reporte privado seja habilitado, sem detalhes técnicos da vulnerabilidade.

## Versões suportadas

Damos suporte de segurança apenas à **última release** publicada de cada repositório. Correções não são portadas para versões anteriores; atualize para a release mais recente.

## Prazos

| Etapa | Prazo |
|---|---|
| Confirmação de recebimento | até 5 dias úteis |
| Correção e divulgação coordenada | até 90 dias após a confirmação |

Durante a análise, mantemos você informado sobre o andamento. Quando a correção estiver pronta, publicamos uma nova release e um aviso de segurança (*security advisory*) e damos crédito a quem reportou, se essa for a vontade da pessoa. Se o prazo de 90 dias não for suficiente por motivo justificado, combinamos uma nova data com quem reportou.

## Escopo

Estão no escopo falhas no código e nos contratos publicados nos repositórios da organização, por exemplo:

- contornar a validação de identidade dos módulos (`SO_PEERCRED`, `id_modulo`) ou os limites do framing do IPC;
- travar, esgotar recursos ou executar código no Core ou no sensor a partir de dados de rede ou mensagens IPC malformadas;
- escapar de restrições de permissão dos sockets ou do ambiente dos processos supervisionados.

Vulnerabilidades em dependências de terceiros devem ser reportadas aos respectivos mantenedores; avise-nos se elas afetarem de forma específica o Psychoscope.
