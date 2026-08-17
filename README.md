# Debian 13 Trixie - Script de Pós-Instalação Automática

Este repositório contém um script Bash projetado para automatizar as tarefas pós-instalação de um sistema Debian 13 "Trixie" limpo (netinst), combinando praticidade com as melhores recomendações de produtividade do blog do Remontti.

## Como Executar

Você pode rodar o script diretamente no terminal do seu Debian recém-instalado (como usuário `root`). 

Escolha um dos métodos rápidos abaixo:

### Método 1: Usando `curl`
```bash
apt update && apt install -y curl && curl -sSL https://raw.githubusercontent.com/seu-usuario/seu-repositorio/main/setup.sh | bash
```

### Método 2: Usando `wget`
```bash
apt update && apt install -y wget && wget -O- https://raw.githubusercontent.com/seu-usuario/seu-repositorio/main/setup.sh | bash
```

### Método 3: Copiando manualmente
Se preferir copiar o script para a máquina antes de executar:
```bash
chmod +x setup.sh
./setup.sh
```

---

## O que o script faz?

1. **Configuração de Relógio (Timezone & NTP)**:
   - Permite definir o fuso horário (com timeout de 10s para não travar execuções automatizadas, padrão: `America/Sao_Paulo`).
   - Instala e configura o `systemd-timesyncd` para garantir que o relógio permaneça sincronizado via NTP.

2. **Repositórios do Debian 13 Trixie**:
   - Ajusta automaticamente o arquivo `/etc/apt/sources.list` habilitando as áreas `contrib`, `non-free` e `non-free-firmware` necessárias para firmwares proprietários e pacotes adicionais.

3. **Atualização & Utilitários de Sistema**:
   - Realiza `apt update && apt dist-upgrade`.
   - Instala: `vim`, `bash-completion`, `fzf` (buscador fuzzy), `grc` (colorizador de comandos), `curl`, `wget`, `unzip`, `man-db`, `htop`, `tree`, `bmon` (monitor de banda), `hdparm`, `mtr-tiny`, `whois`, `dnsutils`, `net-tools` e `git`.

4. **Tuning do Terminal (Bash)**:
   - Ativa autocomplete avançado de comandos globalmente em `/etc/bash.bashrc`.
   - Adiciona aliases úteis com cores (`ls`, `ll`, `l`, `grep`, `ip`, `diff`).
   - Aplica colorização automática nas saídas dos comandos `tail`, `ping`, `ps`, `netstat` e `df` usando `grc`.
   - Configura busca rápida no histórico de comandos com o atalho `CTRL+R` (`fzf`).
   - Ajusta o visual do prompt (`PS1` colorido, diferenciando root em vermelho de usuários comuns em verde).
   - Aplica estas configurações de forma que novos usuários criados no sistema (`/etc/skel/.bashrc`) e o usuário comum que chamou o script também as recebam.

5. **Tuning do Editor VIM**:
   - Ativa realce de sintaxe (`syntax on`) e fundo escuro.
   - Ajusta tabulações para 4 espaços e ativa indentação inteligente globalmente e em `/etc/skel/.vimrc`.
