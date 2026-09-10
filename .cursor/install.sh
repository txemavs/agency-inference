#!/usr/bin/env bash
# Idempotent environment bootstrap: ensure Docker is present, pull the Ollama
# image, and warm the default model so snapshots/builds boot ready to serve.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_docker_installed
ensure_dockerd

echo "[env] Pulling Ollama image..."
compose pull

echo "[env] Starting Ollama (CPU) to warm the model cache..."
compose up -d
wait_for_ollama

echo "[env] Preloading model: ${OLLAMA_PRELOAD_MODEL}"
sudo docker exec inference-ollama ollama pull "${OLLAMA_PRELOAD_MODEL}"

echo "[env] Install complete. Models available:"
curl -fsS "http://localhost:${OLLAMA_PORT}/api/tags"
echo
