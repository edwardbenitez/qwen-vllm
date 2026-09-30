# Choose latest-arm64 for Apple Silicon/Linux ARM or latest-x86_64 for Intel/AMD Linux.
ARG VLLM_IMAGE_TAG=latest-arm64
FROM vllm/vllm-openai-cpu:${VLLM_IMAGE_TAG}

ARG MODEL_PATH=models/Qwen2.5-0.5B-Instruct
ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

COPY ${MODEL_PATH}/ /models/Qwen2.5-0.5B-Instruct/

CMD ["/models/Qwen2.5-0.5B-Instruct", "--host", "0.0.0.0", "--dtype", "bfloat16"]