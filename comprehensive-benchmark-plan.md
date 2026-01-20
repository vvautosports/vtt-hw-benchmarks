# Laptop Benchmark Suite - Implementation Plan

## Summary

Build benchmark suite to compare Framework laptop (Fedora 43) + 4 HP ZBook Ultra G1a laptops (Windows 11, Ryzen AI Max+ 395). Test on Framework first, automate, deploy to HP ZBooks. Results stored in Supabase PostgreSQL on MS-01, visualized via Streamlit dashboard.

**Goal:** Identify best HP ZBook for specific workloads through comprehensive testing.

---

## Test Categories

### Category 1: System Performance (6 tests)

**1.1 CPU Tests**
- Cinebench R23 (multi-core rendering)
- 7-Zip Benchmark (compression + memory bandwidth)

**1.2 GPU Tests**
- Blender Benchmark (3D rendering)
- RDR2 Built-in Benchmark (gaming performance)

**1.3 Memory Tests**
- STREAM Benchmark (memory bandwidth: copy, scale, add, triad)

**1.4 Storage Tests**
- fio (sequential read/write, random IOPS)

**Source:** LTT MarkBench (Cinebench, Blender, Storage), 7-Zip (built-in), STREAM (binary), RDR2 (owned game)

---

### Category 2: AI Inference (5 models)

**Test Tool:** llama-bench from llama.cpp

| Model | Size | Params | Company | Test |
|-------|------|--------|---------|------|
| GPT-OSS | 13.8GB | 20B | NousResearch | Prompt (512t) + Gen (128t) |
| Apriel Thinker | 28.9GB | 15B | RoversX | Prompt (512t) + Gen (128t) |
| Qwen3-Coder | 61.1GB | 30B | Alibaba | Prompt (512t) + Gen (128t) |
| Qwen3 Next | 84.8GB | 80B | Alibaba | Prompt (512t) + Gen (128t) |
| Qwen3 Instruct | 104GB | 235B | Alibaba | Prompt (512t) + Gen (128t) |

**Metrics:** Prompt tokens/sec, Generation tokens/sec, Memory used

---

### Category 3: Image Generation (1 test)

**Model:** Flux.2 Klein (7.75GB, 4B params, Black Forest Labs)  
**Test:** Generate 512x512 image, measure time  
**Tool:** ComfyUI or diffusers

---

## Infrastructure

### MS-01 Hub

**Services:**
1. **NFS Server:** `/mnt/benchmarks/models` (310GB models, read-only)
2. **Supabase:** PostgreSQL + PostgREST + Studio UI
3. **Streamlit Dashboard:** Visualization at http://192.168.4.x:8501

**NFS Exports:**
```
/mnt/benchmarks/models  192.168.4.0/22(ro,sync,no_subtree_check)
/mnt/benchmarks/scripts 192.168.4.0/22(ro,sync,no_subtree_check)
```

### Supabase Database

**Tables:**
- `systems` - Hardware metadata (CPU, RAM, OS)
- `benchmark_runs` - Run metadata + raw JSON output (JSONB)
- `system_tests` - Cinebench, Blender, 7-Zip, STREAM, Storage, RDR2 results
- `llm_tests` - Per-model inference metrics
- `image_tests` - Flux.2 generation times
- `models` - Model registry

**Why JSONB:** Store complete test outputs, extract metrics later

---

## Test Execution Strategy

### Setup Phase (Framework - Run Once)
- Test each component manually
- Verify outputs
- Document working commands
- Establish baseline

### Automated Phase (All Systems - Run 5x)
- Run full suite 5 times per system
- 30-second cooldown between runs
- Calculate mean, median, stddev
- Exception: Tests >1 hour run once only (XXL model)

### Progress Display

```
╔══════════════════════════════════════════════════════════╗
║  Benchmark Suite - Run 2/5                               ║
╠══════════════════════════════════════════════════════════╣
║                                                           ║
║  [Category 1: System Performance]                        ║
║  ├─ Cinebench R23        ████████████ 100% | 15,240     ║
║  ├─ 7-Zip Benchmark      ████████████ 100% | 52,130 MIPS║
║  ├─ Blender              ██████░░░░░░  50% | ETA: 3m    ║
║  ├─ RDR2                 ░░░░░░░░░░░░   0% | Queued     ║
║  ├─ STREAM               ░░░░░░░░░░░░   0% | Queued     ║
║  └─ Storage (fio)        ░░░░░░░░░░░░   0% | Queued     ║
║                                                           ║
║  [Category 2: AI Inference] - 0/5 models                 ║
║  [Category 3: Image Gen] - 0/1 models                    ║
║                                                           ║
║  Cooldown: 30s between tests | Total ETA: 42m            ║
╚══════════════════════════════════════════════════════════╝
```

---

## Implementation Flow

