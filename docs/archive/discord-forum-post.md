# ⚡ VTT Hardware Benchmarks - Cross-Platform Testing Suite Complete!

## What's New

Exciting progress! We've built a complete containerized benchmark suite for VTT hardware testing. This enables consistent, reproducible performance testing across all our systems (HP ZBooks, Framework desktop mainboard, and future devices).

## ✅ Completed This Session

**Containerized Benchmark Suite:**
- ✅ **7-Zip** - CPU compression performance (119K MIPS baseline)
- ✅ **STREAM** - Memory bandwidth testing (102 GB/s baseline)
- ✅ **Storage (fio)** - Disk I/O performance (3.3 GB/s seq read)
- ✅ **AI Inference (llama.cpp)** - Multi-model testing with AMD Strix Halo iGPU acceleration

**Automation & Analysis:**
- ✅ **Multi-Run Automation** - Statistical analysis (mean, median, stddev, CV%)
- ✅ **Progress Indicators** - Real-time test completion feedback
- ✅ **JSON Output** - Structured data for databases/dashboards
- ✅ **Cross-Platform** - Works on Linux (Podman) and Windows (Docker Desktop)

**Framework Desktop Baseline:**
- System: AMD Ryzen AI Max+ 395 (laptop chip in mini-ITX desktop mainboard)
- 7-Zip: 119,390 MIPS overall
- STREAM: 101.9 GB/s memory bandwidth (Triad)
- Storage: 3,266 MB/s sequential read, 22K IOPS random read
- AI Inference (Strix Halo iGPU):
  - gpt-oss-20b-F16 (13GB): 1135 t/s prompt, 46 t/s generation
  - Qwen3-Next-80B Q8 (87GB): 508 t/s prompt, 29 t/s generation
  - Qwen3-235B Q3 (97GB): 131 t/s prompt, 17 t/s generation

## 🔄 Ready for Testing

**HP ZBook Testing (4 units):**
- Windows-specific: Rocket League (via LTT MarkBench) + Cinebench R23
- Cross-platform: All containerized benchmarks (7-Zip, STREAM, Storage)
- Goal: Compare silicon lottery variance, identify best performer per workload

**Setup Guides Available:**
- `HP-ZBOOK-SETUP.md` - Complete Windows software installation
- `MS-01-SETUP.md` - Keras OCR deployment for Rocket League
- `docker/README.md` - Containerized benchmark usage

## 📋 What's Next

**High Priority:**
- Multi-run automation testing and refinement
- PresentMon FPS automation (Windows gaming metrics)
- Test HP ZBooks 01-04
- Performance comparison analysis

**Medium Priority:**
- NFS model sharing infrastructure
- Windows PowerShell multi-run script
- Extended context testing (100k-1M tokens)

**Future:**
- Supabase database integration
- Streamlit visualization dashboard
- Thermal/power monitoring

## 🎯 Use Cases

**Silicon Lottery Analysis:**
All 4 HP ZBooks use identical AMD Ryzen AI Max+ 395 chips. Benchmarks will reveal performance variance and help us assign the best unit for each use case (gaming, CPU-heavy, AI inference, etc.).

**Form Factor Comparison:**
Framework desktop mainboard (mini-ITX) vs HP ZBook laptops - same CPU, different cooling. See how thermal design impacts sustained performance.

**Reproducible Testing:**
Containerized benchmarks eliminate environment differences. Same test, same results, any platform.

## 🤝 How You Can Help

1. **Test on Your Systems**: Benchmarks work on any Docker/Podman system
2. **Contribute Benchmarks**: Got a workload we should test? Add it!
3. **HP ZBook Testing**: Help run the full suite on all 4 units
4. **Model Downloads**: We need GGUF models for AI inference tests

## 📚 Resources

- **[GitHub Repository](https://github.com/vvautosports/vtt-hw-benchmarks)** - Full source code
- **[ROADMAP.md](./ROADMAP.md)** - Feature priorities and next steps
- **[GitHub Issues](./github-issues-to-create.md)** - 7 issues ready to create
- **[Quick Start](./README.md)** - Get benchmarks running in 5 minutes

## 🔧 Technical Details

**Container Images:**
- `vtt-benchmark-7zip` - Alpine + p7zip
- `vtt-benchmark-stream` - Debian + GCC + STREAM
- `vtt-benchmark-storage` - Ubuntu + fio
- `vtt-benchmark-llama` - Ubuntu + llama.cpp

**Quick Test:**
```bash
cd docker
./build-all.sh
./run-all.sh
# Or for statistical analysis:
./run-multiple.sh
```

## 💬 Discussion

Have hardware you want benchmarked? Need specific workload tests? Want to help with HP ZBook testing? Let's discuss!

*#hardware-benchmarks #performance-testing #containerization #vvt-autosports*

---

**Posted from:** vtt-hw-benchmarks commit `424dc21`
**Branch:** master
**Total Commits:** 9 (Initial setup → AI inference with Strix Halo support)
**Repository:** New standalone benchmark project
**Latest:** AMD Strix Halo iGPU AI benchmarks fully operational!
