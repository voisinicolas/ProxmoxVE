#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/rogerfar/rdt-client

APP="RDTClient"
var_tags="${var_tags:-torrent}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/rdtc/ ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -s https://api.github.com/repos/rogerfar/rdt-client/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  if [[ ! -f ~/.rdt-client ]] || [[ "${RELEASE}" != "$(cat ~/.rdt-client 2>/dev/null)" ]]; then
    msg_info "Stopping ${APP}"
    systemctl stop rdtc
    msg_ok "Stopped ${APP}"

    msg_info "Creating backup"
    mkdir -p /opt/rdtc-backup
    cp -R /opt/rdtc/appsettings.json /opt/rdtc-backup/
    msg_ok "Backup created"

    fetch_and_deploy_gh_release "rdt-client" "rogerfar/rdt-client" "prebuild" "latest" "/opt/rdtc" "RealDebridClient.zip"
    cp -R /opt/rdtc-backup/appsettings.json /opt/rdtc/
    if dpkg-query -W dotnet-sdk-8.0 >/dev/null 2>&1; then
      $STD apt-get remove --purge -y dotnet-sdk-8.0
      $STD apt-get install -y dotnet-sdk-9.0
    fi

    msg_info "Starting ${APP}"
    systemctl start rdtc
    msg_ok "Started ${APP}"

    msg_info "Cleaning Up"
    rm -rf /opt/rdtc-backup
    msg_ok "Cleaned"
    
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:6500${CL}"
