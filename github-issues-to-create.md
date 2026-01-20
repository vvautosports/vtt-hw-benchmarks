# GitHub Issues to Create for VTT Hardware Benchmarks

## Issue 1: Storage Benchmark Container (fio) ✅ COMPLETED
**Title:** `[Benchmark] Add Storage I/O Benchmark Container (fio)`

**Status:** ✅ **COMPLETED** - Implemented with progress indicators

**Body:**
```markdown
## Description
Add containerized storage benchmark using fio (Flexible I/O Tester) to measure disk performance across all tested systems. This follows the same pattern as existing 7-Zip and STREAM benchmarks.

## Current Status
- ✅ 7-Zip CPU benchmark container working
- ✅ STREAM memory benchmark container working
- ✅ LLaMA AI inference benchmark container working
- ✅ Storage benchmark implemented and tested

## Scope
Create a new containerized benchmark for storage I/O testing with consistent output format matching existing benchmarks.

## Acceptance Criteria
- [ ] Create `docker/storage/Dockerfile` with fio installed
- [ ] Create `docker/storage/benchmark.sh` with test configurations
- [ ] Implement tests:
  - Sequential read (1M block size)
  - Sequential write (1M block size)
  - Random 4K read (IOPS)
  - Random 4K write (IOPS)
  - Mixed 70/30 read/write workload
- [ ] Output JSON format matching other benchmarks
- [ ] Add to `docker/build-all.sh`
- [ ] Add to `docker/run-all.sh` and `docker/run-all.ps1`
- [ ] Test on Framework laptop baseline
- [ ] Update `docker/README.md` with storage benchmark docs

## Technical Details

### fio Configuration
```ini
[global]
ioengine=libaio
direct=1
size=1G
runtime=60
time_based
group_reporting

[sequential-read]
rw=read
bs=1M

[sequential-write]
rw=write
bs=1M

[random-read-4k]
rw=randread
bs=4k

[random-write-4k]
rw=randwrite
bs=4k

[mixed-rw]
rw=randrw
rwmixread=70
bs=4k
```

### Expected Output Format
```json
{
  "benchmark": "storage",
  "timestamp": "2026-01-20T...",
  "storage_type": "NVMe SSD",
  "results": {
    "sequential_read_mbps": 3500,
    "sequential_write_mbps": 3000,
    "random_read_4k_iops": 450000,
    "random_write_4k_iops": 400000,
    "mixed_rw_iops": 425000
  }
}
```

## Related Files
- `docker/7zip/` - Reference implementation
- `docker/stream/` - Reference implementation
- `docker/build-all.sh` - Add new container
- `docker/run-all.sh` - Add new benchmark run

## Labels
`enhancement`, `benchmark`, `containerization`, `easy`, `good-first-issue`

## Priority
High - Adds critical test diversity

```

---

## Issue 2: Multi-Run Automation and Statistical Analysis 🚧 IN PROGRESS
**Title:** `[Automation] Implement Multi-Run Benchmarks with Statistical Analysis`

**Status:** 🚧 **IN PROGRESS** - Linux implementation complete, testing in progress

**Body:**
```markdown
## Description
Enhance benchmark reliability by running each test multiple times (3-5 runs) and calculating statistical metrics (mean, median, standard deviation, min, max). This eliminates outliers and provides more accurate performance data.

## Current Status
- ✅ Single-run benchmarks working
- ✅ Multi-run script created (Linux)
- 🚧 Testing in progress
- ❌ Windows PowerShell version not yet implemented

## Scope
Create automation to run benchmarks multiple times and analyze results statistically.

## Acceptance Criteria
- [ ] Create `docker/run-multiple.sh` (Linux)
- [ ] Create `docker/run-multiple.ps1` (Windows)
- [ ] Run each benchmark N times (configurable, default 5)
- [ ] Collect all JSON outputs
- [ ] Create `scripts/analyze-results.py` for statistical analysis
- [ ] Calculate metrics:
  - Mean
  - Median
  - Standard deviation
  - Min/Max
  - Coefficient of variation
  - Outlier detection (3-sigma rule)
- [ ] Generate summary report in markdown
- [ ] Generate combined JSON with statistics
- [ ] Update result templates with multi-run format
- [ ] Test on Framework laptop

## Technical Details

### Run-Multiple Script Features
- Configurable number of runs (env var: `BENCHMARK_RUNS=5`)
- Cool-down period between runs (30 seconds default)
- Individual run results saved with timestamps
- Aggregated output file with all runs

### Statistical Analysis Output
```json
{
  "benchmark": "7zip",
  "runs": 5,
  "statistics": {
    "overall_mips": {
      "mean": 119500,
      "median": 119390,
      "stddev": 342,
      "min": 119100,
      "max": 120100,
      "cv": 0.29,
      "outliers": []
    }
  },
  "raw_runs": [119390, 119500, 119100, 120100, 119800]
}
```

## Related Files
- `docker/run-all.sh` - Reference for single runs
- `results/` - Output location for multi-run data
- `scripts/` - New analysis script location

## Labels
`enhancement`, `automation`, `statistics`, `medium-difficulty`

## Priority
High - Critical for accurate performance comparison

```

