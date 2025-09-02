#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/sbondCo/Watcharr

APP="Watcharr"
var_tags="${var_tags:-media}"
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
  if [[ ! -d /opt/watcharr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "watcharr" "sbondCo/Watcharr"; then
    msg_info "Stopping $APP"
    systemctl stop watcharr
    msg_ok "Stopped $APP"

    rm -f /opt/watcharr/server/watcharr
    rm -rf /opt/watcharr/server/ui
    fetch_and_deploy_gh_release "watcharr" "sbondCo/Watcharr" "tarball"

    msg_info "Updating $APP"
    cd /opt/watcharr
    export GOOS=linux
    $STD npm i
    $STD npm run build
    mv ./build ./server/ui
    cd server
    $STD go mod download
    $STD go build -o ./watcharr
    msg_ok "Updated $APP"

    msg_info "Starting $APP"
    systemctl start watcharr
    msg_ok "Started $APP"
    msg_ok "Update Successfully"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3080${CL}"
