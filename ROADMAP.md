# Roadmap

Direção do Psychoscope. É um plano, não uma promessa de datas: as fases são ordenadas por dependência e cada uma termina com um critério verificável. As decisões de escopo são do mantenedor.

## Fase A: fechar o módulo de rede (v0.2.x)

Objetivo: o `mod-net-sensor` e as regras de rede confiáveis o bastante para serem deixados rodando.

- [ ] Reiniciar a máquina com o serviço habilitado e confirmar que ele sobe sozinho (inclusive com a interface Wi-Fi que chega depois do `network.target`).
- [ ] Observar uma semana de tráfego real e catalogar os falsos positivos (já conhecido: `net.beacon` em conexões de keepalive de aplicativos legítimos).
- [ ] `ignore_destinations` (IPs e faixas CIDR) na regra `net.beacon`, mais ajuste de limiares conforme os dados coletados.
- [ ] `KillMode=mixed` na unit do systemd, para o Core encerrar o sensor de forma ordenada (hoje o log mostra `ENCERRAR nao confirmado`, sem efeito prático).
- [ ] Atualizar o sensor para o `psychoscope-proto` v0.2.0 (hoje usa v0.1.0).
- [ ] Higiene: instruções de desinstalação em `docs/INSTALL.md`; proteção do branch `main` nos repositórios.

Pronto quando: uma semana sem alertas falsos inexplicados e a instalação por tarball de release documentada e testada.

Limitações conhecidas do sensor que ficam fora desta fase: QUIC, DoH e DNS sobre TCP além da primeira mensagem do segmento.

## Fase B: preparar a plataforma para outros módulos (v0.3.0)

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