---

## Issue 3: Automated FPS Capture with PresentMon
**Title:** `[Windows] Automated FPS Capture for Rocket League Benchmark`

**Body:**
```markdown
## Description
Integrate PresentMon for automated FPS (frames per second) capture during Rocket League benchmarks, eliminating manual observation and providing accurate performance metrics.

## Current Status
- ✅ Rocket League benchmark runs via LTT MarkBench
- ✅ Keras OCR service integration working
- ❌ FPS capture is manual (visual observation)
- ❌ No automated FPS metrics

## Scope
Create PowerShell automation to run PresentMon alongside Rocket League benchmark and parse FPS data.

## Acceptance Criteria
- [ ] Create `scripts/rocket-league-presentmon.ps1`
- [ ] Download and install PresentMon automatically
- [ ] Launch PresentMon before Rocket League benchmark starts
- [ ] Capture FPS data during entire benchmark run
- [ ] Parse PresentMon CSV output
- [ ] Calculate metrics:
  - Average FPS
  - Minimum FPS
  - Maximum FPS
  - 1% Low (99th percentile)
  - 0.1% Low (99.9th percentile)
  - Frame time variance
- [ ] Output JSON format for automation
- [ ] Integrate with existing MarkBench workflow
- [ ] Update HP ZBook result template with new metrics
- [ ] Test on HP ZBook 01

## Technical Details

### PresentMon Integration
```powershell
# Download PresentMon
$presentMonUrl = "https://github.com/GameTechDev/PresentMon/releases/latest"
# Start PresentMon in background
Start-Process -FilePath "PresentMon.exe" -ArgumentList "--process_name RocketLeague.exe --output_file fps_data.csv" -NoNewWindow

# Run Rocket League benchmark
python rocket_league.py --kerasHost $MS01_IP --kerasPort 8080

# Stop PresentMon
Stop-Process -Name "PresentMon"

# Parse CSV
$fpsData = Import-Csv fps_data.csv
# Calculate statistics...
```

### Expected Output Format
```json
{
  "benchmark": "rocket_league",
  "timestamp": "2026-01-20T...",
  "resolution": "1920x1080",
  "quality": "High",
  "results": {
    "avg_fps": 165.3,
    "min_fps": 142.1,
    "max_fps": 189.4,
    "fps_1_percent_low": 148.5,
    "fps_0_1_percent_low": 145.2,
    "frame_time_avg_ms": 6.05,
    "frame_time_variance": 0.32
  }
}
```

## Related Files
- `HP-ZBOOK-SETUP.md` - Rocket League setup guide
- `results/hp-zbook-template.md` - Result template to update
- `scripts/` - New PowerShell script location

## Dependencies
- PresentMon (https://github.com/GameTechDev/PresentMon)
- Existing LTT MarkBench setup
- Windows 10/11

## Labels
`enhancement`, `windows`, `automation`, `benchmark`, `medium-difficulty`

## Priority
High - Critical for accurate gaming performance measurement

```

---

## Issue 4: Multiple AI Model Testing
**Title:** `[Benchmark] Expand AI Inference Testing to 5+ Models`

