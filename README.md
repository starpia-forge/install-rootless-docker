# install-rootless-docker

## Overview

Automatic installer to enable Docker Rootless mode and set up the installation path and environment variables so you don't have to do it manually.

This repository contains the installer script [install-rootless-docker.sh](install-rootless-docker.sh) which was created to remove the repetitive steps required after a rootful Docker installation: enabling rootless mode, configuring data directories, and creating convenient environment settings.

## Key symbols and helpers in the script
- [`print_usage`](install-rootless-docker.sh)
- [`ensure_rootless_tool`](install-rootless-docker.sh)
- [`restart_rootless_daemon`](install-rootless-docker.sh)
- [`INSTALL_PREFIX`](install-rootless-docker.sh)
- [`DATA_ROOT`](install-rootless-docker.sh)
- [`ENV_FILE`](install-rootless-docker.sh)

## Prerequisites
- A host with rootful Docker already installed.
- Run the script as a non-root user (the script checks and aborts if run as root).
- curl available if the rootless setup tool is not already in PATH.

## Quick start
1. Make the script executable:
   chmod +x install-rootless-docker.sh

2. Run the installer (example):
   ./install-rootless-docker.sh --prefix "$HOME/.docker-rootless" --data-root "/data/docker-rootless"

## Options
- -p, --prefix DIR
  Set base directory for Rootless Docker (defaults to $HOME/.docker-rootless). See [`INSTALL_PREFIX`](install-rootless-docker.sh).
- -d, --data-root DIR
  Set Docker data-root where images/containers/volumes are stored. See [`DATA_ROOT`](install-rootless-docker.sh).
- --no-force
  Do not pass --force to the rootless setup tool. By default the script runs the setup with --force.
- -h, --help
  Show usage and exit. See [`print_usage`](install-rootless-docker.sh).

## What the script does
- Ensures the rootless setup tool (`dockerd-rootless-setuptool.sh`) is available, installing it from https://get.docker.com/rootless if necessary. This logic is handled in [`ensure_rootless_tool`](install-rootless-docker.sh).
- Runs the rootless setup (optionally with --force).
- Writes a docker daemon configuration file with the chosen [`DATA_ROOT`](install-rootless-docker.sh).
- Attempts to restart the rootless daemon using systemd user services when available; otherwise starts `dockerd-rootless.sh` in the background (see [`restart_rootless_daemon`](install-rootless-docker.sh`).
- Creates an environment file at `$INSTALL_PREFIX/rootless-docker-env.sh` (see [`ENV_FILE`](install-rootless-docker.sh)) that:
  - Adds rootless docker binaries to PATH.
  - Sets DOCKER_HOST to the rootless socket.
- Appends a `source` line to `~/.bashrc` to load the environment for new shells.

## Files
- [install-rootless-docker.sh](install-rootless-docker.sh) — main installer script

## Troubleshooting
- If the script warns that `dockerd-rootless.sh` or `dockerd-rootless-setuptool.sh` is not found, ensure the rootless extras package is installed or allow the installer to fetch the static rootless installer (requires curl).
- If systemd --user restart fails, check logs with: journalctl --user -u docker.service

## License
- [MIT License](LICENSE)