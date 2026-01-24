# Windows VM - Quick Test Instructions

**VM Status:** Created and running  
**Next Steps:** Install Windows, then run lite test

---

## Step 1: Connect to VM

```bash
# Option 1: Use virt-viewer (recommended)
virt-viewer windows11-vtt-test

# Option 2: Use virt-manager GUI
virt-manager
# Then double-click 'windows11-vtt-test' in the list

# Option 3: Find VNC port
virsh vncdisplay windows11-vtt-test
# Connect to localhost:PORT shown
```

---

## Step 2: Install Windows 11

1. Follow Windows 11 installation wizard
2. **Skip Microsoft account** - choose "Sign in with a local account instead"
3. Create local user (e.g., `testuser` / `testpass`)
4. Complete initial setup
5. **Skip Windows Updates for now** (we can do this later)

---

## Step 3: Clone Repository in Windows VM

Once Windows is installed and you're logged in, open PowerShell as Administrator:

```powershell
# Clone the repo
cd C:\
git clone https://github.com/vvautosports/vtt-hw-benchmarks.git
cd vtt-hw-benchmarks
```

**Note:** If git is not installed, download it from: https://git-scm.com/download/win

---

## Step 4: Run Automated Setup & Lite Test

In PowerShell (as Administrator), run:

```powershell
cd C:\vtt-hw-benchmarks
.\scripts\setup\Run-Lite-Test-In-VM.ps1
```

This script will:
1. ✅ Check repository is cloned
2. ✅ Run automated setup (WSL2, Docker, containers) - 10-20 minutes
3. ✅ Run lite test (validation + quick benchmark) - 2-3 minutes

**Total time:** ~15-25 minutes

---

## Alternative: Manual Steps

If you prefer to run steps manually:

### 4a. Run Automated Setup
```powershell
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath "D:\ai-models" -NonInteractive
```

### 4b. Run Lite Test
```powershell
.\scripts\testing\Test-Windows-Short.ps1
```

---

## Step 5: Monitor VM Resources (Optional)

In a separate terminal on the host, monitor VM during testing:

```bash
# Watch VM stats
watch -n 1 'virsh domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'

# Or use virt-manager GUI
virt-manager
# Open the VM and view Performance tab
```

---

## Expected Results

✅ Setup completes successfully  
✅ Lite test passes (both validation and benchmark)  
✅ Can see VM resource usage in monitoring tools  

---

## Troubleshooting

### Git not installed in Windows
Download from: https://git-scm.com/download/win

### WSL2 installation requires restart
The setup script will prompt you. Restart Windows VM, then continue.

### Docker not working in WSL2
```bash
# In WSL2 terminal
sudo service docker start
wsl --shutdown  # Restart WSL2
```

### Models not found
Ensure models directory exists: `D:\ai-models`  
Or specify different path: `-ModelPath "E:\models"`

---

## Next Steps After Lite Test Passes

1. Run full default benchmark (30-45 min):
   ```bash
   # In WSL2 in Windows VM
   cd /mnt/c/vtt-hw-benchmarks/docker
   MODEL_CONFIG_MODE=default ./run-ai-models.sh
   ```

2. Monitor resources during full benchmark
3. Compare results with Linux baseline
