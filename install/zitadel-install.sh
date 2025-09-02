#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: dave-yap
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zitadel.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y ca-certificates
msg_ok "Installed Dependecies"

PG_VERSION="17" setup_postgresql

msg_info "Installing Postgresql"
DB_NAME="zitadel"
DB_USER="zitadel"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
DB_ADMIN_USER="root"
DB_ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)
systemctl start postgresql
$STD sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE USER $DB_ADMIN_USER WITH PASSWORD '$DB_ADMIN_PASS' SUPERUSER;"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_ADMIN_USER;"
{
  echo "Application Credentials"
  echo "DB_NAME: $DB_NAME"
  echo "DB_USER: $DB_USER"
  echo "DB_PASS: $DB_PASS"
  echo "DB_ADMIN_USER: $DB_ADMIN_USER"
  echo "DB_ADMIN_PASS: $DB_ADMIN_PASS"
} >>~/zitadel.creds
msg_ok "Installed PostgreSQL"

fetch_and_deploy_gh_release "zitadel" "zitadel/zitadel" "prebuild" "latest" "/usr/local/bin" "zitadel-linux-amd64.tar.gz"

msg_info "Setting up Zitadel Environments"
mkdir -p /opt/zitadel
echo "/opt/zitadel/config.yaml" >"/opt/zitadel/.config"
head -c 32 < <(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9') >"/opt/zitadel/.masterkey"
{
  echo "Config location: $(cat "/opt/zitadel/.config")"
  echo "Masterkey: $(cat "/opt/zitadel/.masterkey")"
} >>~/zitadel.creds
cat <<EOF >/opt/zitadel/config.yaml
Port: 8080
ExternalPort: 8080
ExternalDomain: localhost
ExternalSecure: false
TLS:
  Enabled: false
  KeyPath: ""
  Key: ""
  CertPath: ""
  Cert: ""

Database:
  postgres:
    Host: localhost
    Port: 5432
    Database: ${DB_NAME}
    User:
      Username: ${DB_USER}
      Password: ${DB_PASS}
      SSL:
        Mode: disable
        RootCert: ""
        Cert: ""
        Key: ""
    Admin:
      Username: ${DB_ADMIN_USER}
      Password: ${DB_ADMIN_PASS}
      SSL:
        Mode: disable
        RootCert: ""
        Cert: ""
        Key: ""
DefaultInstance:
  Features:
    LoginV2:
      Required: false
EOF
msg_ok "Installed Zitadel Enviroments"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/zitadel.service
[Unit]
Description=ZITADEL Identiy Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=zitadel
Group=zitadel
ExecStart=/usr/local/bin/zitadel start --masterkeyFile "/opt/zitadel/.masterkey" --config "/opt/zitadel/config.yaml"
Restart=always
RestartSec=5
TimeoutStartSec=0

# Security Hardening options
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q zitadel
msg_ok "Created Services"

msg_info "Zitadel initial setup"
zitadel start-from-init --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml &>/dev/null &
sleep 60
kill $(lsof -i | awk '/zitadel/ {print $2}' | head -n1)
useradd zitadel
msg_ok "Zitadel initialized"

msg_info "Set ExternalDomain to current IP and restart Zitadel"
IP=$(ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
sed -i "0,/localhost/s/localhost/${IP}/" /opt/zitadel/config.yaml
systemctl stop -q zitadel
$STD zitadel setup --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml
systemctl restart -q zitadel
msg_ok "Zitadel restarted with ExternalDomain set to current IP"

msg_info "Create zitadel-rerun.sh"
cat <<EOF >~/zitadel-rerun.sh
systemctl stop zitadel
timeout --kill-after=5s 15s zitadel setup --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml
systemctl restart zitadel
EOF
msg_ok "Bash script for rerunning Zitadel after changing Zitadel config.yaml"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
