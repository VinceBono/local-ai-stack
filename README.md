# local-ai-stack

[![ci](https://github.com/VinceBono/local-ai-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/VinceBono/local-ai-stack/actions/workflows/ci.yml)

A private AI chat stack you start with one command. [Ollama](https://ollama.com) runs the models, [Open WebUI](https://openwebui.com) gives you the chat page, and nothing leaves your machine.

```bash
git clone https://github.com/VinceBono/local-ai-stack && cd local-ai-stack
docker compose up -d
```

Open <http://localhost:3000>. The first account you create becomes the administrator. The first start downloads about 6 GB (images plus a 2 GB model), so give it a few minutes.

## Why this exists

Most "run AI locally" guides end with a model API listening on every network interface and a chat page with no login. This one starts from the safe settings and makes you opt in to anything wider:

| Default | What it means |
|---|---|
| Web page bound to `127.0.0.1` | Other machines on your network can't open it |
| Ollama has no published port | Only the chat page can reach the model API |
| Login required | No anonymous use; people who sign up after you wait for your approval |
| Telemetry switches off | Open WebUI's anonymous usage reporting is disabled |
| Pinned image versions | An upstream release can't change your stack overnight |

CI starts the whole stack on every change and checks the first three rows, plus that the model really answers ([`scripts/smoke.sh`](scripts/smoke.sh)).

## What you need

- Docker with Compose v2 (Docker Desktop on Windows or macOS, Docker Engine on Linux)
- 8 GB of RAM for the default model on CPU. It works without a GPU, slowly.

## Settings

Copy `.env.example` to `.env` to change anything.

| Setting | Default | Notes |
|---|---|---|
| `MODEL` | `llama3.2:3b` | Downloaded on first start. Any tag from the [Ollama library](https://ollama.com/library) |
| `BIND_ADDRESS` | `127.0.0.1` | See "Reaching it from other devices" before changing |
| `WEBUI_PORT` | `3000` | |

To add another model later: `docker compose exec ollama ollama pull <tag>`, or use Admin Panel → Settings → Models in the web page.

A rough sizing rule: a model needs about its download size in memory, plus 1–2 GB. If it doesn't fit in GPU memory, Ollama runs part of it on the CPU and it gets much slower.

## Using an NVIDIA GPU

Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the Docker host (Docker Desktop on Windows with WSL 2 already includes GPU support), then add the GPU file:

```bash
docker compose -f compose.yaml -f compose.gpu.yaml up -d
docker compose exec ollama nvidia-smi     # should list your card
```

To make that the default, set `COMPOSE_FILE` in `.env` as shown in `.env.example`.

Running this in a Proxmox VM? [`docs/proxmox-gpu-passthrough.md`](docs/proxmox-gpu-passthrough.md) covers handing the card to the VM.

## vLLM (optional)

Ollama is the easy choice for one person trying many models. [vLLM](https://docs.vllm.ai) is built for the opposite case: one model answering many people at once. `compose.vllm.yaml` adds it next to Ollama and connects it to the same chat page:

```bash
docker compose -f compose.yaml -f compose.gpu.yaml -f compose.vllm.yaml up -d
```

It needs an NVIDIA GPU and loads the model in `VLLM_MODEL` (a Hugging Face name) at full precision, so it uses much more GPU memory than Ollama does for a model of the same size. Like Ollama, it has no published port.

## Reaching it from other devices

Keep the default binding and put something that encrypts traffic in front of it:

- **Tailscale:** `tailscale serve --bg 3000` publishes it to your own tailnet over HTTPS.
- **Reverse proxy** (Caddy, nginx, Traefik) with a TLS certificate, on the same host.

Setting `BIND_ADDRESS=0.0.0.0` works on a network you trust, but logins then travel unencrypted. Create your administrator account first: until you do, whoever opens the page first gets it.

Don't publish this stack straight to the internet.

## Everyday commands

```bash
docker compose logs -f open-webui   # watch the chat page start
docker compose pull && docker compose up -d   # after changing a version in compose.yaml
docker compose down                 # stop; chats and models are kept
docker compose down -v              # stop and delete all chats, accounts and models
```

Chats and accounts live in the `open-webui` volume, models in the `ollama` volume. Back up the first one.

## Limits

- Tested in CI on Linux with a CPU only. The GPU and vLLM files are checked for valid syntax but have not been run on a GPU, and the Proxmox guide is written from the upstream documentation, not from a test.
- Single machine, a handful of users. No high availability, no backups, no single sign-on.
- Open WebUI and Ollama are separate projects with their own licenses and release notes. Read theirs before upgrading the pinned versions.

## License

MIT for the files in this repository.
