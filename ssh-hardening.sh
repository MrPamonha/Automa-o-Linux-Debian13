#!/bin/bash
# ==============================================================================
# SSH Hardening para Debian 13 Trixie
# Usuário nominal + acesso só por chave + root só via "sudo -i"
# Repositório: github.com/MrPamonha/Automa-o-Linux-Debian13
# ==============================================================================
#
# Uso interativo (pergunta tudo):
#   bash <(curl -fsSL https://raw.githubusercontent.com/MrPamonha/Automa-o-Linux-Debian13/main/ssh-hardening.sh)
#
# Uso direto:
#   ./ssh-hardening.sh --user ricardo --key-url https://github.com/MrPamonha.keys
#   ./ssh-hardening.sh --user ricardo --key "ssh-ed25519 AAAA... ricardo@termius"
#
# Opções:
#   -u, --user NOME        Usuário nominal (criado se não existir)
#   -k, --key "CHAVE"      Chave pública (pode repetir)
#   -f, --key-file ARQ     Arquivo com chave(s) pública(s)
#   -U, --key-url URL      URL com chave(s) pública(s) (ex.: https://github.com/USUARIO.keys)
#   -p, --port PORTA       Porta do SSH (padrão: mantém a atual, normalmente 22)
#   -a, --allow-users      Libera SSH SOMENTE para este usuário (AllowUsers)
#   -y, --yes              Sem perguntas e sem teste de confirmação (automação)
#   -h, --help             Mostra esta ajuda
# ==============================================================================

set -o pipefail

# ------------------------------------------------------------------ visual ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

STEP=0; TOTAL_STEPS=6
step()        { STEP=$((STEP+1)); echo -e "\n${PURPLE}[${STEP}/${TOTAL_STEPS}]${NC} ${BOLD}$1${NC}"; }
log_info()    { echo -e "  ${BLUE}•${NC} $1"; }
log_success() { echo -e "  ${GREEN}✔${NC} $1"; }
log_warning() { echo -e "  ${YELLOW}!${NC} $1"; }
log_error()   { echo -e "  ${RED}✘${NC} $1" >&2; }
die()         { log_error "$1"; exit 1; }

banner() {
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${CYAN}        DEBIAN 13 TRIXIE - SSH HARDENING              ${NC}"
    echo -e "${PURPLE}======================================================${NC}"
    echo -e "${BLUE}Usuário nominal, acesso só por chave e root via sudo.${NC}"
    echo -e "${PURPLE}======================================================${NC}"
}

usage() {
    cat <<'EOF'
Uso: ssh-hardening.sh [opções]
  -u, --user NOME        Usuário nominal (criado se não existir)
  -k, --key "CHAVE"      Chave pública (pode repetir)
  -f, --key-file ARQ     Arquivo com chave(s) pública(s)
  -U, --key-url URL      URL com chave(s) pública(s) (ex.: https://github.com/USUARIO.keys)
  -p, --port PORTA       Porta do SSH (padrão: mantém a atual)
  -a, --allow-users      Libera SSH SOMENTE para este usuário (AllowUsers)
  -y, --yes              Sem perguntas e sem teste de confirmação (automação)
  -h, --help             Mostra esta ajuda
EOF
    exit 0
}

# Leitura sempre do terminal, para funcionar também via "curl | bash"
HAS_TTY=0; (exec </dev/tty) 2>/dev/null && HAS_TTY=1
ask() {        # ask "Pergunta" "padrão" -> REPLY
    local q="$1" def="$2"; REPLY=""
    [ "$HAS_TTY" = 1 ] || { REPLY="$def"; return; }
    if [ -n "$def" ]; then
        read -r -p "$(echo -e "  ${CYAN}?${NC} $q ${DIM}[$def]${NC}: ")" REPLY </dev/tty
    else
        read -r -p "$(echo -e "  ${CYAN}?${NC} $q: ")" REPLY </dev/tty
    fi
    REPLY="${REPLY:-$def}"
}

# --------------------------------------------------------------- argumentos ---
TARGET_USER=""; KEYS=(); KEY_FILES=(); KEY_URLS=(); SSH_PORT=""; ALLOW_ONLY=0; ASSUME_YES=0
while [ $# -gt 0 ]; do
    case "$1" in
        -u|--user)        TARGET_USER="$2"; shift 2 ;;
        -k|--key)         KEYS+=("$2"); shift 2 ;;
        -f|--key-file)    KEY_FILES+=("$2"); shift 2 ;;
        -U|--key-url)     KEY_URLS+=("$2"); shift 2 ;;
        -p|--port)        SSH_PORT="$2"; shift 2 ;;
        -a|--allow-users) ALLOW_ONLY=1; shift ;;
        -y|--yes)         ASSUME_YES=1; shift ;;
        -h|--help)        usage ;;
        *) die "Opção desconhecida: $1 (use --help)" ;;
    esac
