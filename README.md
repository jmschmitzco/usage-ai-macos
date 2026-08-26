# Usage A.I — versão macOS

Monitor de uso do **Claude** e do **ChatGPT (Codex)** na barra de menus do Mac.
É a adaptação da versão Windows, com o mesmo visual: barras listradas animadas,
cores por faixa de uso e o ícone de cada marca acompanhando o preenchimento.

Prévia que aparece ao passar o mouse no ícone da barra de menus:

![prévia no hover](docs/previa.png)

Barras do painel de detalhes, com as cores por faixa de uso:

![barras de progresso](docs/barras.png)

## Requisitos

- macOS 11 (Big Sur) ou mais novo
- **Ferramentas de linha de comando do Xcode** (para compilar):
  ```bash
  xcode-select --install
  ```
- **Claude Code** e/ou **Codex** instalados e logados no Mac. O app lê os
  tokens de onde os próprios CLIs já os guardam:
  - Claude: `~/.claude/.credentials.json` ou o item **"Claude Code-credentials"** no Chaveiro
  - Codex: `~/.codex/auth.json`

## Instalação

Na pasta do projeto:

```bash
chmod +x criar-app.sh iniciar-com-o-sistema.sh
./criar-app.sh
open "Usage A.I.app"
```

O ícone aparece na barra de menus, ao lado do relógio.

Para abrir junto com o sistema:

```bash
./iniciar-com-o-sistema.sh on     # desligar: ./iniciar-com-o-sistema.sh off
```

## Como usar

| Ação | O que acontece |
|---|---|
| **Passar o mouse** no ícone | Prévia com uma barra por serviço, com o logo da marca na ponta do preenchimento |
| **Clique esquerdo** | Painel com todas as cotas (Sessão 5h, Semanal, por modelo), plano contratado e horários de reset |
| **Clique direito** | Menu: Ver detalhes, Atualizar agora, Sair |

As cores seguem o quanto já foi gasto: **até 30% verde**, **30% a 70% amarelo**,
**acima de 70% vermelho**. Os dados são atualizados a cada 3 minutos, sempre fora
da thread da interface — o app nunca trava enquanto consulta.

## Diferenças em relação à versão Windows

| Item | Windows | macOS |
|---|---|---|
| Linguagem | PowerShell + WinForms | Swift + AppKit |
| Onde aparece | Bandeja do sistema | Barra de menus |
| Token do Claude | Arquivo `.credentials.json` | Arquivo **ou Chaveiro** (o Claude Code no Mac costuma usar o Chaveiro) |
| Início automático | Chave `Run` do registro | `LaunchAgent` em `~/Library/LaunchAgents` |
| Fonte | Segoe UI / Segoe UI Black | Fonte do sistema (SF Pro), peso *black* |

## Segurança

- Os tokens são usados **somente** no cabeçalho `Authorization` das duas APIs
  oficiais: `api.anthropic.com` e `chatgpt.com`. Nenhum outro destino de rede.
- O app **não grava nada em disco**. A única exceção é o arquivo do LaunchAgent,
  criado apenas se você ativar o início automático (e removido ao desativar).
- Todo o código está em um único arquivo, `UsageAI.swift`, para facilitar a auditoria.

## Versão para Windows

A versão original, para a bandeja do Windows, está em
[usage-ai-windows](https://github.com/jmschmitzco/usage-ai-windows).

## Aviso

Esta versão foi escrita a partir da versão Windows, mas **ainda não foi compilada
nem testada em um Mac** — foi desenvolvida em uma máquina Windows. Se o `swiftc`
apontar algum erro de compilação, abra uma issue com a mensagem.

---

*Projeto independente, sem vínculo com Anthropic ou OpenAI. "Claude", "ChatGPT"
e seus logos pertencem às respectivas empresas e aparecem aqui apenas para
identificar cada serviço.*
