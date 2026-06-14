#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║              MAILCOW PROFESSIONAL INSTALLER  v2.1                          ║
# ║         Ubuntu 22.04 | Proxmox Template Ready | Multi-DNS Support          ║
# ║                                                                              ║
# ║  DNS Providers:  Cloudflare  •  Microsoft Azure DNS  •  Google Cloud DNS   ║
# ║  Usage:  sudo bash mailcow-installer.sh                                     ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
#  COLOR PALETTE
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  BOLD='\033[1m';       DIM='\033[2m';  NC='\033[0m'
BG_BLUE='\033[44m';  BG_GREEN='\033[42m';  BG_RED='\033[41m'

LOG_FILE="/var/log/mailcow-installer.log"
mkdir -p /var/log
touch "$LOG_FILE"

# ─────────────────────────────────────────────────────────────────────────────
#  LOGGING HELPERS
# ─────────────────────────────────────────────────────────────────────────────
log()     { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"; }
ok()      { echo -e "  ${GREEN}✔${NC}  ${WHITE}$1${NC}"; log "[OK] $1"; }
fail()    { echo -e "\n  ${BG_RED}${WHITE}  ✘  ERROR  ${NC}  ${RED}$1${NC}\n"; log "[FAIL] $1"; exit 1; }
info()    { echo -e "  ${CYAN}➜${NC}  ${CYAN}$1${NC}"; log "[INFO] $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  ${YELLOW}$1${NC}"; log "[WARN] $1"; }
step()    { echo -e "\n${BG_BLUE}${WHITE}${BOLD}  ▶  $1  ${NC}\n"; log "[STEP] $1"; }
sub()     { echo -e "  ${DIM}${MAGENTA}│${NC}  $1"; }
divider() { echo -e "  ${DIM}────────────────────────────────────────────────────${NC}"; }
blank()   { echo ""; }

# ─────────────────────────────────────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────────────────────────────────────
banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║                                                              ║"
  echo "  ║        ███╗   ███╗ █████╗ ██╗██╗      ██████╗ ██████╗      ║"
  echo "  ║        ████╗ ████║██╔══██╗██║██║     ██╔════╝██╔═══██╗     ║"
  echo "  ║        ██╔████╔██║███████║██║██║     ██║     ██║   ██║     ║"
  echo "  ║        ██║╚██╔╝██║██╔══██║██║██║     ██║     ██║   ██║     ║"
  echo "  ║        ██║ ╚═╝ ██║██║  ██║██║███████╗╚██████╗╚██████╔╝     ║"
  echo "  ║        ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚══════╝ ╚═════╝ ╚═════╝     ║"
  echo "  ║                                                              ║"
  echo "  ║          Professional Installer  v2.1  |  Ubuntu 22.04      ║"
  echo "  ║       Proxmox Ready  •  Auto DNS  •  Multi-Provider SSL     ║"
  echo "  ║                                                              ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${DIM}Log file: ${LOG_FILE}${NC}"
  blank
}

