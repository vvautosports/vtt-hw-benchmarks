# Windows VM Quick Start - Create & Test

**Goal:** Create Windows VM and run lite test to validate setup

---

## Step 1: Create the VM

Run this command (requires sudo password):

```bash
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
sudo bash scripts/setup/create-and-setup-vm.sh
```

This will:
- Create VM `windows11-vtt-test` with 48GB RAM, 8 CPUs, 80GB disk
- Boot from Windows 11 ISO
- Set up VNC access

---

## Step 2: Connect to VM

After creation, connect with:

```bash
virt-viewer windows11-vtt-test
```

Or use the GUI:
```bash
virt-manager
# Then double-click 'windows11-vtt-test' in the list
```

---

## Step 3: Install Windows 11

1. Follow Windows 11 installation wizard
2. **Skip Microsoft account** - choose "Sign in with a local account instead"
3. Create a local user (e.g., `testuser` / `testpass`)
4. Complete initial setup
5. Let Windows Updates install (optional, can skip for quick test)

---

## Step 4: Check VM Readiness

In a terminal on the host:

```bash
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
bash scripts/setup/check-vm-ready.sh
```

This will show VM status and connection info.

---

## Step 5: Setup in Windows VM

Once Windows is installed, in the Windows VM (PowerShell as Administrator):

```powershell
# Clone the repo
cd C:\
git clone https://github.com/vvautosports/vtt-hw-benchmarks.git
cd vtt-hw-benchmarks

# Run automated setup (installs WSL2, Docker, pulls containers)
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath "D:\ai-models" -NonInteractive
```

**Note:** This will take 10-20 minutes as it:
- Installs WSL2 (may require restart)
- Installs Docker in WSL2
- Pulls containers from GHCR
- Downloads light models

---

## Step 6: Run Lite Test

After setup completes, run the lite test:

```powershell
# In Windows VM PowerShell (as Admin)
cd C:\vtt-hw-benchmarks
.\scripts\testing\Test-Windows-Short.ps1
```

This will:
1. ✅ Validate Windows setup (WSL2, Docker, containers)
2. ✅ Run quick benchmark (2-3 minutes, one light model)
3. ✅ Verify GPU acceleration works

**Expected time:** 2-3 minutes for the benchmark

---

## Monitoring During Test

In a separate terminal on the host, monitor VM resources:

```bash
# Watch VM stats
watch -n 1 'virsh domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'

# Or use virt-manager GUI
virt-manager
# Open the VM and view Performance tab
```

---

## Troubleshooting

### VM won't start
```bash
# Check libvirt status
systemctl status libvirtd

# Check VM details
virsh dominfo windows11-vtt-test

# View logs
sudo journalctl -u libvirtd -n 50
```

### Can't connect to VM
```bash
# Find VNC port
virsh vncdisplay windows11-vtt-test

# Try virt-viewer
virt-viewer windows11-vtt-test
```

### Setup script fails in Windows
- Ensure running PowerShell as Administrator
- Check internet connection in VM
- Verify WSL2 is installed: `wsl --status`
- Check Docker in WSL2: `wsl bash -c "docker --version"`

---

## Success Criteria

✅ VM created and running  
✅ Windows 11 installed  
✅ Can connect via virt-viewer/virt-manager  
✅ Setup script completes successfully  
✅ Lite test passes (both validation and benchmark)  

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

---

**Ready to create the VM?** Run Step 1 above!