**Body:**
```markdown
## Description
Test multiple AI models of varying sizes to evaluate CPU inference performance across different model architectures and quantization levels.

## Current Status
- ✅ LLaMA inference container infrastructure working
- ✅ llama.cpp built and tested
- ❌ Only tested with single model (ad-hoc)
- ❌ No model library established

## Scope
Download and test 5+ AI models representing different sizes and use cases.

## Acceptance Criteria
- [ ] Download models (or document where to get them):
  - Llama 3.2 1B Q4_K_M (~800 MB)
  - Llama 3.2 3B Q4_K_M (~2 GB)
  - Qwen 2.5 3B Q4_K_M (~2 GB)
  - Qwen 2.5 7B Q4_K_M (~4.5 GB)
  - Phi 3.5 Mini Q4_K_M (~2.3 GB)
- [ ] Store models in shared location (MS-01 or local)
- [ ] Update `docker/run-all.sh` to test all models
- [ ] Update `docker/run-all.ps1` to test all models
- [ ] Document model sources and licenses
- [ ] Test all models on Framework laptop
- [ ] Update result templates with multi-model format
- [ ] Create model comparison analysis

## Technical Details

### Model Sources
Models available from:
- Hugging Face (https://huggingface.co/models)
- TheBloke's GGUF conversions
- Official model repositories

### Multi-Model Runner Script
```bash
# docker/run-all-models.sh
MODELS=(
  "/models/llama-3.2-1b-q4.gguf"
  "/models/llama-3.2-3b-q4.gguf"
  "/models/qwen-2.5-3b-q4.gguf"
  "/models/qwen-2.5-7b-q4.gguf"
  "/models/phi-3.5-mini-q4.gguf"
)

for model in "${MODELS[@]}"; do
  podman run --rm -v "$model:/models/model.gguf" vtt-benchmark-llama
done
```

### Expected Output Format
```json
{
  "benchmark": "llama-multi-model",
  "models_tested": 5,
  "results": [
    {
      "model": "llama-3.2-1b-q4",
      "size_gb": 0.8,
      "prompt_processing_tps": 450,
      "text_generation_tps": 85
    },
    // ... more models
  ]
}
```

## Related Files
- `docker/llama-bench/` - Existing infrastructure
- `docker/run-all.sh` - Update with multi-model support
- `docs/AI-MODELS.md` - New model documentation

## Dependencies
- Requires model files (5-15 GB total)
- May require NFS setup for sharing across devices (Issue #6)

## Labels
`enhancement`, `benchmark`, `ai-inference`, `easy`

## Priority
Medium - Adds test diversity, blocked on model downloads

```

---

## Issue 6: Supabase Database Integration
**Title:** `[Infrastructure] Supabase Database for Benchmark Results`

**Body:**
```markdown
## Description
Migrate from markdown file storage to Supabase PostgreSQL database for structured benchmark result storage, enabling advanced queries, comparisons, and dashboard visualization.

## Current Status
- ✅ Results stored in markdown files in git
- ✅ JSON output from all benchmarks
- ❌ No structured database
- ❌ No queryable result storage

## Scope
Design database schema, create Supabase project, implement upload scripts, and migrate existing results.

## Acceptance Criteria
- [ ] Design database schema:
  - `devices` table (id, name, cpu, gpu, ram, etc.)
  - `benchmark_runs` table (id, device_id, timestamp, benchmark_type)
  - `benchmark_results` table (run_id, metric_name, metric_value)
- [ ] Create Supabase project
- [ ] Implement database schema with migrations
- [ ] Create `scripts/upload-to-supabase.py` for result upload
- [ ] Migrate existing markdown results to database
- [ ] Update benchmark runner scripts to auto-upload
- [ ] Implement query functions for common analyses
- [ ] Document database schema and API usage
- [ ] Test upload from all benchmark types

## Technical Details

### Database Schema (Simplified)
```sql
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL, -- 'hp-zbook', 'framework', etc.
  cpu TEXT,
  gpu TEXT,
  ram_gb DECIMAL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE benchmark_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID REFERENCES devices(id),
  benchmark_type TEXT NOT NULL, -- '7zip', 'stream', 'rocket_league', etc.
  timestamp TIMESTAMP NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE benchmark_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id UUID REFERENCES benchmark_runs(id),
  metric_name TEXT NOT NULL,
  metric_value DECIMAL,
  unit TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Upload Script
```python
# scripts/upload-to-supabase.py
import json
from supabase import create_client

# Parse JSON result
result = json.load(open('result.json'))

# Upload to Supabase
supabase = create_client(url, key)
supabase.table('benchmark_runs').insert({
  'device_id': device_uuid,
  'benchmark_type': result['benchmark'],
  'timestamp': result['timestamp'],
  'metadata': result
}).execute()
```