done

banner
[ "$EUID" -eq 0 ] || die "Execute como root (ou via sudo)."
[ -r /etc/debian_version ] || log_warning "Sistema não parece ser Debian; seguindo mesmo assim."

DROPIN=/etc/ssh/sshd_config.d/00-hardening.conf
BACKUP_DIR="/root/ssh-hardening-backup-$(date +%Y%m%d-%H%M%S)"
TMP_KEYS="$(mktemp)"; trap 'rm -f "$TMP_KEYS" "$SSHD_ERR"' EXIT

# ---------------------------------------------------------------- 1. pacotes --
step "Pacotes (openssh-server, sudo)"
missing=()
for p in openssh-server sudo; do dpkg -s "$p" &>/dev/null || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then
    log_info "Instalando: ${missing[*]}"
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" >/dev/null \
        || die "Falha ao instalar ${missing[*]}."
fi
log_success "openssh-server e sudo presentes."

# ---------------------------------------------------------------- 2. usuário --
step "Usuário nominal"
if [ -z "$TARGET_USER" ]; then
    default_user="${SUDO_USER:-$(logname 2>/dev/null)}"; [ "$default_user" = root ] && default_user=""
    [ "$HAS_TTY" = 1 ] || [ -n "$default_user" ] || die "Informe o usuário com --user."
    ask "Nome do usuário" "$default_user"; TARGET_USER="$REPLY"
