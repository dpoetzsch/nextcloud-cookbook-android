#!/usr/bin/env bash
# Provision a fresh Ubuntu 24.04 VM for building, testing and running the
# Nextcloud Cookbook Android app headlessly. Idempotent: safe to re-run.
#
# Usage:  ./devenv/setup.sh          (from the repo root, as the normal user with sudo)
# Then:   log out / back in once (or `newgrp kvm`) so the kvm + docker groups apply.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_TOOLS_ZIP="commandlinetools-linux-13114758_latest.zip"
SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"
AVD_NAME="cookbook"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# --- 1. System packages ------------------------------------------------------
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  log "Adding Docker's official apt repository"
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

log "Installing apt packages (JDK 21, Docker, emulator runtime libs)"
sudo apt-get update -qq
# Note: use docker-ce (Docker's repo), NOT Ubuntu's docker.io/docker-compose-v2 — they conflict.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  openjdk-21-jdk-headless unzip curl git \
  docker-ce docker-ce-cli containerd.io docker-compose-plugin \
  libpulse0 libnss3 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxtst6 \
  libgl1 libdrm2 libasound2t64 libxkbfile1 libbz2-1.0 libnspr4 \
  imagemagick

log "Adding $USER to kvm + docker groups"
sudo usermod -aG kvm,docker "$USER"
sudo systemctl enable --now docker

# --- 2. Android SDK ------------------------------------------------------------
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "Installing Android command-line tools into $SDK"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/clt.zip" "https://dl.google.com/android/repository/$CMDLINE_TOOLS_ZIP"
  unzip -q "$tmp/clt.zip" -d "$tmp"
  mkdir -p "$SDK/cmdline-tools"
  rm -rf "$SDK/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -rf "$tmp"
fi

export ANDROID_HOME="$SDK"
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:$SDK/emulator:$PATH"

log "Installing SDK packages"
yes | sdkmanager --licenses >/dev/null || true
sdkmanager --install \
  "platform-tools" "emulator" \
  "platforms;android-36" "build-tools;36.0.0" "build-tools;35.0.0" \
  "$SYSTEM_IMAGE" >/dev/null

# --- 3. Emulator (AVD) ---------------------------------------------------------
if ! avdmanager list avd -c | grep -qx "$AVD_NAME"; then
  log "Creating AVD '$AVD_NAME'"
  echo no | avdmanager create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" -d pixel_6
  cat >> "$HOME/.android/avd/$AVD_NAME.avd/config.ini" <<'EOF'
hw.ramSize=3072
disk.dataPartition.size=6G
hw.keyboard=yes
EOF
fi

# --- 4. Shell environment ------------------------------------------------------
if ! grep -q 'ANDROID_HOME' "$HOME/.bashrc"; then
  log "Adding Android env vars to ~/.bashrc"
  cat >> "$HOME/.bashrc" <<EOF

# Android SDK (added by devenv/setup.sh)
export ANDROID_HOME="$SDK"
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH"
EOF
fi

echo "sdk.dir=$SDK" > "$REPO_DIR/local.properties"

log "Done. Log out and back in (for kvm/docker groups), then see devenv/README.md"
