#!/usr/bin/env bash
# Phase-2 roster fetch — 2026-08-27
# Downloads only. Testing is decoupled (the runtime upgrade lands mid-session).
# Launch detached:  setsid nohup ~/fetch_roster.sh > /dev/null 2>&1 &

set -u

HF="$HOME/.local/bin/hf"
ROOT="/mnt/ai-models"
LOG="$HOME/roster-fetch-2026-08-27.log"
DONE="$HOME/roster-fetch-2026-08-27.DONE"

rm -f "$DONE"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# repo | include-pattern | dest-subpath
FETCH=(
  "unsloth/Qwen3.8-27B-GGUF|MTP/mtp-Qwen3.8-27B-Q4_0.gguf|unsloth/Qwen3.8-27B-GGUF"
  "unsloth/Qwen3.6-35B-A3B-MTP-GGUF|Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf|unsloth/Qwen3.6-35B-A3B-MTP-GGUF"
  "ornith-ai/Ornith-1.5-35B-A3B-GGUF|Ornith-1.5-35B-Q8_0.gguf|ornith-ai/Ornith-1.5-35B-A3B-GGUF"
  "unsloth/Qwen3.8-Flash-Next-GGUF|UD-Q4_K_XL/*|unsloth/Qwen3.8-Flash-Next-GGUF"
)

log "=== ROSTER FETCH START (4 targets, ~176.6 GiB) ==="
log "free before: $(df -h "$ROOT" | awk 'NR==2 {print $4}')"

fail=0
for entry in "${FETCH[@]}"; do
  IFS='|' read -r repo include subpath <<< "$entry"
  dest="$ROOT/$subpath"
  log "--- $repo :: $include -> $dest"
  mkdir -p "$dest"
  if "$HF" download "$repo" --include "$include" --local-dir "$dest" >> "$LOG" 2>&1; then
    log "OK  $repo  (dir now $(du -sh "$dest" 2>/dev/null | cut -f1), free $(df -h "$ROOT" | awk 'NR==2 {print $4}'))"
  else
    log "FAIL $repo (exit $?)"
    fail=$((fail + 1))
  fi
done

log "free after: $(df -h "$ROOT" | awk 'NR==2 {print $4}')"
log "=== ROSTER FETCH COMPLETE (failures: $fail) ==="
echo "$fail" > "$DONE"
