# Windows VM Setup - Current Status Assessment

**Date:** 2026-01-24  
**Goal:** Get Windows VM running for benchmark testing

---

## ✅ Completed

1. **Monitoring Tools Installed**
   - ✅ virt-manager, virsh, virt-install installed
   - ✅ User in libvirt group (can use virsh without sudo)

2. **Nested Virtualization**
   - ✅ Enabled (`/sys/module/kvm_amd/parameters/nested` = 1)

3. **Prerequisites Ready**
   - ✅ Windows 11 ISO found: `/home/kalman9/Downloads/Win11_25H2_English_x64.iso`
   - ✅ Disk space available: 425GB free
   - ✅ VM creation script exists: `scripts/setup/create-windows-vm.sh`

---

## ⚠️ Needs Attention

1. **libvirt Service**
   - Status: Enabled but inactive (socket-activated)
   - Action: Will auto-start when VM operations are performed
   - Note: Service is configured correctly, just needs activation

2. **Code Changes**
   - Status: Uncommitted changes in git
   - Files: `docker/run-ai-models.sh`, deleted `results/framework-laptop-20260119.md`, new `STATUS-ASSESSMENT.md`, new `scripts/setup/`
   - Action: Can commit later (not blocking VM setup)

---

## ❌ Not Started

1. **Windows VM Creation**
   - No VM exists yet
   - Ready to create with existing script

2. **Windows Installation**
   - VM needs to be created first
   - Then install Windows 11 from ISO

3. **Monitoring Verification**
   - Can't test until VM exists

---

## 🚀 Next Steps (In Order)

### Step 1: Start libvirt (if needed)
```bash
# libvirt uses socket activation, but you can start it explicitly:
sudo systemctl start libvirtd

# Verify it's running:
systemctl status libvirtd
```

### Step 2: Create Windows VM
```bash
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks

# Create the VM (requires sudo):
sudo bash scripts/setup/create-windows-vm.sh /home/kalman9/Downloads/Win11_25H2_English_x64.iso
```

**This will:**
- Create VM named `windows11-vtt-test`
- Allocate 48GB RAM, 8 CPUs, 80GB disk
- Boot from Windows 11 ISO
- Set up VNC for remote access

### Step 3: Connect to VM
```bash
# Option 1: Use virt-viewer (recommended)
virt-viewer windows11-vtt-test

# Option 2: Use virt-manager GUI
virt-manager
# Then double-click the VM in the list

# Option 3: Find VNC port and use VNC client
virsh vncdisplay windows11-vtt-test
# Connect to localhost:PORT shown
```

### Step 4: Install Windows 11
1. Follow Windows 11 installation wizard
2. Create local user account (no Microsoft account needed)
3. Complete initial setup
4. Install Windows updates

### Step 5: Verify Monitoring
```bash
# Check VM status
virsh list --all

# View resource stats
virsh domstats windows11-vtt-test

# Open virt-manager for GUI monitoring
virt-manager
```

### Step 6: Test in VM
Once Windows is installed:
1. Clone vtt-hw-benchmarks repo in Windows
2. Run automated setup script:
   ```powershell
   .\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath "D:\ai-models" -NonInteractive
   ```
3. Monitor VM resources during benchmark execution
4. Verify containers pull from GHCR

---

## 📊 Current System State

- **libvirt status:** Enabled, socket-activated (will start on demand)
- **User permissions:** ✅ In libvirt group
- **Nested virt:** ✅ Enabled
- **ISO available:** ✅ `/home/kalman9/Downloads/Win11_25H2_English_x64.iso`
- **Disk space:** ✅ 425GB free
- **Existing VMs:** None

---

## 🎯 Quick Start Command

To create the VM right now (requires sudo password):

```bash
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
sudo bash scripts/setup/create-windows-vm.sh /home/kalman9/Downloads/Win11_25H2_English_x64.iso
```

Then connect with:
```bash
virt-viewer windows11-vtt-test
```

---

## 📝 Notes

- libvirt service is configured for socket activation, so it will start automatically when you use virsh/virt-manager
- The VM creation script requires sudo because it needs to create files in `/var/lib/libvirt/images/`
- After VM creation, you can manage it as a regular user (since you're in libvirt group)
- VNC will be accessible on localhost (default port usually 5900)

---

**You're ready to create the VM!** Just run the command in Step 2 above.
