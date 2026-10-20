# Psychoscope

Psychoscope é um **MODR** (*Modular Orchestrated Detection and Response*): uma plataforma modular de detecção e resposta em que um orquestrador central (o Core) supervisiona módulos de coleta, recebe a telemetria deles por IPC local e aplica regras de detecção sobre os eventos.

Todo o código é licenciado sob Apache-2.0.

## Repositórios

| Repositório | Linguagem | Função |
|---|---|---|
| [psychoscope-proto](https://github.com/psychoscope-io/psychoscope-proto) | Protocol Buffers | Contrato canônico: IPC entre o Core e os módulos (`ipc.proto`) e canal de controle da CLI (`control.proto`). Versionado por tags Git. |
| [psychoscope-core](https://github.com/psychoscope-io/psychoscope-core) | Go | Orquestrador: supervisor de módulos, motor de detecção com regras, canal de controle, CLI e TUI. |
| [mod-net-sensor](https://github.com/psychoscope-io/mod-net-sensor) | Rust | Módulo sensor de rede: captura de pacotes (libpcap ou arquivo pcap), decodificação de DNS, TCP e TLS e envio da telemetria ao Core. |

## Como as peças se encaixam

```
mod-net-sensor  --(IPC: socket Unix, protobuf)-->  psychoscope-core  <--(ctl.sock)--  psychoscope-cli / TUI
        \                                              /
         '--------- contrato: psychoscope-proto ------'
```

O Core não precisa de privilégios de captura: só os módulos que precisam deles (como o sensor, com `CAP_NET_RAW`) os recebem.

## Testar em minutos

O `scripts/demo.sh` do [mod-net-sensor](https://github.com/psychoscope-io/mod-net-sensor#testar-em-minutos-demo) compila o Core e o sensor, reproduz um pcap malicioso e abre a TUI, sem privilégios e sem tocar na sua rede.

## Instalar

Binários (linux amd64/arm64) com checksums e atestado de proveniência ficam nas *Releases* de `psychoscope-core` e `mod-net-sensor`. O guia de instalação como serviço systemd, com privilégios mínimos, está em [docs/INSTALL.md](https://github.com/psychoscope-io/psychoscope-core/blob/main/docs/INSTALL.md).

## Participe

- Para contribuir, leia o [guia de contribuição](https://github.com/psychoscope-io/.github/blob/main/CONTRIBUTING.md).
- Para relatar uma vulnerabilidade, siga a [política de segurança](https://github.com/psychoscope-io/.github/blob/main/SECURITY.md) e use o reporte privado do GitHub, nunca uma issue pública.
- A participação na comunidade segue o [código de conduta](https://github.com/psychoscope-io/.github/blob/main/CODE_OF_CONDUCT.md).
