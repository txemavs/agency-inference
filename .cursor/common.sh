#!/usr/bin/env bash
# Shared helpers for the Cloud Agent environment scripts.
#
# The repo ships a docker-compose stack for GPU inference (Ollama + vLLM).
# Cloud Agent VMs have no NVIDIA GPU and run Docker nested, so these helpers
# bring up Ollama on CPU using docker-compose.cpu.yml. vLLM is GPU-only and is
# intentionally not started here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERD_LOG="/var/log/dockerd.log"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_PRELOAD_MODEL="${OLLAMA_PRELOAD_MODEL:-llama3.2:1b}"

# CPU-only Ollama compose invocation.
compose() {
  sudo docker compose \
    -f "$REPO_ROOT/docker-compose.yml" \
    -f "$REPO_ROOT/docker-compose.cpu.yml" \
    --profile ollama "$@"
}

# Install Docker Engine + compose plugin if missing (idempotent). When the
# environment boots from a snapshot/build that already has Docker, this is a
# no-op fast path.
ensure_docker_installed() {
  if command -v docker >/dev/null 2>&1; then
    return 0
  fi
  echo "[env] Installing Docker Engine..."
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  local codename
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  # --force-conf{def,old} avoids the interactive /etc/fuse.conf conffile prompt
  # (DEBIAN_FRONTEND alone does not control dpkg conffile prompts).
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
    docker-compose-plugin fuse-overlayfs
}

# Start the Docker daemon in the background if it is not already responsive.
# Uses fuse-overlayfs because overlayfs is unavailable in the nested VM.
ensure_dockerd() {
  if sudo docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "[env] Starting dockerd..."
  sudo sh -c "nohup dockerd --storage-driver=fuse-overlayfs >>'$DOCKERD_LOG' 2>&1 &"
  for _ in $(seq 1 60); do
    if sudo docker info >/dev/null 2>&1; then
      echo "[env] dockerd is up."
      return 0
    fi
    sleep 1
  done
  echo "[env] dockerd failed to start; last log lines:" >&2
  sudo tail -n 40 "$DOCKERD_LOG" >&2 || true
  return 1
}

# Block until the Ollama HTTP API answers.
wait_for_ollama() {
  for _ in $(seq 1 60); do
    if curl -fsS "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "[env] Ollama did not become ready on port ${OLLAMA_PORT}." >&2
  return 1
}
