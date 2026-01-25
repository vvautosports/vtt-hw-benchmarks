# Windows VM Testing - Documentation Analysis

**Date:** 2026-01-24  
**Purpose:** Analyze existing documentation and identify gaps for Windows VM AI testing

---

## Existing Documentation Inventory

### ✅ Complete and Working

#### 1. **HP-ZBOOK-DEPLOYMENT.md** (`docs/guides/HP-ZBOOK-DEPLOYMENT.md`)
- **Status:** Complete deployment guide
- **Contents:**
  - Prerequisites and hardware requirements
  - Step-by-step deployment procedure
  - Troubleshooting section
  - Performance expectations
  - Validation checklist
- **Issues:**
  - Line 72: References `Setup-HP-ZBook-Automated.ps1` (doesn't exist)
  - Line 157, 165, 173, 341: Multiple references to non-existent script
  - Line 361: Broken link to `WINDOWS-VM-TESTING.md` (doesn't exist)
  - Line 365: Lists `Setup-HP-ZBook-Automated.ps1` as main script
- **Action needed:** Update script references to `setup-windows-full.ps1`

#### 2. **WINDOWS-SETUP.md** (`docs/guides/WINDOWS-SETUP.md`)
- **Status:** Complete technical guide
- **Contents:**
  - WSL2 installation
  - Docker setup
  - Model directory configuration
  - GPU access troubleshooting
- **References:** Correctly references `setup-windows-full.ps1`
- **Action needed:** None - this is accurate

#### 3. **HP-ZBOOK-SETUP.md** (`docs/guides/HP-ZBOOK-SETUP.md`)
- **Status:** Complete setup guide
- **Contents:**
  - Quick start instructions
  - PowerShell execution policy
  - Interactive menu setup
- **References:** Different script names (`HP-ZBOOK-SETUP-INTERACTIVE.ps1`, `HP-ZBOOK-SETUP-ONE-COMMAND.ps1`)
- **Action needed:** Verify these scripts exist or consolidate with `setup-windows-full.ps1`

#### 4. **Download-Light-Models.ps1** (`scripts/utils/Download-Light-Models.ps1`)
- **Status:** ✅ EXISTS and functional
- **Contents:**
  - Downloads GPT-OSS-20B and Qwen3-8B-128K-Q8
  - Progress tracking with BITS
  - Disk space validation
  - Resume capability
- **Action needed:** None

#### 5. **setup-windows-full.ps1** (`scripts/utils/setup-windows-full.ps1`)
- **Status:** ✅ EXISTS and functional
- **Contents:**
  - WSL2 installation
  - Docker installation in WSL2
  - Model directory configuration
  - Container pull/build
  - Test execution
- **Approach:** Uses WSL2 directly (not Docker Desktop)
- **Action needed:** None - this is a working script

#### 6. **SETUP.bat** (`scripts/setup/hp-zbook/SETUP.bat`)
- **Status:** ✅ EXISTS and functional
- **Contents:**
  - Hybrid batch/PowerShell script (self-contained)
  - Prerequisite checks (GitHub CLI, Docker Desktop, repository)
  - Auto-installs missing prerequisites
  - Interactive menu for:
    - Pulling containers
    - Running validation tests
    - Running benchmarks (quick, default, comprehensive)
- **Approach:** Uses Docker Desktop (not WSL2 directly)
- **Referenced in:** `README.md` line 59
- **Action needed:** None - this is the actual working script referenced in README

#### 7. **models-inventory.yaml** (`models-inventory.yaml`)
- **Status:** ✅ Already updated with Qwen3-8B-128K-Q8
- **Contents:**
  - Light models: GPT-OSS-20B, Qwen3-8B-128K-Q8
  - Default models: 5 models
  - Context profiles
- **Action needed:** None

---

## Missing Documentation

### ❌ Missing Files

#### 1. **WINDOWS-VM-TESTING.md**
- **Referenced in:**
  - `HP-ZBOOK-DEPLOYMENT.md` line 361
  - Original plan (`windows_vm_light_testing_0a9dba32.plan.md`)
- **Should contain:**
  - VM creation on Framework desktop (KVM/virt-manager)
  - Nested virtualization setup
  - Windows 11 installation in VM
  - Testing workflow
  - VM-specific troubleshooting
- **Location:** Should be `docs/guides/WINDOWS-VM-TESTING.md` or `docs/testing/windows-vm/README.md`

#### 2. **Setup-HP-ZBook-Automated.ps1**
- **Referenced in:** `HP-ZBOOK-DEPLOYMENT.md` (multiple times)
- **Reality:** Script doesn't exist - `setup-windows-full.ps1` is the actual script
- **Options:**
  - Option A: Create wrapper script `Setup-HP-ZBook-Automated.ps1` that calls `setup-windows-full.ps1`
  - Option B: Update all documentation to reference `setup-windows-full.ps1`
- **Recommendation:** Option B (update docs) - fewer files to maintain

#### 3. **Test-VM-AI-Setup.ps1**
- **Status:** Doesn't exist
- **Purpose:** VM-specific validation for AI testing
- **Should contain:**
  - WSL2 validation
  - Model path verification (Windows → WSL2 mounts)
  - Docker container execution test
  - Quick AI benchmark (GPT-OSS-20B, 512p/128g)
  - CPU-only fallback detection (GPU won't work in nested VM)
- **Location:** `scripts/testing/Test-VM-AI-Setup.ps1`

#### 4. **windows-vm/README.md**
- **Referenced in:**
  - `docs/testing/README.md` line 7, 17
- **Status:** Directory doesn't exist
- **Should contain:** Complete VM testing guide
- **Location:** `docs/testing/windows-vm/README.md`

---

## Documentation Reference Issues

### Broken Links

1. **HP-ZBOOK-DEPLOYMENT.md line 361:**
   ```markdown
   - [WINDOWS-VM-TESTING.md](WINDOWS-VM-TESTING.md) - VM testing guide
   ```
   - **Issue:** File doesn't exist
   - **Fix:** Create file or update link

2. **docs/testing/README.md lines 7, 17:**
   ```markdown
   - **[Windows VM Testing](windows-vm/README.md)** - Test Windows setup in a VM
   ```
   - **Issue:** Directory/file doesn't exist
   - **Fix:** Create `docs/testing/windows-vm/README.md`

### Script Name Mismatches

1. **HP-ZBOOK-DEPLOYMENT.md references:**
   - `Setup-HP-ZBook-Automated.ps1` (lines 72, 157, 165, 173, 341, 365)
   - **Reality:** Script doesn't exist
   - **Options:**
     - Use `setup-windows-full.ps1` (WSL2 approach)
     - Use `SETUP.bat` (Docker Desktop approach)
   - **Fix:** Update all references to one of the existing scripts

2. **HP-ZBOOK-SETUP.md references:**
   - `HP-ZBOOK-SETUP-INTERACTIVE.ps1` (line 36, 45, 68, 114)
   - `HP-ZBOOK-SETUP-ONE-COMMAND.ps1` (line 79, 120)
   - `HP-ZBOOK-SETUP.ps1` (line 126)
   - **Status:** These scripts don't exist
   - **Reality:** `SETUP.bat` exists and provides similar functionality
   - **Fix:** Update references to use `SETUP.bat` or create the missing scripts

3. **README.md references:**
   - `SETUP.bat` (line 59) ✅ **CORRECT** - script exists

---

## Current State Summary

### ✅ Completed Tasks (from original plan)

- [x] Update `models-inventory.yaml` with Qwen3-8B-128K-Q8
- [x] Create `Download-Light-Models.ps1`
- [x] Create `setup-windows-full.ps1` (equivalent to planned `Setup-HP-ZBook-Automated.ps1`)
- [x] Create `HP-ZBOOK-DEPLOYMENT.md`

### ❌ Incomplete Tasks

- [ ] Create Windows VM testing guide
- [ ] Test AI models in Windows VM (main blocker)
- [ ] Fix script name references in documentation
- [ ] Create VM-specific test script
- [ ] Fix broken documentation links

---

## Recommended Action Plan

### Phase 1: Fix Documentation References (Quick Wins)

1. **Update HP-ZBOOK-DEPLOYMENT.md:**
   - Replace all `Setup-HP-ZBook-Automated.ps1` → choose either:
     - `setup-windows-full.ps1` (WSL2 approach) OR
     - `SETUP.bat` (Docker Desktop approach)
   - Fix broken `WINDOWS-VM-TESTING.md` link (create file or remove link)

2. **Update HP-ZBOOK-SETUP.md:**
   - Replace references to non-existent scripts:
     - `HP-ZBOOK-SETUP-INTERACTIVE.ps1` → `SETUP.bat`
     - `HP-ZBOOK-SETUP-ONE-COMMAND.ps1` → `SETUP.bat` (or document manual steps)
     - `HP-ZBOOK-SETUP.ps1` → `SETUP.bat` or `setup-windows-full.ps1`

3. **Fix testing/README.md:**
   - Create `docs/testing/windows-vm/` directory
   - Create `docs/testing/windows-vm/README.md` or fix link

4. **Clarify script usage:**
   - Document when to use `SETUP.bat` vs `setup-windows-full.ps1`
   - `SETUP.bat` = Docker Desktop approach (simpler, recommended)
   - `setup-windows-full.ps1` = WSL2 direct approach (more control)

### Phase 2: Create Missing Documentation

1. **Create Windows VM Testing Guide:**
   - Location: `docs/testing/windows-vm/README.md`
   - Contents:
     - Host setup (Framework desktop, KVM, nested virtualization)
     - VM creation (virt-manager, 8GB RAM, 4 CPUs, 60GB disk)
     - Windows 11 installation
     - Running setup script in VM
     - Testing AI models
     - Troubleshooting (CPU-only, no GPU passthrough)

2. **Create VM Test Script:**
   - Location: `scripts/testing/Test-VM-AI-Setup.ps1`
   - Purpose: Validate AI testing setup in VM
   - Features:
     - WSL2 validation
     - Model path verification
     - Docker test
     - Quick AI benchmark
     - CPU-only detection

### Phase 3: Get AI Testing Working in VM

1. **Identify blockers:**
   - Model path mounting (Windows → WSL2)
   - Docker container execution
   - Environment variable propagation
   - GPU access (won't work - document CPU fallback)

2. **Test workflow:**
   - Setup VM
   - Install Windows 11
   - Run `setup-windows-full.ps1`
   - Download models
   - Run `Test-VM-AI-Setup.ps1`
   - Run `MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test`
   - Document issues and solutions

---

## Key Insights

1. **Multiple setup approaches exist:**
   - `SETUP.bat` - Docker Desktop approach (referenced in README, works)
   - `setup-windows-full.ps1` - WSL2 approach (exists, works)
   - Documentation references scripts that don't exist

2. **Script confusion:**
   - `HP-ZBOOK-DEPLOYMENT.md` references non-existent `Setup-HP-ZBook-Automated.ps1`
   - `HP-ZBOOK-SETUP.md` references non-existent PowerShell scripts
   - `README.md` correctly references `SETUP.bat`

3. **Main blocker:** AI testing not working in VM (needs investigation)

4. **Missing pieces:**
   - VM-specific testing guide
   - VM-specific validation script
   - Clarification on which setup script to use when

---

## Next Steps

1. ✅ **Analyze existing docs** (this document)
2. ⏳ **Fix documentation references** (script names, broken links)
3. ⏳ **Create VM testing guide** (`docs/testing/windows-vm/README.md`)
4. ⏳ **Create VM test script** (`scripts/testing/Test-VM-AI-Setup.ps1`)
5. ⏳ **Test AI in VM** (identify and fix blockers)
6. ⏳ **Document VM limitations** (CPU-only, performance expectations)

---

**Last Updated:** 2026-01-24
