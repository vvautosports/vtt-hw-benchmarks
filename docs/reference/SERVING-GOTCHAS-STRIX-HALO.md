# Serving Gotchas — Strix Halo (Unsloth / llama.cpp)

Operational quick-reference for anyone serving LLMs on VVC's AMD Strix Halo boxes (Framework Desktop, Fedora; HP G1a, Windows) via Unsloth Studio (`unsloth run`, which wraps llama-server). Each gotcha found the hard way during the 2026-08-26/27 benchmarking campaign — full narrative and evidence chain in [UNSLOTH-DIRECTION.md](UNSLOTH-DIRECTION.md).

---

## (a) Unified-memory corruption on gfx1151

**SYMPTOM:** Model loads and serves, but generation is garbage. Non-thinking mode produces pure `"/"` spam from token 1. Thinking mode never closes its reasoning block — even at `max_tokens=32768` (4× the normal battery cap) — so requests run to the token cap and never produce a real answer. Looks like a "verbose thinker" problem at first glance; raising `max_tokens` does not fix it.

**ROOT CAUSE:** Unsloth Studio auto-sets `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` for AMD unified-memory APUs. Under runtime build `b10639-mix-f6f92fe` on gfx1151, that setting corrupts the forward pass itself — confirmed with a template-free raw `/completion` call (no chat template, no stop tokens, no EOS metadata involved): still garbage. Matches HF `unsloth/Qwen3.8-Flash-Next-GGUF` community discussion #30. The var has shipped for Strix Halo since ~June; corruption is an interaction of `var × b10639-mix × gfx1151`, not the var alone — the earlier `b10472` batches almost certainly ran with the same var set and were clean.

**FIX:** Set `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` in the server's environment before launch.

- **Framework (Fedora), now permanent:** `~/.bashrc.d/unsloth.sh` (`export UNSLOTH_DISABLE_UNIFIED_MEMORY=1` — covers interactive shells, ssh-command invocations, and harness `bash -c` launches) **plus** `~/.config/environment.d/50-unsloth.conf` (systemd user services / GUI-launched sessions). Both are needed — one alone misses some launch paths.
- **HP G1a (Windows):** apply via `setx UNSLOTH_DISABLE_UNIFIED_MEMORY 1` (persistent user env var). Not yet verified end-to-end on Windows as of 2026-08-27 — apply the same pattern when the G1a next serves and confirm.
- **Critical gotcha in the opt-out mechanism itself:** ggml tests for the variable's *presence*, not its value. Setting `UNSLOTH_DISABLE_UNIFIED_MEMORY=0` does **not** disable it — the variable must be unset (or exported as the fix, not zeroed) to actually opt out. Verify by checking the running `llama-server` process's environment directly if in doubt.

