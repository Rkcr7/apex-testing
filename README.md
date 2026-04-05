# APEX

**GPU-Accelerated Lossless Compression — High Ratio at High Speed**

APEX achieves high compression ratios at high throughput — a combination that has traditionally required choosing one or the other. GPU-accelerated for maximum performance, with a dedicated CPU-only binary for systems without NVIDIA GPUs.

| Data Type | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| Source code (Linux Kernel 1.5GB) | **9.26x** | **1,895 MB/s** | **1,476 MB/s** |
| Structured data (JSON 1.1GB) | **18.11x** | **1,899 MB/s** | **3,842 MB/s** |
| Genomic data (Human Genome 3GB) | **4.35x** | **1,833 MB/s** | **1,483 MB/s** |
| Text (Wikipedia 954MB) | **4.36x** | **1,633 MB/s** | **974 MB/s** |
| Mixed corpus (Silesia 202MB) | **4.01x** | **698 MB/s** | **704 MB/s** |

Tested on 3 systems with different GPUs (RTX 5070, 4090, 5090) and CPUs (Zen 2, Zen 4). Ratios are deterministic — identical across all hardware. Speeds scale with GPU compute and CPU core count.

**No GPU? APEX still works.** CPU-only mode: 826 MB/s on JSON, 253 MB/s on Linux Kernel, 131 MB/s at 4.0x on Silesia — faster than every BWT compressor without GPU. See [CPU-Only Mode](BENCHMARKS.md#cpu-only-mode-no-gpu-required).

Full results, 3-system comparison, CPU-only benchmarks, and vs-competition in [BENCHMARKS.md](BENCHMARKS.md).

### Testing & Validation

APEX is in active development. This binary is shared for community validation — verify the claims on your own hardware.

### Validated on 3 independent systems

| System | GPU | CPU | Best Compress | Best Decompress |
|--------|-----|-----|-------------|----------------|
| Dev machine (laptop) | RTX 5070 Laptop | Ryzen 9 8940HX (Zen 4) | 1,642 MB/s | 2,022 MB/s |
| Vast.ai cloud | RTX 4090 | EPYC 7D12 (Zen 2) | 1,793 MB/s | 2,324 MB/s |
| Vast.ai cloud | **RTX 5090** | Dual EPYC 7742 (Zen 2) | **1,899 MB/s** | **4,403 MB/s** |

Ratios match exactly across all 3 systems. All round-trip verified PASS. Full results in [BENCHMARKS.md](BENCHMARKS.md).

> **Note**: Speed depends on both GPU and CPU. See [CPU Architecture Effects](BENCHMARKS.md#how-cpu-architecture-affects-apex) for details on how Zen 2 vs Zen 4, AVX2 vs AVX-512, and clock speed affect results.

### Purpose of this release

We've published results showing high ratio at high speed — a combination no existing compressor achieves. Extraordinary claims require independent verification. This binary lets you:

- **Validate** — Run the same benchmarks on your hardware and verify the claims
- **Reproduce** — Download the exact datasets we used and reproduce our methodology
- **Compare** — Test against zstd, bzip2, libbsc, or any compressor on the same data
- **Verify correctness** — Every compressed file round-trips to a byte-identical original (PASS/FAIL)
- **Explore** — Test on your own data, find optimal configs for your workload

### What's included

| File | Size | GPU | CPU | Description |
|------|------|-----|-----|-------------|
| `apex` | 16 MB | Yes | AVX2 | **Default** — GPU + any modern CPU |
| `apex-gpu-avx2` | 16 MB | Yes | AVX2 | Same as `apex` |
| `apex-gpu-avx512` | 16 MB | Yes | AVX-512 | GPU + AVX-512 CPU (Zen 4+, Intel 12th gen+). Faster decompress. |
| `apex-cpu-avx2` | 1.3 MB | **No** | AVX2 | **CPU-only** — no CUDA needed. Any CPU from 2013+. |
| `apex-cpu-avx512` | 1.3 MB | **No** | AVX-512 | **CPU-only** — no CUDA needed. Zen 4+, Intel 12th gen+. Fastest CPU-only. |
| `apex-cpu-sse42` | 1.1 MB | **No** | SSE4.2 | **CPU-only** — oldest CPUs. Sandy Bridge+ (2011+). No AVX needed. |
| `download_datasets.sh` | 15 KB | | | Downloads benchmark datasets into `data/` |
| `verify.sh` | 7 KB | | | Independent verification using standard Unix tools |
| `sysinfo.sh` | 3 KB | | | Prints full system info (CPU, GPU, RAM, CUDA, OS) |
| `BENCHMARKS.md` | | | | Full results: 14 datasets, 3 systems, CPU-only, vs-competition |
| `LICENSE` | | | | Testing license |

### Which binary to use?

> **For best performance, use the binary that matches your system.** The `*-avx512` variants are significantly faster on decompress (+77-122%) and slightly faster on compress (~10-15%). Using the wrong variant won't give wrong results — `apex` (default) always works — but you'll leave performance on the table.

**Step 1: Check your system:**
```bash
# Do you have an NVIDIA GPU?
nvidia-smi
# Shows GPU info → you have a GPU
# "command not found" → no GPU, use apex-cpu-*

# Does your CPU support AVX-512?
grep -c avx512 /proc/cpuinfo
# Number > 0 → YES, use *-avx512 variant for best speed
# 0 → NO, use *-avx2 variant (or default apex)

# Quick one-liner to tell you which binary to use:
if nvidia-smi &>/dev/null; then
  if grep -q avx512 /proc/cpuinfo; then echo "Use: apex-gpu-avx512";
  else echo "Use: apex (default)"; fi
else
  if grep -q avx512 /proc/cpuinfo; then echo "Use: apex-cpu-avx512";
  elif grep -q avx2 /proc/cpuinfo; then echo "Use: apex-cpu-avx2";
  else echo "Use: apex-cpu-sse42"; fi
fi
```

**Step 2: Pick your binary:**

```
Do you have an NVIDIA GPU + CUDA?
├─ YES → Does your CPU support AVX-512?
│        ├─ YES (Zen 4+, Intel 12th+) → apex-gpu-avx512  (fastest)
│        └─ NO  (older CPU)           → apex  (default, always works)
└─ NO  → Does your CPU support AVX2?
         ├─ YES + AVX-512 → apex-cpu-avx512  (fastest CPU-only)
         ├─ YES           → apex-cpu-avx2   (any CPU from 2013+)
         └─ NO  (very old) → apex-cpu-sse42  (Sandy Bridge+ 2011+)
```

| Your System | Best Binary | What it needs |
|------------|------------|--------------|
| NVIDIA GPU + AVX-512 CPU | **`apex-gpu-avx512`** | CUDA + AVX-512 |
| NVIDIA GPU + older CPU | **`apex`** (default) | CUDA + AVX2 |
| No GPU + AVX-512 CPU | **`apex-cpu-avx512`** | Just AVX-512 |
| No GPU + AVX2 CPU (2013+) | **`apex-cpu-avx2`** | Just AVX2 |
| No GPU + old CPU (2011+) | **`apex-cpu-sse42`** | Just SSE4.2 |

> **Note on `apex-cpu-sse42`:** This binary is verified to contain zero AVX/AVX2/AVX-512 instructions (confirmed via `objdump`). Round-trip tested and cross-compatible with all other binaries. However, it has not been tested on actual pre-AVX2 hardware (Sandy Bridge/Ivy Bridge). If you have such hardware and test it, please share your results.

> **Note:** Using `apex` (default) on an AVX-512 CPU works fine — correct results, good speed. You just won't get the extra decompress boost that `apex-gpu-avx512` provides. It never crashes; it just doesn't use the wider instructions.

### CPU-Only Mode (No GPU)

No NVIDIA GPU? No CUDA? No problem. Use `apex-cpu-avx2` (or `apex-cpu-avx512` for Zen 4+):

```bash
chmod +x apex-cpu-avx2
./apex-cpu-avx2 --help             # Shows "GPU: Disabled (CPU-only mode)"
./apex-cpu-avx2 bench data/silesia.tar
./apex-cpu-avx2 compress myfile.tar myfile.apex -mt
./apex-cpu-avx2 decompress myfile.apex restored.tar
```

All binaries produce **identical compressed files** — same format, same ratios. A file compressed with `apex-cpu-avx2` can be decompressed with `apex-gpu-avx512` and vice versa.

CPU-only APEX is faster than every BWT compressor (bsc, bzip2, bzip3, LZMA) even without GPU. See [CPU-Only benchmarks](BENCHMARKS.md#cpu-only-mode-no-gpu-required).

### What's NOT included

Source code is not part of this release. APEX is in development and will be released when ready. This binary is provided specifically for the purpose of community validation and independent benchmarking.

> **New here?** Start with [Quick Start](#3-quick-start), then run `./apex tune mydata.tar` — it tests all configurations on YOUR data and recommends the best one.

---

## Table of Contents

| # | Section | What You'll Find |
|---|---------|-----------------|
| 1 | [System Requirements](#1-system-requirements) | What hardware and software you need |
| 2 | [Setup Checklist](#2-setup-checklist) | Step-by-step verification before running |
| 3 | [Quick Start](#3-quick-start) | From download to first benchmark in 30 seconds |
| 4 | [Understanding the Output](#4-understanding-the-output) | What every line of output means |
| 5 | [All Commands](#5-all-commands-explained) | Every command and flag with examples |
| 6 | [Default Behavior](#6-default-behavior) | What happens when you run each mode |
| 7 | [Download Datasets](#7-download-benchmark-datasets) | Get the exact datasets we benchmarked |
| 8 | [Reproduce Our Benchmarks](#8-reproduce-our-benchmarks) | Step-by-step to reproduce our published numbers |
| 9 | [Hardware Configuration](#9-hardware-configuration) | Adapt APEX to your CPU, GPU, and RAM |
| 10 | [Advanced Tuning](#10-advanced-tuning) | Block size selection, preprocessing, flag combinations |
| 11 | [Reference Numbers](#11-reference-numbers) | Our published results (your target to match/beat) |
| 12 | [Troubleshooting](#12-troubleshooting) | Common issues and fixes |
| 13 | [Reporting Results](#13-reporting-your-results) | How to share your findings with the community |

---

## Our Test System

All published benchmark numbers were measured on this exact configuration:

| Component | Specification |
|-----------|--------------|
| **Machine** | ASUS TUF Gaming A16 (2025) — laptop |
| **CPU** | AMD Ryzen 9 8940HX (Zen 4, 16 cores / 32 threads, 1MB L2/core, 64MB L3, 5.4 GHz boost) |
| **GPU** | NVIDIA RTX 5070 Laptop (Blackwell GB206, 8GB GDDR7, 384 GB/s bandwidth) |
| **RAM** | 16GB DDR5-5200 single-channel (~40 GB/s) |
| **Storage** | Samsung 1TB NVMe Gen4 (~6.5 GB/s sequential) |
| **OS** | Ubuntu 24.04.4 LTS, Kernel 6.17.0 |
| **CUDA** | 13.2.51, Driver 580.126.09 |
| **Power** | Plugged in (AC), ASUS Performance mode (max fans), CPU governor: performance |

All benchmarks were run plugged in with Performance thermal profile enabled. Battery mode reduces GPU power from ~115W to ~47W, significantly lowering speeds. If you're on a laptop, make sure you're plugged in and in performance mode for comparable results.

Your results will differ based on your hardware. That's the point — we want to see how APEX performs across different systems.

### What We Test On

APEX is benchmarked on **14 real-world datasets** across multiple domains — not just standard compression benchmarks.

| Category | Datasets | Why it matters |
|----------|---------|---------------|
| **Standard benchmarks** | Silesia (202MB), enwik8 (96MB), enwik9 (954MB) | Industry-standard. Every compressor publishes these. Directly comparable. |
| **Source code** | Linux Kernel (1.5GB), LLVM (2.4GB), Chromium (4.6GB) | Real production codebases. Tests scaling on large repetitive data. |
| **Structured data** | GH Events JSON (480MB), Large JSON (1.1GB), Wiki SQL, CSV | Real API logs, database dumps, tabular data. Tests on highly repetitive patterns. |
| **Genomics** | Human Genome GRCh38 (3.0GB) | Real DNA reference genome. BWT is native to this domain. |
| **Incompressible** | Firefox (79MB), Taxi Parquet (48MB) | Already-compressed binaries. APEX correctly detects and stores RAW at memcpy speed — proves content detection works. |
| **Pure text** | Pizza&Chili English (2.1GB) | Standard academic BWT benchmark. Pure English, no markup. |

All datasets are publicly downloadable. No synthetic or generated data. The included `download_datasets.sh` fetches the same files we used — you test on exactly what we tested on.

---

## 1. System Requirements

### Minimum

| Requirement | Minimum | How to Check |
|------------|---------|-------------|
| **OS** | Linux x86-64 (Ubuntu 22.04+, Fedora 38+, Arch) | `uname -m` should show `x86_64` |
| **CPU** | Any x86-64 with AVX2 (~2015 onwards) | `grep avx2 /proc/cpuinfo` |
| **RAM** | 4 GB (for small files) | `free -h` |
| **Disk** | 1 GB free (for binary + one dataset) | `df -h .` |

### For GPU acceleration (recommended)

| Requirement | Minimum | How to Check |
|------------|---------|-------------|
| **NVIDIA GPU** | Turing or newer (RTX 20xx+, T4+) | `nvidia-smi` |
| **NVIDIA Driver** | 525+ | `nvidia-smi` (top row shows driver version) |
| **CUDA Toolkit** | 12.0+ | `nvcc --version` |
| **VRAM** | 6 GB+ (8 GB recommended) | `nvidia-smi` (shows memory) |

### Supported GPUs

| Generation | GPUs | Year |
|-----------|------|------|
| Turing | RTX 2060-2080 Ti, GTX 1660 Ti, T4 | 2018-2019 |
| Ampere | RTX 3060-3090, A100, A10, A30 | 2020-2021 |
| Lovelace | RTX 4060-4090, L40, L40S | 2022-2023 |
| Hopper | H100, H200 | 2023-2024 |
| Blackwell | RTX 5070-5090, B100, B200 | 2024-2025 |

**No GPU?** APEX still works — it falls back to CPU-only mode automatically. Same compression ratio, just slower speed.

---

## 2. Setup Checklist

**Quickest way**: Run the included `sysinfo.sh` script — it checks everything at once:

```bash
chmod +x sysinfo.sh
./sysinfo.sh
```

This prints your CPU (model, cores, clock, AVX2/AVX-512), GPU (model, VRAM, driver), RAM, CUDA version, OS, and APEX status. Copy-paste the output when sharing benchmark results.

**Or check manually**, one by one:

```bash
# 1. Check OS
uname -m
# Expected: x86_64

# 2. Check CPU supports AVX2
grep -c avx2 /proc/cpuinfo
# Expected: a number > 0

# 3. Check NVIDIA driver
nvidia-smi
# Expected: shows GPU name, driver version, VRAM
# If "command not found": no NVIDIA driver installed (APEX will use CPU-only mode)

# 4. Check CUDA toolkit
nvcc --version
# Expected: shows CUDA version 12.0+
# If "command not found": install CUDA toolkit (see below)

# 5. Check available RAM
free -h
# Look at "available" column — need at least 2-4 GB free

# 6. Check disk space
df -h .
# Need ~10 GB for datasets + compressed files
```

### Install CUDA (if missing)

```bash
# Ubuntu 22.04/24.04:
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update && sudo apt install -y cuda-toolkit-13-2
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
nvcc --version  # Should now work

# Fedora:
sudo dnf install cuda-toolkit

# If you don't want to install CUDA:
# Use apex-cpu-avx2 instead — no CUDA needed, full CPU performance
```

---

## 3. Quick Start

### With GPU (NVIDIA + CUDA)

```bash
# Clone the repo
git clone https://github.com/Rkcr7/apex-testing.git
cd apex-testing

# Make binaries executable
chmod +x apex apex-gpu-avx2 apex-gpu-avx512 apex-cpu-avx2 apex-cpu-avx512 apex-cpu-sse42 verify.sh download_datasets.sh sysinfo.sh

# Print your system info (share this with benchmarks)
./sysinfo.sh

# Check it works
./apex --help
# You should see: APEX version, SIMD tier, GPU status, worker count
# If you have AVX-512: use ./apex-gpu-avx512 instead for best performance

# Download benchmark datasets
./download_datasets.sh

# Benchmark Silesia
./apex bench data/silesia.tar

# Benchmark ALL 5 datasets at once (with cooldown, saves to results.txt)
for f in data/silesia.tar data/enwik9 data/realworld/linux-kernel.tar data/realworld/large_json_1gb.json data/realworld/grch38.fna; do echo ""; echo "=== $f ==="; ./apex bench "$f"; sleep 10; done 2>&1 | tee results.txt

# Compress a file
./apex compress myfile.tar myfile.apex -mt

# Decompress
./apex decompress myfile.apex restored.tar

# Verify it's lossless (byte-perfect)
cmp myfile.tar restored.tar && echo "PASS: Files are identical"
```

### Without GPU (CPU-only)

```bash
git clone https://github.com/Rkcr7/apex-testing.git
cd apex-testing
chmod +x apex-cpu-avx2 apex-cpu-avx512 apex-cpu-sse42 verify.sh download_datasets.sh sysinfo.sh

./sysinfo.sh                                  # Check system
./download_datasets.sh                        # Download datasets
./apex-cpu-avx2 bench data/silesia.tar        # Benchmark (CPU-only)
./apex-cpu-avx2 compress myfile.tar myfile.apex -mt
./apex-cpu-avx2 decompress myfile.apex restored.tar
# If your CPU has AVX-512: use apex-cpu-avx512 instead for best speed
```

---

## 4. Understanding the Output

### What `--help` shows

```
APEX 0.1.0 — GPU-Accelerated Lossless Compression
SIMD:    AVX-512 (Tier 1)        ← Your CPU's vector instruction set
GPU:     CUDA enabled             ← GPU detected and ready
Workers: 14 threads               ← Auto-detected worker count (your cores - 2)
```

- **SIMD Tier 1** (AVX-512): Best. Found on AMD Zen 4+ and Intel Ice Lake+.
- **SIMD Tier 2** (AVX2): Good. Any modern CPU.
- **GPU: CUDA enabled**: GPU acceleration is active (~10x faster than CPU-only).
- **GPU: Disabled (CPU-only mode)**: No CUDA found. Works fine, just slower.
- **Workers**: Number of parallel threads. Auto-detected as `physical_cores - 2`.

### What compress output shows

```
Compressed: 211957760 -> 52983644 bytes (4.00x ratio)
Speed:      541 MB/s  Time: 373 ms  Threads: 14
```

- **211957760 -> 52983644**: Original size → compressed size (in bytes)
- **4.00x ratio**: Original / compressed = how much smaller. Higher = better.
- **541 MB/s**: Compression throughput (original_size / time). Higher = faster.
- **Threads: 14**: Worker threads used.

### What bench output shows

```
Config        Compress    Decomp    Ratio  Verify
------        --------    ------    -----  ------
1T              226 MB/s    613 MB/s   4.02x  PASS
Par 6MB         541 MB/s    672 MB/s   4.00x  PASS
```

- **1T**: Single-thread mode (best ratio, slower). Uses 1 GPU transform + parallel encoding.
- **Par 6MB**: Parallel mode with 6MB blocks. Uses 14 workers + GPU. Fastest.
- **Compress/Decomp**: Speed in MB/s. These are algorithm speed (excludes file I/O).
- **Ratio**: Compression ratio. Higher = better.
- **PASS**: Round-trip verified (compress → decompress → byte-compare = identical).

---

## 5. All Commands Explained

### `compress` — Compress a file

```bash
./apex compress <input> <output.apex> [flags]
```

| Flag | What It Does | When to Use |
|------|-------------|-------------|
| (no flags) | 1T mode: single-thread + GPU, largest blocks | Best ratio. Archival. |
| `-mt` | Parallel mode: auto threads + GPU, auto block size | **Best speed. Use this most of the time.** |
| `--par N` | Parallel with N MB blocks (6, 8, 12, 14, 16, 18, 20) | Specific tuning after running `tune`. |
| `-t N` | Use exactly N worker threads | Control CPU usage (e.g., `-t 4` on shared server). |
| `--no-lzp` | Skip preprocessing | +65% compress speed, -0.5% ratio. Speed-critical. |
| `-v` | Verbose output | See GPU status, pipeline details. |

**Examples:**
```bash
./apex compress data.tar data.apex              # 1T mode (best ratio)
./apex compress data.tar data.apex -mt          # Parallel (best speed)
./apex compress data.tar data.apex --par 14     # 14MB blocks (for source code)
./apex compress data.tar data.apex -mt -t 8     # Parallel, 8 threads
./apex compress data.tar data.apex -mt --no-lzp # Parallel, skip preprocessing (fastest)
./apex compress data.tar data.apex -v           # Verbose (see pipeline info)
```

### `decompress` — Decompress a file

```bash
./apex decompress <input.apex> <output> [-v]
```

Decompression auto-detects everything from the .apex file header. No flags needed.

```bash
./apex decompress data.apex restored.tar        # Decompress
./apex decompress data.apex restored.tar -v     # Verbose
```

### `tune` — Find the best config for YOUR data

```bash
./apex tune <input> [-t N]
```

Tests all configs (1T + 7 parallel block sizes), measures speed and ratio, and recommends the best. **Run this before benchmarking.**

```bash
./apex tune mydata.tar                          # Auto threads
./apex tune mydata.tar -t 8                     # Test with 8 threads
```

Output: table of all configs with speeds + ratio, then specific recommendations for fastest compress, best ratio, fastest decompress, and best overall.

### `bench` — Full benchmark (compress + decompress + verify)

```bash
./apex bench <input> [-v]
```

Tests **8 configurations** automatically: 1T + Par 6/8/12/14/16/18/20 MB. For each config:
1. Warmup run (initializes GPU, excluded from timing)
2. Compress best-of-2 (data pre-loaded in RAM, measures algorithm speed only)
3. Decompress best-of-2
4. Round-trip verify (`memcmp` original vs decompressed)

**Speed measurement**: data is pre-loaded in RAM before timing starts. The timer wraps only the compression/decompression call — no file I/O, no memory allocation. This is the same methodology used by [lzbench](https://github.com/inikep/lzbench) and other standard benchmark frameworks. The speed you see is pure algorithm throughput.

```bash
./apex bench data/silesia.tar                   # Standard benchmark
./apex bench data/silesia.tar -v                # With methodology notes
```

Example output:
```
Config        Compress    Decomp    Ratio  Verify
------        --------    ------    -----  ------
1T              226 MB/s    613 MB/s   4.02x  PASS
Par 6MB         541 MB/s    672 MB/s   4.00x  PASS
Par 8MB         524 MB/s    654 MB/s   4.01x  PASS
Par 12MB        413 MB/s    621 MB/s   4.04x  PASS
...
```

To see wall-clock speed (including file I/O), use `time ./apex compress ...` or the `verify.sh` script which shows both.

### `info` — Show file structure

```bash
./apex info <output.apex>
```

Shows block count, compression ratio, format version, original size.

---

## 6. Default Behavior

### What happens when you run `./apex compress data.tar data.apex` (no flags)?

1. APEX detects content type (text? binary? JSON? already compressed?)
2. Runs in **1T mode**: single-thread compression using GPU acceleration
3. Creates 1-2 large blocks for maximum context
4. Applies preprocessing (removes long-range repeated sequences)
5. GPU-accelerated transform (groups similar contexts together)
6. Entropy encoding (near-optimal bit-level coding)
7. Output is a single `.apex` file with headers, compressed blocks, and checksums

**This gives the BEST ratio** but is slower than parallel mode.

### What happens with `-mt` flag?

1. Same pipeline, but splits input into N blocks of 6MB each
2. 14 worker threads (auto-detected) process blocks in parallel
3. Workers share the GPU — while 1 uses GPU, others do CPU encoding in parallel
4. A collector thread writes blocks in order
5. **This gives the BEST speed** — typically 2-5x faster than 1T.

### What happens with `--par 14`?

Same as `-mt` but with 14MB blocks instead of auto (6MB). Larger blocks = better ratio, slightly fewer blocks for pipeline overlap.

### What about `--no-lzp`?

Skips the preprocessing step. The preprocessor scans for repeated 40+ byte sequences and removes them before transform. Skipping it makes compression ~65% faster but loses ~0.5% ratio. Worth it if speed matters more than that last 0.5%.

---

## 7. Download Benchmark Datasets

The included script downloads the same public datasets used in our benchmarks.

```bash
chmod +x download_datasets.sh

# Essential 5 datasets (~8.4 GB on disk):
#   Silesia (202 MB)       — universal mixed benchmark
#   enwik9 (954 MB)        — Wikipedia text
#   Linux Kernel (1.5 GB)  — source code tarball
#   Large JSON (1.1 GB)    — repetitive structured data
#   Human Genome (3.0 GB)  — DNA reference genome
./download_datasets.sh

# All 14 datasets (~17 GB)
./download_datasets.sh --all

# Check what you have
./download_datasets.sh --list
```

All datasets are publicly available from their original sources (kernel.org, mattmahoney.net, NCBI, etc.). The script just automates the download + decompression.

---

## 8. Reproduce Our Benchmarks

### Quick: single dataset

```bash
./apex bench data/silesia.tar
```

### Full: all 5 essential datasets with cooldown

```bash
echo "=== Silesia ===" && ./apex bench data/silesia.tar && sleep 10
echo "=== enwik9 ===" && ./apex bench data/enwik9 && sleep 10
echo "=== Linux Kernel ===" && ./apex bench data/realworld/linux-kernel.tar && sleep 10
echo "=== Large JSON ===" && ./apex bench data/realworld/large_json_1gb.json && sleep 10

# Human Genome (3GB) — use compress+decompress to avoid OOM in bench:
echo "=== Human Genome ==="
./apex compress data/realworld/grch38.fna /tmp/g.apex -mt && \
./apex decompress /tmp/g.apex /tmp/g_out && \
cmp data/realworld/grch38.fna /tmp/g_out && echo "PASS" && \
rm -f /tmp/g.apex /tmp/g_out
```

### Verify lossless (any file)

```bash
./apex compress myfile.tar test.apex -mt
./apex decompress test.apex test_out.tar
cmp myfile.tar test_out.tar && echo "ROUND-TRIP: PASS"
md5sum myfile.tar test_out.tar    # Should show identical hashes
rm -f test.apex test_out.tar
```

### Independent verification (don't trust APEX's own numbers)

The included `verify.sh` runs **14 independent checks** using only standard Unix tools (`stat`, `md5sum`, `sha256sum`, `cmp`, `date`, `bc`). It does NOT use APEX's self-reported numbers.

**What it tests:**
1. 1T compress works
2. Decompress produces correct output
3. Lossless: size match + MD5 + SHA256 + byte-level `cmp` (4 checks)
4. Parallel mode round-trip (compress + decompress + verify)
5. Custom configs: `--par 8`, `--par 20`, `--no-lzp` all round-trip correctly
6. Cross-mode: 1T and Par 14MB both decompress
7. Determinism: compressing twice → identical output

```bash
# Basic usage
./verify.sh data/silesia.tar

# Specify which binary to test
./verify.sh data/silesia.tar ./apex-gpu-avx512
./verify.sh data/silesia.tar ./apex-cpu-avx2

# Test on multiple datasets
./verify.sh data/enwik9
./verify.sh data/realworld/large_json_1gb.json
./verify.sh data/realworld/linux-kernel.tar
```

Or do it manually without any script:
```bash
# Compress and check the compressed file size yourself
./apex compress data/silesia.tar /tmp/test.apex -mt
ls -la data/silesia.tar /tmp/test.apex
# Calculate ratio: 211957760 / compressed_size

# Decompress and check MD5 yourself
./apex decompress /tmp/test.apex /tmp/test_out
md5sum data/silesia.tar /tmp/test_out
# Both hashes MUST be identical

# Time it yourself
time ./apex compress data/silesia.tar /tmp/test.apex -mt
# speed = 202 MB / real_seconds

rm -f /tmp/test.apex /tmp/test_out
```

### Note on speed measurement

`apex bench` measures **algorithm speed** (data pre-loaded in RAM, excluding file I/O) — the same methodology used by [lzbench](https://github.com/inikep/lzbench), Squash, and all standard compression benchmarks. Wall-clock `time` includes disk read + write, which is slower. Both are valid measurements; they answer different questions.

### Why cooldown?

Laptops throttle GPU/CPU under sustained load. 10 seconds between datasets prevents thermal throttling from affecting subsequent results. Desktops and servers need less cooldown.

---

## 9. Hardware Configuration

### CPU: Thread count

APEX auto-detects your physical CPU cores and uses `cores - 2` threads (reserves 2 for OS/IO).

```bash
# Check what APEX detected
./apex --help | grep Workers

# Check your actual cores
nproc                              # Total logical threads (includes SMT/HT)
lscpu | grep "Core(s) per socket"  # Physical cores per socket
lscpu | grep "Socket(s)"           # Number of sockets (usually 1)
```

**Override:**
```bash
./apex compress data.tar out.apex -mt -t 8      # Force 8 threads
./apex tune mydata.tar -t 4                     # Tune with 4 threads
```

| Your CPU | Cores | Auto Workers | Override? |
|---------|-------|-------------|-----------|
| Intel i5 / Ryzen 5 (4-6 core) | 4-6 | 2-4 | Usually fine |
| Intel i7 / Ryzen 7 (8 core) | 8 | 6 | Usually fine |
| Intel i9 / Ryzen 9 (16 core) | 16 | 14 | Usually fine |
| Threadripper (32-64 core) | 32-64 | 28-56 | Consider `-t 30` (GPU bottleneck) |
| EPYC / Xeon (64-128 core) | 64-128 | 56+ | Use `-t 30` (diminishing returns) |
| Laptop on battery | Any | Auto | Consider `-t 4` to save power |
| Shared server | Any | Auto | Use `-t <your_fair_share>` |

**Intel hybrid CPUs** (12th-14th gen with P+E cores): APEX uses all detected cores. E-cores are slower for compression. For best results, use `-t <P-core count - 2>`.

### GPU: VRAM

APEX uses ~5.2 GB VRAM by default (128MB transform blocks × 2 GPU contexts × 20.5x working memory).

| Your VRAM | Will It Work? | Notes |
|----------|--------------|-------|
| 4 GB | Marginal | May fail on large files. Use `--par 6`. |
| 6 GB | Yes | Occasional pressure on large blocks. |
| **8 GB** | **Yes (default)** | **Designed for this.** |
| 12-16 GB | Yes | Extra headroom, no benefit from defaults. |
| 24+ GB | Yes | No additional benefit (blocks capped at 128MB). |

**If GPU fails**, APEX automatically falls back to CPU transform. Same ratio, slower speed.

### RAM

| File Size | RAM Needed (bench) | RAM Needed (compress) |
|----------|-------------------|----------------------|
| 100 MB | ~400 MB | ~200 MB |
| 500 MB | ~2 GB | ~1 GB |
| 1 GB | ~4 GB | ~2 GB |
| 3 GB | ~10 GB | ~5 GB |

The `bench` command needs ~3x file size (input + compressed + decompressed in RAM simultaneously). If OOM, use `compress` + `decompress` separately.

### Storage

Any SSD is fine. APEX peaks at ~1.7 GB/s throughput (Large JSON) — NVMe Gen3+ handles this easily. HDDs may bottleneck on large files.

---

## 10. Advanced Tuning

### Block size selection

Block size is the most important tuning parameter. It controls the trade-off between speed and ratio.

| Block Size | Speed | Ratio | Best For |
|-----------|-------|-------|---------|
| `--par 6` | Fastest | Lowest par ratio | Small/mixed files (<200MB), max throughput |
| `--par 8` | Fast | Good | Text files, Wikipedia, books |
| `--par 12` | Balanced | Better | Medium source code, tarballs |
| `--par 14` | Good | High | Large source code (LLVM, Chromium) |
| `--par 18` | Good | Higher | Repetitive data (JSON, CSV, logs) |
| `--par 20` | Moderate | Best par | Best ratio in parallel mode |
| (no flags) | Slowest | **Best overall** | 1T mode, archival, maximum ratio |

**Why?** Larger blocks give transform more context to find patterns. A 20MB block sees patterns spanning 20MB. A 6MB block only sees 6MB. But larger blocks mean fewer blocks, so less pipeline overlap with the GPU.

**Don't guess — measure:**
```bash
./apex tune mydata.tar    # Tests ALL sizes, recommends the best
```

### Skip preprocessing for speed

```bash
./apex compress data.tar data.apex -mt --no-lzp
```

preprocessing scans for repeated 40+ byte sequences. It costs ~400 MB/s throughput. On data with few long repeats (binary, random-looking), it's pure overhead. `--no-lzp` skips it.

- **Text/source/JSON**: Keep preprocessing on (ratio gain is worth it)
- **Binary/mixed**: Try both with `tune`, preprocessing might not help
- **Speed-critical**: `--no-lzp` for +65% compress speed

### Combine flags

```bash
# Maximum speed: parallel + skip preprocessing + small blocks
./apex compress data.tar data.apex --par 6 --no-lzp

# Maximum ratio: 1T mode (default, no flags needed)
./apex compress data.tar data.apex

# Balanced: parallel with medium blocks
./apex compress data.tar data.apex --par 14

# Controlled: specific threads + blocks
./apex compress data.tar data.apex --par 16 -t 8
```

---

## 11. Reference Numbers

Our test system: **AMD Ryzen 9 8940HX (16C/32T) + NVIDIA RTX 5070 Laptop (8GB) + 16GB DDR5**

### Speed Mode (Parallel)

| Dataset | Size | Compress | Decompress | Ratio | Config |
|---------|------|----------|------------|-------|--------|
| Silesia (mixed) | 202 MB | 541 MB/s | 672 MB/s | 4.00x | Par 6MB |
| enwik9 (text) | 954 MB | 634 MB/s | 697 MB/s | 4.36x | Par 8MB |
| Linux Kernel | 1.5 GB | 817 MB/s | 999 MB/s | 9.26x | Par 12MB |
| LLVM Source | 2.4 GB | 945 MB/s | 1,402 MB/s | 4.90x | Par 14MB |
| Large JSON | 1.1 GB | 1,642 MB/s | 2,022 MB/s | 18.11x | Par 18MB |
| Human Genome | 3.0 GB | 479 MB/s | 757 MB/s | 4.36x | Par 8MB |

### Ratio Mode (1T)

| Dataset | Ratio | Compress | Decompress |
|---------|-------|----------|------------|
| Large JSON | 23.11x | 540 MB/s | 1,965 MB/s |
| Linux Kernel | 9.64x | 329 MB/s | 1,201 MB/s |
| enwik9 | 5.04x | 241 MB/s | 642 MB/s |
| Human Genome | 4.48x | 213 MB/s | 828 MB/s |
| enwik8 | 4.39x | 141 MB/s | 209 MB/s |
| Silesia | 4.02x | 226 MB/s | 578 MB/s |

**Your numbers will differ** based on your GPU, CPU, and RAM. Run `./apex bench` and `./apex tune` to measure YOUR system.

---

## 12. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `GPU: Disabled (CPU-only mode)` | CUDA not found | Install CUDA toolkit, ensure `nvcc` is in PATH |
| First run is slow | CUDA driver loading (one-time per process) | Normal. Use `apex bench` for accurate speed. CPU-only binary has no delay. |
| `Killed` or no output after starting | Not enough RAM (see below) | Use compress+decompress separately |
| GPU memory errors | VRAM < 8 GB | Use `--par 6` for smaller GPU transform blocks |
| `GLIBC_2.38 not found` | Old Linux | Need Ubuntu 24.04+ or Fedora 39+. Or glibc 2.38+. |
| Speeds lower than reference | Different hardware | Expected. Run `./apex tune` for YOUR optimal config. |
| Speed drops during long benchmarks | Thermal throttling | Add `sleep 10` between datasets. Desktop/server won't have this. |
| `command not found` | Not executable | `chmod +x apex` |
| `No such file or directory` for datasets | Not downloaded | Run `./download_datasets.sh` first |

### If bench crashes or gets killed (OOM)

The `bench` command loads the entire file into RAM three times (original + compressed + decompressed). For large files this can exceed available memory:

| File Size | RAM needed for bench | RAM needed for compress+decompress |
|-----------|---------------------|------------------------------------|
| 200 MB | ~600 MB | ~300 MB |
| 1 GB | ~3 GB | ~1.5 GB |
| 3 GB | ~9 GB | ~4.5 GB |

**How to tell if bench failed from OOM:**
```bash
# If you see any of these, it's an OOM:
# - "Killed" message
# - Process exits with no output after "Config" header
# - Shell returns with no error message
# - dmesg shows "Out of memory: Killed process"

# Check with:
dmesg | tail -5    # Look for "oom-kill" or "Out of memory"
```

**Fix — test with compress + decompress instead:**
```bash
# This uses much less RAM (no triple-buffering)
./apex compress data/realworld/grch38.fna /tmp/test.apex -mt
./apex decompress /tmp/test.apex /tmp/test_out
cmp data/realworld/grch38.fna /tmp/test_out && echo "PASS"
rm -f /tmp/test.apex /tmp/test_out

# To measure speed, use time:
time ./apex compress data/realworld/grch38.fna /tmp/test.apex -mt
# speed = file_size_MB / real_seconds
```

### Diagnostic commands

```bash
# Full system check
./apex --help                                    # APEX version, GPU status, workers
nvidia-smi                                       # GPU model, VRAM, driver version
nvcc --version                                   # CUDA toolkit version
nproc                                            # CPU thread count
free -h                                          # Available RAM
lscpu | grep -E "Model name|Core|Socket|Thread"  # CPU details
```

---

## 13. Reporting Your Results

When sharing benchmark results, please include this information so others can compare:

### Template

```
=== Hardware ===
CPU:  [model] ([cores]C/[threads]T)
GPU:  [model] ([VRAM] GB)
RAM:  [total] GB [DDR4/DDR5] [single/dual channel]
OS:   [distro] [version], Kernel [version]
CUDA: [version]

=== APEX Info ===
[paste output of: ./apex --help | head -4]

=== Results ===
[paste output of: ./apex bench data/silesia.tar]

=== Round-trip Verification ===
[paste output of: ./apex compress data/silesia.tar /tmp/t.apex -mt && \
  ./apex decompress /tmp/t.apex /tmp/t_out && \
  md5sum data/silesia.tar /tmp/t_out]
```

### Example

```
=== Hardware ===
CPU:  AMD Ryzen 7 7700X (8C/16T)
GPU:  NVIDIA RTX 4070 (12 GB)
RAM:  32 GB DDR5-6000 dual channel
OS:   Ubuntu 24.04, Kernel 6.8.0
CUDA: 13.2.51

=== APEX Info ===
APEX 0.1.0 — GPU-Accelerated Lossless Compression
SIMD:    AVX-512 (Tier 1)
GPU:     CUDA enabled
Workers: 6 threads

=== Results ===
Config        Compress    Decomp    Ratio  Verify
1T              XXX MB/s    XXX MB/s   4.02x  PASS
Par 6MB         XXX MB/s    XXX MB/s   4.00x  PASS
...
```

---

## Acknowledgments

APEX uses [libcubwt](https://github.com/IlyaGrebnov/libcubwt) and [libsais](https://github.com/IlyaGrebnov/libsais) — both by [Ilya Grebnov](https://github.com/IlyaGrebnov). These are exceptional libraries that make high-performance BWT practical.

We also benchmark against [libbsc](https://github.com/IlyaGrebnov/libbsc) (also by Grebnov) — a BWT compressor using the same underlying libraries. bsc achieves 5-14% better ratio; APEX is 7-18x faster. Full comparison in [BENCHMARKS.md](BENCHMARKS.md#apex-vs-libbsc-bsc--bwt-compressor-comparison).

## Disclaimers

- APEX is under active development (v0.1.0). While all 14 benchmark datasets pass round-trip verification, there may be edge cases or configurations we haven't encountered yet. If you find an issue, we'd appreciate hearing about it.
- There is one known issue: LLVM 2.4GB fails in 1T mode due to a block boundary bug at ~384MB. All parallel modes work correctly on this file.
- Performance varies by hardware. Our reference numbers are from a specific test system (Ryzen 9 8940HX + RTX 5070 Laptop). Your results will differ based on GPU, CPU, and thermal conditions.
- The binary auto-detects hardware capabilities. If GPU is not available or CUDA is not installed, it falls back to CPU-only mode automatically and will print `GPU: Disabled (CPU-only mode)`.
- Compression is **lossless** — decompressed output is byte-identical to the original. Every `bench` and `tune` run verifies this automatically (PASS/FAIL).

## Contact

For questions, collaboration, or licensing inquiries: **ritik135001@gmail.com**

## License

**APEX Testing License v1.0** — Copyright 2026 Ritik. All rights reserved.

This binary is provided **exclusively for testing, benchmarking, and evaluation**. No ownership or IP rights are transferred. See [LICENSE](LICENSE) for full terms.

You **MAY**: download, run, benchmark, share results with attribution, distribute this package unchanged.

You **MAY NOT**: reverse-engineer, decompile, use in production or commercial services, resell, wrap in another product/service/API, repackage under a different name, claim credit, or create derivative works.

All rights not explicitly granted are reserved by the author.
