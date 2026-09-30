#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "huggingface-hub>=0.30,<1",
# ]
# ///

"""Download a complete, reproducible local snapshot of the Qwen model repository."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from huggingface_hub import HfApi, snapshot_download
from huggingface_hub.utils import HfHubHTTPError

MODEL_ID = "Qwen/Qwen2.5-0.5B-Instruct"
DEFAULT_DESTINATION = Path("models/Qwen2.5-0.5B-Instruct")
REQUIRED_ARTIFACTS = ("config.json", "generation_config.json")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=f"Download every artifact from {MODEL_ID} for an offline Docker build."
    )
    parser.add_argument(
        "--destination",
        type=Path,
        default=DEFAULT_DESTINATION,
        help=f"Directory for the model snapshot (default: {DEFAULT_DESTINATION})",
    )
    parser.add_argument(
        "--revision",
        default="main",
        help="Hugging Face branch, tag, or commit SHA to resolve (default: main)",
    )
    parser.add_argument(
        "--token",
        default=None,
        help="Optional Hugging Face token; defaults to HF_TOKEN or saved Hugging Face credentials.",
    )
    return parser.parse_args()


def validate_snapshot(destination: Path) -> None:
    missing_artifacts = [
        artifact for artifact in REQUIRED_ARTIFACTS if not (destination / artifact).is_file()
    ]
    has_tokenizer = any(
        (destination / artifact).is_file()
        for artifact in ("tokenizer.json", "tokenizer.model", "vocab.json")
    )
    has_weights = any(destination.glob("*.safetensors"))

    if missing_artifacts or not has_tokenizer or not has_weights:
        problems = [f"missing required files: {', '.join(missing_artifacts)}"] if missing_artifacts else []
        if not has_tokenizer:
            problems.append("missing tokenizer artifact")
        if not has_weights:
            problems.append("missing .safetensors weight file")
        raise RuntimeError("Downloaded snapshot is incomplete: " + "; ".join(problems))


def main() -> int:
    args = parse_args()
    destination = args.destination.expanduser().resolve()

    try:
        model_info = HfApi().model_info(MODEL_ID, revision=args.revision, token=args.token)
        resolved_revision = model_info.sha
        print(f"Resolving {MODEL_ID} at commit {resolved_revision}")
        snapshot_download(
            repo_id=MODEL_ID,
            revision=resolved_revision,
            local_dir=destination,
            token=args.token,
        )
        validate_snapshot(destination)
    except (HfHubHTTPError, OSError, RuntimeError) as error:
        print(f"Download failed: {error}", file=sys.stderr)
        return 1

    print(f"Downloaded complete snapshot to {destination}")
    print(f"Resolved revision: {resolved_revision}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())