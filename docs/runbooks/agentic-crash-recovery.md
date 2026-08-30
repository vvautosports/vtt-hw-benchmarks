# Agentic-load crash recovery (inference boxes)

Recovery pattern for a bench/agent box that goes dark under sustained inference
or agentic load. Written from the 2026-08-29 Framework incident (Track 2A smoke,
issue #12): a kill storm during an in-flight Claude Code run wedged the process
table, a serve relaunch on top of that state crashed the box to power-off, and a
**Wake-on-LAN packet booted it back with no physical intervention**. Runs that
deliberately push limits should treat this as the standard recovery loop, not an
emergency.

## Decision tree — box stopped answering

1. **Confirm it's the box, not the path.** From a same-LAN machine:
   - ping the mesh IP AND the LAN IP (Framework: `100.64.0.1` / `192.168.4.34`)
   - ping the LAN gateway (`192.168.4.1`) to prove your own link is healthy
   - `tailscale status` "active" entries can be STALE — never trust them over ping
2. **LAN answers but mesh doesn't** → tailscaled died, box is fine: ssh over LAN,
   restart tailscaled, done.
3. **Both dead, gateway healthy** → box is down. Send WOL (step below). It costs
   nothing: a crashed-to-off box boots; a hung-but-powered kernel ignores it.
4. **WOL brought it back** → wait 60-120s for boot, ssh over **LAN first**
   (tailscaled comes up later than sshd), then run the post-recovery checklist.
   **Success = sshd answers.** A few ping replies that never become ssh mean the
   box stirred and crashed again during boot (seen 2026-08-29) — that is a
   FAILED heal, not a slow one; do not report recovery on ping alone.
5. **Still dead / ping-flapping after ~5 min** → hung kernel or crash-looping
   boot; physical power cycle is the only remaining move. After a hard amdgpu
   crash, prefer a full reset: hold power 10s off, wait a few seconds, boot —
   platform state from the crash can survive a soft WOL start.

## Wake-on-LAN

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/utils/wake_node.ps1 -Mac 9c:bf:0d:00:e5:9d -Broadcast 255.255.255.255,192.168.7.255
```

- Framework Desktop MAC: `9c:bf:0d:00:e5:9d` (2.5GbE; from the vvt-infrastructure
  switch port map — other node MACs live there too)
- On Linux healers: `wakeonlan <mac>` / `ether-wake <mac>`
- The Denver flat network is `192.168.4.0/22` → subnet broadcast `192.168.7.255`
- WOL survives because the NIC stays powered after a crash-to-off; verified armed
  on the Framework 2026-08-29

## Post-recovery checklist

- [ ] `uptime` confirms a fresh boot; note the crash window for the incident log
- [ ] Leftover run processes are gone (fresh boot guarantees it)
- [ ] `/mnt/ai-models` mounted (it's 97% full — check before any serve)
- [ ] Harvest any interrupted run dir (`results.jsonl` is flushed per record, so
      completed cells survive a crash; scratch dirs hold transcripts/diffs)
- [ ] Restore the baseline serve (GLM-4.7-Flash resting state) or the run's model
- [ ] Journal the crash: `journalctl -b -1 -p err | tail -50` → amdgpu evidence
      into the tracking issue

## Wedge lessons that led here (don't repeat them)

- **SIGKILLing agents mid-GPU-op can leave `/proc` entries whose `comm`/`cmdline`
  reads hang** → every `pgrep -f`, `pkill -f`, and `ps` then wedges box-wide.
  Recover with a time-boxed per-PID scan, then kill by PID:

  ```bash
  for p in $(ls /proc | grep -E "^[0-9]+$"); do
    c=$(timeout 0.3 cat /proc/$p/comm 2>/dev/null) || c="<HUNG-READ>"
    case "$c" in python3|claude|node|llama-server|"<HUNG-READ>") echo "$p $c";; esac
  done
  ```

- **Over tailscale SSH, never combine a pattern-kill with any command whose
  literal text contains the unbracketed target string** (e.g. a `nohup unsloth
  run ...` launch). tailscaled embeds the full command in its own `be-child`
  argv, so the pkill matches — and kills — your own session. Separate ssh calls,
  or put launches in script files on the box. Bracketed patterns (`[l]lama-server`)
  protect only against the pattern itself, not against other literals in the
  same command line.
- **Don't relaunch a serve on top of a wedged process table** — that's what took
  the box down. Clear or reboot first.

## Future: self-heal automation

Long unattended batteries should detect box-down (ping loss), fire WOL, wait for
ready, and resume from the last flushed `results.jsonl` record — tracked in #13.
Guardrails: cap heal attempts per run, log every heal into the run manifest.
