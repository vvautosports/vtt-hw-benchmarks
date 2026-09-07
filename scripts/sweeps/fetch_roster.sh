#!/usr/bin/env bash
# Phase-2 roster fetch — 2026-08-27
# Downloads only. Testing is decoupled (the runtime upgrade lands mid-session).
# Launch detached:  setsid nohup ~/fetch_roster.sh > /dev/null 2>&1 &

set -u

HF="$HOME/.local/bin/hf"
ROOT="/mnt/ai-models"
LOG="$HOME/roster-fetch-2026-08-27.log"
DONE="$HOME/roster-fetch-2026-08-27.DONE"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# --------------------------------------------------------------------------- #
# Driver ship list -- `bash fetch_roster.sh --ship` copies the drivers to the
# node and downloads NOTHING.
#
# The sweep drivers execute from $HOME on the node (they `sys.path.insert(0,
# HOME)` and import each other as flat modules), so every module a driver imports
# has to land in $HOME too. run_manifest.py is imported by roster_batch.py AND
# toolcall_battery.py -- if it is missing on the node, both die at import. Keep
# this list in sync when a driver grows an import. The drivers are stdlib-only,
# so a plain copy is the entire install step.
#
#   bash fetch_roster.sh --ship                       # -> $HOME on this box
#   SHIP_DEST=/tmp/stage bash fetch_roster.sh --ship  # -> somewhere else
# --------------------------------------------------------------------------- #
SHIP_FILES=(
  run_manifest.py
  roster_batch.py
  toolcall_battery.py
  sweep_phase1.py
  sweep_phase2.py
  sweep_toolcall.py
)

if [ "${1:-}" = "--ship" ]; then
  src="${SHIP_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
  dest="${SHIP_DEST:-$HOME}"
  rc=0
  for f in "${SHIP_FILES[@]}"; do
    if [ -f "$src/$f" ]; then
      cp "$src/$f" "$dest/$f" && echo "shipped $f -> $dest"
    else
      echo "MISSING $src/$f (driver will fail to import on the node)" >&2
      rc=1
    fi
  done
  exit "$rc"
fi

rm -f "$DONE"

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
