# install-rootless-docker

## Overview

Automatic installer to enable Docker Rootless mode and set up the installation path and environment variables so you don't have to do it manually.

This repository contains the installer script [rootless-docker-install.sh](rootless-docker-install.sh) which was created to remove the repetitive steps required after a rootful Docker installation: enabling rootless mode, configuring data directories, and creating convenient environment settings.

## Key symbols and helpers in the script
- [`print_usage`](rootless-docker-install.sh)
- [`ensure_rootless_tool`](rootless-docker-install.sh)
- [`restart_rootless_daemon`](rootless-docker-install.sh)
- [`INSTALL_PREFIX`](rootless-docker-install.sh)
- [`DATA_ROOT`](rootless-docker-install.sh)
- [`ENV_FILE`](rootless-docker-install.sh)

## Prerequisites
- A host with rootful Docker already installed.
- Run the script as a non-root user (the script checks and aborts if run as root).
- curl available if the rootless setup tool is not already in PATH.

## Quick start
1. Make the script executable:
   chmod +x rootless-docker-install.sh

2. Run the installer (example):
   ./rootless-docker-install.sh --prefix "$HOME/.docker-rootless" --data-root "/data/docker-rootless"

## Options
- -p, --prefix DIR
  Set base directory for Rootless Docker (defaults to $HOME/.docker-rootless). See [`INSTALL_PREFIX`](rootless-docker-install.sh).
- -d, --data-root DIR
  Set Docker data-root where images/containers/volumes are stored. See [`DATA_ROOT`](rootless-docker-install.sh).
- --no-force
  Do not pass --force to the rootless setup tool. By default the script runs the setup with --force.
- -h, --help
  Show usage and exit. See [`print_usage`](rootless-docker-install.sh).

## What the script does
- Ensures the rootless setup tool (`dockerd-rootless-setuptool.sh`) is available, installing it from https://get.docker.com/rootless if necessary. This logic is handled in [`ensure_rootless_tool`](rootless-docker-install.sh).
- Runs the rootless setup (optionally with --force).
- Writes a docker daemon configuration file with the chosen [`DATA_ROOT`](rootless-docker-install.sh).
- Attempts to restart the rootless daemon using systemd user services when available; otherwise starts `dockerd-rootless.sh` in the background (see [`restart_rootless_daemon`](rootless-docker-install.sh`).
- Creates an environment file at `$INSTALL_PREFIX/rootless-docker-env.sh` (see [`ENV_FILE`](rootless-docker-install.sh)) that:
  - Adds rootless docker binaries to PATH.
  - Sets DOCKER_HOST to the rootless socket.
- Appends a `source` line to `~/.bashrc` to load the environment for new shells.

## Files
- [rootless-docker-install.sh](rootless-docker-install.sh) — main installer script

## Troubleshooting
- If the script warns that `dockerd-rootless.sh` or `dockerd-rootless-setuptool.sh` is not found, ensure the rootless extras package is installed or allow the installer to fetch the static rootless installer (requires curl).
- If systemd --user restart fails, check logs with: journalctl --user -u docker.service

## License
- MIT License