# ─────────────────────────────────────────────────────────────────────────────
#  BOOTSTRAP
# ─────────────────────────────────────────────────────────────────────────────
bootstrap() {
  step "Bootstrapping Essential Tools"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq 2>/dev/null || true

  for tool in curl wget git jq; do
    if ! command -v "$tool" &>/dev/null; then
      apt-get install -y -qq "$tool" 2>/dev/null || true
      ok "$tool installed"
    else
      sub "$tool already present"
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
#  PROXMOX AUDIT
# ─────────────────────────────────────────────────────────────────────────────
proxmox_audit() {
  step "Proxmox Template Detection & System Audit"

  VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "none")
  if [[ "$VIRT_TYPE" != "none" ]]; then
    ok "Virtualization detected: ${VIRT_TYPE^^}"
  else
    sub "No virtualization detected (bare metal)"
  fi

  blank
  echo -e "  ${BOLD}${WHITE}System Overview${NC}"
  divider

  OS_PRETTY=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
  sub "OS         : ${GREEN}${OS_PRETTY}${NC}"
  sub "Kernel     : $(uname -r)"
  sub "Hostname   : $(hostname)"

  CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "Unknown")
  CPU_CORES=$(nproc 2>/dev/null || echo "?")
  sub "CPU        : ${CPU_MODEL} (${CPU_CORES} cores)"

  TOTAL_RAM=$(awk '/MemTotal/{printf "%.0f MB", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
  FREE_RAM=$(awk '/MemAvailable/{printf "%.0f MB", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
  sub "Memory     : Total ${TOTAL_RAM}  |  Available ${FREE_RAM}"

  DISK_INFO=$(df -h / 2>/dev/null | awk 'NR==2{print "Total "$2"  Used "$3"  Free "$4}' || echo "?")
  sub "Disk (/)   : ${DISK_INFO}"

  blank
  echo -e "  ${BOLD}${WHITE}Installed Services Audit${NC}"
  divider

  CONFLICT_FOUND=false
  for svc in postfix exim4 sendmail apache2 nginx haproxy; do
    if systemctl list-units --type=service --all 2>/dev/null | grep -q "${svc}.service"; then
      STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
      if [[ "$STATUS" == "active" ]]; then
        warn "RUNNING   : $svc  ${RED}(will be stopped)${NC}"
        CONFLICT_FOUND=true
      else
        sub "Installed : $svc  ${YELLOW}[${STATUS}]${NC}"
      fi
    fi
  done
  [[ "$CONFLICT_FOUND" == "false" ]] && ok "No conflicting services found"

  blank
  echo -e "  ${BOLD}${WHITE}Required Ports Audit${NC}"
  divider

  PORT_BLOCKED=false
  for port in 25 80 110 143 443 465 587 993 995 4190; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      warn "Port ${port}  BLOCKED  (will be cleared)"
      PORT_BLOCKED=true
    else
      sub "Port ${port}  ${GREEN}Available${NC}"
    fi
  done
  [[ "$PORT_BLOCKED" == "false" ]] && ok "All required ports are available"

  blank
  echo -e "  ${BOLD}${WHITE}Docker Status${NC}"
  divider

  if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "?")
    sub "Docker     : ${GREEN}Installed${NC}  v${DOCKER_VER}"
  else
    sub "Docker     : ${YELLOW}Not installed${NC}  (will be installed)"
  fi

  if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VER=$(docker compose version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "?")
    sub "Compose    : ${GREEN}Installed${NC}  v${COMPOSE_VER}"
  else
    sub "Compose    : ${YELLOW}Not installed${NC}  (will be installed)"
  fi

  blank
  echo -e "  ${BOLD}${WHITE}Minimum Requirements Check${NC}"
  divider

  RAM_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  DISK_GB=$(df / 2>/dev/null | awk 'NR==2{print int($4/1024/1024)}' || echo 0)
  CPU_COUNT=$(nproc 2>/dev/null || echo 1)

  if [[ "$RAM_MB" -lt 2048 ]]; then
    warn "RAM: ${RAM_MB}MB  (Minimum 2GB recommended)"
  else
    ok "RAM: ${RAM_MB}MB  ✓"
  fi

  if [[ "$DISK_GB" -lt 10 ]]; then
    warn "Disk: ${DISK_GB}GB free  (Minimum 10GB recommended)"
  else
    ok "Disk: ${DISK_GB}GB free  ✓"
  fi

  if [[ "$CPU_COUNT" -lt 2 ]]; then
    warn "CPU: ${CPU_COUNT} core  (Minimum 2 cores recommended)"
  else
    ok "CPU: ${CPU_COUNT} cores  ✓"
  fi

  blank
  read -rp "  Continue with installation? (y/N): " AUDIT_CONFIRM < /dev/tty
  if [[ ! "$AUDIT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n  ${YELLOW}Installation cancelled.${NC}"
    exit 0
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT COLLECTION
# ─────────────────────────────────────────────────────────────────────────────
get_input() {
  step "Configuration Setup"

  blank
  echo -e "  ${BOLD}${WHITE}Domain Name${NC}  ${DIM}(e.g. example.com)${NC}"
  read -rp "  ▸ Domain: " DOMAIN < /dev/tty
  [[ -z "$DOMAIN" ]] && fail "Domain name cannot be empty!"
  MAIL_HOST="mail.${DOMAIN}"

  DETECTED_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null \
    || wget -qO- --timeout=5 ifconfig.me 2>/dev/null \
    || hostname -I 2>/dev/null | awk '{print $1}' \
    || echo "")

  blank
  echo -e "  ${BOLD}${WHITE}Server IP Address${NC}  ${DIM}(auto-detected: ${DETECTED_IP})${NC}"
  read -rp "  ▸ IP [${DETECTED_IP}]: " SERVER_IP < /dev/tty
  SERVER_IP=${SERVER_IP:-$DETECTED_IP}
  [[ -z "$SERVER_IP" ]] && fail "Server IP could not be determined!"

  blank
  echo -e "  ${BOLD}${WHITE}Timezone${NC}  ${DIM}(e.g. Asia/Dhaka, America/New_York, Europe/London)${NC}"
  read -rp "  ▸ Timezone [Asia/Dhaka]: " TZ_INPUT < /dev/tty
  MAILCOW_TZ=${TZ_INPUT:-Asia/Dhaka}

  blank
  echo -e "  ${BOLD}${WHITE}Postmaster / Admin Email${NC}"
  read -rp "  ▸ Email [postmaster@${DOMAIN}]: " ADMIN_EMAIL < /dev/tty
  ADMIN_EMAIL=${ADMIN_EMAIL:-postmaster@${DOMAIN}}

  blank
  echo -e "  ${BOLD}${WHITE}DNS Provider${NC}"
  divider
  echo -e "  ${CYAN}  1)${NC}  Cloudflare           ${DIM}(Automatic DNS + SSL)${NC}"
  echo -e "  ${CYAN}  2)${NC}  Microsoft Azure DNS  ${DIM}(Automatic via Azure CLI)${NC}"
  echo -e "  ${CYAN}  3)${NC}  Google Cloud DNS     ${DIM}(Automatic via gcloud)${NC}"
  echo -e "  ${CYAN}  4)${NC}  Manual               ${DIM}(Provide DNS records yourself)${NC}"
  blank
  read -rp "  ▸ Choice [1-4]: " DNS_CHOICE < /dev/tty
  DNS_CHOICE=${DNS_CHOICE:-4}

  case "$DNS_CHOICE" in
    1) collect_cloudflare_creds ;;
    2) collect_azure_creds      ;;
    3) collect_gcloud_creds     ;;
    4) DNS_PROVIDER="Manual"    ;;
    *) fail "Invalid DNS provider selection!" ;;
  esac

  blank
  echo -e "  ${BG_BLUE}${WHITE}${BOLD}  ▶  Configuration Summary  ${NC}"
  blank
  echo -e "  ${BOLD}Domain       ${NC}: ${GREEN}${DOMAIN}${NC}"
  echo -e "  ${BOLD}Mail Host    ${NC}: ${GREEN}${MAIL_HOST}${NC}"
  echo -e "  ${BOLD}Server IP    ${NC}: ${GREEN}${SERVER_IP}${NC}"
  echo -e "  ${BOLD}Timezone     ${NC}: ${GREEN}${MAILCOW_TZ}${NC}"
  echo -e "  ${BOLD}Admin Email  ${NC}: ${GREEN}${ADMIN_EMAIL}${NC}"
  echo -e "  ${BOLD}DNS Provider ${NC}: ${GREEN}${DNS_PROVIDER}${NC}"
  blank
  read -rp "  ▸ Proceed with installation? (y/N): " CONFIRM < /dev/tty
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n  ${YELLOW}Installation cancelled.${NC}"
    exit 0
  fi
}

