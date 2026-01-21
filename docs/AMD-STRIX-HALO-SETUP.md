# AMD Strix Halo Setup for AI Benchmarks

Configuration guide for AMD Ryzen AI Max+ 395 (Strix Halo) AI inference benchmarks.

## BIOS Settings

**UMA Frame Buffer Size (iGPU Memory Allocation):**
- **Recommended:** 4 GB
- **Previous:** 512 MB (minimum)
- **Why:** Larger allocation improves GPU inference performance and stability

**How to configure:**
1. Enter BIOS/UEFI (typically F2 or DEL during boot)
2. Navigate to Advanced → AMD CBS → NBIO Common Options
3. Find "UMA Frame Buffer Size" or "iGPU Memory"
4. Set to 4GB (4096 MB)
5. Save and reboot

## Backend Options

The AI benchmarks use pre-built toolboxes from [kyuz0/amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes).

### Vulkan (RADV) - Default & Most Stable

**Pros:**
- Most stable and compatible
- Works with all model sizes
- Recommended for most users

**Cons:**
- Slightly slower than ROCm in some cases

**Container:** `docker.io/kyuz0/amd-strix-halo-toolboxes:vulkan-radv`

**Device Mounts:**
```bash
--device /dev/dri --group-add video --security-opt seccomp=unconfined
```

### ROCm - Better Performance (if stable)

**Pros:**
- Better performance for some workloads
- More optimized for ML/AI

**Cons:**
- Less stable
- May have compatibility issues with some models

**Available versions:**
- `rocm-6.4.4` - Stable ROCm 6.4.4
- `rocm-7.1.1` - Current GA release
- `rocm7-nightlies` - Bleeding edge (use with caution)

**Device Mounts:**
```bash
--device /dev/dri --device /dev/kfd --group-add video --group-add render --security-opt seccomp=unconfined
```

## Critical Flags for Strix Halo

These flags are **REQUIRED** or inference will crawl/crash:

- `-fa 1` - Flash attention (mandatory for Strix Halo)
- `-mmp 0` - Disable memory mapping (mandatory for stability)
- `-ngl 999` - Offload all layers to GPU

These are automatically included in our benchmark scripts.

## Building with Different Backends

**Vulkan (default):**
```bash
cd docker/llama-bench
podman build -t vtt-benchmark-llama .
```

**ROCm 7.1.1:**
```bash
cd docker/llama-bench
podman build --build-arg BACKEND=rocm-7.1.1 -t vtt-benchmark-llama-rocm .
```

**ROCm 6.4.4:**
```bash
cd docker/llama-bench
podman build --build-arg BACKEND=rocm-6.4.4 -t vtt-benchmark-llama-rocm6 .
```

## Running AI Benchmarks

### Single Model Test

**With Vulkan (default):**
```bash
podman run --rm \
  --device /dev/dri --group-add video --security-opt seccomp=unconfined \
  -v /mnt/ai-models/model.gguf:/models/model.gguf:ro \
  vtt-benchmark-llama
```

**With ROCm:**
```bash
podman run --rm \
  --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --security-opt seccomp=unconfined \
  -v /mnt/ai-models/model.gguf:/models/model.gguf:ro \
  vtt-benchmark-llama-rocm
```

### Multiple Models Test

The `run-ai-models.sh` script automatically tests all GGUF models in `/mnt/ai-models`:

```bash
cd docker
./run-ai-models.sh
```

This will:
- Discover all GGUF models
- Handle multi-part models automatically
- Mount AMD iGPU devices
- Run benchmarks with Strix Halo optimizations
- Output JSON results with performance metrics

## Troubleshooting

### Firmware Issues

**DO NOT use `linux-firmware-20251125`** - it breaks ROCm support on Strix Halo.

If you have it installed, downgrade following the [toolbox troubleshooting guide](https://github.com/kyuz0/amd-strix-halo-toolboxes/blob/main/docs/troubleshooting-firmware.md).

### GPU Not Detected

```bash
# Check GPU devices exist
ls -l /dev/dri

# Check video group membership
groups

# Test GPU detection inside container
podman run --rm \
  --device /dev/dri --group-add video \
  vtt-benchmark-llama \
  llama-cli --list-devices
```

### Poor Performance

1. **Check BIOS UMA allocation:** Should be 4GB, not 512MB
2. **Verify flash attention is enabled:** Check benchmark output for `-fa 1`
3. **Try ROCm backend:** May be faster for your specific model
4. **Check thermal throttling:** Use `radeontop` to monitor GPU

### Model Won't Load

1. **Multi-part models:** Ensure all parts are in same directory
2. **Memory:** Use VRAM estimator to check if model fits
3. **Backend limits:** AMDVLK has 2GB buffer limit, switch to RADV

## Performance Expectations

**Framework Desktop (mini-ITX) with AMD Ryzen AI Max+ 395:**
- Small models (7B Q4): 40-80 tokens/sec
- Medium models (30B Q4): 15-30 tokens/sec
- Large models (70B+ Q4): 5-15 tokens/sec

**HP ZBook (laptop) with same CPU:**
- Expect similar performance
- May thermal throttle faster than desktop form factor
- BIOS UMA allocation may differ

## References

- [AMD Strix Halo Toolboxes GitHub](https://github.com/kyuz0/amd-strix-halo-toolboxes)
- [Interactive Benchmark Viewer](https://kyuz0.github.io/amd-strix-halo-toolboxes/)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
