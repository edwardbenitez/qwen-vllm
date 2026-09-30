# Offline Qwen CPU vLLM Image

This project downloads a complete snapshot of `Qwen/Qwen2.5-0.5B-Instruct` and packages it into an official vLLM CPU image. The resulting image serves the model without downloading model files at runtime.

## Download Model Artifacts

Install [uv](https://docs.astral.sh/uv/) and run:

```sh
uv run download_model.py
```

The script stores all model repository files in `models/Qwen2.5-0.5B-Instruct` and prints the resolved Hugging Face commit SHA. To reproduce a particular snapshot, pass that SHA on later downloads:

```sh
uv run download_model.py --revision <commit-sha>
```

For a Hugging Face environment that requires authentication, provide `HF_TOKEN` before running the script. Do not pass the token to the Docker build; it is not required after the model has been downloaded.

```sh
HF_TOKEN=... uv run download_model.py
```

## Build Image

Use the ARM64 image on Apple Silicon or other Linux ARM hosts:

```sh
docker build --build-arg VLLM_IMAGE_TAG=latest-arm64 --tag qwen2.5-0.5b-cpu:arm64 .
```

Use the x86_64 image for Intel/AMD Linux hosts:

```sh
docker build --build-arg VLLM_IMAGE_TAG=latest-x86_64 --tag qwen2.5-0.5b-cpu:amd64 .
```

For an AMD64 image built on an ARM64 Mac, use a buildx builder that supports `linux/amd64`:

```sh
docker buildx build --platform linux/amd64 \
  --build-arg VLLM_IMAGE_TAG=latest-x86_64 \
  --tag qwen2.5-0.5b-cpu:amd64 --load .
```

This creates an AMD64 image; it does not make the Mac's ARM CPU an AMD64 CPU. Rancher Desktop can run that image using emulation, but CPU-heavy vLLM compilation and inference may be very slow or stall during worker startup. Use the ARM64 image for local Apple Silicon testing, and use the AMD64 image on a native Intel/AMD Linux host for representative AMD64 validation. The `No available shared memory broadcast block found` message can occur while a worker is still compiling; inspect subsequent logs to see whether startup completes or the worker exits.

`latest-*` follows vLLM releases. Replace it with a release-specific tag, such as `v<version>-arm64`, after selecting the version you intend to maintain.

## Run Server

The CPU backend requires a Linux host with the CPU features supported by the selected vLLM image. Docker Desktop on macOS runs the Linux container in its VM, so production compatibility depends on the eventual Linux deployment host.

Allocate enough memory to the Docker VM before starting the container. The model weights require about 1 GiB alone; allocate at least 4 GiB for this small model, plus any KV cache configured for request concurrency. A startup log reporting available RAM below the checkpoint size means the container runtime must be given more memory.

```sh
docker run --rm \
  --name qwen-vllm \
  --publish 8000:8000 \
  --shm-size=4g \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  --env VLLM_CPU_KVCACHE_SPACE=2 \
  --env VLLM_CPU_OMP_THREADS_BIND=auto \
  qwen2.5-0.5b-cpu:arm64
```

```sh
docker run --rm \
  --name qwen-vllm-x86 \
  --publish 8000:8000 \
  --shm-size=4g \
  --cap-add SYS_NICE \
  --security-opt seccomp=unconfined \
  --env VLLM_CPU_KVCACHE_SPACE=2 \
  --env VLLM_CPU_OMP_THREADS_BIND=auto \
  qwen2.5-0.5b-cpu:amd64
```

`VLLM_CPU_KVCACHE_SPACE` is measured in GiB. Increase it only when the host has enough RAM for model weights and request concurrency. `VLLM_CPU_OMP_THREADS_BIND=auto` keeps vLLM's default NUMA-aware binding; configure an explicit CPU range on a tuned production host.

The extra capability and seccomp setting enable vLLM's NUMA optimizations with less privilege than a fully privileged container.

## Smoke Test

After the server reports readiness, list the loaded model:

```sh
curl http://localhost:8000/v1/models
```

Then send an OpenAI-compatible chat completion request:

```sh
curl http://localhost:8000/v1/chat/completions \
  --header 'Content-Type: application/json' \
  --data '{
    "model": "/models/Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "Reply with exactly: ready"}],
    "max_tokens": 16,
    "temperature": 0
  }'
```

The server startup log should identify the CPU platform. `HF_HUB_OFFLINE=1` and `TRANSFORMERS_OFFLINE=1` ensure the packaged model is used rather than contacting Hugging Face at runtime.
