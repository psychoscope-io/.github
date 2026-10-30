# Roadmap

Direção do Psychoscope. É um plano, não uma promessa de datas: os marcos são ordenados por dependência, cada um tem um objetivo, uma justificativa para a posição que ocupa e termina com um critério verificável. As decisões de escopo são do mantenedor; para propor algo, abra uma issue (veja o [guia de contribuição](CONTRIBUTING.md)).

Este roadmap cobre o projeto de código aberto: o monitoramento de **uma máquina Linux, feito nela mesma**.

## Visão

Uma ferramenta que se instala em minutos, roda o tempo todo sem incomodar e, quando alerta, diz **o que aconteceu, por que é suspeito e o que fazer**. Quem a instala deve confiar nos alertas o bastante para não desligá-la.

O caminho tem quatro etapas, nesta ordem:

1. **Confiança:** os alertas de rede que já existem ficam bons o bastante para o uso diário.
2. **Plataforma:** o Core deixa de saber só de rede e passa a aceitar qualquer tipo de módulo.
3. **Cobertura:** um segundo módulo (processos) e a ligação entre processo e rede.
4. **Estabilidade:** a versão 1.0, com compromisso de compatibilidade.

Essa ordem é deliberada. Aumentar a cobertura antes de confiar nos alertas multiplica falsos positivos; abrir a plataforma antes de ter um segundo caso real a molda ao primeiro; declarar estabilidade antes dos dois fixa decisões ainda não testadas.

## Princípios