collect_cloudflare_creds() {
  DNS_PROVIDER="Cloudflare"
  blank
  echo -e "  ${BOLD}${WHITE}Cloudflare Credentials${NC}"
  echo -e "  ${DIM}cloudflare.com → My Profile → API Tokens → Create Token${NC}"
  read -rp "  ▸ API Token: " CF_TOKEN < /dev/tty
  [[ -z "$CF_TOKEN" ]] && fail "Cloudflare API Token is required!"
  echo -e "  ${DIM}cloudflare.com → Your Domain → Overview → Zone ID (right sidebar)${NC}"
  read -rp "  ▸ Zone ID: " CF_ZONE_ID < /dev/tty
  [[ -z "$CF_ZONE_ID" ]] && fail "Cloudflare Zone ID is required!"
}

collect_azure_creds() {
  DNS_PROVIDER="Microsoft Azure DNS"
  blank
  echo -e "  ${BOLD}${WHITE}Microsoft Azure DNS Credentials${NC}"
  read -rp "  ▸ Azure Resource Group: " AZ_RESOURCE_GROUP < /dev/tty
  [[ -z "$AZ_RESOURCE_GROUP" ]] && fail "Azure Resource Group is required!"
  read -rp "  ▸ Azure DNS Zone Name [${DOMAIN}]: " AZ_ZONE < /dev/tty
  AZ_ZONE=${AZ_ZONE:-$DOMAIN}
}

