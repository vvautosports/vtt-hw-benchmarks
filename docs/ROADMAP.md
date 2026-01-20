# VTT Hardware Benchmarks - Roadmap

## Current Status (v0.1 - Baseline)

**Completed:**
- ✅ Git repository structure
- ✅ Containerized benchmarks (7-Zip, STREAM, LLaMA)
- ✅ Linux/Windows support (Podman/Docker)
- ✅ Framework laptop baseline results
- ✅ Windows setup guides (HP ZBook, Rocket League, Cinebench)
- ✅ MS-01 Keras OCR deployment scripts
- ✅ Result templates and documentation

**Ready for:**
- HP ZBook testing (4 units)
- Windows-specific benchmarks (Rocket League, Cinebench)
- Cross-platform benchmarks on Windows via Docker Desktop

---

## Phase 2: Complete Device Testing

**Immediate Next Steps (Tonight/This Week):**

1. **Deploy Keras OCR on MS-01**
   - Task: Run `./scripts/deploy-keras-ocr.sh` on MS-01
   - Time: 10 minutes
   - Blocker: None
   - Output: Keras OCR service running on port 8080

2. **Test HP ZBook 01 (Windows)**
   - Task: Follow `HP-ZBOOK-SETUP.md` to install software
   - Task: Run Rocket League benchmark via MarkBench
   - Task: Run Cinebench R23
   - Task: Run containerized benchmarks (7-Zip, STREAM)
   - Time: 90 minutes initial setup + 30 min testing
   - Blocker: Depends on Keras OCR deployment
   - Output: `results/hp-zbook-01-YYYYMMDD.md`

3. **Test Remaining HP ZBooks (02, 03, 04)**
   - Task: Repeat testing process
   - Time: 30 minutes each (software already installed)
   - Blocker: None (can parallelize)
   - Output: Complete result files for all units

4. **Comparison Analysis**
   - Task: Compare all 5 systems (4 HP ZBooks + 1 Framework)
   - Task: Identify best performer for each workload
   - Task: Document silicon lottery variance
   - Time: 1 hour
   - Blocker: Need all device results
   - Output: `docs/performance-comparison.md`

---

## Phase 3: Automation & Refinement

**Priority: Medium (After initial testing complete)**

### 3.1 Automated FPS Capture for Rocket League

**Goal:** Eliminate manual FPS observation

**Tasks:**
- [ ] Integrate PresentMon for Windows FPS capture
- [ ] Parse PresentMon output automatically
- [ ] Add FPS stats to JSON output (avg, min, max, 1%, 0.1%)
- [ ] Update MarkBench runner script

**Assignable:** Yes - Independent task
**Time Estimate:** 3-4 hours
**Files to modify:**
- `scripts/rocket-league-runner.ps1` (new)
- `results/hp-zbook-template.md` (update)

### 3.2 Multi-Run Automation

**Goal:** Run each benchmark 3-5 times for statistical analysis

**Tasks:**
- [ ] Wrap benchmark runners in loop scripts
- [ ] Collect multiple runs per benchmark
- [ ] Calculate mean, median, stddev
- [ ] Identify outliers
- [ ] Generate statistical summary

**Assignable:** Yes - Independent task
**Time Estimate:** 4-5 hours
**Files to create:**
- `docker/run-multiple.sh`
- `scripts/analyze-results.py` (Python script)

### 3.3 Storage Benchmarks

**Goal:** Add disk I/O testing

**Tasks:**
- [ ] Create fio (Flexible I/O) benchmark container
- [ ] Add sequential read/write tests
- [ ] Add random 4K read/write tests
- [ ] Add IOPS measurement
- [ ] Test NVMe performance

**Assignable:** Yes - Independent task
**Time Estimate:** 3-4 hours
**Files to create:**
- `docker/storage/Dockerfile`
- `docker/storage/benchmark.sh`
- `docker/storage/fio-config.ini`

### 3.4 Additional AI Models

**Goal:** Test 5 different AI models (per original plan)

**Current:** LLaMA infrastructure exists
**Need:**
- [ ] Test Llama 3.2 3B Q4_K_M
- [ ] Test Llama 3.2 1B Q4_K_M
- [ ] Test Qwen 2.5 7B Q4_K_M
- [ ] Test Phi 3.5 Mini
- [ ] Test Gemma 2B

**Assignable:** Partially - Need model files first
**Time Estimate:** 2-3 hours (once models downloaded)
**Files to modify:**
- `docker/run-all.sh` (add multiple model support)
- `docker/run-all.ps1` (add multiple model support)

---

## Phase 4: Infrastructure & Visualization

**Priority: Low (After baseline testing complete)**

### 4.1 Database Integration (Supabase)

