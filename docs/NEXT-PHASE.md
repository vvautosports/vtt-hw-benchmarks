# Next Phase: MLflow Integration & Dashboarding

**Trigger:** After successful completion of Task #13 (default 5-model test)

**Phase Order:**
1. Validate Task #13 results
2. Run first HP ZBook test (same 5 models)
3. Deploy MLflow stack to MS-01
4. Implement real-time result tracking
5. Create dashboarding
6. Then run full 20-model test overnight

---

## Phase 1: Validation (Post Task #13)

**Success Criteria:**
- [ ] Default 5-model test completes successfully
- [ ] JSON output validates with `scripts/utils/validate-results.sh`
- [ ] Performance metrics within expected ranges
- [ ] No errors in log file

**Expected Results:**
- GLM-4.7-Flash-Q8: 700-900 t/s prompt, 30-40 t/s gen
- GPT-OSS-20B: 1000-1200 t/s prompt, 40-50 t/s gen
- Large models (235B): 100-200 t/s prompt, 10-20 t/s gen

---

## Phase 2: HP ZBook First Test

**Goal:** Validate Windows/HP ZBook setup before full rollout

**Steps:**
1. Run `scripts/utils/setup-windows.ps1` on one HP ZBook
2. Verify WSL2 and Docker installation
3. Run `MODEL_CONFIG_MODE=default ./run-ai-models.sh`
4. Compare results to Framework baseline (±10%)
5. Document any Windows-specific issues

---

## Phase 3: MS-01 MLflow Stack Deployment

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

---

## Phase 4: Real-Time Result Tracking

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

---

## Phase 5: Dashboarding

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

## Phase 6: Full 20-Model Test (Overnight)

**Only After:**
- ✅ Task #13 validated
- ✅ HP ZBook test successful
- ✅ MLflow stack deployed
- ✅ Auto-commit working
- ✅ Dashboarding accessible

**Command:**
```bash
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```

**Expected:**
- Duration: 2-3 hours
- Models: ~20 auto-discovered
- Results: Posted to MLflow + git

**Next Day Review:**
- Check dashboard for all results
- Validate auto-commits worked
- Compare performance across all models
- Identify fastest/most efficient models

---

## Implementation Tasks

**Create these as separate tasks:**

1. **Deploy MLflow Stack**
   - SSH to MS-01
   - Run deployment script
   - Verify all services
   - Configure client env vars

2. **Implement Auto-Commit**
   - Modify run-ai-models.sh
   - Add git commit logic
   - Test on Framework
   - Document commit format

3. **Add MLflow Logging**
   - Create Python wrapper script
   - Parse JSON results
   - Log to MLflow
   - Test on Framework

4. **Build Dash Dashboard**
   - Setup Dash app structure
   - Connect to MLflow backend
   - Create 4 core dashboards
   - Deploy to MS-01 (port 8050)

5. **HP ZBook Validation**
   - Run setup-windows.ps1
   - Run default test
   - Compare to Framework
   - Document issues

6. **Full 20-Model Test**
   - Verify all systems ready
   - Run overnight
   - Review results in dashboard

---

## Success Metrics

**Phase 3 (MLflow):**
- All 4 containers running on MS-01
- Accessible from Framework/ZBooks
- Test data logged successfully

**Phase 4 (Auto-tracking):**
- Results auto-committed to git
- MLflow shows all test runs
- No manual intervention needed

**Phase 5 (Dashboarding):**
- Dashboard accessible at http://192.168.7.30:8050
- Shows all system results
- Allows filtering/comparison
- Manual annotations work

**Phase 6 (Full Test):**
- All 20 models complete
- Results in dashboard
- Performance data collected
- Silicon lottery variance identified

---

**Next Steps:** Complete Task #13, then proceed with phases above
