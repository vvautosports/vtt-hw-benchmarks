#!/usr/bin/env bash
# Unattended chain — 2026-08-28 afternoon.
#
# Job 1: --disable-tools champion re-baseline (6 models). Closes the last open caveat on
#        the corpus: every t/s and token-economy number before --disable-tools is suspect.
# Job 2: day-one battery for the two models downloaded this morning.
#
# Safe job runs FIRST on purpose. DeepSeek-V4-Flash is 97 GiB of weights against ~122 GiB
# usable, so its load is the one thing here that might fail; putting it second means a
# failure cannot waste the window.
#
# Launch detached:
#   ssh -n framework 'setsid nohup ~/chain_2026_08_28.sh > /dev/null 2>&1 < /dev/null & disown'

set -u

LOG="$HOME/chain-2026-08-28.log"
DONE="$HOME/chain-2026-08-28.DONE"
rm -f "$DONE"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

run_job() {
  local name="$1" spec="$2" rundir="$3"
  log "=== JOB START: $name (spec $spec -> $rundir)"
  rm -rf "$rundir"
  if python3 "$HOME/isolated_battery.py" "$spec" "$rundir" >> "$LOG" 2>&1; then
    log "=== JOB OK: $name  ($(grep -c '"task"' "$rundir/results.jsonl" 2>/dev/null) records)"
  else
    log "=== JOB FAILED: $name (exit $?) — continuing to next job"
  fi
}

log "########## CHAIN START ##########"
log "free: $(df -h /mnt/ai-models | awk 'NR==2 {print $4}')"

run_job "champion re-baseline (--disable-tools)" \
        "$HOME/batch_rebaseline_toolsoff.json" "$HOME/rebaseline-toolsoff"

run_job "day-one: DeepSeek-V4-Flash + Muse-Glimmer" \
        "$HOME/batch_dayone_2026_08_28.json" "$HOME/dayone-2026-08-28"

log "########## CHAIN COMPLETE ##########"
echo "done" > "$DONE"
