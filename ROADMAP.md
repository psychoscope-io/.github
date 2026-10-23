# Roadmap

Direção do Psychoscope. É um plano, não uma promessa de datas: as fases são ordenadas por dependência e cada uma termina com um critério verificável. As decisões de escopo são do mantenedor.

## Fase A: fechar o módulo de rede (v0.2.x e v0.3.0)

Objetivo: o `mod-net-sensor` e as regras de rede confiáveis o bastante para serem deixados rodando.

- [x] Reiniciar a máquina com o serviço habilitado e confirmar que ele sobe sozinho. Passou em 2026-10-20 (sensor conectado, sem reinícios); a corrida com a interface Wi-Fi que chega depois do `network.target` não se manifestou, mas é um teste só.
- [ ] Observar uma semana de tráfego real e catalogar os falsos positivos (já conhecido: `net.beacon` em conexões de keepalive de aplicativos legítimos).
- [x] `ignore_destinations` (IPs e faixas CIDR) na regra `net.beacon` (core v0.3.0).
- [ ] Ajustar limiares conforme os dados coletados na semana de tráfego real.
- [x] `psychoscope-cli alerts -v` mostra o contexto do alerta, ao vivo e no histórico (core v0.3.0).
- [x] `net.dns.nxdomain_burst` ignora zonas de DNS reverso (`ignore_suffixes`, padrão `in-addr.arpa` e `ip6.arpa`): o disparo 5 s após o boot eram consultas de DNS reverso de endereços 172.x, compatíveis com as redes Docker da máquina de teste (core v0.3.0).
- [x] TUI: sair e encerrar módulo por linha de comando (`:q`, `:stop`), e tela de detalhes do alerta com `Enter` (core v0.3.0).
- [x] `KillMode=mixed` na unit do systemd: o Core encerra o sensor de forma ordenada e o aviso `ENCERRAR nao confirmado` some (core v0.3.0; confirmado com unidades transitórias, falta ver no serviço instalado).
- [x] Sensor no `psychoscope-proto` v0.2.0 (sem release própria; entra na próxima do sensor).
- [x] Instruções de desinstalação em `docs/INSTALL.md`.
- [x] Proteção do branch `main`: já exige os checks de CI em cada repositório. Está com `enforce_admins` desligado, então o mantenedor ainda pode empurrar direto; ligar isso (para valer também para ele) é decisão do mantenedor.

Pronto quando: uma semana sem alertas falsos inexplicados e a instalação por tarball de release documentada e testada.

Limitações conhecidas do sensor que ficam fora desta fase: QUIC, DoH e DNS sobre TCP além da primeira mensagem do segmento.

## Configuração em tempo de execução (v0.4.0)

Ajustar limiares, exceções e regras desligadas sem editar JSON nem reiniciar o serviço. Desenho: os ajustes ficam num arquivo próprio no diretório de estado, por cima do arquivo do administrador (que nunca é tocado); só o root escreve, com auditoria no log; só um conjunto fechado de campos é editável (nunca `modules`, sockets ou caminhos).

- [x] Contrato aditivo no `psychoscope-proto` v0.3.0 (`PedidoLerConfig`, `PedidoAplicarConfig`, `ListaConfig`).
- [x] Motor reconfigurável ao vivo (`Engine.Reconfigure`: troca regras e janela, mantém os eventos retidos) e limites de retenção (`Persister.SetLimits`).
- [x] `internal/settings` (catálogo por reflexão, validação conjunta, gravação atômica `0600`, auditoria) e `overrides_path` no arquivo de configuração.
- [x] `psychoscope-cli config`, `config set` e `config reset`.
- [x] Tela de configurações na TUI (`:config`): rascunho, `Enter` e `:set` para editar, `:w` para gravar, `:q`/`:q!`/`:wq`, modo somente leitura.
- [x] Tecla `i` no detalhe do alerta acrescenta a exceção sugerida (beacon, força bruta, túnel DNS).
- [x] Comandos da TUI coerentes com o vim, em inglês (`:q`, `:q!`, `:quit`, `:stop`, `:config`, `:set`, `:w`, `:wq`); `:sair`, `:pause` e `:resume` removidos.
- [ ] Validar na máquina real: instalar a v0.4.0, aplicar a exceção do Telegram pela tela e ver o `net.beacon` sumir sem reiniciar; conferir `overrides.json` (`0600`, dono `psychoscope`) e a auditoria no `journalctl`.

## Fase B: preparar a plataforma para outros módulos (v0.5.0)

Hoje o contrato (`EventoTelemetria`) e o motor de detecção só conhecem eventos de rede (`EventoFluxoRede`). Um segundo módulo exige generalizá-los de forma aditiva.

- [ ] `EventoTelemetria.dado` com novas variantes (mudança só aditiva no `psychoscope-proto`).
- [ ] `Event` genérico no motor: cada regra declara o tipo de evento que consome.
- [ ] Métricas, alertas e TUI por módulo, sem suposição de que todo módulo é de rede.
- [ ] Guia e skill "como criar um módulo" (hoje só existe a do decoder de protocolo).
- [ ] Modelo de privilégios por módulo (capabilities e usuário), mantendo o Core sem privilégios.

Feito antes do módulo novo, e não junto, para a plataforma não ficar moldada ao primeiro caso.

## Fase C: monitoramento de processos do sistema

Escopo decidido: processos do sistema (execuções suspeitas, binários removidos do disco, comandos vindos de `/tmp`). Começa lendo `/proc`, sem privilégio. Monitoramento de recursos de hardware (CPU, memória, temperatura, disco) e coleta em tempo real por eBPF ficam para uma etapa posterior.

- [ ] Novo módulo (nome a definir) emitindo eventos de processo para o Core.
- [ ] Primeiras regras, cada uma com casos de falso positivo.
- [ ] Documentação de instalação e privilégios do módulo.

## Fase D: correlação entre módulos

Ligar o processo ao tráfego de rede, para que um alerta diga qual programa originou a conexão (por exemplo, o processo que mantém um beacon). É o principal ganho de ter mais de um módulo.

## Depois

- Resposta (o "R" do MODR): hoje o sistema só detecta. Ações como bloquear um IP exigem desenho próprio de segurança e confirmação.
- Gateway web.
- Módulos de inteligência de ameaças e de regras YARA.
