#!/bin/bash
# ============================================================================
# APEX System Info — Prints full hardware and software details
# Run this before benchmarking to document your test system.
# ============================================================================

echo "============================================================"
echo "  APEX System Information Report"
echo "  $(date)"
echo "============================================================"
echo ""

echo "=== CPU ==="
lscpu 2>/dev/null | grep -E "Model name|Architecture|CPU\(s\)|Thread|Core|Socket|MHz|max MHz|cache|Vendor|Family|Stepping" || cat /proc/cpuinfo | head -20
echo ""

echo "=== CPU Features ==="
echo -n "AVX2:    " && grep -qc avx2 /proc/cpuinfo && echo "YES" || echo "NO"
echo -n "AVX-512: " && grep -qc avx512 /proc/cpuinfo && echo "YES" || echo "NO"
echo -n "SSE4.2:  " && grep -qc sse4_2 /proc/cpuinfo && echo "YES" || echo "NO"
echo ""

echo "=== Memory ==="
free -h 2>/dev/null || cat /proc/meminfo | head -5
echo ""

echo "=== GPU ==="
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free,compute_cap,power.limit,clocks.max.gr,clocks.max.mem --format=csv,noheader 2>/dev/null
    echo ""
    nvidia-smi 2>/dev/null
else
    echo "No NVIDIA GPU detected (nvidia-smi not found)"
fi
echo ""

echo "=== CUDA ==="
if command -v nvcc &>/dev/null; then
    nvcc --version 2>/dev/null | grep -E "release|Build"
else
    # nvcc not in PATH — check alternative locations
    for p in /usr/local/cuda/bin/nvcc /usr/local/cuda-*/bin/nvcc /opt/cuda/bin/nvcc; do
        if [ -x "$p" ]; then
            $p --version 2>/dev/null | grep -E "release|Build"
            break
        fi
    done
    # Also check nvidia-smi for CUDA version
    if command -v nvidia-smi &>/dev/null; then
        echo "CUDA Runtime: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null) (from nvidia-smi)"
    else
        echo "CUDA: not detected"
    fi
fi
echo ""

echo "=== Storage ==="
df -h . 2>/dev/null | head -2
# Show disk type (NVMe/SSD/HDD)
ROOT_DEV=$(df . 2>/dev/null | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's|/dev/||' | sed 's/p$//')
if [ -n "$ROOT_DEV" ] && [ -e "/sys/block/$ROOT_DEV/queue/rotational" ]; then
    ROTA=$(cat /sys/block/$ROOT_DEV/queue/rotational 2>/dev/null)
    if [ "$ROTA" = "0" ]; then
        if echo "$ROOT_DEV" | grep -q "nvme"; then echo "Type: NVMe SSD"; else echo "Type: SSD"; fi
    else
        echo "Type: HDD"
    fi
fi
echo ""

echo "=== OS ==="
echo "Distro:  $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel:  $(uname -r)"
echo "Arch:    $(uname -m)"
echo "glibc:   $(ldd --version 2>&1 | head -1)"
echo ""

echo "=== APEX ==="
if [ -x ./apex ]; then
    ./apex --help 2>&1 | head -4
else
    echo "apex binary not found in current directory"
fi
echo ""

echo "=== Power (if available) ==="
cat /sys/class/power_supply/AC*/online 2>/dev/null && echo "(1=AC plugged, 0=battery)" || echo "N/A"
cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy 2>/dev/null && echo "(0=Performance, 1=Balanced, 2=Silent)" || true
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || true
echo ""

echo "============================================================"
echo "  Copy-paste the above when sharing benchmark results."
echo "============================================================"
