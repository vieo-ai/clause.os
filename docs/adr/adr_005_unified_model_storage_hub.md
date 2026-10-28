# ADR 005: Unified Model Storage & Ecosystem Cache Projection

## Status
Accepted

## Context
ClauseOS hosts heterogeneous AI coprocessors, fine-tuning runtimes, and inference engines, including:
- **Unsloth / Hugging Face Transformers** (PyTorch safetensors, tokenizers, LoRAs)
- **ComfyUI** (Checkpoints, UNet backbones, VAE, CLIP, GGUF diffusion)
- **Lemonade / FastFlowLM** (GGUF quantizations, OpenAI-compatible local APIs)

Without strict path unification, each subsystem defaults to isolated download caches, resulting in multi-gigabyte duplications, disk exhaustion, and broken offline hermetic operation.

## Decision
1. **Single Hermetic Anchor**: Direct all model downloads and hub caches into `$env:CLAUSE_HOME/.local/share/models`.
2. **Canonical Environment Exposure**: Standardize on Hugging Face Hub environment variables across all platforms:
   - `HF_HOME = $env:CLAUSE_HOME/.local/share/models`
   - `HUGGINGFACE_HUB_CACHE = $HF_HOME/hub`
   - `TRANSFORMERS_CACHE = $HUGGINGFACE_HUB_CACHE`
   - `TORCH_HOME = $HF_HOME/torch`
3. **ComfyUI Bridge**: Automate generation of `extra_model_paths.yaml` inside ComfyUI's root during Stage 3 provisioning, pointing directly to the unified `$HF_HOME/hub` root.
4. **GGUF Unification**: GGUF weights pulled via Hugging Face repositories reside in `$HF_HOME/hub` without artificial symlink indirection. Tools requiring local paths read from this single source of truth.

## Consequences
- **Positive**: Zero duplicate weight downloads between fine-tuning (Unsloth) and image/LLM generation (ComfyUI / FastFlowLM).
- **Positive**: Complete portability—moving or backing up `.home/.local/share/models` moves all downloaded AI assets.
- **Negative**: Initial download paths within ComfyUI file pickers reflect Hugging Face blob directory structures rather than clean flat filenames unless mapped via workflow presets.