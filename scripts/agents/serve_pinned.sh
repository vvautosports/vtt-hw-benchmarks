#!/usr/bin/env bash
# Clean-slate pinned serve + REAL residency verification.
#
# Fixes the two bugs that wiped the 2026-09-02 overnight run:
#  1. `curl /health` on 8888 returns the studio SPA index.html with HTTP 200 even
#     when NO model is resident. It is a frontend catch-all, not a health probe.
#     The real check is `unsloth start claude --no-launch`, which exits non-zero
#     with "No model is currently resident".
#  2. A stale studio parent can keep LISTENING on 8888 after its model is gone.
#     A new `unsloth run` then fails to bind, spawns an ORPHAN studio + child on a
#     random port, and every agent still talks to 8888 and sees no model. Orphans
#     stack, each holding a model copy in GTT, which is what drove the baseline to
#     103 GB and caused the OOM. So: always start from zero parents/children.
set -u
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"
MODEL=/mnt/ai-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/Qwen3-Coder-30B-A3B-Instruct-UD-Q8_K_XL.gguf

count_children() { local n=0 p e; for p in /proc/[0-9]*; do e=$(readlink "$p/exe" 2>/dev/null); case "$e" in *llama-server) n=$((n+1));; esac; done; echo "$n"; }
list_parents()  { local p c; for p in /proc/[0-9]*; do c=$(tr "\0" " " < "$p/cmdline" 2>/dev/null); case "$c" in *"unsloth run"*) echo "${p#/proc/}";; esac; done; }

echo "[serve] tearing down any existing serve"
for pid in $(list_parents); do kill "$pid" 2>/dev/null; done
sleep 6
for p in /proc/[0-9]*; do e=$(readlink "$p/exe" 2>/dev/null); case "$e" in *llama-server) kill "${p#/proc/}" 2>/dev/null;; esac; done
sleep 6
for p in /proc/[0-9]*; do e=$(readlink "$p/exe" 2>/dev/null); case "$e" in *llama-server) kill -9 "${p#/proc/}" 2>/dev/null;; esac; done
sleep 3

if ss -ltn 2>/dev/null | grep -q ":8888 "; then
  echo "[serve] FATAL: port 8888 still held after teardown"; exit 1
fi
AVAIL=$(free -g | awk "/^Mem:/{print \$7}")
echo "[serve] clean baseline: ${AVAIL}GB available, $(count_children) children"
if [ "$AVAIL" -lt 90 ]; then echo "[serve] FATAL: only ${AVAIL}GB available, expected >90 on a clean box"; exit 1; fi

# Prompt-cache size. llama.cpp --cache-ram defaults to 8192 MiB and the studio
# never sets it; the ~26k-token agent KV state then evicts every turn and the
# whole context is reprocessed (147k ptok/cell, 1.54 tok/s). 32 GiB keeps it.
CACHE_RAM="${LLAMA_ARG_CACHE_RAM:-32768}"
echo "[serve] launching pinned (-c 65536 --parallel 1, LLAMA_ARG_CACHE_RAM=${CACHE_RAM} MiB)"
setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 LLAMA_ARG_CACHE_RAM="$CACHE_RAM" unsloth run \
  --model "$MODEL" --max-seq-length 65536 --parallel 1 \
  -H 0.0.0.0 -p 8888 > "$HOME/unsloth-serve.log" 2>&1 < /dev/null &
disown

echo "[serve] waiting for REAL residency (unsloth start claude --no-launch)"
for i in $(seq 1 45); do
  sleep 20
  if timeout 60 unsloth start claude --no-launch >/dev/null 2>&1; then
    echo "[serve] model RESIDENT after $((i*20))s"
    NC=$(count_children); NP=$(list_parents | wc -l)
    echo "[serve] parents=$NP children=$NC avail=$(free -g | awk "/^Mem:/{print \$7}")GB"
    [ "$NP" -eq 1 ] && [ "$NC" -eq 1 ] || { echo "[serve] FATAL: expected exactly 1 parent + 1 child"; exit 1; }
    ss -ltnp 2>/dev/null | grep -q ":8888 " || { echo "[serve] FATAL: nothing on 8888"; exit 1; }
    echo "[serve] OK"; exit 0
  fi
done
echo "[serve] FATAL: model never became resident"; exit 1