### Phase 1: MS-01 Setup
1. Deploy Supabase (PostgreSQL + PostgREST + Studio)
2. Create database schema
3. Configure NFS exports
4. Download models (310GB)
5. Validate: NFS accessible, Supabase responding

### Phase 2: Framework Manual Testing
**Test each individually (run once):**
1. Mount NFS from MS-01
2. Cinebench R23
3. 7-Zip benchmark
4. Blender benchmark
5. RDR2 benchmark
6. STREAM benchmark
7. Storage (fio)
8. llama-bench (all 5 models)
9. Flux.2 (optional)
10. Document results

### Phase 3: Automation
1. Build unified script: `run-all-benchmarks.sh`
2. Organize by category
3. Add progress display
4. Implement cooldown
5. POST results to Supabase REST API
6. Test: Run 5x on Framework, verify aggregation

### Phase 4: Container
1. Extend `geerlingguy/docker-fedora43-ansible`
2. Add benchmark tools (sysbench, fio, 7z, llama-bench)
3. Add models via NFS mount
4. Copy benchmark scripts
5. Test on Framework

### Phase 5: HP Deployment
1. Setup Windows + Docker Desktop + WSL2
2. Install Headscale client
3. Mount NFS in WSL2
4. Load container
5. Run full suite (5x)
6. Repeat for all 4 HP ZBooks

### Phase 6: Dashboard
1. Create Streamlit app on MS-01
2. Connect to Supabase PostgreSQL
3. Display system comparison charts
4. Show per-category best performers
5. Export results to CSV
6. Access at http://192.168.4.x:8501

---

## Script Structure

```
scripts/
├── validate-ms01.sh        # Check NFS, Supabase, models
├── run-all.sh              # Full suite, 5x runs
├── run-category.sh         # Single category, Nx runs
│   # Usage: ./run-category.sh system 5
│   # Usage: ./run-category.sh ai 5
│   # Usage: ./run-category.sh image 1
└── utils/
    ├── progress-display.sh
    ├── cooldown.sh
    └── upload-results.sh
```

---

## Dashboard Features

**System Comparison Page:**
- Bar charts: CPU score, GPU score, Memory bandwidth, AI tokens/sec
- Table: All systems ranked by category
- Highlight best performer per workload

**Model Performance Page:**
- Line chart: tokens/sec across all 5 models per system
- Identify which HP excels at which model size
- Memory usage comparison

**Statistical Analysis:**
- Mean, median, standard deviation (5 runs)
- Silicon lottery variance between HP units
- Consistency scores

**Raw Data Export:**
- Download CSV of all results
- Filter by system, date, test type

---

## Repository Structure

```
homelab-benchmarks/
├── README.md
├── Dockerfile
├── scripts/
│   ├── run-all.sh
│   ├── run-category.sh
│   ├── validate-ms01.sh
│   └── utils/
├── supabase/
│   ├── docker-compose.yml
│   ├── schema.sql
│   └── seed-models.sql
├── dashboard/
│   ├── app.py
│   ├── requirements.txt
│   └── queries.sql
└── docs/
    ├── SETUP.md
    └── TESTING.md
```

---

## Success Criteria

**Phase 1 Complete:**
- [ ] Supabase running on MS-01
- [ ] NFS serving models
- [ ] All 6 models downloaded
- [ ] Database schema created

**Phase 2 Complete:**
- [ ] All 12 tests run successfully on Framework
- [ ] Results saved to Supabase
- [ ] Baseline performance documented

**Phase 3 Complete:**
- [ ] Unified script runs all tests
- [ ] 5x automation working
- [ ] Progress display functional
- [ ] Results aggregate correctly

**Phase 4 Complete:**
- [ ] Container built and tested
- [ ] Runs on Framework in container
- [ ] Performance similar to bare metal

**Phase 5 Complete:**
- [ ] All 4 HP ZBooks tested
- [ ] 5x runs completed per system
- [ ] All results in Supabase

**Phase 6 Complete:**
- [ ] Dashboard deployed
- [ ] Charts display correctly
- [ ] Best performers identified
- [ ] Export functionality works

---

## Test Summary

**Total Tests:** 12 (6 system + 5 AI + 1 image)  
**Setup Time:** 1x run (~45 min)  
**Automated Time:** 5x runs (~3.5 hours per system)  
**Total Systems:** 5 (Framework + 4 HP)  
**Total Data Points:** ~60 benchmark runs

**Expected Outcome:** Clear identification of best HP ZBook for:
- CPU-heavy workloads
- GPU rendering
- Memory-intensive tasks
- Small LLM inference (20B-30B)
- Large LLM inference (80B-235B)
- Gaming performance

**Deliverables:**
1. Working benchmark suite
2. MS-01 infrastructure (NFS + Supabase + Dashboard)
3. Performance comparison report
4. HP assignment recommendations
