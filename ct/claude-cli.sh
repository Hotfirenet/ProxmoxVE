#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Hotfirenet/ProxmoxVE/feat/claude-cli/misc/build.func)
# Copyright (c) 2021-2026 Johan VIVIEN
# Author: Johan VIVIEN
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/anthropics/claude-code

APP="Claude CLI"
var_tags="${var_tags:-ai}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if ! command -v claude &>/dev/null; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating ${APP}"
  npm update -g @anthropic-ai/claude-code
  msg_ok "Updated ${APP} to $(claude --version)"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} SSH into the container, then authenticate:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}claude /login${CL}"
echo -e "${INFO}${YW} Then start the remote-control service:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}systemctl start claude-remote${CL}"
echo -e "${INFO}${YW} Scan the QR code from claude.ai/code on your phone:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}journalctl -u claude-remote -f${CL}"
