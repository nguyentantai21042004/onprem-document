#!/usr/bin/env bash
set -euo pipefail

# Ensure running with bash (not sh/dash)
if [ -z "${BASH_VERSINFO:-}" ]; then
  echo "Please run this script with bash: sudo bash harbor-install.sh"
  exit 1
fi

#
# Harbor installation using existing Docker and existing SSL certificate/key
# - Assumes Docker Engine + Compose plugin are already installed
# - Assumes you already have a valid certificate and private key
#

########################################
#            Configuration             #
########################################

# Domain for Harbor (FQDN)
DOMAIN="harbor.ngtantai.pro"

# Existing certificate and key (source paths)
# If your cert/key are already at /etc/harbor/ssl, you can keep defaults
CERT_SRC="/etc/harbor/ssl/harbor.crt"
KEY_SRC="/etc/harbor/ssl/harbor.key"

# Installation directories
HARBOR_BASE_DIR="/opt/harbor"
HARBOR_INSTALL_DIR="${HARBOR_BASE_DIR}/harbor"
HARBOR_DATA_DIR="/data/harbor"

# Optional: timezone (comment out to skip)
#TZ="Asia/Ho_Chi_Minh"

########################################
#           Pre-flight checks          #
########################################

echo "[Check] Docker availability"
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is not installed. Please install Docker CE + Compose plugin first."
  exit 1
fi

if command -v docker-compose >/dev/null 2>&1; then
  echo "[Info] docker-compose detected"
else
  echo "[Info] Using 'docker compose' (plugin)"
fi

# Ensure dependencies
echo "[Prep] Installing required packages"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release openssl net-tools

# Optional timezone
if [ "${TZ:-}" != "" ]; then
  echo "[Prep] Setting timezone: ${TZ}"
  sudo timedatectl set-timezone "$TZ" || true
fi

########################################
#          SSL placement/trust         #
########################################

echo "[SSL] Ensuring certificate and key at /etc/harbor/ssl"
sudo mkdir -p /etc/harbor/ssl

if [ ! -f /etc/harbor/ssl/harbor.crt ] || [ ! -f /etc/harbor/ssl/harbor.key ]; then
  # Copy from provided sources if different
  if [ -f "$CERT_SRC" ] && [ -f "$KEY_SRC" ]; then
    sudo cp "$CERT_SRC" /etc/harbor/ssl/harbor.crt
    sudo cp "$KEY_SRC" /etc/harbor/ssl/harbor.key
  else
    echo "ERROR: CERT_SRC or KEY_SRC not found. Set CERT_SRC/KEY_SRC to your existing cert/key paths."
    exit 1
  fi
fi

sudo chmod 600 /etc/harbor/ssl/harbor.key
sudo chmod 644 /etc/harbor/ssl/harbor.crt

echo "[SSL] Verifying certificate subject"
if openssl x509 -in /etc/harbor/ssl/harbor.crt -noout -subject >/dev/null 2>&1; then
  CERT_SUBJ=$(openssl x509 -in /etc/harbor/ssl/harbor.crt -noout -subject | sed 's/^subject= //')
  echo "[SSL] Subject: ${CERT_SUBJ}"
else
  echo "WARNING: Unable to parse certificate subject"
fi

echo "[Docker Trust] Adding cert to Docker trust store for ${DOMAIN}"
sudo mkdir -p "/etc/docker/certs.d/${DOMAIN}"
sudo cp /etc/harbor/ssl/harbor.crt "/etc/docker/certs.d/${DOMAIN}/ca.crt" || true
sudo systemctl restart docker

########################################
#          Download Harbor             #
########################################

echo "[Harbor] Preparing directories"
sudo mkdir -p "$HARBOR_BASE_DIR"
sudo mkdir -p "$HARBOR_DATA_DIR"
cd "$HARBOR_BASE_DIR"

