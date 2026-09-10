#!/usr/bin/env bash
# Per-boot startup: bring the Docker daemon and the Ollama (CPU) service up.
# Safe to run repeatedly; compose reconciles the already-created container.
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_docker_installed
ensure_dockerd

echo "[env] Bringing up Ollama (CPU)..."
compose up -d
wait_for_ollama

echo "[env] Ollama is ready on http://localhost:${OLLAMA_PORT}"
