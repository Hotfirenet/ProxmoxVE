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
$STD apt install -y git
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs

msg_info "Installing Claude CLI"
$STD npm install -g @anthropic-ai/claude-code
msg_ok "Installed Claude CLI $(claude --version)"

msg_info "Setting up Workspace"
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
