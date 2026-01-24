# Automated Windows Installation

The VM creation script now supports **unattended installation** using `autounattend.xml`.

## How It Works

1. Script creates an ISO with `autounattend.xml`
2. Attaches it as a second CD-ROM to the VM
3. Windows Setup automatically finds and uses it
4. Installation completes without user interaction

## Credentials

- **Username:** `testuser`
- **Password:** `VTTTest123!`
- **Computer Name:** `VTT-TEST-VM`

## To Use

Just run the normal VM creation script - it will automatically enable unattended install if `autounattend.xml` exists:

```bash
sudo bash scripts/setup/create-windows-vm.sh /path/to/Win11.iso
```

The VM will install Windows automatically. You can monitor progress with `virt-viewer` but no interaction is needed.

## After Installation

Once Windows boots, you can:
1. Connect via RDP (enabled automatically)
2. Log in with `testuser` / `VTTTest123!`
3. Run the setup scripts
