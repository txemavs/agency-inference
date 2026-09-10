# agency-inference

**Nodos de inferencia GPU-edge para Agency** — Ollama, vLLM y más.

> ⚠️ Este repositorio NO contiene código de Agency. Es un stack de inferencia independiente que cualquier PC con GPU NVIDIA puede ejecutar para exponer modelos LLM en red local o Tailscale.

---

## Qué es / What is this

Stack Docker para exponer servicios de inferencia LLM en tu red local:

- **Ollama** — API nativa en puerto 11434, fácil gestión de modelos
- **vLLM** — API compatible OpenAI en puerto 8000, alto rendimiento

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
# Editar .env primero:
# VLLM_MODEL=meta-llama/Llama-3.2-1B-Instruct

docker compose --profile vllm up -d
```

Verificar:

```bash
curl http://localhost:8000/v1/models
```

### 4. Ejecutar ambos (puertos diferentes)

```bash
docker compose --profile ollama --profile vllm up -d
```

- Ollama: `http://localhost:11434`
- vLLM: `http://localhost:8000/v1`

### 5. Sin GPU (CPU-only) / GPU-less hosts

Para máquinas sin GPU NVIDIA (CI, portátiles, VMs) usa el override
`docker-compose.cpu.yml`, que elimina la reserva de GPU y ejecuta Ollama en CPU:

```bash
docker compose -f docker-compose.yml -f docker-compose.cpu.yml \
  --profile ollama up -d
docker exec -it inference-ollama ollama pull llama3.2:1b
curl http://localhost:11434/api/generate \
  -d '{"model":"llama3.2:1b","prompt":"hola","stream":false}'
```

> vLLM requiere GPU y no se cubre en modo CPU.

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
```

### Acceso desde Tailscale

Si tienes Tailscale instalado, otros dispositivos de tu red Tailscale pueden acceder:

```bash
# Desde otro PC en tu Tailscale
curl http://mi-pc-gpu.tail1234.ts.net:11434/api/tags
```

---

## Cómo lo usará Agency / Agency Integration

Agency registrará estos endpoints en su catálogo de modelos:

```
Host: mi-pc-gpu.local:11434  (Ollama)
Host: mi-pc-gpu.local:8000   (vLLM)
```

**No hay código en este repo que conecte con Agency.** La integración se hace desde Agency configurando la URL del servidor de inferencia.

---

## Estructura

```
.
├── docker-compose.yml       # Perfiles: ollama, vllm (GPU)
├── docker-compose.cpu.yml   # Override CPU-only (sin GPU)
├── .cursor/                 # Entorno para Cursor Cloud Agents
├── .env.example             # Template de configuración
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

### Logs

```bash
docker compose --profile ollama logs -f
docker compose --profile vllm logs -f
```

---

## Licencia

MIT