**EVIDENCE:** [UNSLOTH-DIRECTION.md § "Root cause: unified-memory env corruption on Strix Halo"](UNSLOTH-DIRECTION.md#root-cause-unified-memory-env-corruption-on-strix-halo-2026-08-27-pm); re-validation data in [`results/sweeps/2026-08-27-b10639-umfix-batch/`](../../results/sweeps/2026-08-27-b10639-umfix-batch/manifest.yaml).

---

## (b) Cross-request state bleed on b10639

**SYMPTOM:** A model answers as though it already completed a *different* task earlier in the conversation — e.g. a code task returns "All 8 doctests pass" and a markdown table describing tests, with no function definition anywhere; or a summarize task addresses the topic of the *previous* request instead of the one asked. Looks like a model-quality regression or a generational inversion, but only shows up on multi-request server sessions.

**ROOT CAUSE:** Confirmed cross-request state leakage on `b10639-mix-f6f92fe`. A discriminating test (same battery run forward, reversed, and fully isolated with a fresh server per task) showed the failures track **request position in the server session**, not the task itself — both affected Qwen-family models pass 3/3 the moment each task gets its own fresh server. Suspected mechanism (untested): `--parallel 4 --kv-unified --slot-save-path` slot save/restore plus LRU slot reuse interacting with unmerged upstream KV-tracking changes carried in the `b10639-mix` fork. `b10472` is not fully exonerated (it only ran multi-request batches, never an order test) but graded clean throughout.

**FIX (benchmarking):** grading sessions must use a **fresh server per task** ("isolated" protocol) — any server-reusing batch on `b10639` measures "model + session history," not the model alone. `bleed_order_test.py` and `isolated_battery.py` implement this.

**FIX (production):** this is a live risk, not just a benchmarking artifact. Any multi-request serving session on `b10639` can leak context between unrelated requests/users. Weigh the pinned `b10472` standalone runtime (see gotcha (d)) for anything stateful-sensitive until this is fixed upstream.

**EVIDENCE:** [UNSLOTH-DIRECTION.md § "Bleed-order test: cross-request state bleed CONFIRMED"](UNSLOTH-DIRECTION.md#bleed-order-test-cross-request-state-bleed-confirmed-2026-08-27-night); data in [`results/sweeps/2026-08-27-bleed-order-test/`](../../results/sweeps/2026-08-27-bleed-order-test/manifest.yaml), driver [`scripts/sweeps/bleed_order_test.py`](../../scripts/sweeps/bleed_order_test.py).

---

## (c) Server-side tools enabled by default

**SYMPTOM:** A request that should be a simple ~100-token completion shows `prompt_tokens` in the thousands (observed range: 2,000–16,000), sometimes with a multi-leg agentic-looking transaction and a final answer that's just an apology or error string instead of the expected content. Looks like a model failure; it is actually a serving-config issue.

**ROOT CAUSE:** `unsloth run` enables server-side tools (web search, code execution) by default. Studio injects system/tool-schema content into the prompt, varying by model, and the model can spontaneously invoke a server-side tool (confirmed: a 235B model invoked code execution on a plain code-writing task, studio's tool loop failed, and it returned an apology string instead of code). A full corpus scan found 48 records across nearly every run in this campaign with prompt_tokens in the 2,000–16,000 range against a battery prompt of ~100 tokens.

**FIX:** pass **`--disable-tools`** on every benchmark serve going forward (now a registry-wide rule). Content-channel pass/fail grades from before this fix still stand (they measure what the consumer actually received), but **any t/s or token-economy comparison predating this fix should be treated as suspect** — some of the "regression" findings earlier in the campaign (e.g. part of the b10639 code-token-bloat finding, 8,019→15,323 tokens) may partly reflect tool-loop overhead rather than raw generation. A `--disable-tools` re-baseline and a tools-on/off A/B are queued but not yet run.

**SIGNATURE TO WATCH FOR:** `prompt_tokens > 2000` on a request that should be short is the tell — treat any such record as suspect until re-measured under `--disable-tools`.

**EVIDENCE:** [UNSLOTH-DIRECTION.md § "Server-side tools contamination"](UNSLOTH-DIRECTION.md#server-side-tools-contamination-2026-08-27-night); data in [`results/sweeps/2026-08-27-baselines-235b-oss120b/`](../../results/sweeps/2026-08-27-baselines-235b-oss120b/manifest.yaml), `caveats.server_side_tools_contamination`.

---

## (d) Smaller operational notes

- **llama-server ignores SIGTERM.** This build family does not shut down on SIGTERM — orchestration and harness code must escalate to **SIGKILL** to actually stop the process.
- **`kill_serve()` / `pkill -f llama-server` takes out every llama-server on the box**, including a pinned production server, not just the one the harness started. Before mixing a pinned/production server with harness batch runs, scope the pkill to match the specific runtime path (e.g. `.unsloth/llama.cpp`) or accept the outage.
- **whisper.cpp prebuilt pairing breaks on in-place runtime updates.** whisper prebuilts pair to a specific llama.cpp tag via `paired_llama_tag` in `UNSLOTH_WHISPER_PREBUILT_INFO.json`. `unsloth studio update` bumps the llama.cpp runtime in place; if no matching whisper prebuilt has shipped yet for the new tag, curated whisper dictation breaks (`unsloth studio verify-install` passes but does not re-pair). Confirmed break: `b10639` shipped 2026-08-27, whisper.cpp's latest prebuilt (v1.9.2-unsloth.11) still pairs to `b10472-mix-4b653db` as of this writing. Browser and Transformers-based dictation are unaffected — only the curated/native path breaks. Re-check after any `unsloth studio update` and after any new whisper.cpp prebuilt release.
- **No studio downgrade path exists.** `unsloth studio update` replaces `~/.unsloth/llama.cpp` in place — no pin, no channel selection, no prior version retained on disk. The CLI exposes only `run/stop/update/verify-install/reset-password`. When an update regresses, the recovery path is a **standalone pinned runtime staged beside the studio**, not a rollback command. See [LLAMA-RUNTIME-PINNING.md](LLAMA-RUNTIME-PINNING.md) for the staged-runtime pattern (currently `b10472-mix-4b653db` pinned at `~/llama-runtimes/b10472-mix-4b653db/` on the Framework, fronted via Studio Settings → Connections → llama.cpp when needed). Note the pinning doc's own caveat: a standalone launch does **not** inherit the studio's `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` by default, so a "pinned" run and a studio-wrapped run of the same build are not automatically the same environment — record the env vars used in any benchmark record.

**EVIDENCE:** SIGTERM/pkill/whisper notes: [UNSLOTH-DIRECTION.md](UNSLOTH-DIRECTION.md) (phase-2 param sweep ops-gotcha note; root-cause section caveats; version-sweep `side_effect` field). No-downgrade-path and pinning pattern: [LLAMA-RUNTIME-PINNING.md](LLAMA-RUNTIME-PINNING.md).
