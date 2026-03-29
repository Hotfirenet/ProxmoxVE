#!/usr/bin/env bash

# Copyright (c) 2021-2026 Johan VIVIEN
# Author: Johan VIVIEN
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/anthropics/claude-code

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  curl \
  git \
  ca-certificates \
  gnupg
msg_ok "Installed Dependencies"

msg_info "Installing Node.js 22"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
  >/etc/apt/sources.list.d/nodesource.list
$STD apt update
$STD apt install -y nodejs
msg_ok "Installed Node.js $(node --version)"

msg_info "Installing Claude CLI"
$STD npm install -g @anthropic-ai/claude-code
msg_ok "Installed Claude CLI $(claude --version)"

msg_info "Setting up workspace"
mkdir -p /opt/claude-workspace
msg_ok "Workspace ready at /opt/claude-workspace"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/claude-remote.service
[Unit]
Description=Claude CLI Remote Control
After=network.target
Documentation=https://docs.anthropic.com/en/docs/claude-code

[Service]
Type=simple
User=root
WorkingDirectory=/opt/claude-workspace
ExecStart=/usr/local/bin/claude remote-control
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl enable claude-remote
msg_ok "Created Service (run 'claude /login' then 'systemctl start claude-remote')"

motd_ssh
customize
cleanup_lxc
