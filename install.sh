#!/usr/bin/env bash

# Simplified Xray installer with version prompt or argument mode

set -e

# --- Colors ---
red=$(tput setaf 1)
green=$(tput setaf 2)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

# --- Constants ---
DAT_PATH=${DAT_PATH:-/usr/local/share/xray}
BIN_PATH="/usr/local/bin/xray"
TMP_DIR=$(mktemp -d)
ZIP_FILE="$TMP_DIR/xray.zip"

# --- Functions ---

check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "${red}[ERROR]${reset} You must run this script as root."
    exit 1
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) MACHINE="64" ;;
    aarch64 | armv8*) MACHINE="arm64-v8a" ;;
    armv7l | armv7) MACHINE="arm32-v7a" ;;
    armv6l) MACHINE="arm32-v6" ;;
    mips64le) MACHINE="mips64le" ;;
    riscv64) MACHINE="riscv64" ;;
    *) echo "${red}[ERROR]${reset} Unsupported architecture: $(uname -m)"; exit 1 ;;
  esac
}

get_latest_version() {
  echo "${cyan}[INFO]${reset} Fetching latest Xray version..."
  local tmp_json
  tmp_json=$(mktemp)
  if ! curl -fsSL -o "$tmp_json" https://api.github.com/repos/XTLS/Xray-core/releases/latest; then
    echo "${red}[ERROR]${reset} Failed to get latest version info."
    exit 1
  fi
  LATEST_VERSION=$(grep '"tag_name":' "$tmp_json" | head -n 1 | cut -d '"' -f4)
  rm -f "$tmp_json"
}

download_xray() {
  local version=$1
  local url="https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-${MACHINE}.zip"
  echo "${cyan}[INFO]${reset} Downloading Xray ${version} for ${MACHINE}..."
  if ! curl -fL -o "$ZIP_FILE" "$url"; then
    echo "${red}[ERROR]${reset} Failed to download Xray binary."
    exit 1
  fi
  echo "${green}[OK]${reset} Xray binary downloaded."
}

install_xray() {
  echo "${cyan}[INFO]${reset} Installing Xray..."
  unzip -q "$ZIP_FILE" -d "$TMP_DIR"
  install -m 755 "$TMP_DIR/xray" "$BIN_PATH"
  install -d "$DAT_PATH"
  [[ -f "$TMP_DIR/geoip.dat" ]] && install -m 644 "$TMP_DIR/geoip.dat" "$DAT_PATH/geoip.dat"
  [[ -f "$TMP_DIR/geosite.dat" ]] && install -m 644 "$TMP_DIR/geosite.dat" "$DAT_PATH/geosite.dat"
  echo "${green}[OK]${reset} Xray installed to ${BIN_PATH}"
}

cleanup() {
  rm -rf "$TMP_DIR"
  echo "${cyan}[INFO]${reset} Cleaned up temporary files."
}

# --- Main ---

check_root
detect_arch

if [[ -n "$1" ]]; then
  INSTALL_VERSION="$1"
  echo "${green}[INFO]${reset} Using specified version: ${INSTALL_VERSION}"
else
  echo -n "${cyan}Enter Xray version to install (e.g. v1.8.4) [leave empty for latest]: ${reset}"
  read -r USER_VERSION
  if [[ -z "$USER_VERSION" ]]; then
    get_latest_version
    INSTALL_VERSION="$LATEST_VERSION"
    echo "${green}[INFO]${reset} Using latest version: ${INSTALL_VERSION}"
  else
    INSTALL_VERSION="$USER_VERSION"
    echo "${green}[INFO]${reset} Using specified version: ${INSTALL_VERSION}"
  fi
fi

download_xray "$INSTALL_VERSION"
install_xray
cleanup

echo "${green}[DONE]${reset} Xray ${INSTALL_VERSION} installed successfully!"