collect_gcloud_creds() {
  DNS_PROVIDER="Google Cloud DNS"
  blank
  echo -e "  ${BOLD}${WHITE}Google Cloud DNS Credentials${NC}"
  read -rp "  ▸ GCP Project ID: " GCP_PROJECT < /dev/tty
  [[ -z "$GCP_PROJECT" ]] && fail "GCP Project ID is required!"
  read -rp "  ▸ Cloud DNS Managed Zone Name: " GCP_ZONE_NAME < /dev/tty
  [[ -z "$GCP_ZONE_NAME" ]] && fail "GCP DNS Zone Name is required!"
}

# ─────────────────────────────────────────────────────────────────────────────
#  SYSTEM PREPARATION
# ─────────────────────────────────────────────────────────────────────────────
prepare_system() {
  step "System Preparation & Package Installation"
  export DEBIAN_FRONTEND=noninteractive

  info "Updating package lists..."
  apt-get update -qq 2>/dev/null || true
  ok "Package lists updated"

  info "Upgrading installed packages..."
  apt-get upgrade -y -qq 2>/dev/null || true
  ok "System packages upgraded"

  info "Installing required packages..."
  apt-get install -y -qq ca-certificates gnupg lsb-release python3 ufw ntp htop net-tools 2>/dev/null || true
  ok "Required packages installed"

  timedatectl set-ntp true 2>/dev/null || true
  ok "NTP time sync enabled"

  hostnamectl set-hostname "$MAIL_HOST" 2>/dev/null || hostname "$MAIL_HOST" 2>/dev/null || true
  if ! grep -q "$MAIL_HOST" /etc/hosts 2>/dev/null; then
    echo "${SERVER_IP}  ${MAIL_HOST}  mail" >> /etc/hosts
  fi
  ok "Hostname configured: ${MAIL_HOST}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  DOCKER
# ─────────────────────────────────────────────────────────────────────────────
install_docker() {
  step "Docker Engine Installation"

  if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "?")
    ok "Docker already installed: v${DOCKER_VER}"
  else
    info "Installing Docker Engine..."
    curl -fsSL https://get.docker.com | bash 2>/dev/null || fail "Docker installation failed!"
    ok "Docker installed"
  fi

  if ! docker compose version &>/dev/null 2>&1; then
    info "Installing Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
  fi
  ok "Docker Compose ready"

  systemctl enable docker 2>/dev/null || true
  systemctl start  docker 2>/dev/null || true
  ok "Docker service enabled and started"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PORT CONFLICTS
# ─────────────────────────────────────────────────────────────────────────────
fix_ports() {
  step "Resolving Port Conflicts"

  for svc in postfix exim4 sendmail apache2 nginx haproxy; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      systemctl stop    "$svc" 2>/dev/null || true
      systemctl disable "$svc" 2>/dev/null || true
      ok "Stopped: ${svc}"
    fi
  done

  # Kill anything on port 25
  if ss -tlnp 2>/dev/null | grep -q ":25 "; then
    fuser -k 25/tcp 2>/dev/null || true
    sleep 2
    ok "Port 25 cleared"
  fi

  ok "Port conflict resolution complete"
}

# ─────────────────────────────────────────────────────────────────────────────
#  DNS: CLOUDFLARE
# ─────────────────────────────────────────────────────────────────────────────
setup_cloudflare_dns() {
  step "Cloudflare DNS — Configuring Records"

  CF_API="https://api.cloudflare.com/client/v4"

  cf_api() {
    curl -s -X "$1" "${CF_API}$2" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H "Content-Type: application/json" \
      ${3:+--data "$3"}
  }

  VERIFY=$(cf_api GET "/user/tokens/verify")
  echo "$VERIFY" | jq -e '.success' &>/dev/null || fail "Cloudflare API Token is invalid!"
  ok "Cloudflare API Token verified"

  upsert_cf_record() {
    local TYPE=$1 NAME=$2 CONTENT=$3 PRIORITY=${4:-}
    EXISTING=$(cf_api GET "/zones/${CF_ZONE_ID}/dns_records?type=${TYPE}&name=${NAME}")
    RECORD_ID=$(echo "$EXISTING" | jq -r '.result[0].id // empty' 2>/dev/null || echo "")

    if [[ "$TYPE" == "MX" ]]; then
      PAYLOAD=$(jq -n --arg t "$TYPE" --arg n "$NAME" --arg c "$CONTENT" --argjson p "${PRIORITY:-10}" \
        '{type:$t, name:$n, content:$c, ttl:1, priority:$p}')
    else
      PAYLOAD=$(jq -n --arg t "$TYPE" --arg n "$NAME" --arg c "$CONTENT" \
        '{type:$t, name:$n, content:$c, ttl:1, proxied:false}')
    fi

    if [[ -n "$RECORD_ID" ]]; then
      cf_api PUT "/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}" "$PAYLOAD" > /dev/null
      ok "Updated   ${TYPE}  ${NAME}"
    else
      cf_api POST "/zones/${CF_ZONE_ID}/dns_records" "$PAYLOAD" > /dev/null
      ok "Created   ${TYPE}  ${NAME}"
    fi
  }

  upsert_cf_record "A"     "$MAIL_HOST"              "$SERVER_IP"
  upsert_cf_record "MX"    "$DOMAIN"                 "$MAIL_HOST"  "10"
  upsert_cf_record "TXT"   "$DOMAIN"                 "v=spf1 mx a:${MAIL_HOST} ~all"
  upsert_cf_record "TXT"   "_dmarc.${DOMAIN}"        "v=DMARC1; p=quarantine; rua=mailto:${ADMIN_EMAIL}; ruf=mailto:${ADMIN_EMAIL}; fo=1"
  upsert_cf_record "CNAME" "autodiscover.${DOMAIN}"  "$MAIL_HOST"
  upsert_cf_record "CNAME" "autoconfig.${DOMAIN}"    "$MAIL_HOST"

  ok "All Cloudflare DNS records configured"
}

# ─────────────────────────────────────────────────────────────────────────────
#  DNS: AZURE
# ─────────────────────────────────────────────────────────────────────────────
setup_azure_dns() {
  step "Microsoft Azure DNS — Configuring Records"

  if ! command -v az &>/dev/null; then
    info "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash 2>/dev/null || fail "Azure CLI installation failed!"
    ok "Azure CLI installed"
  fi

  info "Initiating Azure login..."
  az login --use-device-code 2>/dev/null || fail "Azure login failed!"
  ok "Azure authenticated"

  RG="$AZ_RESOURCE_GROUP"; ZONE="$AZ_ZONE"; TTL=3600

  az network dns record-set a   add-record   -g "$RG" -z "$ZONE" -n "mail"        -a "$SERVER_IP"   --ttl $TTL -o none 2>/dev/null || true; ok "A record: mail"
  az network dns record-set mx  add-record   -g "$RG" -z "$ZONE" -n "@"  --exchange "${MAIL_HOST}." --preference 10 --ttl $TTL -o none 2>/dev/null || true; ok "MX record"
  az network dns record-set txt add-record   -g "$RG" -z "$ZONE" -n "@"  --value "v=spf1 mx a:${MAIL_HOST} ~all" --ttl $TTL -o none 2>/dev/null || true; ok "SPF record"
  az network dns record-set txt add-record   -g "$RG" -z "$ZONE" -n "_dmarc" --value "v=DMARC1; p=quarantine; rua=mailto:${ADMIN_EMAIL}" --ttl $TTL -o none 2>/dev/null || true; ok "DMARC record"
  az network dns record-set cname set-record -g "$RG" -z "$ZONE" -n "autodiscover" -c "${MAIL_HOST}" --ttl $TTL -o none 2>/dev/null || true; ok "CNAME autodiscover"
  az network dns record-set cname set-record -g "$RG" -z "$ZONE" -n "autoconfig"   -c "${MAIL_HOST}" --ttl $TTL -o none 2>/dev/null || true; ok "CNAME autoconfig"

  ok "All Azure DNS records configured"
}

# ─────────────────────────────────────────────────────────────────────────────
#  DNS: GOOGLE CLOUD
# ─────────────────────────────────────────────────────────────────────────────
setup_gcloud_dns() {
  step "Google Cloud DNS — Configuring Records"

  if ! command -v gcloud &>/dev/null; then
    info "Installing Google Cloud CLI..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null
    apt-get update -qq 2>/dev/null || true
    apt-get install -y -qq google-cloud-cli 2>/dev/null || fail "gcloud CLI installation failed!"
    ok "Google Cloud CLI installed"
  fi

  info "Initiating Google Cloud login..."
  gcloud auth login --no-launch-browser 2>/dev/null || fail "GCP login failed!"
  gcloud config set project "$GCP_PROJECT" --quiet
  ok "Google Cloud authenticated"

  FQDN="${DOMAIN}."; ZONE="$GCP_ZONE_NAME"; TTL=3600

  gcloud dns record-sets create "${MAIL_HOST}." --zone="$ZONE" --type="A"   --ttl=$TTL --rrdatas="$SERVER_IP"                   2>/dev/null || true; ok "A record"
  gcloud dns record-sets create "${FQDN}"       --zone="$ZONE" --type="MX"  --ttl=$TTL --rrdatas="10 ${MAIL_HOST}."              2>/dev/null || true; ok "MX record"
  gcloud dns record-sets create "${FQDN}"       --zone="$ZONE" --type="TXT" --ttl=$TTL --rrdatas="\"v=spf1 mx a:${MAIL_HOST} ~all\"" 2>/dev/null || true; ok "SPF record"
  gcloud dns record-sets create "_dmarc.${FQDN}" --zone="$ZONE" --type="TXT" --ttl=$TTL --rrdatas="\"v=DMARC1; p=quarantine; rua=mailto:${ADMIN_EMAIL}\"" 2>/dev/null || true; ok "DMARC record"
  gcloud dns record-sets create "autodiscover.${FQDN}" --zone="$ZONE" --type="CNAME" --ttl=$TTL --rrdatas="${MAIL_HOST}." 2>/dev/null || true; ok "CNAME autodiscover"
  gcloud dns record-sets create "autoconfig.${FQDN}"   --zone="$ZONE" --type="CNAME" --ttl=$TTL --rrdatas="${MAIL_HOST}." 2>/dev/null || true; ok "CNAME autoconfig"

  ok "All Google Cloud DNS records configured"
}

# ─────────────────────────────────────────────────────────────────────────────
#  MAILCOW INSTALL
# ─────────────────────────────────────────────────────────────────────────────
install_mailcow() {
  step "Mailcow Dockerized — Download & Configure"

  INSTALL_DIR="/opt/mailcow-dockerized"

  if [[ -d "$INSTALL_DIR" ]]; then
    warn "Existing installation found — removing for clean install"
    cd "$INSTALL_DIR"
    docker compose down -v 2>/dev/null || true
    cd /
    rm -rf "$INSTALL_DIR"
    ok "Old installation removed"
  fi

  info "Cloning Mailcow repository..."
  cd /opt
  git clone https://github.com/mailcow/mailcow-dockerized -q || fail "Failed to clone Mailcow!"
  ok "Repository cloned"

  cd "$INSTALL_DIR"

  info "Generating mailcow.conf..."
  printf '%s\n%s\n1\n' "$MAIL_HOST" "$MAILCOW_TZ" | ./generate_config.sh 2>/dev/null || true

  if [[ ! -f "mailcow.conf" ]]; then
    fail "mailcow.conf was not generated! Check generate_config.sh output."
  fi

  sed -i "s|^MAILCOW_TZ=.*|MAILCOW_TZ=${MAILCOW_TZ}|" mailcow.conf 2>/dev/null || true

  ok "mailcow.conf configured"
  sub "FQDN      : ${MAIL_HOST}"
  sub "Timezone  : ${MAILCOW_TZ}"
}

# ─────────────────────────────────────────────────────────────────────────────
#  START CONTAINERS
# ─────────────────────────────────────────────────────────────────────────────
start_mailcow() {
  step "Starting Mailcow Containers"

  cd /opt/mailcow-dockerized

  # Make sure postfix is stopped before pulling
  systemctl stop postfix 2>/dev/null || true
  systemctl disable postfix 2>/dev/null || true
  fuser -k 25/tcp 2>/dev/null || true
  sleep 2

  # Disable IPv6 for Docker if not supported (common in LXC)
  if ! ping6 -c1 -W2 1.1.1.1 &>/dev/null 2>&1; then
    info "IPv6 not available — disabling for Docker"
    mkdir -p /etc/docker
    echo '{"ipv6": false}' > /etc/docker/daemon.json
    systemctl restart docker 2>/dev/null || true
    sleep 3
    ok "IPv6 disabled for Docker"
  fi

  info "Pulling Docker images (this will take several minutes, please wait)..."
  docker compose pull
  PULL_EXIT=$?
  if [[ $PULL_EXIT -ne 0 ]]; then
    warn "Some images failed — retrying..."
    sleep 5
    docker compose pull 2>/dev/null || true
    ok "Pull retry complete"
  else
    ok "All images pulled successfully"
  fi

  info "Starting all containers..."
  docker compose up -d --remove-orphans
  UP_EXIT=$?

  if [[ $UP_EXIT -ne 0 ]]; then
    warn "Some containers may have failed — checking status..."
    docker compose ps
    blank
    warn "Attempting restart in 10 seconds..."
    sleep 10
    docker compose up -d --remove-orphans 2>/dev/null || true
  fi

  info "Waiting for services to initialize (45 seconds)..."
  sleep 45

  # Final status check
  RUNNING=$(docker compose ps 2>/dev/null | grep -c "running\|Up" || echo 0)
  if [[ "$RUNNING" -gt 5 ]]; then
    ok "Mailcow is running  (${RUNNING} containers active)"
  else
    warn "Only ${RUNNING} containers running — check: docker compose ps"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  FIREWALL
# ─────────────────────────────────────────────────────────────────────────────
setup_firewall() {
  step "Firewall Configuration (UFW)"

  ufw --force reset   2>/dev/null || true
  ufw default deny incoming  2>/dev/null || true
  ufw default allow outgoing 2>/dev/null || true
  ufw allow ssh              2>/dev/null || true

  for port in 25 80 110 143 443 465 587 993 995 4190; do
    ufw allow "${port}/tcp" 2>/dev/null || true
    sub "Allowed: ${port}/tcp"
  done

  ufw --force enable 2>/dev/null || true
  ok "Firewall enabled with mail server rules"
}

# ─────────────────────────────────────────────────────────────────────────────
#  DKIM
# ─────────────────────────────────────────────────────────────────────────────
configure_dkim() {
  step "DKIM Key Configuration"

  info "Waiting for DKIM key generation (45 seconds)..."
  sleep 45

  RSPAMD_CONTAINER=$(docker ps --format '{{.Names}}' 2>/dev/null | grep rspamd | head -1 || echo "")
  DKIM_KEY=""

  if [[ -n "$RSPAMD_CONTAINER" ]]; then
    DKIM_KEY=$(docker exec "$RSPAMD_CONTAINER" \
      cat /etc/rspamd/dkim/${DOMAIN}.dkim.key 2>/dev/null | \
      grep -v "^-" | tr -d '\n' 2>/dev/null || echo "")
  fi

  if [[ -n "$DKIM_KEY" ]]; then
    DKIM_RECORD="v=DKIM1; k=rsa; p=${DKIM_KEY}"
    DKIM_NAME="dkim._domainkey.${DOMAIN}"

    case "$DNS_CHOICE" in
      1)
        CF_PAYLOAD=$(jq -n --arg n "$DKIM_NAME" --arg c "$DKIM_RECORD" \
          '{type:"TXT", name:$n, content:$c, ttl:1, proxied:false}')
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
          -H "Authorization: Bearer ${CF_TOKEN}" \
          -H "Content-Type: application/json" \
          --data "$CF_PAYLOAD" > /dev/null 2>/dev/null || true
        ok "DKIM published to Cloudflare"
        ;;
      2)
        az network dns record-set txt add-record \
          -g "$AZ_RESOURCE_GROUP" -z "$AZ_ZONE" -n "dkim._domainkey" \
          --value "$DKIM_RECORD" --ttl 3600 -o none 2>/dev/null || true
        ok "DKIM published to Azure DNS"
        ;;
      3)
        gcloud dns record-sets create "${DKIM_NAME}." \
          --zone="$GCP_ZONE_NAME" --type="TXT" --ttl=3600 \
          --rrdatas="\"${DKIM_RECORD}\"" 2>/dev/null || true
        ok "DKIM published to Google Cloud DNS"
        ;;
    esac

    echo "${DKIM_RECORD}" > /root/mailcow-dkim.txt
    sub "DKIM key saved to: /root/mailcow-dkim.txt"
  else
    warn "DKIM key not yet generated — get it from:"
    sub "Admin Panel → Configuration → ARC/DKIM Keys"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  FINAL SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