fi
[[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Nome de usuário inválido: '$TARGET_USER'."
[ "$TARGET_USER" != root ] || die "O usuário nominal não pode ser o root."

if id "$TARGET_USER" &>/dev/null; then
    log_success "Usuário ${BOLD}$TARGET_USER${NC} já existe."
else
    useradd -m -s /bin/bash "$TARGET_USER" || die "Falha ao criar $TARGET_USER."
    log_success "Usuário ${BOLD}$TARGET_USER${NC} criado."
fi
usermod -aG sudo "$TARGET_USER" && log_success "$TARGET_USER no grupo sudo."
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# O sudo pede a senha do usuário: garantir que ela exista
pw_state="$(passwd -S "$TARGET_USER" 2>/dev/null | awk '{print $2}')"
if [ "$pw_state" = "P" ]; then
    log_success "Usuário já tem senha (usada só no sudo, não no SSH)."
elif [ "$HAS_TTY" = 1 ] && [ "$ASSUME_YES" != 1 ]; then
    log_info "Defina a senha de $TARGET_USER (usada só no ${BOLD}sudo -i${NC}, nunca no SSH):"
    tries=0
    until passwd "$TARGET_USER" </dev/tty; do
        tries=$((tries+1))
        [ "$tries" -ge 3 ] && { log_warning "Senha não definida: rode 'passwd $TARGET_USER' depois (o sudo depende dela)."; break; }
        log_warning "Tente de novo ($tries/3)."
    done
else
    log_warning "$TARGET_USER sem senha: o sudo não vai funcionar até rodar 'passwd $TARGET_USER'."
fi

# ----------------------------------------------------------------- 3. chaves --
step "Chave(s) pública(s)"
for k in "${KEYS[@]}"; do echo "$k" >> "$TMP_KEYS"; done
for f in "${KEY_FILES[@]}"; do
    [ -r "$f" ] || die "Arquivo de chave não encontrado: $f"; cat "$f" >> "$TMP_KEYS"; echo >> "$TMP_KEYS"
done
for u in "${KEY_URLS[@]}"; do
    log_info "Baixando chaves de $u"
    if command -v curl &>/dev/null; then curl -fsSL "$u" >> "$TMP_KEYS"
    else wget -qO- "$u" >> "$TMP_KEYS"; fi || die "Falha ao baixar $u"
    echo >> "$TMP_KEYS"
done
if ! grep -q '[^[:space:]]' "$TMP_KEYS" && [ -s "$USER_HOME/.ssh/authorized_keys" ]; then
    log_info "Nenhuma chave nova informada; usando as que já estão em authorized_keys."
elif ! grep -q '[^[:space:]]' "$TMP_KEYS"; then
    [ "$HAS_TTY" = 1 ] || die "Informe uma chave com --key, --key-file ou --key-url."
    log_info "Cole a chave pública (linha que começa com ssh-ed25519 / ssh-rsa / ecdsa-...):"
    while :; do
        ask "Chave"; [ -n "$REPLY" ] || continue
        echo "$REPLY" > "$TMP_KEYS"
        ssh-keygen -l -f "$TMP_KEYS" &>/dev/null && break
        log_warning "Isso não parece uma chave pública válida. Tente de novo."
    done
fi

install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$USER_HOME/.ssh"
AK="$USER_HOME/.ssh/authorized_keys"; touch "$AK"
added=0; invalid=0
while IFS= read -r line; do
    line="$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$line" ] || [[ "$line" == \#* ]] && continue
    if ! ssh-keygen -l -f /dev/stdin <<<"$line" &>/dev/null; then invalid=$((invalid+1)); continue; fi
    keybody="$(awk '{print $2}' <<<"$line")"
    if grep -qF "$keybody" "$AK"; then
        log_info "Já presente: $(ssh-keygen -l -f /dev/stdin <<<"$line" | awk '{print $2, $NF}')"
    else
        echo "$line" >> "$AK"; added=$((added+1))
        log_success "Adicionada: $(ssh-keygen -l -f /dev/stdin <<<"$line" | awk '{print $2, $NF}')"
    fi
done < "$TMP_KEYS"
chown "$TARGET_USER:$TARGET_USER" "$AK"; chmod 600 "$AK"
[ "$invalid" -gt 0 ] && log_warning "$invalid linha(s) inválida(s) ignorada(s)."

valid_total="$(ssh-keygen -l -f "$AK" 2>/dev/null | wc -l)"
[ "$valid_total" -ge 1 ] || die "Nenhuma chave válida em $AK. Nada foi alterado no SSH (proteção contra trancar o acesso)."
log_success "$valid_total chave(s) válida(s) em $AK."

# ----------------------------------------------------------- 4. sshd config ---
step "Configuração do sshd"
mkdir -p "$BACKUP_DIR" /etc/ssh/sshd_config.d
cp -a /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null
cp -a /etc/ssh/sshd_config.d "$BACKUP_DIR/" 2>/dev/null
log_info "Backup em ${DIM}$BACKUP_DIR${NC}"

grep -qE '^\s*Include\s+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config \
    || die "O sshd_config não inclui /etc/ssh/sshd_config.d/*.conf; ajuste manualmente."

{
    echo "# Gerado por ssh-hardening.sh em $(date '+%F %T') - não edite à mão"
    echo "# No sshd vale o PRIMEIRO valor lido: o prefixo 00- garante prioridade."
    [ -n "$SSH_PORT" ] && echo "Port $SSH_PORT"
    cat <<'EOF'
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    [ "$ALLOW_ONLY" = 1 ] && echo "AllowUsers $TARGET_USER"
} > "$DROPIN"
chmod 644 "$DROPIN"

rollback() {
    log_warning "Desfazendo alterações do sshd..."
    rm -f "$DROPIN"
    cp -a "$BACKUP_DIR/sshd_config" /etc/ssh/sshd_config 2>/dev/null
    sshd -t && systemctl restart ssh
    log_success "Configuração anterior restaurada (usuário e chaves foram mantidos)."
}

SSHD_ERR="$(mktemp)"
if ! sshd -t 2>"$SSHD_ERR"; then
    log_error "sshd -t reprovou a configuração:"; sed 's/^/      /' "$SSHD_ERR" >&2
    rm -f "$DROPIN"; die "Nada foi aplicado."
fi
log_success "Sintaxe validada (sshd -t)."

log_info "Configuração efetiva:"
sshd -T 2>/dev/null | grep -E '^(port|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|authenticationmethods|maxauthtries|allowusers) ' \
    | while IFS= read -r l; do echo -e "      ${DIM}${l}${NC}"; done

# ----------------------------------------------------------- 5. serviço -------
step "Serviço SSH"
# ssh.socket ignora "Port" do sshd_config e o reload (SIGHUP) já derrubou o sshd
# em container: usar ssh.service com restart.
if systemctl is-enabled ssh.socket &>/dev/null || systemctl is-active ssh.socket &>/dev/null; then
    systemctl disable --now ssh.socket &>/dev/null && log_success "ssh.socket desativado."
fi
systemctl enable ssh &>/dev/null
systemctl restart ssh || { rollback; die "Falha ao reiniciar o ssh."; }
sleep 1
systemctl is-active --quiet ssh || { rollback; die "O ssh não ficou ativo."; }
log_success "ssh.service ativo e habilitado no boot (sessões abertas continuam)."

# ----------------------------------------------------------- 6. teste ---------
step "Teste de acesso"
PORT_NOW="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
IP_NOW="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ "$ASSUME_YES" = 1 ] || [ "$HAS_TTY" != 1 ]; then
    log_warning "Modo automático: teste o acesso numa sessão nova antes de fechar esta."
else
    echo -e "  ${YELLOW}NÃO feche esta sessão.${NC} Em outra janela, teste:"
    echo -e "      ${BOLD}ssh -p ${PORT_NOW:-22} ${TARGET_USER}@${IP_NOW:-<ip>}${NC}   e depois   ${BOLD}sudo -i${NC}"
    TIMEOUT="${SSH_HARDENING_TIMEOUT:-180}"
    if read -r -t "$TIMEOUT" -p "$(echo -e "  ${CYAN}?${NC} Funcionou? Digite ${BOLD}ok${NC} em até ${TIMEOUT}s (senão eu desfaço): ")" ans </dev/tty \
        && [ "${ans,,}" = "ok" ]; then
        log_success "Acesso confirmado."
    else
        echo; rollback; die "Sem confirmação: o SSH voltou como estava. Corrija e rode de novo."
    fi
fi

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    SSH BLINDADO COM SUCESSO!                         ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "  Usuário ......: ${BOLD}$TARGET_USER${NC} (grupo sudo)"
echo -e "  Acesso .......: ${BOLD}só chave${NC}, porta ${BOLD}${PORT_NOW:-22}${NC}, root bloqueado no SSH"
echo -e "  Virar root ...: ${BOLD}sudo -i${NC}"
echo -e "  Emergência ...: console do Proxmox (qm terminal / pct enter)"
echo -e "  Desfazer .....: ${DIM}rm $DROPIN && systemctl restart ssh${NC}"
echo -e "${GREEN}======================================================${NC}"
