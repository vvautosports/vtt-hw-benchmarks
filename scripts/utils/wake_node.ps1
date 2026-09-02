# Wake a crashed/off node with a Wake-on-LAN magic packet.
#
# Proven 2026-08-29: the Framework Desktop crashed to power-off under an
# agentic inference load (amdgpu, Strix Halo); this packet booted it back with
# no physical intervention. WOL only helps a machine that is OFF or asleep —
# a hung-but-powered kernel ignores it (then it's the power button).
#
# Usage (from any Windows box on the same LAN):
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/utils/wake_node.ps1 -Mac 9c:bf:0d:00:e5:9d
#   ... -Broadcast 192.168.7.255   # add the subnet broadcast when directed L2 helps
#
# Known MACs live in vvt-infrastructure (switch port maps); see
# docs/runbooks/agentic-crash-recovery.md for the recovery decision tree.
# Linux equivalent: `wakeonlan <mac>` or `ether-wake <mac>`.
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$')]
    [string]$Mac,
    [string[]]$Broadcast = @('255.255.255.255'),
    [int]$Port = 9
)

$bytes = $Mac.Split(':') | ForEach-Object { [byte]('0x' + $_) }
$pkt = (,[byte]0xFF * 6) + ($bytes * 16)

$udp = New-Object Net.Sockets.UdpClient
$udp.EnableBroadcast = $true
foreach ($target in $Broadcast) {
    $udp.Connect($target, $Port)
    [void]$udp.Send($pkt, $pkt.Length)
    Write-Output "magic packet for $Mac -> ${target}:$Port"
}
$udp.Close()
