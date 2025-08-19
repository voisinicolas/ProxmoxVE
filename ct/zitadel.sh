#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: dave-yap (dave-yap)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zitadel.com/

APP="Zitadel"
var_tags="${var_tags:-identity-provider}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
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
  if [[ ! -f /etc/systemd/system/zitadel.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -fsSL https://api.github.com/repos/zitadel/zitadel/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  if [[ ! -f ~/.zitadel ]] || [[ "${RELEASE}" != "$(cat ~/.zitadel)" ]]; then
    msg_info "Stopping $APP"
    systemctl stop zitadel
    msg_ok "Stopped $APP"

    rm -f /usr/local/bin/zitadel
    fetch_and_deploy_gh_release "zitadel" "zitadel/zitadel" "prebuild" "latest" "/usr/local/bin" "zitadel-linux-amd64.tar.gz"

    msg_info "Updating $APP to ${RELEASE}"
    $STD zitadel setup --masterkeyFile /opt/zitadel/.masterkey --config /opt/zitadel/config.yaml --init-projections=true
    msg_ok "Updated $APP to ${RELEASE}"

    msg_info "Starting $APP"
    systemctl start zitadel
    msg_ok "Started $APP"

    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080/ui/console${CL}"
