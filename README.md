# agency-inference

**Nodos de inferencia GPU-edge para Agency** — Ollama, vLLM, ComfyUI, Voice (STT/TTS).

> ⚠️ Este repositorio NO contiene código de Agency. Es un stack de inferencia independiente que cualquier PC con GPU NVIDIA puede ejecutar para exponer servicios de IA en red local o Tailscale.

---

## Qué es / What is this

Stack Docker para exponer servicios de inferencia en tu red local:

| Perfil | Servicio | Puerto | Descripción |
|--------|----------|--------|-------------|
| `ollama` | Ollama | 11434 | LLM local, API nativa |
| `vllm` | vLLM | 8000 | LLM alto rendimiento, API OpenAI |
| `comfy` | ComfyUI | 8188 | Generación de imágenes (nodos) |
| `voice` | Voice STT/TTS | 5002 | Transcripción y síntesis de voz |
| `capabilities` | Capabilities | 9090 | Descubrimiento de servicios |

Freezeable y versionado independientemente de Agency. Puedes usar `v1.0.0` hoy y actualizarlo cuando quieras.

---

## Requisitos / Prerequisites

| Componente | Requerido | Notas |
|------------|-----------|-------|
| Docker + Docker Compose | ✅ | v2.x recomendado |
| NVIDIA GPU | ✅ | Con drivers instalados |
| [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) | ✅ | Para GPU passthrough |
| [Tailscale](https://tailscale.com/) | Recomendado | Para acceso seguro desde otros hosts |

### Verificar NVIDIA Container Toolkit

```bash
# Debe mostrar tu GPU
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

---

## Uso / Usage

### 1. Configurar entorno

```bash
cp .env.example .env
# Editar .env si quieres cambiar puertos o rutas de modelos
```

### 2. Iniciar Ollama

```bash
docker compose --profile ollama up -d
```

Verificar:

```bash
curl http://localhost:11434/api/tags
# {"models":[]}
```

Descargar un modelo:

```bash
docker exec -it inference-ollama ollama pull llama3.2:1b
```

### 3. Iniciar vLLM (opcional)

> ⚠️ **Requiere `VLLM_MODEL` configurado en `.env`** y acceso a HuggingFace. Algunos modelos requieren `HF_TOKEN`.

```bash
docker compose --profile vllm up -d
```

Verificar:

```bash
curl http://localhost:8000/v1/models
```

### 4. Iniciar ComfyUI (opcional)

> ⚠️ **VRAM Warning:** ComfyUI con checkpoints de Stable Diffusion necesita 4-8GB+ VRAM. No ejecutes ComfyUI junto con Ollama/vLLM en GPUs de 6-8GB — usa `--lowvram` o `--cpu` en `COMFY_EXTRA_ARGS`.

```bash
docker compose --profile comfy up -d
```

Verificar:

```bash
curl http://localhost:8188/system_stats
```

Abrir UI en navegador: `http://localhost:8188`

**Nota:** El contenedor inicia sin checkpoints. Para añadir modelos:
1. **Manual:** Coloca archivos `.safetensors` en `COMFY_MODELS/checkpoints/`
2. **ComfyUI Manager:** Instálalo como custom node y descarga desde la UI
3. **Provisioning:** Monta un script en `/root/user-scripts/` ([docs](https://github.com/YanWenKun/ComfyUI-Docker))

### 5. Iniciar Voice STT/TTS (opcional)

> ⚠️ **VRAM Warning:** El modelo Whisper large-v3 necesita ~4GB VRAM. Usa `VOICE_STT_MODEL=Systran/faster-distil-whisper-small.en` para GPUs pequeñas.

```bash
docker compose --profile voice up -d
```

Verificar:

```bash
curl http://localhost:5002/health
```

Transcribir audio (STT):

```bash
curl -X POST http://localhost:5002/v1/audio/transcriptions \
  -F file=@audio.mp3 \
  -F model=whisper-1
```

Sintetizar voz (TTS):

```bash
curl -X POST http://localhost:5002/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model": "tts-1", "input": "Hello world", "voice": "alloy"}' \
  --output speech.mp3
```

### 6. Ejecutar múltiples perfiles

```bash
# Ollama + ComfyUI (LLM + imágenes)
docker compose --profile ollama --profile comfy up -d

# Todos los servicios (requiere GPU con mucha VRAM)
docker compose --profile ollama --profile comfy --profile voice --profile capabilities up -d
```

> ⚠️ **VRAM compartida:** Cada servicio reserva la GPU completa. En GPUs de 6-8GB, ejecuta solo **un** servicio GPU-intensivo a la vez. Ollama es más ligero y puede coexistir con otros.

**Puertos por defecto:**
- Ollama: `http://localhost:11434`
- vLLM: `http://localhost:8000`
- ComfyUI: `http://localhost:8188`
- Voice: `http://localhost:5002`
- Capabilities: `http://localhost:9090`

---

## Capabilities / Descubrimiento de Servicios

El archivo `capabilities.json` describe los servicios disponibles en este nodo. Agency puede consumirlo para auto-descubrir qué capacidades ofrece el nodo.

### Servir capabilities.json

```bash
# Opción 1: Perfil capabilities (nginx en puerto 9090)
docker compose --profile capabilities up -d
curl http://localhost:9090/capabilities.json

# Opción 2: Leer el archivo directamente
cat capabilities.json
```

### Formato del archivo

```json
{
  "node": {
    "name": "agency-inference",
    "version": "1.0.0"
  },
  "services": [
    {
      "id": "ollama",
      "kind": "llm.ollama",
      "port": 11434,
      "base_url": "http://${HOST}:11434",
      "health_path": "/api/tags"
    },
    ...
  ]
}
```

**Kinds disponibles:**
- `llm.ollama` — LLM con API Ollama nativa
- `llm.vllm` — LLM con API OpenAI-compatible
- `image.comfy` — Generación de imágenes ComfyUI
- `voice.stt_tts` — Speech-to-text y text-to-speech

---

## Integración con Agency / Agency Integration

### 1. Registrar el nodo manualmente

Desde Agency, configura los endpoints del nodo de inferencia:

```bash
# En tu .env de Agency o settings
OLLAMA_HOST=http://mi-pc-gpu.tail1234.ts.net:11434
COMFYUI_URL=http://mi-pc-gpu.tail1234.ts.net:8188
VOICE_URL=http://mi-pc-gpu.tail1234.ts.net:5002
```

### 2. Descubrir capabilities

```bash
# Desde Agency, consultar qué servicios ofrece el nodo
curl http://mi-pc-gpu.tail1234.ts.net:9090/capabilities.json
```

### 3. Verificar conectividad

```bash
# Healthchecks por servicio
curl http://mi-pc-gpu.tail1234.ts.net:11434/api/tags      # Ollama
curl http://mi-pc-gpu.tail1234.ts.net:8000/v1/models      # vLLM
curl http://mi-pc-gpu.tail1234.ts.net:8188/system_stats   # ComfyUI
curl http://mi-pc-gpu.tail1234.ts.net:5002/health         # Voice
```

### Mapeo Agency → Inference Node

| Servicio Agency | Variable/Setting | Endpoint Inference |
|-----------------|------------------|-------------------|
| LLM (Ollama) | `OLLAMA_HOST` | `http://<node>:11434` |
| LLM (OpenAI-compat) | `OPENAI_API_BASE` | `http://<node>:8000/v1` |
| Imágenes | `COMFYUI_URL` | `http://<node>:8188` |
| Voz STT | `STT_URL` | `http://<node>:5002/v1/audio/transcriptions` |
| Voz TTS | `TTS_URL` | `http://<node>:5002/v1/audio/speech` |

---

## Red y Seguridad / Network & Security

Los servicios escuchan en `0.0.0.0` para permitir acceso desde la LAN.

### ⚠️ IMPORTANTE

- **NUNCA expongas estos puertos a Internet** sin autenticación
- Usa **Tailscale** para acceso seguro entre máquinas
- O configura firewall para permitir solo IPs de tu red local

```bash
# Ejemplo: solo permitir red local
sudo ufw allow from 192.168.1.0/24 to any port 11434
sudo ufw allow from 192.168.1.0/24 to any port 8000
sudo ufw allow from 192.168.1.0/24 to any port 8188
sudo ufw allow from 192.168.1.0/24 to any port 5002
sudo ufw allow from 192.168.1.0/24 to any port 9090
```

### Acceso desde Tailscale

Si tienes Tailscale instalado, otros dispositivos de tu red Tailscale pueden acceder:

```bash
# Desde otro PC en tu Tailscale
curl http://mi-pc-gpu.tail1234.ts.net:11434/api/tags
curl http://mi-pc-gpu.tail1234.ts.net:9090/capabilities.json
```

---

## Estructura / Structure

```
.
├── docker-compose.yml   # Perfiles: ollama, vllm, comfy, voice, capabilities
├── capabilities.json    # Descripción de servicios para Agency
├── .env.example         # Template de configuración
├── .gitignore
└── README.md
```

---

## Troubleshooting

### GPU no detectada

```bash
# Verificar drivers NVIDIA
nvidia-smi

# Verificar container toolkit
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### vLLM no arranca

- Verifica `VLLM_MODEL` en `.env`
- Algunos modelos necesitan `HF_TOKEN` para HuggingFace
- Modelos grandes pueden requerir más VRAM

### ComfyUI sin modelos

El contenedor arranca vacío. Descarga checkpoints manualmente o usa ComfyUI Manager.

### Voice lento en primera ejecución

Los modelos Whisper y Kokoro se descargan en el primer uso (~2-4GB). Espera a que termine.

### Logs

```bash
docker compose --profile ollama logs -f
docker compose --profile vllm logs -f
docker compose --profile comfy logs -f
docker compose --profile voice logs -f
```

---

## Licencia / License

MIT
