# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Proxmox VE Helper-Scripts — a community collection of Bash scripts that automate LXC container and VM creation on Proxmox VE. Each application requires exactly two files: a CT script (`ct/AppName.sh`) that runs on the Proxmox host and an install script (`install/appname-install.sh`) that runs inside the container. The install script is never invoked directly by users.

## Validation (no build system — scripts only)

```bash
# Syntax check
bash -n ct/myapp.sh
bash -n install/myapp-install.sh

# Static analysis
shellcheck ct/myapp.sh
shellcheck install/myapp-install.sh
```

Real testing requires an actual Proxmox host. Push to your fork and test via curl:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/ProxmoxVE/main/ct/myapp.sh)"
```
GitHub takes 10–30 seconds to serve updated raw files after a push.

## Fork Setup & PR Workflow

```bash
bash docs/contribution/setup-fork.sh --full  # updates 600+ curl URLs to your fork
```

**CRITICAL**: `setup-fork.sh` modifies 600+ files. PRs must contain ONLY your 2 new files. Use cherry-pick:

```bash
git fetch upstream
git checkout -b submit/myapp upstream/main
cp ../your-work-branch/ct/myapp.sh ct/myapp.sh
cp ../your-work-branch/install/myapp-install.sh install/myapp-install.sh
git add ct/myapp.sh install/myapp-install.sh
git commit -m "feat: add MyApp"
git diff upstream/main --name-only  # must show ONLY your 2 files
```

## Naming Conventions

| File | Convention |
|------|-----------|
| `ct/AppName.sh` | Title Case (e.g. `PiHole.sh`, `NextCloud.sh`) |
| `install/appname-install.sh` | lowercase with hyphens |
| `ct/headers/appname` | lowercase, no extension |
| `defaults/appname.vars` | lowercase |

`NSAPP` is automatically derived from `APP` (lowercase, no spaces) — it drives the install script filename.

## Architecture

```
misc/build.func          # Main orchestrator sourced by all CT scripts (~3800 lines)
misc/tools.func          # Helper functions: setup_nodejs, setup_postgresql, fetch_and_deploy_gh_release, etc.
misc/core.func           # UI/color utilities, msg_info/msg_ok/msg_error
misc/install.func        # Container setup (setting_up_container, network_check, update_os)
misc/error_handler.func  # catch_errors, exit code handling
misc/alpine-install.func # Alpine-specific container setup
misc/alpine-tools.func   # Alpine-specific tool helpers
misc/cloud-init.func     # VM cloud-init configuration
ct/                      # Host-side container creation scripts
install/                 # Container-side installation scripts
vm/                      # VM creation scripts
tools/pve/               # Proxmox management utilities
```

`build.func` is loaded by CT scripts via `source <(curl -fsSL ...)`. It exposes `start`, `build_container`, `description`, `variables`, `color`, `catch_errors`, `header_info`, `check_for_gh_release`, `fetch_and_deploy_gh_release`, and all `setup_*` functions from `tools.func`.

## CT Script Structure (`ct/AppName.sh`)

```bash
#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/Hotfirenet/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: YourName
# License: MIT | https://github.com/Hotfirenet/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/owner/repo

APP="AppName"
var_tags="${var_tags:-tag1;tag2}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
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
  if [[ ! -d /opt/appname ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
  if check_for_gh_release "appname" "owner/repo"; then
    msg_info "Stopping Service"; systemctl stop appname; msg_ok "Stopped Service"
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "appname" "owner/repo" "tarball" "latest" "/opt/appname"
    msg_info "Starting Service"; systemctl start appname; msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:PORT${CL}"
```

## Install Script Structure (`install/appname-install.sh`)

```bash
#!/usr/bin/env bash
# Copyright header...

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y dependency1 dependency2
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs                         # or setup_uv, setup_go, etc.
PG_DB_NAME="mydb" PG_DB_USER="myuser" setup_postgresql_db

fetch_and_deploy_gh_release "appname" "owner/repo" "tarball" "latest" "/opt/appname"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/appname.service
[Unit]
Description=AppName Service
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/appname
ExecStart=/usr/bin/node /opt/appname/server.js
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now appname
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
```

## Key Rules

**Always use `tools.func` helpers — never implement custom equivalents:**

| Task | Wrong | Right |
|------|-------|-------|
| Download a GitHub release | custom `wget`/`curl` + `tar` | `fetch_and_deploy_gh_release "app" "owner/repo"` |
| Check for update | manual curl + jq version compare | `check_for_gh_release "app" "owner/repo"` |
| Install Node.js | curl NodeSource pipe bash | `NODE_VERSION="22" setup_nodejs` |
| Install PostgreSQL | manual apt + config | `PG_VERSION="16" setup_postgresql` |
| Create DB | manual `psql` commands | `PG_DB_NAME="db" PG_DB_USER="u" setup_postgresql_db` |

**`tools.func` functions have built-in `msg_info`/`msg_ok` — never wrap them in extra message blocks.** This includes: `fetch_and_deploy_gh_release`, `check_for_gh_release`, `setup_nodejs`, `setup_postgresql`, `setup_mariadb`, `setup_go`, `setup_java`, `setup_php`, `setup_uv`, `setup_rust`, `setup_ruby`, `setup_composer`, `setup_ffmpeg`, `setup_imagemagick`, `setup_adminer`, `setup_hwaccel`.

**Other hard rules:**
- Never use Docker — all installs are bare-metal on the LXC container
- All `apt`/`npm`/build commands must be prefixed with `$STD` to suppress output
- No `sudo` — containers run as root
- No separate system users for apps
- No `systemctl daemon-reload` for new service files
- `.env` files use `KEY=VALUE`, never `export KEY=VALUE`
- Write multi-line config with heredocs, never `echo >>` chains
- No unnecessary variables — only create when truly reused
- Always end `update_script()` with `exit`
- Always end install scripts with `motd_ssh`, `customize`, `cleanup_lxc`
- Default OS: Debian 13 unless application requires otherwise

## `fetch_and_deploy_gh_release` Modes

```bash
fetch_and_deploy_gh_release "app" "owner/repo"                                      # tarball (default)
fetch_and_deploy_gh_release "app" "owner/repo" "binary"                             # .deb package
fetch_and_deploy_gh_release "app" "owner/repo" "prebuild" "latest" "/opt/app" "file.tar.gz"
fetch_and_deploy_gh_release "app" "owner/repo" "singlefile" "latest" "/opt/app" "binary-linux-amd64"
CLEAN_INSTALL=1 fetch_and_deploy_gh_release "app" "owner/repo" ...                 # wipe before deploy
```

## dev_mode Flags (Testing)

```bash
dev_mode="trace,keep" bash -c "$(curl -fsSL .../ct/myapp.sh)"
```

Flags: `trace` (set -x), `keep` (don't delete on failure), `pause`, `breakpoint`, `logs` (save to `/var/log/community-scripts/`), `dryrun`, `motd`.

## Website Metadata

Do **not** add JSON files to the repo. Website metadata (description, logo, categories, etc.) is submitted via the **Report issue** button on the script's page at community-scripts.org.
