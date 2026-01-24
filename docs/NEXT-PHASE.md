# Next Phase: MLflow Integration & Gaming Benchmarks

**Current Priority:** Local AI benchmarks working first (Windows → Linux)

**Testing Order:**
1. HP ZBook #1 - Windows local testing (Phase 1)
2. Framework Desktop - Linux validation (Phase 1)
3. Deploy MLflow to MS-01 (Phase 2)
4. HP ZBooks #2-4 with central tracking (Phase 2)
5. Gaming benchmarks (Phase 3 - Deferred)

---

## Phase 1: Local Testing (Current)

**Goal:** Get AI benchmarks working locally without MS-01 dependency

### 1.1 HP ZBook #1 - Windows Setup
- Run `scripts/utils/setup-windows-full.ps1`
- Run `scripts/testing/Test-Windows-Setup.ps1 -FullTest`
- Results save to `results/windows/hp-zbook-01/`
- Commit manually: `git add results/ && git commit`

### 1.2 Framework Desktop - Linux Validation
- Run: `cd docker && MODEL_CONFIG_MODE=default ./run-ai-models.sh`
- Results save to `results/linux/framework-desktop/`
- Validates both Windows and Linux paths work

**No MS-01 required** - Everything runs locally, results committed manually

---

## Phase 2: MS-01 Central Results (After Phase 1 Complete)

**Trigger:** After HP ZBook #1 AND Framework Desktop working

### 2.1 Deploy MLflow Stack to MS-01

**Infrastructure Setup:**

Deploy to MS-01 (`192.168.7.30`):
```bash
ssh ms01-admin@192.168.7.30
cd /opt
git clone https://github.com/vvautosports/vtt-hw-benchmarks.git
cd vtt-hw-benchmarks
./scripts/deployment/deploy-mlflow-stack.sh
```

**Components:**
- PostgreSQL (port 5432) - MLflow backend
- MinIO (ports 9000, 9001) - S3 artifact storage
- MLflow server (port 5000) - Experiment tracking
- Keras OCR (port 8080) - Rocket League testing

**Verification:**
```bash
curl http://192.168.7.30:5000/api/2.0/mlflow/experiments/list
docker-compose ps  # All 4 containers "Up"
```

**Configure Clients:**
```bash
# On Framework and HP ZBooks
export MLFLOW_TRACKING_URI=http://192.168.7.30:5000
echo 'export MLFLOW_TRACKING_URI=http://192.168.7.30:5000' >> ~/.bashrc
```

### 2.2 Update Test Scripts for MLflow

**Objective:** Automatically commit test results to git and MLflow

### 4.1 Git Auto-Commit Integration

Modify `docker/run-ai-models.sh` to:
1. Generate results JSON
2. Auto-commit to git with timestamp
3. Push to remote (optional, may want manual review)

**Example Integration:**
```bash
# After benchmark completes
git add results/ai-models-*.json
git commit -m "Auto: Benchmark results $(hostname) $(date -Iseconds)"
# Optional: git push origin master
```

**Considerations:**
- Use `--no-verify` to skip hooks during auto-commit
- Include system info in commit message
- Create separate branch for auto-commits vs manual work

### 4.2 MLflow Integration

**Modify `docker/run-ai-models.sh` to log metrics:**
```python
import mlflow
import json

# After each model test
with mlflow.start_run(run_name=f"{hostname}-{model_name}"):
    mlflow.log_params({
        "model": model_name,
        "size_gb": size_gb,
        "hostname": hostname,
        "cpu": cpu_model,
        "memory_gb": memory_gb
    })

    mlflow.log_metrics({
        "prompt_tps": prompt_processing_tps,
        "generation_tps": text_generation_tps
    })

    # Log full JSON as artifact
    mlflow.log_artifact(json_output_file)
```

**Benefits:**
- Centralized tracking across all machines
- Historical trend analysis
- Easy comparison between systems
- Experiment versioning

### 2.3 Test HP ZBooks #2 & #3

With MS-01 configured, test remaining laptops:
- Results save locally AND post to MS-01 MLflow
- Compare all machines in MLflow dashboard

---

## Phase 3: Gaming Benchmarks (Deferred)

**Priority:** After AI benchmarks working on all machines

**Components to Deploy:**

### 3.1 Keras OCR Service (MS-01)
Deploy for Rocket League menu navigation:
```bash
./scripts/deployment/deploy-keras-ocr-lxc.sh
```

