# HP ZBook Ultra G1a - Unit XX

**Test Date:** YYYY-MM-DD
**Tester:** [Your Name]
**Test Location:** [Location]

---

## System Specifications

**Model:** HP ZBook Ultra G1a
**CPU:** AMD Ryzen AI Max+ 395
**GPU:** [Check in Device Manager]
**RAM:** [Total GB - check in System Info]
**Storage:** [Type and capacity]
**BIOS Version:** [Optional]
**Windows Version:** [e.g., Windows 11 Pro 23H2]

### System Information Commands
```powershell
# Get detailed info:
systeminfo
wmic cpu get name,numberofcores,numberoflogicalprocessors
wmic path win32_VideoController get name
wmic memorychip get capacity
```

---

## Benchmark Results

### Rocket League (1080p High Quality, Uncapped FPS)

**Configuration:**
- Resolution: 1920x1080
- Render Quality: High Quality
- Vertical Sync: Off
- Anti-Aliasing: FXAA High
- Replay: RLCS Season 9

**Results:**
- **Average FPS:** [XXX fps]
- **Minimum FPS:** [XXX fps] (if available)
- **Maximum FPS:** [XXX fps] (if available)
- **1% Low:** [XXX fps] (if available)
- **0.1% Low:** [XXX fps] (if available)

**Observations:**
- Thermal performance: [Any throttling noted?]
- Fan noise: [Quiet/Moderate/Loud]
- Visual stuttering: [Yes/No]
- Overall smoothness: [Excellent/Good/Fair/Poor]

**Command Used:**
```powershell
python rocket_league.py --kerasHost 192.168.4.X --kerasPort 8080
```

---

### Cinebench R23

**Multi-Core Test:**
- **Score:** [XXXX pts]
- **Duration:** [~XX minutes]

**Single-Core Test:** (optional)
- **Score:** [XXXX pts]
- **Duration:** [~XX minutes]

**Thermal Observations:**
- Peak CPU temperature: [if monitored]
- Sustained boost clock: [if monitored]
- Thermal throttling: [Yes/No]

---

## Additional Tests (Optional)

### 7-Zip Benchmark
- **Compression:** [XXXX MIPS]
- **Decompression:** [XXXX MIPS]
- **Overall Rating:** [XXXX MIPS]

### AI Model Inference (llama-bench)
- **Model:** [e.g., llama-3.2-3b-q4_k_m]
- **Tokens/sec:** [XXX t/s]
- **Prompt Processing:** [XXX t/s]

### Storage (fio or CrystalDiskMark)
- **Sequential Read:** [XXXX MB/s]
- **Sequential Write:** [XXXX MB/s]
- **Random 4K Read:** [XXXX IOPS]
- **Random 4K Write:** [XXXX IOPS]

---

## Issues / Notes

### Problems Encountered
- [List any issues during testing]
- [Configuration problems]
- [Benchmark failures]

### Workarounds Applied
- [Solutions used]

### System Quirks
- [Any unusual behavior]
- [Hardware-specific notes]

---

## Comparison with Other Units

| Metric | Unit 01 | Unit 02 | Unit 03 | Unit 04 | This Unit |
|--------|---------|---------|---------|---------|-----------|
| RL FPS | [XXX] | [XXX] | [XXX] | [XXX] | **[XXX]** |
| CB R23 Multi | [XXXX] | [XXXX] | [XXXX] | [XXXX] | **[XXXX]** |
| CB R23 Single | [XXXX] | [XXXX] | [XXXX] | [XXXX] | **[XXXX]** |

---

## Recommendations

**Assignment:**
- Best for: [Gaming / CPU-heavy / Balanced / etc.]
- User profile: [Developer / Gamer / Content Creator / etc.]

**Reasoning:**
[Explain why this unit suits this use case based on benchmark performance]

---

## Test Environment

**Network:**
- MS-01 IP: [192.168.4.X]
- Keras OCR Service: [Running/Not Used]
- Network Type: [Headscale VPN / Local LAN]

**Ambient Conditions:**
- Room temperature: [~XX°C] (if known)
- Laptop placement: [On desk / Cooling pad / etc.]
- Power mode: [Plugged in / Battery]
- Windows power plan: [High Performance / Balanced / etc.]

---

## Next Steps

- [ ] Test remaining HP ZBooks
- [ ] Add more comprehensive benchmarks
- [ ] Multiple test runs for statistical validity
- [ ] Automate FPS capture with PresentMon
- [ ] Database entry (Supabase)

---

## Raw Data / Logs

```
[Paste any raw output, logs, or screenshots here]
```

---

**Tested by:** [Your Name]
**Sign-off:** [Date and initials]