**Goal:** Store results in structured database

**Tasks:**
- [ ] Design Supabase schema (devices, benchmarks, runs)
- [ ] Create Supabase project and tables
- [ ] Write result upload script
- [ ] Migrate existing markdown results to database
- [ ] Update runner scripts to auto-upload results

**Assignable:** Yes - Independent task
**Time Estimate:** 6-8 hours
**Skills needed:** PostgreSQL, Supabase API
**Files to create:**
- `scripts/upload-to-supabase.py`
- `docs/database-schema.md`

### 4.2 Dashboard (Streamlit or Web)

**Goal:** Visualize benchmark results

**Tasks:**
- [ ] Create Streamlit dashboard
- [ ] Query results from Supabase
- [ ] Chart performance comparisons
- [ ] Device comparison tables
- [ ] Export reports

**Assignable:** Yes - Independent task (after Supabase)
**Time Estimate:** 8-10 hours
**Skills needed:** Python, Streamlit, data visualization
**Files to create:**
- `dashboard/app.py`
- `dashboard/requirements.txt`

### 4.3 NFS Model Sharing

**Goal:** Share AI model files across devices

**Tasks:**
- [ ] Set up NFS server on MS-01
- [ ] Export models directory via NFS
- [ ] Mount NFS share on HP ZBooks
- [ ] Update LLaMA benchmark to use NFS models

**Assignable:** Yes - Independent task
**Time Estimate:** 2-3 hours
**Skills needed:** Linux NFS, Windows NFS client

### 4.4 CI/CD for Nightly Benchmarks

**Goal:** Automatic periodic testing

**Tasks:**
- [ ] Create GitHub Actions workflow (or cron job)
- [ ] Schedule nightly benchmark runs
- [ ] Auto-commit results
- [ ] Send notifications on performance regression

**Assignable:** Yes - Independent task
**Time Estimate:** 4-5 hours
**Skills needed:** GitHub Actions or cron

---

## Phase 5: Advanced Features

**Priority: Future / Nice-to-Have**

### 5.1 GPU Benchmarks

- Blender rendering tests
- GPU compute (CUDA/ROCm)
- ML training benchmarks

### 5.2 Thermal Monitoring

- Continuous temperature logging during benchmarks
- Throttling detection
- Cooling performance comparison

### 5.3 Power Consumption

- Measure watts during benchmarks
- Performance per watt calculations
- Battery life testing

### 5.4 Real-World Workloads

- Code compilation (kernel, large project)
- Video encoding (FFmpeg)
- Photo processing (darktable, RawTherapee)
- Container builds (Docker/Podman)

---

## Next Actionable Task (Can Be Assigned)

### Task: Automated FPS Capture with PresentMon

**Why this task:**
- Independent of other work
- High value (eliminates manual observation)
- Clear deliverable
- Well-defined scope

**Deliverables:**
1. PowerShell script: `scripts/rocket-league-presentmon.ps1`
2. PresentMon integration
3. Automatic FPS parsing (avg, min, max, percentiles)
4. JSON output format
5. Documentation update

**Acceptance Criteria:**
- Rocket League benchmark runs automatically
- PresentMon captures FPS data
- Script outputs JSON with FPS metrics
- No manual observation needed

**Estimated Time:** 3-4 hours

**Dependencies:**
- PresentMon v1.x or v2.x
- Existing MarkBench Rocket League setup
- Windows machine for testing

---

## Alternative Next Task: Storage Benchmarks

**Why this task:**
- Independent containerized benchmark
- Follows same pattern as 7-Zip/STREAM
- Cross-platform
- No external dependencies

**Deliverables:**
1. `docker/storage/Dockerfile`
2. `docker/storage/benchmark.sh`
3. fio configuration for common tests
4. JSON output format
5. Integration with `run-all.sh`

**Acceptance Criteria:**
- fio benchmark runs in container
- Sequential read/write tested
- Random 4K read/write tested
- IOPS measured
- Results in JSON format

**Estimated Time:** 3-4 hours

**Dependencies:**
- None (fio is open source)

---

## Summary: What's Next?

**For Tonight:**
1. Deploy Keras OCR on MS-01
2. Test HP ZBook 01 (full suite)

**This Week:**
3. Test HP ZBooks 02-04
4. Create performance comparison document

**Taskable to Others:**
- PresentMon FPS automation (Windows/PowerShell)
- Storage benchmark container (Docker/Bash)
- Multi-run automation script (Bash/Python)
- Supabase database setup (PostgreSQL/API)
- Streamlit dashboard (Python/Streamlit)

**Blocked Until Models Downloaded:**
- Multiple AI model testing
- NFS model sharing

Pick the task that fits your skills/interests!
