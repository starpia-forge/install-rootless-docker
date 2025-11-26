#!/bin/bash
# Rootless Docker Install script
# Repository: https://github.com/starpia-forge/install-rootless-docker
# Licensed under the MIT License. See LICENSE file in the project root for details.

set -euo pipefail

# Default configuration values
DEFAULT_PREFIX="$HOME/.docker-rootless"
INSTALL_PREFIX="$DEFAULT_PREFIX"
DATA_ROOT=""
SETUP_FORCE=1   # run dockerd-rootless-setuptool.sh with --force by default

print_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Automatic installer for Rootless Docker on a host where rootful Docker is already installed.
This script must be run as a non-root user.

Options:
  -p, --prefix DIR       Base directory for Rootless Docker (default: $DEFAULT_PREFIX)
                         The default data-root will be DIR/data if not explicitly set.
  -d, --data-root DIR    Docker data-root directory (where images/containers/volumes are stored)
  --no-force             Do NOT pass --force to dockerd-rootless-setuptool.sh
  -h, --help             Show this help message and exit

Examples:
  $0 --prefix "\$HOME/docker-rootless" --data-root "/data/docker-rootless"
EOF
}

# Check for root privileges (must NOT be run as root)
if [ "$(id -u)" -eq 0 ]; then
  echo "[ERROR] This script must NOT be run as root." >&2
  exit 1
fi

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--prefix|--install-root)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] Option $1 requires a directory argument." >&2
        exit 1
      fi
      INSTALL_PREFIX="$2"
      shift 2
      ;;
    -d|--data-root)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] Option $1 requires a directory argument." >&2
        exit 1
      fi
      DATA_ROOT="$2"
      shift 2
      ;;
    --no-force)
      SETUP_FORCE=0
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Normalize paths to absolute paths when possible
if command -v readlink >/dev/null 2>&1; then
  INSTALL_PREFIX="$(readlink -f "$INSTALL_PREFIX" 2>/dev/null || echo "$INSTALL_PREFIX")"
  if [[ -n "$DATA_ROOT" ]]; then
    DATA_ROOT="$(readlink -f "$DATA_ROOT" 2>/dev/null || echo "$DATA_ROOT")"
  fi
fi

# Default data-root: PREFIX/data if not specified
if [[ -z "$DATA_ROOT" ]]; then
  DATA_ROOT="$INSTALL_PREFIX/data"
fi

echo "[INFO] INSTALL_PREFIX  = $INSTALL_PREFIX"
echo "[INFO] DATA_ROOT       = $DATA_ROOT"

# Create directories
mkdir -p "$INSTALL_PREFIX"
mkdir -p "$DATA_ROOT"

if [[ ! -w "$INSTALL_PREFIX" ]]; then
  echo "[ERROR] INSTALL_PREFIX is not writable: $INSTALL_PREFIX" >&2
  exit 1
fi
if [[ ! -w "$DATA_ROOT" ]]; then
  echo "[ERROR] DATA_ROOT is not writable: $DATA_ROOT" >&2
  exit 1
fi

# Ensure dockerd-rootless-setuptool.sh is available
ensure_rootless_tool() {
  if command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    echo "[INFO] Using existing dockerd-rootless-setuptool.sh found in PATH."
    return 0
  fi

  echo "[INFO] dockerd-rootless-setuptool.sh not found in PATH."
  echo "[INFO] Attempting to install Rootless Docker via https://get.docker.com/rootless."

  if ! command -v curl >/dev/null 2>&1; then
    echo "[ERROR] curl is required to download the rootless installation script." >&2
    echo "       Alternatively, ensure the docker-ce-rootless-extras package is installed by an administrator." >&2
    exit 1
  fi

  # get.docker.com/rootless installs static rootless docker in user space
  curl -fsSL https://get.docker.com/rootless | sh

  if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    echo "[ERROR] dockerd-rootless-setuptool.sh still not found after running get.docker.com/rootless." >&2
    exit 1
  fi
}

ensure_rootless_tool

# Run Rootless Docker setup
echo "[INFO] Running Rootless Docker setup."

SETUP_ARGS=(install)
if [[ "$SETUP_FORCE" -eq 1 ]]; then
  SETUP_ARGS+=(--force)
  echo "[INFO] Proceeding with --force even if /var/run/docker.sock (rootful Docker) exists."
fi

dockerd-rootless-setuptool.sh "${SETUP_ARGS[@]}"

echo "[INFO] Basic Rootless Docker setup completed."

# Configure daemon.json with data-root
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DOCKER_CFG_DIR="$CFG_DIR/docker"
DAEMON_JSON="$DOCKER_CFG_DIR/daemon.json"