echo "[Harbor] Fetching latest release version"
HARBOR_VERSION=$(curl -s https://api.github.com/repos/goharbor/harbor/releases/latest | grep -Po '"tag_name": "\K[^"]*' || true)
if [ -z "$HARBOR_VERSION" ]; then
  HARBOR_VERSION="v2.13.1"
  echo "[Harbor] Fallback version: ${HARBOR_VERSION}"
else
  echo "[Harbor] Latest version: ${HARBOR_VERSION}"
fi

TARBALL="harbor-offline-installer-${HARBOR_VERSION}.tgz"
if [ ! -f "$TARBALL" ]; then
  echo "[Harbor] Downloading ${TARBALL}"
  sudo wget -q --show-progress "https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/${TARBALL}"
else
  echo "[Harbor] Tarball already exists: ${TARBALL}"
fi

if [ -d "$HARBOR_INSTALL_DIR" ]; then
  echo "[Harbor] Existing install dir found at ${HARBOR_INSTALL_DIR}"
else
  echo "[Harbor] Extracting ${TARBALL}"
  sudo tar xzf "$TARBALL"
fi

cd "$HARBOR_INSTALL_DIR"

########################################
#            Configure Harbor          #
########################################

echo "[Harbor] Writing harbor.yml"
sudo tee harbor.yml > /dev/null <<EOF
hostname: ${DOMAIN}

http:
  port: 80

https:
  port: 443
  certificate: /etc/harbor/ssl/harbor.crt
  private_key: /etc/harbor/ssl/harbor.key

harbor_admin_password: Harbor12345

database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900
  conn_max_lifetime: 5m
  conn_max_idle_time: 0

data_volume: ${HARBOR_DATA_DIR}

trivy:
  ignore_unfixed: false
  skip_update: false
  skip_java_db_update: false
  offline_scan: false
  security_check: vuln
  insecure: false
  timeout: 5m0s

jobservice:
  max_job_workers: 10
  max_job_duration_hours: 24
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor
EOF

########################################
#            Install Harbor            #
########################################

echo "[Harbor] Running prepare"
sudo ./prepare

# Verify prepare produced docker-compose.yml
if [ ! -f docker-compose.yml ]; then
  echo "[Error] prepare did not generate docker-compose.yml."
  echo "- Recheck hostname and sections in harbor.yml (especially jobservice)."
  echo "- Fix issues, then rerun: sudo ./prepare"
  exit 1
fi

echo "[Harbor] Installing (with Trivy)"
sudo ./install.sh --with-trivy

########################################
#        Systemd service (autostart)   #
########################################

if [ -f /opt/harbor/harbor/docker-compose.yml ]; then
  echo "[Service] Creating systemd unit /etc/systemd/system/harbor.service"
  sudo tee /etc/systemd/system/harbor.service > /dev/null <<'EOF'
[Unit]
Description=Harbor (Docker Compose)
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/opt/harbor/harbor
ExecStart=/bin/sh -c 'if command -v docker-compose >/dev/null 2>&1; then docker-compose -f /opt/harbor/harbor/docker-compose.yml up -d; else /usr/bin/docker compose -f /opt/harbor/harbor/docker-compose.yml up -d; fi'
ExecStop=/bin/sh -c 'if command -v docker-compose >/dev/null 2>&1; then docker-compose -f /opt/harbor/harbor/docker-compose.yml down; else /usr/bin/docker compose -f /opt/harbor/harbor/docker-compose.yml down; fi'
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

  echo "[Service] Enabling and starting Harbor"
  sudo systemctl daemon-reload
  sudo systemctl enable harbor
  sudo systemctl start harbor
else
  echo "[Service] Skipped creating systemd unit because /opt/harbor/harbor/docker-compose.yml not found"
fi

########################################
#               Verify                 #
########################################

if [ -f /opt/harbor/harbor/docker-compose.yml ]; then
  echo "[Verify] docker compose ps"
  if command -v docker-compose >/dev/null 2>&1; then
    sudo docker-compose -f /opt/harbor/harbor/docker-compose.yml ps || true
  else
    sudo docker compose -f /opt/harbor/harbor/docker-compose.yml ps || true
  fi
else
  echo "[Verify] Skipped docker compose ps (compose file missing)"
fi

echo "[Verify] Listening on 80/443"
sudo netstat -tlnp | grep -E ':(80|443)' || true

echo "[Done] Access Harbor at: https://${DOMAIN}"
echo "[Info] Default admin account: admin / Harbor12345"