**Requirements:**
- Proxmox LXC container on MS-01
- Docker with Keras OCR service
- Port 8080 accessible from HP ZBooks
- See: `docs/guides/MS-01-LXC-DEPLOYMENT.md`

### 3.2 Rocket League Benchmarks (HP ZBooks)
**Guide:** `docs/guides/HP-ZBOOK-ROCKET-LEAGUE.md`

**Software:**
- Epic Games Launcher
- Rocket League (free-to-play)
- Python 3.11
- Poetry
- LTT MarkBench

**Process:**
- Automated gameplay with standardized replay
- Keras OCR for menu navigation
- FPS measurement and logging

### 3.3 Cinebench R23
**Platform:** Windows (HP ZBooks)

**Integration:**
- Manual run (or script)
- Multi-core and single-core tests
- Record scores in results

### 3.4 Other LTT MarkBench Tests
**Available Tests:**
- CS:GO
- Shadow of the Tomb Raider
- Other automated gaming benchmarks

**Documentation:** https://github.com/LTTLabsOSS/markbench-tests

---

## Phase 4: Dashboarding & Analysis

**Preferred Stack:** Open-source Databricks ecosystem

### Option 1: Plotly Dash (Recommended)
- Open-source Python framework
- Interactive visualizations
- Works with MLflow data
- Human-editable layouts

**Architecture:**
```
MLflow (data source)
    ↓
Dash App (visualization)
    ↓
Web UI (port 8050)
```

**Features to Build:**
1. **Performance Comparison Dashboard**
   - Compare same model across different systems
   - Silicon lottery variance visualization
   - Sort by prompt/gen speed

2. **System Overview Dashboard**
   - All systems at a glance
   - Latest test results
   - Health status indicators

3. **Model Performance Dashboard**
   - All models on one system
   - Performance by model size
   - Efficiency metrics (perf/GB)

4. **Trend Analysis Dashboard**
   - Performance over time
   - Regression detection
   - Temperature/throttling correlation

**Manual Tweaking:**
- Custom annotations
- Threshold highlighting
- Filtering/grouping
- Export to PDF/PNG

### Option 2: MLflow UI (Built-in)
- Already included with MLflow
- Basic visualization
- Less customizable but zero-setup

### Option 3: Superset (Apache)
- More powerful BI tool
- SQL-based queries
- More complex setup

**Recommendation:** Start with Dash, fallback to MLflow UI

---

## Phase 5: Full Testing Suite

**After All Systems Working:**

### 5.1 Full 20-Model AI Test
```bash
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```
- Duration: 2-3 hours
- All GGUF models auto-discovered
- Results to MLflow + git

### 5.2 Complete Hardware Benchmarks
All systems run full suite:
- 7-Zip (CPU)
- STREAM (memory bandwidth)
- Storage I/O (fio)
- AI inference (llama.cpp)
- Gaming (Rocket League, Cinebench)

### 5.3 Silicon Lottery Analysis
Compare identical hardware:
- 4x HP ZBook Ultra G1a laptops
- Same CPU, RAM, storage
- Identify performance variance
- Document best performers for team assignment

---

## Success Criteria

**Phase 1 Complete:**
- ✅ HP ZBook #1 running AI benchmarks locally
- ✅ Framework Desktop running AI benchmarks locally
- ✅ Results saving to `results/` directory
- ✅ Both Windows and Linux paths validated

**Phase 2 Complete:**
- ✅ MLflow stack deployed on MS-01
- ✅ HP ZBooks #2-4 posting results to MLflow
- ✅ Dashboard showing all system results
- ✅ Comparison between machines working

**Phase 3 Complete:**
- ✅ Keras OCR deployed on MS-01
- ✅ Rocket League benchmarks working on HP ZBooks
- ✅ Cinebench integration complete
- ✅ Full gaming suite validated

**Phase 5 Complete:**
- ✅ All systems tested with full benchmark suite
- ✅ Silicon lottery analysis complete
- ✅ Performance data for team hardware assignment decisions

---

## Current Status

**Now:** Phase 1 - Local AI testing (Windows first, then Linux)
**Next:** Phase 2 - MS-01 MLflow deployment
**Later:** Phase 3 - Gaming benchmarks
**Future:** Phase 4 - Dashboarding & Phase 5 - Full suite
