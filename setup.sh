#!/bin/bash
# ==============================================================================
# Script de Pós-Instalação para Debian 13 Trixie
# Autor: Adaptado/Melhorado com base nas recomendações do blog.remontti.com.br
# ==============================================================================

# Cores para saída organizada
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem Cor

# Banner de Inicialização
echo -e "${PURPLE}======================================================${NC}"
echo -e "${CYAN}    DEBIAN 13 TRIXIE - POST-INSTALL AUTOMATION        ${NC}"
echo -e "${PURPLE}======================================================${NC}"
echo -e "${BLUE}Este script irá configurar relógio, repositórios,${NC}"
echo -e "${BLUE}instalar pacotes essenciais e otimizar Bash/Vim.${NC}"
echo -e "${PURPLE}======================================================${NC}"

# Verificar privilégios de root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Este script precisa ser executado como root (ou via sudo).${NC}"
    exit 1
fi

# Função para log de progresso
log_info() {
    echo -e "\n${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# 1. Ajustar fuso horário e relógio (NTP)
configure_datetime() {
    log_info "Configurando fuso horário e relógio..."
    DEFAULT_TZ="America/Sao_Paulo"
    
    # Prompt com timeout de 10 segundos
    echo -e "${CYAN}Defina o fuso horário (ex: America/Sao_Paulo, America/Manaus, etc.)${NC}"
    read -t 10 -p "Pressione Enter para usar o padrão [$DEFAULT_TZ]: " USER_TZ
    USER_TZ=${USER_TZ:-$DEFAULT_TZ}
    
    if timedatectl set-timezone "$USER_TZ" 2>/dev/null; then
        log_success "Fuso horário definido para: $USER_TZ"
    else
        log_warning "Fuso horário '$USER_TZ' inválido. Definindo padrão: $DEFAULT_TZ"
        timedatectl set-timezone "$DEFAULT_TZ"
    fi
    
    # Instala o timesyncd se necessário e ativa sincronização
    apt-get update -y &>/dev/null
    apt-get install -y systemd-timesyncd &>/dev/null
    timedatectl set-ntp true
    log_success "Sincronização automática do relógio (NTP) ativada."
    echo -e "Status atual do relógio:"
    timedatectl status | grep -E "Local time|Universal time|Time zone|System clock synchronized|NTP service"
}

# 2. Configurar fontes do apt (/etc/apt/sources.list)
configure_sources() {
    log_info "Configurando repositórios (contrib, non-free, non-free-firmware)..."
    
    # Backup de segurança
    if [ ! -f /etc/apt/sources.list.bak ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
        log_info "Backup do sources.list criado em /etc/apt/sources.list.bak"
    fi
    
    # Garantir contrib, non-free e non-free-firmware para o Debian 13 Trixie
    # Verifica se já contém "contrib" para evitar duplicar
    if ! grep -q "contrib" /etc/apt/sources.list; then
        sed -i 's/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list
        log_success "Repositórios contrib, non-free e non-free-firmware adicionados."
    else
        log_success "Repositórios já parecem estar configurados."
    fi
}

# 3. Atualizar o sistema e instalar pacotes essenciais
install_packages() {
    log_info "Atualizando a lista de pacotes e realizando upgrade do sistema..."
    apt-get update && apt-get dist-upgrade -y
    
    log_info "Instalando ferramentas essenciais (Vim, FZF, GRC, Htop, Net-tools)..."
    apt-get install -y \
        vim \
        bash-completion \
        fzf \
        grc \
        curl \
        wget \
        unzip \
        man-db \
        htop \
        tree \
        bmon \
        hdparm \
        mtr-tiny \
        whois \
        dnsutils \
        net-tools \
        git \
        sudo \
        apt-transport-https \
        ca-certificates
        
    log_success "Pacotes essenciais instalados com sucesso!"
}

# 4. Configurações de Terminal (Bash, Aliases, Prompt Colorido)
configure_bash() {
    log_info "Configurando customizações do terminal (Bash)..."
    
    # 4.1 Autocompletar avançado no /etc/bash.bashrc (para todos os usuários)
    if ! grep -q "# Autocompletar extra" /etc/bash.bashrc; then
        cat << 'EOF' >> /etc/bash.bashrc

# Autocompletar extra
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
        log_success "Bash completion global ativado."
    fi

    # 4.2 Aliases e Cores no /root/.bashrc e /etc/skel/.bashrc (para novos usuários)
    setup_user_bashrc() {
        local target_rc="$1"
        local is_root="$2"
        
        # Criar backup se existir
        [ -f "$target_rc" ] && cp "$target_rc" "${target_rc}.bak"
        
        # Limpar aliases antigos que vamos redefinir para evitar duplicações
        sed -i '/# Configurações Customizadas Remontti/,$d' "$target_rc" 2>/dev/null
        
        # Bloco de customizações
        cat << 'EOF' >> "$target_rc"

# Configurações Customizadas Remontti
export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lha'

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias ip='ip -c'
alias diff='diff --color=auto'

# Colorização de saídas com GRC
if [ -x /usr/bin/grc ]; then
    alias tail='grc tail'
    alias ping='grc ping'
    alias ps='grc ps'
    alias netstat='grc netstat'
    alias df='grc df'
fi

# Atalho FZF para busca no histórico (CTRL+R)
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    source /usr/share/doc/fzf/examples/key-bindings.bash
fi
EOF

        # Definir Prompt PS1 Colorido dinâmico
        if [ "$is_root" = "true" ]; then
            # Root: Vermelho marcante
            echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\\$\[\033[00m\] '" >> "$target_rc"
        else
            # Usuário comum: Verde
            echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;32m\]\\$\[\033[00m\] '" >> "$target_rc"
        fi
    }

    # Aplicar para root
    setup_user_bashrc "/root/.bashrc" "true"
    # Aplicar para novos usuários (/etc/skel/.bashrc)
    setup_user_bashrc "/etc/skel/.bashrc" "false"
    
    # Aplicar para o usuário comum existente que chamou o script se houver (ex: logado via SSH)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        setup_user_bashrc "/home/$SUDO_USER/.bashrc" "false"
        chown "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.bashrc"
        [ -f "/home/$SUDO_USER/.bashrc.bak" ] && chown "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.bashrc.bak"
    fi
    
    log_success "Customizações de terminal aplicadas para root e usuários normais."
}

# 5. Otimizações de configuração do VIM
configure_vim() {
    log_info "Configurando VIM..."
    
    # Habilitar sintaxe e fundo escuro globalmente no /etc/vim/vimrc
    sed -i 's/"syntax on/syntax on/g' /etc/vim/vimrc 2>/dev/null || sed -i 's/"syntax/syntax/g' /etc/vim/vimrc
    sed -i 's/"set background=dark/set background=dark/g' /etc/vim/vimrc 2>/dev/null || sed -i 's/"set background/set background/g' /etc/vim/vimrc
    
    # Configurações do .vimrc
    write_vimrc() {
        local vimrc_path="$1"
        cat << 'EOF' > "$vimrc_path"
" Configurações Customizadas do VIM
set showmatch     " Mostrar colchetes/parênteses correspondentes
set ts=4          " Tamanho do Tab (4 espaços)
set sts=4         " Soft tab stop
set sw=4          " Shift width para autoindentação
set autoindent    " Auto-indentação ativa
set smartindent   " Indentação inteligente
set smarttab      " Tab inteligente
set expandtab     " Transforma tab em espaços
set number        " Mostra número de linhas
EOF
    }

    # Criar .vimrc para root
    write_vimrc "/root/.vimrc"
    
    # Criar .vimrc no /etc/skel para futuros usuários
    write_vimrc "/etc/skel/.vimrc"
    
    # Criar .vimrc para o usuário comum atual (se existir)
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        write_vimrc "/home/$SUDO_USER/.vimrc"
        chown "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.vimrc"
    fi
    
    log_success "Vim configurado com sucesso."
}

# Execução ordenada das funções
configure_datetime
configure_sources
install_packages
configure_bash
configure_vim

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!                ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}Para aplicar as alterações no terminal atual, execute:${NC}"
echo -e "${CYAN}source ~/.bashrc${NC}"
echo -e "${YELLOW}ou faça login novamente com:${NC}"
echo -e "${CYAN}su -${NC}"
echo -e "${GREEN}======================================================${NC}"
