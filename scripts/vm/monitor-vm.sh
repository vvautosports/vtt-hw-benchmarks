#!/bin/bash
# Monitor Windows VM during testing
# Shows real-time stats for VM resource usage

VM_NAME="windows11-vtt-test"

echo "═══════════════════════════════════════════════════════════════"
echo "  Windows VM Monitor - ${VM_NAME}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Monitoring VM resources. Press Ctrl+C to stop."
echo ""

# Check if VM is running
if ! virsh -c qemu:///system list --state-running | grep -q "$VM_NAME"; then
    echo "ERROR: VM is not running"
    echo "Start it with: virsh -c qemu:///system start $VM_NAME"
    exit 1
fi

# Monitor function
monitor_vm() {
    while true; do
        clear
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Windows VM Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # VM State
        STATE=$(virsh -c qemu:///system domstate "$VM_NAME")
        echo "VM State: $STATE"
        echo ""
        
        # Get stats
        STATS=$(virsh -c qemu:///system domstats "$VM_NAME" 2>/dev/null)
        
        # CPU stats
        echo "CPU Usage:"
        echo "$STATS" | grep "cpu\." | head -5
        echo ""
        
        # Memory stats
        echo "Memory Usage:"
        echo "$STATS" | grep -E "balloon\.(current|maximum)" | head -4
        echo ""
        
        # Network stats
        echo "Network:"
        echo "$STATS" | grep -E "net\.[0-9]+\.(rx|tx)\.bytes" | head -4
        echo ""
        
        # Disk stats
        echo "Disk I/O:"
        echo "$STATS" | grep -E "block\.[0-9]+\.(rd|wr)\.bytes" | head -4
        echo ""
        
        echo "───────────────────────────────────────────────────────────────"
        echo "Press Ctrl+C to stop monitoring"
        
        sleep 2
    done
}

# Run monitor
monitor_vm