mkdir -p "$DOCKER_CFG_DIR"

if [[ -f "$DAEMON_JSON" ]]; then
  ts=$(date +%s)
  backup="$DAEMON_JSON.bak.$ts"
  echo "[INFO] Existing daemon.json found, creating backup: $backup"
  cp "$DAEMON_JSON" "$backup"
fi

cat > "$DAEMON_JSON" <<EOF
{
  "data-root": "$DATA_ROOT"
}
EOF

echo "[INFO] Wrote data-root configuration to $DAEMON_JSON"
echo "       {
           \"data-root\": \"$DATA_ROOT\"
         }"

# Restart rootless daemon depending on environment
restart_rootless_daemon() {
  echo "[INFO] restart_rootless_daemon() called."

  # First check if systemctl exists
  if command -v systemctl >/dev/null 2>&1; then
    # Then check if systemd --user is usable for this user
    if systemctl --user show-environment >/dev/null 2>&1; then
      echo "[INFO] Detected systemd --user. Restarting docker.service."

      # Temporarily disable 'set -e' inside this block to avoid aborting on non-zero
      set +e
      systemctl --user daemon-reload
      systemctl --user restart docker.service
      rc=$?
      set -e

      if [[ $rc -ne 0 ]]; then
        echo "[WARN] systemctl --user restart docker.service failed." >&2
        echo "       Check logs with: journalctl --user -u docker.service" >&2
      else
        echo "[INFO] docker.service restarted successfully."
      fi
      return
    else
      echo "[INFO] systemctl is available, but systemd --user does not seem active for this user."
      echo "[INFO] Falling back to starting dockerd-rootless.sh manually."
    fi
  else
    echo "[INFO] systemctl not found on this system."
    echo "[INFO] Falling back to starting dockerd-rootless.sh manually."
  fi

  # Fallback path: start dockerd-rootless.sh directly
  if ! command -v dockerd-rootless.sh >/dev/null 2>&1; then
    echo "[WARN] dockerd-rootless.sh not found in PATH; cannot start the daemon automatically." >&2
    echo "       Ensure dockerd-rootless.sh is in your PATH and start it manually if needed." >&2
    return
  fi

  # daemon.json already contains data-root, so no extra flags are necessary
  nohup dockerd-rootless.sh >/dev/null 2>&1 &
  echo "[INFO] dockerd-rootless.sh started in the background."
}

restart_rootless_daemon

# Create environment file for convenient usage
BIN_PATH="$(command -v dockerd-rootless.sh || true)"
if [ -z "$BIN_PATH" ]; then
  echo "[WARN] dockerd-rootless.sh not found in PATH; environment file will not be created."
  exit 0
fi

BIN_DIR="$(dirname "$BIN_PATH")"
ENV_FILE="$INSTALL_PREFIX/rootless-docker-env.sh"

cat > "$ENV_FILE" <<EOF
# Rootless Docker environment settings (auto-generated)

# Rootless Docker binaries in PATH
export PATH="$BIN_DIR:\$PATH"

# Set DOCKER_HOST to the rootless docker socket if not already set
if [ -z "\${DOCKER_HOST:-}" ]; then
  if [ -n "\${XDG_RUNTIME_DIR:-}" ]; then
    export DOCKER_HOST="unix://\${XDG_RUNTIME_DIR}/docker.sock"
  else
    export DOCKER_HOST="unix:///run/user/$UID/docker.sock"
  fi
fi
EOF

echo "[INFO] Environment file created: $ENV_FILE"

# Automatically add 'source ENV_FILE' to ~/.bashrc
BASHRC="$HOME/.bashrc"

if [ -f "$BASHRC" ]; then
  if grep -Fq "$ENV_FILE" "$BASHRC"; then
    echo "[INFO] ~/.bashrc already references $ENV_FILE. No changes made to ~/.bashrc."
  else
    echo "source \"$ENV_FILE\"" >> "$BASHRC"
    echo "[INFO] Appended 'source \"$ENV_FILE\"' to ~/.bashrc."
  fi
else
  echo "source \"$ENV_FILE\"" > "$BASHRC"
  echo "[INFO] Created ~/.bashrc and added 'source \"$ENV_FILE\"'."
fi

echo
echo "[INFO] Rootless Docker environment will be loaded automatically for new bash shells."
echo "[INFO] To apply it in the current shell, run:  source ~/.bashrc"
echo
echo "[INFO] Quick test after reloading shell:"
echo "       docker context ls"
echo "       docker info"