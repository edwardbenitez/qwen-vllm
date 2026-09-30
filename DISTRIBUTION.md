# Publish to Docker Hub

These steps publish separate ARM64 and AMD64 images. Build from a directory containing the downloaded model snapshot; model weights are part of the Docker build context but are excluded from Git.

## 1. Prepare Docker Hub

1. Create a Docker Hub account and a repository, for example `qwen-vllm-cpu`.
2. Create a Docker Hub personal access token with read and write permissions.
3. Set the account and repository names in your shell. `DOCKERHUB_USERNAME` is your Docker Hub account or organization name:

```sh
export DOCKERHUB_USERNAME=mightydevs
export DOCKERHUB_REPOSITORY=qwen-vllm-cpu
export IMAGE_VERSION=1.0.0
```

Log in using the personal access token when Docker prompts for a password. Do not put the token in a command-line argument or commit it to this repository:

```sh
docker login --username "$DOCKERHUB_USERNAME"
```

## 2. Download the Model

From this repository directory, fetch the model artifacts before building:

```sh
uv run download_model.py
```

For reproducible releases, use a reviewed Hugging Face commit SHA with `--revision` and record it alongside the image version.

## 3. Build and Push ARM64

```sh
docker build \
  --build-arg VLLM_IMAGE_TAG=latest-arm64 \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-arm64" \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:latest-arm64" \
  .

docker push "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-arm64"
docker push "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:latest-arm64"
```

## 4. Build and Push AMD64

On an AMD64 host, build and push directly:

```sh
docker build \
  --build-arg VLLM_IMAGE_TAG=latest-x86_64 \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-amd64" \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:latest-amd64" \
  .

docker push "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-amd64"
docker push "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:latest-amd64"
```

On an ARM64 Mac, use a buildx builder that supports AMD64 and push directly instead of loading the image locally:

```sh
docker buildx build --platform linux/amd64 \
  --build-arg VLLM_IMAGE_TAG=latest-x86_64 \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-amd64" \
  --tag "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:latest-amd64" \
  --push .
```

The published tags are architecture-specific. Consumers should select the tag matching their Linux host; these commands do not create a single multi-platform tag.

## 5. Verify and Pull

Confirm the tags exist on the Docker Hub repository page, then pull the appropriate image:

```sh
docker pull "$DOCKERHUB_USERNAME/$DOCKERHUB_REPOSITORY:$IMAGE_VERSION-arm64"
```

For AMD64, replace `arm64` with `amd64`. Run the image using the CPU runtime options and API smoke tests in [README.md](README.md#run-server).

## Release Notes

- Publish a new immutable `IMAGE_VERSION` tag for each model or vLLM base-image update. Use the corresponding `latest-arm64` or `latest-amd64` tag only as a moving convenience tag.
- Keep the Qwen model's Apache-2.0 license and applicable notices with your distribution, and review the vLLM image's licensing and Docker Hub terms before redistribution.
- The image includes model weights, so pushes require uploading roughly 1 GB of model data plus the vLLM base image layers. Docker Hub may reuse base layers already present in the destination repository.
