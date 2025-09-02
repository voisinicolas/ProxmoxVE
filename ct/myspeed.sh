#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster) | Co-Author: MickLesk (Canbiz)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://myspeed.dev/

APP="MySpeed"
var_tags="${var_tags:-tracking}"
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
  if [[ ! -d /opt/myspeed ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  if check_for_gh_release "myspeed" "gnmyt/myspeed"; then
    msg_info "Stopping Service"
    systemctl stop myspeed
    msg_ok "Stopped Service"

    msg_info "Creating backup"
    cd /opt
    rm -rf myspeed_bak
    mv myspeed myspeed_bak
    msg_ok "Backup created"

    fetch_and_deploy_gh_release "myspeed" "gnmyt/myspeed" "prebuild" "latest" "/opt/myspeed" "MySpeed-*.zip"

    msg_info "Updating ${APP}"
    cd /opt/myspeed
    $STD npm install
    if [[ -d /opt/myspeed_bak/data ]]; then
      mkdir -p /opt/myspeed/data/
      cp -r /opt/myspeed_bak/data/* /opt/myspeed/data/
    fi
    msg_ok "Updated ${APP}"

    msg_info "Starting Service"
    systemctl start myspeed
    msg_ok "Started Service"
    msg_ok "Updated Successfully!\n"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5216${CL}"
