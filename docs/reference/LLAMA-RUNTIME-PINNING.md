# Pinned llama.cpp Runtimes Beside Unsloth Studio

**Why this exists (2026-08-27):** `unsloth studio update` replaces `~/.unsloth/llama.cpp` **in place** — no pin, no downgrade, no channels, and no prior version survives on disk (confirmed against studio 2026.8.22; the CLI exposes only `run/stop/update/verify-install/reset-password`). When an update regresses (see the b10639 investigation in [UNSLOTH-DIRECTION.md](UNSLOTH-DIRECTION.md)), the recovery path is a standalone pinned runtime beside the studio, not a rollback.

## Staged pinned runtime

| | |
|---|---|
| Runtime | `b10472-mix-4b653db` (the validated "production" build of the 2026-08 sweeps) |
| Location | Framework: `~/llama-runtimes/b10472-mix-4b653db/` |
| Source | `github.com/unslothai/llama.cpp` release `b10472-mix-4b653db`, asset `app-…-linux-x64-rocm-gfx1151.tar.gz` (336 MB) |
| Integrity | sha256 `710527a1b636…f42f52`, verified against the release's `llama-prebuilt-sha256.json` |
| Verified | `./llama-server --version` → `0.1.1-dev (build 10472, commit 7a556b8f9)` |

Always prefer unsloth's own **mix** builds over vanilla `ggml-org/llama.cpp` releases for pinning — the gfx1151 mix carries Unsloth's patches; a vanilla build is a different runtime, not a pin.

## Launching the pinned server

```bash
cd ~/llama-runtimes/b10472-mix-4b653db
LD_LIBRARY_PATH=. ./llama-server -m /mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --port 9888 --parallel 4 --flash-attn on --no-context-shift \
  --jinja --spec-default --chat-template-kwargs '{"enable_thinking": true}' -ngl -1
```

Flags mirror what the studio wrapper passes (read the current set from any `serve-*.log`: the `Starting llama-server:` line). Port 9888 to stay clear of the studio proxy (8888) and its random internal ports.

**Env-var caveat:** a standalone launch does NOT inherit the studio's `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` — on this hardware that is currently a *feature* (see the root-cause section in UNSLOTH-DIRECTION.md), but it means standalone and studio-wrapped runs of "the same build" are not automatically the same environment. Record the env in any benchmark record.

## Fronting it from Studio

Studio Settings → **Connections → llama.cpp** → base URL `http://127.0.0.1:9888`, any API key. The model then appears as a Connection model in the studio UI/API. Documented pattern (unsloth docs: "Connect llama.cpp to Unsloth").

## Operational gotchas

- **`kill_serve()` in the sweep harness kills every `llama-server` on the box** (`pkill -f llama-server`) — a pinned production server will be collateral damage of any batch run. Before mixing a pinned server with harness batches, scope the pkill (match `.unsloth/llama.cpp` path) or accept the outage.
- This llama-server family **ignores SIGTERM** — stop with SIGKILL.
- whisper.cpp prebuilts pair to a specific llama tag (`UNSLOTH_WHISPER_PREBUILT_INFO.json` → `paired_llama_tag`, linked from the shared `build/bin/Release` dir). An in-place llama update strands the pairing — that is the curated-dictation break of 2026-08-27. After any runtime change, re-run `unsloth studio verify-install` and re-check dictation.
- Studio's bundled runtime will keep auto-updating on `unsloth studio update`; the pin only protects the standalone copy. Keep the tarball (`~/llama-runtimes/b10472-gfx1151.tar.gz`) so the pin can be reproduced on the G1a (Windows zip asset exists for gfx1151 as well).