## Related Files
- `scripts/` - Upload script location
- `results/` - Existing markdown results to migrate
- `docker/run-all.sh` - Add auto-upload after benchmarks

## Dependencies
- Supabase account and project
- Python Supabase client library
- API keys and environment configuration

## Labels
`infrastructure`, `database`, `supabase`, `high-difficulty`

## Priority
Low - Future enhancement, not critical for initial testing

```

---

## Issue 7: Performance Dashboard (Streamlit)
**Title:** `[Visualization] Streamlit Dashboard for Benchmark Results`

**Body:**
```markdown
## Description
Create interactive web dashboard using Streamlit to visualize benchmark results, compare devices, and identify performance trends.

## Current Status
- ✅ Benchmark results available (markdown/future database)
- ❌ No visualization dashboard
- ❌ Manual comparison required

## Scope
Build Streamlit application to query and visualize benchmark data.

## Acceptance Criteria
- [ ] Create `dashboard/app.py` Streamlit application
- [ ] Implement pages:
  - Overview: All devices summary
  - Device Comparison: Side-by-side comparison
  - Benchmark Details: Deep dive per benchmark
  - Performance Trends: Historical performance
  - Leaderboard: Best performers per workload
- [ ] Visualizations:
  - Bar charts for benchmark comparisons
  - Line charts for trend analysis
  - Radar charts for multi-metric comparison
  - Tables for detailed data
- [ ] Filters:
  - Device type
  - Date range
  - Benchmark type
- [ ] Export capabilities (CSV, PDF report)
- [ ] Deploy dashboard (local or cloud)
- [ ] Document dashboard usage

## Technical Details

### Dashboard Structure
```python
# dashboard/app.py
import streamlit as st
import plotly.express as px

st.title("VTT Hardware Benchmark Dashboard")

# Sidebar filters
device_filter = st.sidebar.multiselect("Devices", devices)
benchmark_filter = st.sidebar.multiselect("Benchmarks", benchmarks)

# Main content
tab1, tab2, tab3 = st.tabs(["Overview", "Comparison", "Details"])

with tab1:
    # Overall performance chart
    fig = px.bar(data, x='device', y='score', color='benchmark')
    st.plotly_chart(fig)

# ... more pages
```

### Sample Visualizations
- 7-Zip MIPS comparison across all devices
- Memory bandwidth (STREAM) comparison
- Rocket League FPS by device
- AI inference tokens/sec by model size
- Silicon lottery variance visualization

## Related Files
- `dashboard/` - New directory for dashboard app
- `dashboard/requirements.txt` - Python dependencies
- `scripts/query-results.py` - Helper functions for data retrieval

## Dependencies
- Requires Supabase database (Issue #6) OR can work with markdown files initially
- Python Streamlit library
- Plotly for charts

## Labels
`enhancement`, `visualization`, `dashboard`, `high-difficulty`

## Priority
Low - Nice-to-have, not critical for initial testing

```

---

## Summary

### Implementation Status

**Completed:**
1. ✅ **Issue #1: Storage Benchmark** - Adds critical test diversity

**Recommended Implementation Order (by difficulty):**

1. ✅ **Issue #1: Storage Benchmark** (Easy) - COMPLETED
2. **Issue #4: Multiple AI Models** (Easy) - Adds test diversity, needs model downloads
3. **Issue #2: Multi-Run Automation** (Medium) - Critical for statistical accuracy
4. **Issue #3: PresentMon FPS** (Medium) - Critical for Windows gaming metrics
5. **Issue #5: NFS Model Sharing** (Medium) - Infrastructure improvement
6. **Issue #6: Supabase Database** (Hard) - Future infrastructure
7. **Issue #7: Streamlit Dashboard** (Hard) - Visualization layer

### Priority Categorization

**High Priority (Automation & Test Diversity):**
- ✅ Issue #1: Storage Benchmark (DONE)
- Issue #2: Multi-Run Automation
- Issue #3: PresentMon FPS

**Medium Priority (Test Expansion):**
- Issue #4: Multiple AI Models
- Issue #5: NFS Model Sharing

**Low Priority (Future Infrastructure):**
- Issue #6: Supabase Database
- Issue #7: Streamlit Dashboard

### Next Recommended Tasks

Focus on Issues #2 (Multi-run automation) or #4 (Multiple AI models):
- Add most value immediately
- Follow established patterns
- Don't require external dependencies (except model downloads for #4)
- Work across all platforms
