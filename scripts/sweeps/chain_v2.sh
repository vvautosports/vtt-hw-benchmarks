#!/bin/bash
# v2 chain: wait for Qwen3.8 quant download -> BASELINES batch (235B + oss-120b,
# per Kal 2026-08-27) -> quant ladder. Replaces chain_ladder.sh.
set -u
LOG=~/qwen38-quant-download.log
echo "[chain-v2] armed $(date)" >> ~/qwen38-chain.log
for i in $(seq 1 720); do
  if grep -q "DOWNLOAD DONE" "$LOG" 2>/dev/null; then break; fi
  if ! pgrep -f "python.*qwen38_quant_dl" > /dev/null; then
    if ! grep -q "DOWNLOAD DONE" "$LOG" 2>/dev/null; then
      echo "[chain-v2] download died without DONE" >> ~/qwen38-chain.log
      exit 1
    fi
    break
  fi
  sleep 30
done
if ! grep -q "DOWNLOAD DONE" "$LOG" 2>/dev/null; then
  echo "[chain-v2] timed out waiting for download" >> ~/qwen38-chain.log
  exit 1
fi
echo "[chain-v2] download done; launching baselines $(date)" >> ~/qwen38-chain.log
mkdir -p ~/batch-baselines-2026-08-27
python3 ~/isolated_battery.py ~/batch_baselines_235b_oss120b.json ~/batch-baselines-2026-08-27 >> ~/batch-baselines.log 2>&1
echo "[chain-v2] baselines exit=$?; launching quant ladder $(date)" >> ~/qwen38-chain.log
for q in UD-IQ4_XS UD-Q2_K_XL; do
  if ! ls /mnt/ai-models/unsloth/Qwen3.8-Flash-Next-GGUF/$q/*.gguf > /dev/null 2>&1; then
    echo "[chain-v2] $q missing, skipping ladder" >> ~/qwen38-chain.log
    exit 1
  fi
done
mkdir -p ~/qwen38-quant-ladder-2026-08-27
python3 ~/qwen38_quant_ladder.py ~/qwen38-quant-ladder-2026-08-27 >> ~/qwen38-quant-ladder.log 2>&1
echo "[chain-v2] ladder exit=$?; all done $(date)" >> ~/qwen38-chain.log
touch ~/chain-v2-ALL-DONE
