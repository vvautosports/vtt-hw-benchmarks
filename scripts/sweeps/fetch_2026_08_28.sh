#!/usr/bin/env bash
# Roster fetch — 2026-08-28
# Downloads only. Testing is decoupled (Track 1 harness is built while this runs).
# Launch detached:  setsid nohup ~/fetch_2026_08_28.sh > /dev/null 2>&1 &
#
# Muse-Glimmer replaces the deleted gemma-3-27b as the vision/mmproj niche, so it is
# pulled as a QUALITY ANCHOR (UD-Q8_K_XL) rather than a fit-compromise quant: at 167 GiB
# free the earlier Q4 sizing (written against a stale ~62 GB reading) is unnecessary.
# The mmproj is the vision encoder and is tiny — quantizing THAT is where vision quality
# actually degrades, so it is taken at BF16 regardless of the text quant.

set -u

HF="$HOME/.local/bin/hf"
ROOT="/mnt/ai-models"
LOG="$HOME/roster-fetch-2026-08-28.log"
DONE="$HOME/roster-fetch-2026-08-28.DONE"

rm -f "$DONE"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# repo | include-pattern | dest-subpath
FETCH=(
  "unsloth/Muse-Glimmer-30B-GGUF|Muse-Glimmer-30B-UD-Q8_K_XL.gguf|unsloth/Muse-Glimmer-30B-GGUF"
  "unsloth/Muse-Glimmer-30B-GGUF|mmproj-Muse-Glimmer-30B-BF16.gguf|unsloth/Muse-Glimmer-30B-GGUF"
  "unsloth/DeepSeek-V4-Flash-0731-GGUF|UD-IQ3_XXS/*|unsloth/DeepSeek-V4-Flash-0731-GGUF"
)

# Muse first (33.7 GiB, unblocks the vision smoke fast), then DeepSeek (97.1 GiB).
log "=== FETCH START (3 targets, ~130.7 GiB) ==="
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
log "=== FETCH COMPLETE (failures: $fail) ==="
echo "$fail" > "$DONE"
