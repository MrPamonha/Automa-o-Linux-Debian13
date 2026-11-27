# Debian 13 Trixie - Pós-Instalação Automática

Dois scripts para rodar em **toda máquina Debian 13 "Trixie" nova** (VM ou container LXC, a partir do netinst), nesta ordem:

| # | Script | O que faz |
|---|---|---|
| 1 | `setup.sh` | Relógio/NTP, repositórios, atualização, pacotes essenciais, Bash e Vim (recomendações do blog do Remontti) |
| 2 | `ssh-hardening.sh` | Usuário nominal com chave, SSH só por chave, root bloqueado no SSH e acessível via `sudo -i` |

## Uso rápido (como `root`)

```bash
apt update && apt install -y curl

# 1) Pós-instalação
curl -fsSL https://raw.githubusercontent.com/MrPamonha/Automa-o-Linux-Debian13/main/setup.sh | bash

# 2) SSH (pergunta usuário, senha do sudo e chave)
bash <(curl -fsSL https://raw.githubusercontent.com/MrPamonha/Automa-o-Linux-Debian13/main/ssh-hardening.sh)
```

> Rode o `ssh-hardening.sh` pelo **console** ou por uma sessão SSH que você **não vai fechar** até testar o acesso novo.

Também dá para copiar os arquivos para a máquina e rodar `bash setup.sh` / `bash ssh-hardening.sh`.

---

## 1. `setup.sh` — o que faz

1. **Relógio (fuso e NTP)**
   - Pergunta o fuso por 10 s (padrão `America/Sao_Paulo`). Lê do terminal, então funciona também via `curl | bash`; sem terminal, usa o padrão.
   - Instala e ativa o `systemd-timesyncd`.
2. **Repositórios**
   - Habilita `contrib`, `non-free` e `non-free-firmware` tanto no formato antigo (`/etc/apt/sources.list`) quanto no deb822 (`/etc/apt/sources.list.d/debian.sources`).
   - Só mexe nas linhas do `debian.org` (repositórios de terceiros ficam intactos) e pode ser rodado várias vezes sem duplicar nada.
3. **Atualização e utilitários**
   - `apt update && apt dist-upgrade`.
   - Instala: `vim`, `bash-completion`, `fzf`, `grc`, `curl`, `wget`, `unzip`, `man-db`, `htop`, `tree`, `bmon`, `hdparm`, `mtr-tiny`, `whois`, `dnsutils`, `net-tools`, `git`, `sudo`.
4. **Terminal (Bash)**
   - Autocomplete global, aliases coloridos (`ls`, `ll`, `l`, `grep`, `ip`, `diff`), `grc` em `tail`/`ping`/`ps`/`netstat`/`df`, `CTRL+R` com `fzf`.
   - Prompt colorido: root em vermelho, usuários em verde.
   - Vale para root, novos usuários (`/etc/skel`) e o usuário que chamou o script (via `sudo` ou `su -`).
5. **Vim**: sintaxe, fundo escuro, tab de 4 espaços, indentação inteligente, números de linha.

---

## 2. `ssh-hardening.sh` — o que faz

| Etapa | Detalhe |
|---|---|
| Pacotes | Garante `openssh-server` e `sudo` |
| Usuário | Cria o usuário nominal (se não existir), coloca no grupo `sudo` e pede a senha dele — usada **só no `sudo -i`**, nunca no SSH |
| Chaves | Aceita chave colada, arquivo ou URL (ex.: `https://github.com/USUARIO.keys`); valida cada uma com `ssh-keygen` e não duplica |
| sshd | Grava `/etc/ssh/sshd_config.d/00-hardening.conf` (prioridade sobre os demais) e valida com `sshd -t` antes de aplicar |
| Serviço | Desativa o `ssh.socket` e usa `ssh.service` com **restart** (o `reload` já derrubou o sshd em container) |
| Teste | Pede para você testar numa sessão nova e digitar `ok` em até 180 s — **sem confirmação, desfaz sozinho** |

**Configuração aplicada:** `PermitRootLogin no`, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `AuthenticationMethods publickey`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`.

### Proteções contra se trancar fora
- Sem nenhuma chave válida no `authorized_keys`, **não altera nada** no SSH.
- Se o `sshd -t` reprovar, nada é aplicado.
- Backup do `sshd_config` e do `sshd_config.d` em `/root/ssh-hardening-backup-<data>/`.
- Rollback automático se o serviço não subir ou se o acesso não for confirmado.
- Sessões já abertas continuam vivas durante o restart.

### Opções

```text
-u, --user NOME        Usuário nominal (criado se não existir)
-k, --key "CHAVE"      Chave pública (pode repetir)
-f, --key-file ARQ     Arquivo com chave(s) pública(s)
-U, --key-url URL      URL com chave(s) pública(s)
-p, --port PORTA       Porta do SSH (padrão: mantém a atual)
-a, --allow-users      Libera SSH SOMENTE para este usuário (AllowUsers)
-y, --yes              Sem perguntas e sem teste de confirmação (automação)
-h, --help             Ajuda
```

Exemplo sem perguntas sobre a chave:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MrPamonha/Automa-o-Linux-Debian13/main/ssh-hardening.sh) \
  --user ricardo --key "ssh-ed25519 AAAA... ricardo@termius"
```

### Desfazer manualmente

```bash
rm /etc/ssh/sshd_config.d/00-hardening.conf && systemctl restart ssh
```

Em último caso, acesse pelo console do Proxmox (`qm terminal <vmid>` / `pct enter <ctid>`).