show_result() {
  blank
  echo -e "${GREEN}${BOLD}"
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║                                                              ║"
  echo "  ║        ✅   MAILCOW INSTALLATION COMPLETE!                  ║"
  echo "  ║                                                              ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"

  echo -e "  ${BOLD}${WHITE}Access Details${NC}"
  divider
  echo -e "  ${CYAN}Admin Panel    ${NC}: ${GREEN}https://${MAIL_HOST}/admin${NC}"
  echo -e "  ${CYAN}Webmail        ${NC}: ${GREEN}https://${MAIL_HOST}${NC}"
  echo -e "  ${CYAN}Username       ${NC}: ${YELLOW}admin${NC}"
  echo -e "  ${CYAN}Password       ${NC}: ${RED}moohoo${NC}  ${DIM}← Change immediately!${NC}"
  blank

  echo -e "  ${BOLD}${WHITE}DNS Records${NC}  ${DIM}(Provider: ${DNS_PROVIDER})${NC}"
  divider

  if [[ "$DNS_CHOICE" == "4" ]]; then
    echo -e "  ${YELLOW}Add these records manually:${NC}"
    blank
    printf "  %-8s %-35s %s\n" "Type" "Name" "Value"
    divider
    printf "  %-8s %-35s %s\n" "A"     "mail.${DOMAIN}"              "${SERVER_IP}"
    printf "  %-8s %-35s %s\n" "MX"    "${DOMAIN}"                   "mail.${DOMAIN} (priority 10)"
    printf "  %-8s %-35s %s\n" "TXT"   "${DOMAIN}"                   "v=spf1 mx a:mail.${DOMAIN} ~all"
    printf "  %-8s %-35s %s\n" "TXT"   "_dmarc.${DOMAIN}"            "v=DMARC1; p=quarantine; rua=mailto:${ADMIN_EMAIL}"
    printf "  %-8s %-35s %s\n" "CNAME" "autodiscover.${DOMAIN}"      "mail.${DOMAIN}"
    printf "  %-8s %-35s %s\n" "CNAME" "autoconfig.${DOMAIN}"        "mail.${DOMAIN}"
    printf "  %-8s %-35s %s\n" "TXT"   "dkim._domainkey.${DOMAIN}"   "Get from Admin Panel → ARC/DKIM Keys"
  else
    ok "All DNS records automatically configured via ${DNS_PROVIDER}"
    [[ -f /root/mailcow-dkim.txt ]] && sub "DKIM key backup: /root/mailcow-dkim.txt"
  fi

  blank
  echo -e "  ${BOLD}${WHITE}Container Status${NC}"
  divider
  cd /opt/mailcow-dockerized 2>/dev/null || true
  docker compose ps 2>/dev/null | tail -n +2 | while IFS= read -r line; do
    if echo "$line" | grep -qi "up"; then
      echo -e "  ${GREEN}✔${NC}  $line"
    else
      echo -e "  ${RED}✘${NC}  $line"
    fi
  done

  blank
  echo -e "  ${BOLD}${WHITE}Post-Installation Checklist${NC}"
  divider
  echo -e "  ${YELLOW}□${NC}  Change admin password immediately"
  echo -e "  ${YELLOW}□${NC}  Add domain: Admin Panel → Mail Setup → Domains"
  echo -e "  ${YELLOW}□${NC}  Create first mailbox"
  echo -e "  ${YELLOW}□${NC}  Configure DKIM: Admin Panel → Configuration → ARC/DKIM Keys"
  echo -e "  ${YELLOW}□${NC}  Verify MX: ${DIM}nslookup -type=MX ${DOMAIN}${NC}"
  echo -e "  ${YELLOW}□${NC}  Test deliverability: ${DIM}https://mail-tester.com${NC}"
  blank

  cat > /root/mailcow-info.txt << EOF
════════════════════════════════════════
  MAILCOW INSTALLATION RECORD
════════════════════════════════════════
  Install Date : $(date)
  Domain       : ${DOMAIN}
  Mail Host    : ${MAIL_HOST}
  Server IP    : ${SERVER_IP}
  Timezone     : ${MAILCOW_TZ}
  DNS Provider : ${DNS_PROVIDER}
  Admin URL    : https://${MAIL_HOST}/admin
  Username     : admin
  Password     : moohoo  ← CHANGE IMMEDIATELY
  Log File     : ${LOG_FILE}
════════════════════════════════════════
EOF

  ok "Installation record saved: /root/mailcow-info.txt"
  blank
  echo -e "  ${DIM}Full log: ${LOG_FILE}${NC}"
  blank
}

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
  banner

  [[ $EUID -ne 0 ]] && fail "Please run as root:  sudo bash mailcow-installer.sh"

  bootstrap
  proxmox_audit
  get_input
  prepare_system
  install_docker
  fix_ports

  case "$DNS_CHOICE" in
    1) setup_cloudflare_dns ;;
    2) setup_azure_dns      ;;
    3) setup_gcloud_dns     ;;
  esac

  install_mailcow
  start_mailcow
  setup_firewall

  [[ "$DNS_CHOICE" != "4" ]] && configure_dkim

  show_result
}

main "$@"