- **Alerta explicável e ajustável.** Todo alerta traz o contexto que o originou e, quando faz sentido, uma exceção pronta para aplicar. Falso positivo sem explicação é tratado como defeito.
- **Privilégio mínimo.** O Core roda sem privilégios; cada módulo recebe só o que precisa e o documenta.
- **Local primeiro.** Os dados ficam na máquina. Nada é enviado para fora sem configuração explícita do administrador.
- **Leve.** Custo de CPU e memória medido e publicado ([DESEMPENHO.md](https://github.com/psychoscope-io/mod-net-sensor/blob/main/docs/DESEMPENHO.md)); regressão de desempenho bloqueia versão.
- **Contrato estável.** Mudanças no `psychoscope-proto` são aditivas, para que módulos de versões diferentes continuem conversando com o Core.
- **Toda regra vem com seu teste.** Regra nova só entra com pcap ou fixture de caso positivo, de caso negativo e dos falsos positivos conhecidos.

## Onde estamos

Versões atuais: `psychoscope-core` v0.12.0, `mod-net-sensor` v0.3.0, `psychoscope-proto` v0.5.0.

Já entregue:

- **Core:** supervisor de módulos, IPC autenticado pelo kernel (`SO_PEERCRED`), motor de detecção em janela deslizante, alertas persistidos em SQLite e métricas Prometheus.
- **Sensor de rede:** libpcap ou arquivo pcap, decodificação de DNS, TCP, TLS e ICMP, contadores de perda e descarte, `--check` e `--list-interfaces` para diagnosticar o ambiente.
- **Oito regras de rede:** varredura SYN, força bruta em portas de autenticação, varredura ICMP, rajada de NXDOMAIN (DGA), túnel DNS, taxa de DNS, TLS suspeito e beacon.
- **CLI e TUI:** detalhe do alerta, exceção sugerida em uma tecla (`i`, desfeita com `u`) e configuração em tempo de execução, sem editar JSON nem reiniciar o serviço.
- **Diagnóstico:** `psychoscope-cli doctor` verifica serviço, permissões, módulos e perda de pacotes e diz o que corrigir (`--sensor` inclui o `--check` do sensor; `--json` para scripts).
- **Referência das regras:** uma página por regra com o que detecta, como investigar, falsos positivos e como ajustar ([REGRAS.md](https://github.com/psychoscope-io/psychoscope-core/blob/main/docs/REGRAS.md)).
- **Estado do motor preservado:** cooldowns e séries do beacon sobrevivem a reinício e a mudança de configuração (só a regra com limiar ajustado recomeça).
- **Alertas enquadrados e reproduzíveis:** cada alerta indica a técnica do MITRE ATT&CK, e `psychoscope-cli analyze arquivo.pcap` reproduz alertas offline, sem instalar o serviço.
- **Falsos positivos catalogados:** os limiares padrão foram ajustados a partir de uma semana de tráfego real, e cada caso virou um pcap de teste que a regra não pode voltar a disparar.
- **Desempenho medido sob carga:** sem perdas até 200 mil pacotes/s de ruído e até 100 mil de DNS, com os números e os limites publicados no [DESEMPENHO.md](https://github.com/psychoscope-io/mod-net-sensor/blob/main/docs/DESEMPENHO.md).
- **Privilégio separado:** o sensor roda em serviço próprio (`psychoscope-sensor`), com usuário dedicado e capabilities ambientes, sem `setcap`; o Core fica sem capabilities e com `NoNewPrivileges`, e autentica o módulo externo pelo UID que o kernel informa. `psychoscope-cli migrate-config` converte a configuração antiga.
- **Instalação:** serviços systemd com usuários dedicados, por `get.sh` (instala, atualiza e desinstala) ou por tarball de release com checksums e atestado de proveniência.

Ainda não verificado: execução em arm64 (os binários são gerados, mas não rodados), comportamento em tráfego alto em placa de rede física e em outro hardware, e taxa de falsos positivos ao longo de semanas.

## Visão geral dos marcos

| Marco | Tema | Pergunta que responde |
|---|---|---|
| 1 | Confiável no uso diário | Posso deixar rodando e confiar nos alertas? |
| 2 | Plataforma para outros módulos | Posso escrever um módulo sem alterar o Core? |
| 3 | Monitoramento de processos | O que está sendo executado na máquina? |
| 4 | Correlação processo e rede | Qual programa originou esta conexão? |
| 5 | Versão 1.0 | Posso depender disso sem medo de quebra? |

Um marco só fecha quando o critério "pronto quando" é cumprido; correções menores saem entre eles.

## Marco 1: confiável no uso diário

**Objetivo:** dá para deixar o Psychoscope rodando numa máquina real por semanas sem alertas falsos inexplicados e sem precisar ler o código para entender um alerta.

**Por que primeiro:** é o que decide se alguém mantém a ferramenta instalada. Tudo o que vem depois herda a reputação dos alertas atuais.

*Validar o que já existe*

- [x] Validar a configuração em tempo de execução na máquina real: aplicar uma exceção pela TUI e ver o alerta sumir sem reiniciar; conferir `overrides.json` (`0600`, dono `psychoscope`) e a auditoria no `journalctl`. (Validado no serviço instalado: a exceção do beacon pela tecla `i` valeu sem reiniciar, o `overrides.json` ficou `0600` com dono `psychoscope`, o `journalctl` registrou a mudança com UID, PID, antes e depois, e `config reset` removeu o arquivo. Os alertas já gerados ficam no histórico, como previsto; só os novos deixam de aparecer.)
- [x] Confirmar o encerramento ordenado do sensor (`KillMode=mixed`) no serviço instalado, não só em unidades transitórias. (Verificado no serviço instalado: parada em ~30 ms, o sensor encerrado pelo Core com o resumo final e sem perdas, sem SIGKILL nem processo órfão, e o serviço sobe de novo com um sensor novo.)
- [ ] Rodar o Core e o sensor em arm64 de verdade, e não só compilar.
- [x] Medir o comportamento sob tráfego alto (taxa de pacotes, perdas, uso de CPU e memória) e publicar o resultado no `DESEMPENHO.md`. (Em um laptop i7-8565U: sem perdas até 200 mil pacotes/s de ruído e até 100 mil pacotes/s de DNS, em `lo` e em `veth`; 10 min a 50 mil pacotes/s sem perdas e com memória estável; gargalo atribuído à leitura IPC do Core e corrigido, e dois defeitos achados sob carga foram corrigidos no Core v0.11.1 e v0.11.2. Não medido: placa de rede física, outro hardware e arm64; acima de ~200 mil eventos/s o motor ainda descarta eventos, contados e documentados.)
- [x] Instalação testada do zero em Debian, Ubuntu e Fedora, incluindo atualização sem perder configuração nem histórico. (Testada em contêineres Docker com Debian 12, Ubuntu 24.04 e Fedora, pelo `deploy/test_distros.sh` do `psychoscope-core`. No Fedora a release do sensor não subia, porque pedia `libpcap.so.0.8`; o sensor passa a levar o libpcap embutido, e o binário foi conferido num Fedora 44 sem libpcap instalada. Não coberto: arm64, outras versões das distribuições e captura em Wi-Fi real.)

*Reduzir falsos positivos*

- [x] Observar uma semana de tráfego real e catalogar os falsos positivos (374 alertas em 8 dias; o catálogo está em `docs/REGRAS.md` do `psychoscope-core`).
- [x] Ajustar os limiares padrão conforme esse catálogo. (Só onde havia um sinal que separa o legítimo do ataque: o scan horizontal ignora destinos que respondem, o `net.dns.nxdomain_burst` ignora consultas de descoberta de serviço; o `net.beacon` e o TLS ficaram com exceções documentadas.)
- [x] Transformar cada falso positivo catalogado em um pcap de teste: a regra não pode voltar a disparar nele. (As oito regras têm caso no `mod-net-sensor` (`testdata/falsos-positivos/`), conferido pelo `analyze` no `e2e.sh`, mais cinco ataques que têm de continuar disparando; cada caso traz o ajuste que o silencia.)
- [x] Preservar o estado do motor (cooldowns e séries do beacon) entre reinícios do Core, para que reiniciar ou reconfigurar não traga de volta alertas já vistos.

*Tornar o alerta compreensível*

- [x] Página de referência por regra: o que detecta, por que importa, falsos positivos conhecidos, como investigar e como ajustar.
- [x] Cada alerta indica a técnica correspondente do MITRE ATT&CK, para quem precisa enquadrar o que viu.
- [x] `psychoscope-cli doctor`: verifica de uma vez serviço, permissões, interface, sensor conectado e perda de pacotes, e diz o que corrigir.
- [x] Análise offline de um pcap pela CLI (`psychoscope-cli analyze arquivo.pcap`), para reproduzir um alerta, testar um ajuste ou avaliar a ferramenta sem instalar o serviço.

**Pronto quando:** uma semana em máquina real sem alerta falso inexplicado, toda regra com página de referência e ao menos um pcap de falso positivo nos testes, e instalação validada nas três distribuições e nas duas arquiteturas.

## Marco 2: plataforma para outros módulos

**Objetivo:** o Core aceita módulos que não são de rede sem gambiarra. Hoje o contrato (`EventoTelemetria`) e o motor só conhecem eventos de rede (`EventoFluxoRede`).

**Por que agora:** é a base do Marco 3. Fazer antes do módulo novo, e não junto, evita que a plataforma nasça moldada ao primeiro caso. O guia de módulos também é o que permite a terceiros contribuírem.

- [ ] `EventoTelemetria.dado` com novas variantes (mudança só aditiva no `psychoscope-proto`).
- [ ] `Event` genérico no motor: cada regra declara o tipo de evento que consome.
- [ ] Métricas, alertas e TUI por módulo, sem supor que todo módulo é de rede.
- [ ] Modelo de privilégios por módulo (capabilities e usuário), mantendo o Core sem privilégios.
- [ ] Regras com testes de tabela e fixtures reutilizáveis, para quem escreve uma regra testá-la sem subir o Core inteiro.
- [ ] Guia "como criar um módulo", com um módulo mínimo de exemplo que passa nos testes de ponta a ponta.
- [ ] Política de versionamento do contrato publicada: o que é compatível, como um módulo declara a versão que fala e como o Core reage a uma versão desconhecida.

**Pronto quando:** o módulo de exemplo do guia, escrito sem tocar no Core, emite eventos, dispara uma regra e aparece na TUI.

## Marco 3: monitoramento de processos

**Objetivo:** detectar execuções suspeitas na máquina. Começa lendo `/proc`, sem privilégio, para manter a instalação simples e o risco baixo.

**Por que depois do Marco 2:** é o primeiro módulo não-rede e serve de prova de que a plataforma funciona.

- [ ] Novo módulo emitindo eventos de início e fim de processo para o Core.
- [ ] Primeiras regras:
  - binário executado a partir de diretórios graváveis por todos (`/tmp`, `/dev/shm`);
  - processo cujo executável foi removido do disco;
  - shell com entrada ou saída ligada a um socket de rede.

  Cada uma com seus falsos positivos documentados e um caso de teste que os reproduz.
- [ ] Exceções sugeridas no detalhe do alerta, como nas regras de rede.
- [ ] Páginas de referência das novas regras, no mesmo formato do Marco 1.
- [ ] Documentação de instalação, privilégios e limitações (o que uma leitura periódica de `/proc` não vê, como processos de vida muito curta).

**Pronto quando:** as regras de processo passam pelo mesmo critério do Marco 1 (uma semana em máquina real sem alerta falso inexplicado).

## Marco 4: correlação entre processo e rede

**Objetivo:** um alerta de rede diz qual programa originou a conexão, por exemplo, o processo que mantém um beacon. É o principal ganho de ter mais de um módulo e o que diferencia o Psychoscope de olhar rede e processos em separado.

- [ ] Associar conexões a processos (PID, executável e usuário) na máquina local.
- [ ] Contexto do processo no detalhe dos alertas de rede, quando disponível.
- [ ] Exceções por executável, além de por destino (por exemplo, ignorar o beacon de um aplicativo conhecido, não de um IP).
- [ ] Regras que só existem com os dois lados: por exemplo, um executável de diretório gravável que abre conexões periódicas para fora.
- [ ] Revisar os limiares do Marco 1 com o contexto de processo, que deve eliminar parte dos falsos positivos.

**Pronto quando:** os alertas de beacon e de força bruta originados na própria máquina mostram o processo responsável.

## Marco 5: versão 1.0

**Objetivo:** compromisso de estabilidade para quem instala e para quem escreve módulos.

- [ ] Contrato, formato de configuração e saída da CLI declarados estáveis: mudança incompatível só em versão maior.
- [ ] Pacotes `.deb` e `.rpm`, além do tarball e do `get.sh`.
- [ ] Alertas também no journald em formato estruturado e estável, para quem já coleta logs da máquina.
- [ ] Exportação local de alertas (JSON e CSV) pela CLI.
- [ ] Páginas de manual (`man`) e autocompletar de shell para a CLI.
- [ ] Fuzzing contínuo dos decoders do sensor e do framing do IPC no CI.
- [ ] Revisão de segurança do Core e dos módulos antes da publicação.
- [ ] SBOM publicado em cada release, ao lado dos checksums e do atestado de proveniência.
- [ ] Documentação completa: instalação, operação, referência de regras e de configuração, criação de módulos.

**Pronto quando:** a v1.0 do Core e dos módulos sai com os itens acima e a política de compatibilidade publicada.

## Em avaliação

Ideias sem compromisso, que podem entrar num marco ou ser descartadas:

- Cobertura do sensor: DNS sobre TCP além da primeira mensagem do segmento, SNI em QUIC e identificação de DNS sobre HTTPS.
- Novas regras de rede a partir do que o Marco 1 revelar.
- Regras de rede para IPv6 com a mesma profundidade das de IPv4, caso o catálogo do Marco 1 mostre lacunas.
- Tradução da documentação para o inglês, para ampliar a base de contribuidores.

## Como acompanhar e participar

- Cada item deste roadmap vira uma issue quando começa a ser feito; o estado fica nos marcos do GitHub.
- Falso positivo ou falso negativo que você encontrou é a contribuição mais útil agora: abra uma issue com o alerta (`alerts -v`) e, se possível, um pcap anonimizado.
- Proposta de funcionalidade: abra uma issue descrevendo o problema que ela resolve antes da solução; ela é avaliada contra os princípios acima.
