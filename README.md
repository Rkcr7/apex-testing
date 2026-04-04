# APEX 0.1.0 — Pre-built Binary Release

**GPU-Accelerated Lossless Compression — 4.0x+ ratio at 500+ MB/s**

This package contains a pre-built binary for benchmarking and evaluation. No source code, no build system — just download, run, and measure.

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Setup Checklist](#2-setup-checklist)
3. [Quick Start (30 seconds)](#3-quick-start)
4. [Understanding the Output](#4-understanding-the-output)
5. [All Commands Explained](#5-all-commands-explained)
6. [Default Behavior](#6-default-behavior)
7. [Download Benchmark Datasets](#7-download-benchmark-datasets)
8. [Reproduce Our Benchmarks](#8-reproduce-our-benchmarks)
9. [Hardware Configuration](#9-hardware-configuration)
10. [Advanced Tuning](#10-advanced-tuning)
11. [Reference Numbers](#11-reference-numbers)
12. [Troubleshooting](#12-troubleshooting)
13. [Reporting Your Results](#13-reporting-your-results)

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

Run these commands one by one. Every line should give a clear result.

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
# APEX will still work, just in CPU-only mode (same ratio, slower speed)
```

---

## 3. Quick Start

```bash
# Extract the package
tar xzf apex-0.1.0-linux-x86_64-cuda.tar.gz
cd apex-0.1.0-linux-x86_64-cuda

# Make binary executable
chmod +x apex

# Check it works
./apex --help
# You should see: APEX version, SIMD tier, GPU status, worker count

# Compress a file
./apex compress myfile.tar myfile.apex -mt

# Decompress
./apex decompress myfile.apex restored.tar

# Verify it's lossless (byte-perfect)
cmp myfile.tar restored.tar && echo "PASS: Files are identical"
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
- **GPU: CUDA enabled**: GPU will be used for BWT transform (~10x faster than CPU).
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

- **1T**: Single-thread mode (best ratio, slower). Uses 1 GPU BWT + parallel rANS.
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
| `--no-lzp` | Skip LZP preprocessing | +65% compress speed, -0.5% ratio. Speed-critical. |
| `-v` | Verbose output | See GPU status, pipeline details. |

**Examples:**
```bash
./apex compress data.tar data.apex              # 1T mode (best ratio)
./apex compress data.tar data.apex -mt          # Parallel (best speed)
./apex compress data.tar data.apex --par 14     # 14MB blocks (for source code)
./apex compress data.tar data.apex -mt -t 8     # Parallel, 8 threads
./apex compress data.tar data.apex -mt --no-lzp # Parallel, skip LZP (fastest)
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

Runs best-of-2 compress and decompress on all configs. Verifies round-trip for each.

```bash
./apex bench data/silesia.tar                   # Standard benchmark
./apex bench data/silesia.tar -v                # With methodology notes
```

### `info` — Show file structure

```bash
./apex info <output.apex>
```

Shows block count, compression ratio, format version, original size.

---

## 6. Default Behavior

### What happens when you run `./apex compress data.tar data.apex` (no flags)?

1. APEX detects content type (text? binary? JSON? already compressed?)
2. Runs in **1T mode**: single-thread compression using GPU for BWT
3. Creates 1-2 large blocks (64-128MB each) for maximum BWT context
4. Applies LZP preprocessing (removes long-range repeated sequences)
5. GPU BWT transforms the data (groups similar contexts together)
6. Adaptive rANS encodes the BWT output (near-optimal entropy coding)
7. Output is a single `.apex` file with headers, compressed blocks, and checksums

**This gives the BEST ratio** but is slower than parallel mode.

### What happens with `-mt` flag?

1. Same pipeline, but splits input into N blocks of 6MB each
2. 14 worker threads (auto-detected) process blocks in parallel
3. Workers share the GPU via mutex — while 1 does GPU BWT, others do CPU rANS
4. A collector thread writes blocks in order
5. **This gives the BEST speed** — typically 2-5x faster than 1T.

### What happens with `--par 14`?

Same as `-mt` but with 14MB blocks instead of auto (6MB). Larger blocks = better ratio, slightly fewer blocks for pipeline overlap.

### What about `--no-lzp`?

Skips the LZP preprocessing step. LZP scans for repeated 40+ byte sequences and removes them before BWT. Skipping it makes compression ~65% faster but loses ~0.5% ratio. Worth it if speed matters more than that last 0.5%.

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

APEX uses ~5.2 GB VRAM by default (128MB BWT blocks × 2 GPU contexts × 20.5x working memory).

| Your VRAM | Will It Work? | Notes |
|----------|--------------|-------|
| 4 GB | Marginal | May fail on large files. Use `--par 6`. |
| 6 GB | Yes | Occasional pressure on large blocks. |
| **8 GB** | **Yes (default)** | **Designed for this.** |
| 12-16 GB | Yes | Extra headroom, no benefit from defaults. |
| 24+ GB | Yes | No additional benefit (blocks capped at 128MB). |

**If GPU fails**, APEX automatically falls back to CPU BWT. Same ratio, slower speed.

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

**Why?** Larger blocks give BWT more context to find patterns. A 20MB block sees patterns spanning 20MB. A 6MB block only sees 6MB. But larger blocks mean fewer blocks, so less pipeline overlap with the GPU.

**Don't guess — measure:**
```bash
./apex tune mydata.tar    # Tests ALL sizes, recommends the best
```

### Skip LZP for speed

```bash
./apex compress data.tar data.apex -mt --no-lzp
```

LZP scans for repeated 40+ byte sequences. It costs ~400 MB/s throughput. On data with few long repeats (binary, random-looking), it's pure overhead. `--no-lzp` skips it.

- **Text/source/JSON**: Keep LZP on (ratio gain is worth it)
- **Binary/mixed**: Try both with `tune`, LZP might not help
- **Speed-critical**: `--no-lzp` for +65% compress speed

### Combine flags

```bash
# Maximum speed: parallel + skip LZP + small blocks
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
| First run is slow (~450ms extra) | CUDA driver init | Normal. Subsequent runs are full speed. |
| `Killed` or `OOM` on bench | Not enough RAM | Use compress+decompress separately (not bench) for large files |
| GPU memory errors | VRAM < 8 GB | Use `--par 6` for smaller GPU BWT blocks |
| `GLIBC_2.38 not found` | Old Linux | Need Ubuntu 24.04+ or Fedora 39+. Or glibc 2.38+. |
| Speeds lower than reference | Different hardware | Expected. Run `./apex tune` for YOUR optimal config. |
| Speed drops during long benchmarks | Thermal throttling | Add `sleep 10` between datasets. Desktop/server won't have this. |
| `command not found` | Not executable | `chmod +x apex` |
| `No such file or directory` for datasets | Not downloaded | Run `./download_datasets.sh` first |

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

## Package Contents

| File | Size | Description |
|------|------|-------------|
| `apex` | 16 MB | Pre-built binary (stripped, multi-GPU-arch) |
| `download_datasets.sh` | 14 KB | Dataset download script |
| `README.md` | This file | Complete usage guide |

## Disclaimers

- Performance varies by hardware. Our reference numbers are from a specific test system (Ryzen 9 8940HX + RTX 5070 Laptop). Your results will differ.
- The binary auto-detects hardware capabilities. If GPU is not available or CUDA is not installed, it falls back to CPU-only mode automatically and will print `GPU: Disabled (CPU-only mode)`.
- Compression is **lossless** — decompressed output is byte-identical to the original. Every `bench` and `tune` run verifies this automatically (PASS/FAIL).
- APEX is in active development. This is version 0.1.0.

## License

**APEX Testing License v1.0**

Copyright 2026 Ritik. All rights reserved.

This pre-built binary is provided solely for:
- **Testing**: Verifying compression performance on your hardware
- **Benchmarking**: Comparing against other compressors
- **Evaluation**: Assessing suitability for your use case
- **Sharing results**: Publishing benchmark data with proper attribution
- **Reproducibility**: Allowing others to verify published claims

You MAY:
- Download, run, and benchmark this binary
- Share benchmark results publicly (with hardware details)
- Distribute this package unchanged for others to test
- Use compressed files produced by this binary

You MAY NOT:
- Reverse-engineer, decompile, or disassemble this binary
- Use this binary in production systems or commercial services
- Modify or create derivative works from this binary
- Remove or alter this license notice

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
THE AUTHORS SHALL NOT BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY.
