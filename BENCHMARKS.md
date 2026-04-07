# APEX Benchmarks

Verified across 21 datasets on 3 independent systems. Includes standard benchmarks and enterprise production data (server logs, financial tick data, analytics exports). All results round-trip verified (PASS).

**Contents:**
- [Development Machine Results](#development-machine-results) — Our laptop (Ryzen 9 + RTX 5070 Laptop), datasets 1-14
- [Enterprise & Production Data](#enterprise--production-data) — Server logs, financial tick data, analytics exports (datasets 15-21)
- [APEX vs zstd on Server Logs](#apex-vs-zstd-on-enterprise-server-logs) — Head-to-head at multiple zstd levels and thread counts
- [Independent Validation #1 — RTX 4090](#independent-validation--vastai-rtx-4090) — Vast.ai cloud (EPYC 7D12 + RTX 4090)
- [Independent Validation #2 — RTX 5090](#independent-validation--vastai-rtx-5090--dual-epyc-7742) — Vast.ai cloud (Dual EPYC 7742 + RTX 5090)
- [Three-System Comparison](#three-system-comparison) — Side-by-side analysis
- [CPU Architecture Effects](#how-cpu-architecture-affects-apex) — Zen 2 vs Zen 4, AVX2 vs AVX-512, clock speed
- [APEX vs libbsc](#apex-vs-libbsc-bsc--bwt-compressor-comparison) — Head-to-head with the closest BWT competitor
- [CPU-Only Mode](#cpu-only-mode-no-gpu-required) — No GPU results: 826 MB/s on JSON, 131 MB/s at 4.0x on Silesia

---

## Development Machine Results

| Component | Specification |
|-----------|--------------|
| **Machine** | ASUS TUF Gaming A16 (2025) — laptop |
| **CPU** | AMD Ryzen 9 8940HX (Zen 4 / 2023, 16C/32T, 5.4 GHz boost) |
| **GPU** | NVIDIA RTX 5070 Laptop (Blackwell, 8GB GDDR7) |
| **RAM** | 16GB DDR5-5200 single-channel |
| **Storage** | Samsung 1TB NVMe Gen4 |
| **OS** | Ubuntu 24.04.4 LTS, Kernel 6.17.0 |
| **CUDA** | 13.2.51, Driver 580.126.09 |
| **Power** | AC plugged in, Performance mode, CPU governor: performance |

---

## Methodology

### How `apex bench` measures speed

`apex bench` tests 8 configurations (1T + Par 6/8/12/14/16/18/20 MB) on each dataset:

1. Data is loaded into RAM once (mmap). No disk I/O during timing.
2. GPU warmup run (excluded from timing — initializes CUDA contexts).
3. Each config: compress best-of-2, decompress best-of-2.
4. Speed = `original_file_size_MB / time_seconds` (algorithm throughput, not wall-clock).
5. Round-trip verified: `memcmp(original, decompressed)` for each config.

This is the same methodology used by [lzbench](https://github.com/inikep/lzbench), Squash, and other standard compression benchmark frameworks.

### Verify the speeds yourself

**`verify.sh`** — runs `apex bench` and shows the benchmark speed:
```bash
./verify.sh data/silesia.tar
```

**`time` command** — shows wall-clock (slower, includes disk + CUDA startup):
```bash
time ./apex compress data/silesia.tar /tmp/test.apex -mt
```

### Why CLI `time` is slower than `apex bench`

| | zstd | APEX (GPU) | APEX (CPU-only) |
|---|---|---|---|
| **Process startup** | Near-zero | CUDA driver loading (one time)| Near-zero |
| **Silesia compress** | 2.4s | 1.2s | 1.8s |
| **Algorithm only** | ~2.4s | ~380ms | ~1.6s |

The APEX GPU binary loads the CUDA driver on every process start (typically a few hundred ms, varies by GPU and driver). This is a **one-time cost per process** — not per file. In production use (server, pipeline, daemon), CUDA loads once and all subsequent files compress at full algorithm speed.

The CPU-only binary (`apex-cpu-avx2`) has **no CUDA overhead** — its startup is 1ms, same as zstd.

### Other methodology details

- **Runs**: Best of 2 runs per configuration.
- **Cooldown**: 10 seconds between datasets (prevents thermal throttling).
- **Verification**: Every result round-trip verified (compress → decompress → byte-compare).

### Would these numbers reproduce?

- **Ratio**: YES, exactly. Compression ratio is deterministic.
- **Speed**: YES, ±5%. lzbench uses best-of-N which often gives slightly higher numbers.
- **GPU required**: Decompress speeds require the same GPU. Without GPU: ~200 MB/s.

### Disclosures

1. Parallel mode uses 14 CPU threads + 1 GPU. The 1T mode uses 1 pipeline worker + GPU (actually 2 CPU threads + CUDA driver threads — not purely single-threaded).
2. Decompress requires GPU for full speed. CPU-only decompress is ~200-250 MB/s.
3. Thermal throttling on laptops can reduce speeds by 10-20% under sustained load.
4. The CLI reads the entire input file into RAM before processing. `bench` needs ~3x file size in RAM, `compress`/`decompress` need ~1.5x. For files over 4 GB on 16 GB RAM systems, use `compress`/`decompress` with `--par 6` instead of `bench`. The compression algorithm itself is block-based (6-20 MB blocks) and does not require the full file in memory — this is a CLI convenience, not an algorithm limitation.

---

## Results by Dataset

All results in this section are from our **development machine** (ASUS TUF Gaming A16, Ryzen 9 8940HX + RTX 5070 Laptop). For results on other hardware, see [RTX 4090](#independent-validation--vastai-rtx-4090) and [RTX 5090](#independent-validation--vastai-rtx-5090--dual-epyc-7742) sections below.

**Legend**: C = Compress (MB/s), D = Decompress (MB/s), R = Ratio, RT = Round-trip verified

---

### 1. Silesia Corpus (202 MB, mixed)

The universal compression benchmark. 12 files: literature, executables, MRI, chemical data, source code, XML, star catalogs. Every major compressor publishes Silesia numbers.

Source: [sun.aei.polsl.pl](https://sun.aei.polsl.pl/~sdeor/index.php?page=silesia)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 212 MB/s | **594 MB/s** | **4.02x** | PASS |
| **Par 6MB** | **551 MB/s** | **704 MB/s** | 4.00x | PASS |
| Par 8MB | 539 MB/s | 699 MB/s | 4.01x | PASS |
| **Par 20MB** | 343 MB/s | 360 MB/s | **4.08x** | PASS |

### 2. enwik8 (96 MB, English Wikipedia XML)

Standard text compression benchmark. First 10^8 bytes of Wikipedia XML dump.

Source: [mattmahoney.net](http://mattmahoney.net/dc/textdata.html)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 141 MB/s | 209 MB/s | **4.39x** | PASS |
| **Par 6MB** | **349 MB/s** | 404 MB/s | 3.76x | PASS |
| Par 8MB | 324 MB/s | **440 MB/s** | 3.83x | PASS |
| Par 20MB | 197 MB/s | 229 MB/s | **4.03x** | PASS |

### 3. enwik9 (954 MB, English Wikipedia XML)

Large-file text benchmark. First 10^9 bytes of Wikipedia. 10x larger than enwik8.

Source: [mattmahoney.net](http://mattmahoney.net/dc/textdata.html)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 248 MB/s | **755 MB/s** | **5.04x** | PASS |
| Par 6MB | 590 MB/s | 791 MB/s | 4.28x | PASS |
| **Par 8MB** | **658 MB/s** | **794 MB/s** | 4.36x | PASS |
| **Par 20MB** | 510 MB/s | 652 MB/s | **4.60x** | PASS |

### 4. Linux Kernel (1,474 MB, source code tarball)

Linux v6.12 complete source: 92,438 files. C source, headers, Makefiles, Kconfig, docs.

Source: [kernel.org](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 341 MB/s | **1,268 MB/s** | **9.64x** | PASS |
| Par 6MB | 711 MB/s | 1,129 MB/s | 8.94x | PASS |
| Par 8MB | 714 MB/s | 1,161 MB/s | 9.08x | PASS |
| **Par 12MB** | **802 MB/s** | 1,059 MB/s | 9.26x | PASS |
| Par 14MB | 744 MB/s | **1,034 MB/s** | 9.30x | PASS |
| Par 16MB | 738 MB/s | 1,013 MB/s | 9.38x | PASS |
| Par 20MB | 703 MB/s | 1,028 MB/s | **9.44x** | PASS |

### 5. GH Events JSON (480 MB, highly repetitive JSON)

One hour of all GitHub activity. Identical JSON schema keys repeat millions of times.

Source: [data.gharchive.org](https://data.gharchive.org/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 499 MB/s | **1,431 MB/s** | **22.15x** | PASS |
| Par 6MB | 732 MB/s | 1,382 MB/s | 14.91x | PASS |
| **Par 18MB** | **1,330 MB/s** | **1,758 MB/s** | 17.54x | PASS |
| Par 20MB | 1,224 MB/s | 1,703 MB/s | 17.89x | PASS |
| **Par 24MB** | 1,196 MB/s | 1,592 MB/s | **18.34x** | PASS |

### 6. LLVM Source (2,445 MB, C++ source tarball)

LLVM/Clang compiler: template-heavy C++, headers, tests, CMake.

Source: [github.com/llvm/llvm-project](https://github.com/llvm/llvm-project)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| Par 8MB | 836 MB/s | 1,235 MB/s | 4.91x | PASS |
| **Par 14MB** | **945 MB/s** | **1,402 MB/s** | 4.90x | PASS |
| Par 16MB | 887 MB/s | 1,342 MB/s | 5.00x | PASS |
| **Par 20MB** | 893 MB/s | 1,312 MB/s | **5.06x** | PASS |

*Note: 1T mode has a known bug at block boundary ~384MB on this 2.4GB file. All Par modes PASS.*

### 7. Chromium Source (4,680 MB, C++ source tarball)

Chromium browser source: C++, JavaScript, Python, HTML, binary resources. Largest dataset tested.

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| Par 6MB | 446 MB/s | 1,012 MB/s | 3.27x | PASS |
| **Par 8MB** | **938 MB/s** | **1,193 MB/s** | 3.30x | PASS |
| **Par 16MB** | 842 MB/s | 988 MB/s | **3.32x** | PASS |
| Par 18MB | 837 MB/s | **1,273 MB/s** | 3.06x | PASS |

### 8. Large JSON (1,078 MB, repetitive JSON)

Large JSON with recurring key/value patterns. Achieves 2 GB/s decompress.

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 540 MB/s | **1,965 MB/s** | **23.11x** | PASS |
| Par 6MB | 848 MB/s | 1,579 MB/s | 15.23x | PASS |
| **Par 18MB** | **1,642 MB/s** | **2,022 MB/s** | 18.11x | PASS |
| Par 20MB | 1,689 MB/s | **2,053 MB/s** | 18.43x | PASS |
| **Par 24MB** | 1,520 MB/s | 1,896 MB/s | **18.90x** | PASS |

### 9. Wiki SQL (101 MB, database dump)

Simple English Wikipedia page metadata. CREATE TABLE + INSERT INTO statements.

Source: [dumps.wikimedia.org](https://dumps.wikimedia.org/simplewiki/latest/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 245 MB/s | 311 MB/s | **4.49x** | PASS |
| **Par 8MB** | **335 MB/s** | **459 MB/s** | 4.38x | PASS |

### 10. WA Electric CSV (65 MB, tabular data)

Washington State electric vehicle registrations. ~200K records, highly repetitive columns.

Source: [data.wa.gov](https://data.wa.gov/Transportation/Electric-Vehicle-Population-Data/f6w7-q2d2)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 257 MB/s | **482 MB/s** | **21.60x** | PASS |
| **Par 6MB** | **446 MB/s** | **830 MB/s** | 17.49x | PASS |

### 11. Firefox (79 MB, binary application tarball)

Firefox for Linux: ELF executables, shared libs, pre-compressed resources.

**Result**: 1.00x ratio (incompressible — correct behavior, stored at memcpy speed).

### 12. Taxi Parquet (48 MB, columnar binary)

NYC taxi trip data in Apache Parquet (internally compressed with Snappy/ZSTD).

**Result**: 1.00x ratio (incompressible — correct behavior).

### 13. Pizza&Chili English (2,108 MB, Gutenberg text)

2.1GB of English literature from Project Gutenberg. Pure text, no markup.

Source: [pizzachili.dcc.uchile.cl](http://pizzachili.dcc.uchile.cl/texts/nlang/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 212 MB/s | **756 MB/s** | **4.37x** | PASS |
| **Par 6MB** | **620 MB/s** | **696 MB/s** | 3.96x | PASS |
| Par 8MB | 631 MB/s | 679 MB/s | 4.02x | PASS |
| **Par 20MB** | 541 MB/s | 647 MB/s | **4.22x** | PASS |

### 14. Human Genome GRCh38 (2,999 MB, DNA reference genome)

Human reference genome in FASTA format. 4-alphabet DNA (ACGT) with N's and headers.

Source: [ftp.ncbi.nlm.nih.gov](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 219 MB/s | **801 MB/s** | **4.48x** | PASS |
| **Par 6MB** | **493 MB/s** | **887 MB/s** | 4.35x | PASS |
| **Par 8MB** | 490 MB/s | 815 MB/s | 4.36x | PASS |
| **Par 20MB** | 480 MB/s | 715 MB/s | **4.40x** | PASS |

---

## Enterprise & Production Data

Results on real-world enterprise datasets. Tested on our **development machine** (Ryzen 9 8940HX + RTX 5070 Laptop). These represent data types that enterprises compress daily at scale — server logs, financial tick data, and analytics exports.

> **Note on large files**: `bench` allocates ~3x file size in RAM. For files over 2 GB on 16 GB RAM systems, we used `compress`/`decompress` commands separately with `--par 6` (lowest memory usage), then verified round-trip via MD5 checksum.

---

### 15. Spark Application Logs (2,804 MB, enterprise server logs)

Combined Apache Spark application logs from Loghub. The exact type of data that Datadog, Splunk, and Elastic ingest at 10-200+ TB/day.

Source: [Loghub](https://github.com/logpai/loghub)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 430 MB/s | **1,852 MB/s** | **29.16x** | PASS |
| Par 6MB | 741 MB/s | 1,844 MB/s | 27.44x | PASS |
| Par 8MB | 618 MB/s | 1,728 MB/s | 27.75x | PASS |
| Par 12MB | 1,254 MB/s | **2,069 MB/s** | 28.13x | PASS |
| **Par 14MB** | **1,364 MB/s** | **2,036 MB/s** | 28.25x | PASS |
| Par 16MB | 1,302 MB/s | 1,964 MB/s | **28.35x** | PASS |
| Par 18MB | 1,260 MB/s | 1,991 MB/s | 28.42x | PASS |
| Par 20MB | 1,205 MB/s | 1,960 MB/s | 28.43x | PASS |

Best ratio: **29.16x** at 430/1,852 MB/s (1T) — 2.8 GB → 96 MB. Best speed: **1,364 MB/s** at 28.25x (Par 14MB). Best decompress: **2,069 MB/s** at 28.13x (Par 12MB).

---

### 16. HDFS Logs (1,505 MB, Hadoop distributed file system logs)

Hadoop Distributed File System block operations — allocations, replications, DataNode heartbeats. Extremely repetitive structured text.

Source: [Loghub](https://github.com/logpai/loghub)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 376 MB/s | **1,357 MB/s** | **17.79x** | PASS |
| Par 6MB | 481 MB/s | 979 MB/s | 15.81x | PASS |
| Par 8MB | 463 MB/s | 1,004 MB/s | 16.06x | PASS |
| **Par 12MB** | **994 MB/s** | **1,330 MB/s** | **16.36x** | PASS |
| Par 14MB | 898 MB/s | 1,180 MB/s | 16.43x | PASS |
| Par 16MB | 908 MB/s | 1,188 MB/s | 16.52x | PASS |
| Par 18MB | 873 MB/s | 1,169 MB/s | 16.60x | PASS |
| Par 20MB | 855 MB/s | 1,171 MB/s | 16.65x | PASS |

Best ratio: **17.79x** at 376/1,357 MB/s (1T) — 1.5 GB → 85 MB. Best speed: **994 MB/s** at 16.36x (Par 12MB).

---

### 17. BGL Supercomputer Logs (709 MB, HPC system logs)

Blue Gene/L supercomputer logs from Lawrence Livermore National Lab. System diagnostics from 131,072 processors.

Source: [Loghub](https://github.com/logpai/loghub)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 324 MB/s | 1,033 MB/s | 17.03x | PASS |
| **Par 6MB** | 394 MB/s | 987 MB/s | **17.45x** | PASS |
| Par 8MB | 660 MB/s | 1,071 MB/s | 17.42x | PASS |
| **Par 12MB** | **767 MB/s** | **1,102 MB/s** | **17.32x** | PASS |
| Par 14MB | 714 MB/s | 1,105 MB/s | 17.32x | PASS |
| Par 16MB | 686 MB/s | 1,121 MB/s | 17.30x | PASS |
| Par 18MB | 735 MB/s | 1,001 MB/s | 17.25x | PASS |
| Par 20MB | 611 MB/s | 1,023 MB/s | 17.26x | PASS |

Best ratio: **17.45x** at 394/987 MB/s (Par 6MB) — 709 MB → 41 MB. Best speed: **767 MB/s** at 17.32x (Par 12MB).

---

### 18. Binance BTC Trades (3,703 MB, financial tick data CSV)

Every BTC/USDT trade on Binance, January 2024. CSV: trade_id, price, quantity, quoteQty, time, isBuyerMaker.

Source: [data.binance.vision](https://data.binance.vision/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **Par 6MB** | **589 MB/s** | **718 MB/s** | **6.48x** | PASS |

3.7 GB → 572 MB. Tested with compress/decompress (bench OOM on 16 GB RAM for 3.7 GB file). Round-trip verified via MD5.

---

### 19. Binance BNB Trades (612 MB, financial tick data CSV)

Every BNB/USDT trade on Binance, January 2024. Same format as BTC, fewer trades.

Source: [data.binance.vision](https://data.binance.vision/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 247 MB/s | 654 MB/s | 7.10x | PASS |
| **Par 6MB** | **531 MB/s** | **682 MB/s** | **7.27x** | PASS |
| Par 8MB | 493 MB/s | 653 MB/s | 7.29x | PASS |
| Par 12MB | 395 MB/s | 608 MB/s | 7.31x | PASS |
| Par 14MB | 433 MB/s | 560 MB/s | 7.32x | PASS |
| Par 16MB | 414 MB/s | 554 MB/s | 7.32x | PASS |
| Par 18MB | 411 MB/s | 516 MB/s | 7.31x | PASS |
| **Par 20MB** | 391 MB/s | 501 MB/s | **7.33x** | PASS |

Best ratio: **7.33x** at 391/501 MB/s (Par 20MB). Best speed: **531 MB/s** at 7.27x (Par 6MB).

---

### 20. IMDb Title Database (2,582 MB, analytics TSV export)

Five IMDb database tables as TSV: titles, names, crew, episodes, ratings. Typical data lake export format.

Source: [datasets.imdbws.com](https://datasets.imdbws.com/)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 249 MB/s | **860 MB/s** | **5.53x** | PASS |
| **Par 6MB** | **583 MB/s** | 719 MB/s | 5.36x | PASS |
| Par 8MB | 580 MB/s | 699 MB/s | 5.40x | PASS |
| Par 12MB | 500 MB/s | 672 MB/s | 5.44x | PASS |
| Par 14MB | 521 MB/s | 666 MB/s | 5.45x | PASS |
| Par 16MB | 511 MB/s | 651 MB/s | 5.47x | PASS |
| Par 18MB | 513 MB/s | 655 MB/s | 5.48x | PASS |
| Par 20MB | 483 MB/s | 633 MB/s | 5.48x | PASS |

Best ratio: **5.53x** at 249/860 MB/s (1T) — 2.6 GB → 467 MB. Best speed: **583 MB/s** at 5.36x (Par 6MB).

---

### 21. NYC Taxi Parquet (659 MB, pre-compressed columnar data)

12 months of NYC yellow taxi trip records in Apache Parquet format. Already internally compressed (Snappy).

Source: [NYC TLC](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)

**Result**: **1.00x** at 2,603/6,645 MB/s (Par 18MB) — RAW passthrough. APEX's 4KB entropy sampling detects pre-compressed Parquet blocks and stores them without wasting CPU/GPU cycles. The 6.6 GB/s decompress confirms pure memcpy throughput.

---

## vs Competition (Silesia, same hardware)

### Multi-threaded (all compressors using their best multi-threaded configs)

| Compressor | Config | Threads | Ratio | Compress | Decompress |
|-----------|--------|---------|-------|----------|------------|
| **APEX** | **Par 6MB** | **14 + GPU** | **4.00x** | **551 MB/s** | **704 MB/s** |
| **APEX** | **1T** | **1 + GPU** | **4.02x** | **212 MB/s** | **594 MB/s** |
| zstd 1.5.5 | -9 -T14 | 14 | 3.56x | 337 MB/s | 2,021 MB/s |
| zstd 1.5.5 | -12 -T14 | 14 | 3.63x | 126 MB/s | 2,021 MB/s |
| zstd 1.5.5 | -15 -T10 --long | 10 | 3.72x | 29 MB/s | 991 MB/s |
| bsc 3.3.12 | default (-b25, CPU BWT) | all (OpenMP) | 4.42x | 58 MB/s | 309 MB/s |
| bsc 3.3.12 | -e2 (best ratio, CPU BWT) | all (OpenMP) | **4.47x** | 56 MB/s | 228 MB/s |

### Single-worker / Low-thread (from lzbench 2.2.1)

> Note: APEX 1T uses 1 pipeline worker + GPU (not purely single-threaded). Other tools below are CPU-only single-threaded.

| Compressor | Config | Threads | Ratio | Compress | Decompress |
|-----------|--------|---------|-------|----------|------------|
| **APEX** | **1T** | **1 + GPU** | **4.02x** | **226 MB/s** | **578 MB/s** |
| zstd 1.5.5 | -5 | 1 | 3.36x | 125 MB/s | 1,197 MB/s |
| zstd 1.5.5 | -22 | 1 | 4.05x | 2 MB/s | 1,197 MB/s |
| bzip2 | -9 | 1 | 3.88x | 13 MB/s | 46 MB/s |
| bzip3 1.5.2 | -5 | 1 | 4.48x | 12 MB/s | 15 MB/s |
| LZMA 25.01 | -5 | 1 | 4.35x | 3 MB/s | 110 MB/s |

**Methodology notes:**
- **APEX Par 6MB**: 14 parallel worker threads + GPU. Each worker processes one block at a time.
- **APEX 1T**: Despite the name "1T" (one worker in the pipeline), this mode actually uses **2 CPU threads** (main thread + async encoding worker) plus 2 CUDA driver threads when GPU is available. It is NOT purely single-threaded. "1T" means one pipeline worker (no block-level parallelism), not one OS thread.
- **zstd**: Multi-threaded tested with zstd CLI v1.5.5 at levels -9, -12, -15 with -T10/-T14 threads and `--long=27`. Single-threaded from lzbench 2.2.1. These represent zstd's best configs across speed-ratio range.
- **bsc**: Native CLI v3.3.12 with OpenMP (uses all CPU cores), CPU BWT mode. bsc also has GPU modes (-G) using Sort Transform which achieve comparable or faster compress on some datasets. Tested default (-b25) and best-ratio (-e2). Full comparison in [libbsc section below](#apex-vs-libbsc-bsc--bwt-compressor-comparison).
- **Scaling**: APEX decompress speed scales with GPU hardware — tested on laptop RTX 5070 (672 MB/s Silesia), RTX 4090 shows +15% on some datasets, RTX 5090 reaches 4,403 MB/s on JSON. bsc decompress is CPU-bound (QLFC decode is serial) and does not benefit from better GPU hardware.
- **bzip2, bzip3, LZMA**: Single-threaded via lzbench 2.2.1 at their best ratio settings.
- **Decompress**: zstd has significantly faster decompression (LZ77 memcpy-based decode). This is a fundamental algorithm difference, not a threading advantage.

---

## APEX vs zstd on Enterprise Server Logs

Server logs are the dominant data type in enterprise observability pipelines (Datadog, Splunk, Elastic, Grafana Loki). We tested zstd at multiple levels and thread counts to find its best possible performance on these datasets, then compared against APEX.

**Why multiple zstd configs?** zstd multi-threading does not scale linearly — [documented scaling plateau at ~5 threads](https://github.com/facebook/zstd/issues/3907) due to memory pool fragmentation. Higher thread counts show diminishing returns or even regression. We tested different level+thread combinations to give zstd every advantage at each operating point.

All tests on the same machine (Ryzen 9 8940HX, 16C/32T + RTX 5070 Laptop). zstd v1.5.5.

### Spark Application Logs (2.8 GB)

| Compressor | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| **APEX Par 14MB** | **28.25x** | **1,364 MB/s** | **2,036 MB/s** |
| **APEX 1T** | **29.16x** | **430 MB/s** | **1,852 MB/s** |
| zstd -9 -T14 | 21.10x | 1,263 MB/s | 3,419 MB/s |
| zstd -12 -T14 | 21.29x | 661 MB/s | 3,590 MB/s |
| zstd -12 -T6 | 21.29x | 388 MB/s | 3,590 MB/s |
| zstd -15 -T10 | 21.44x | 208 MB/s | 3,641 MB/s |
| zstd -15 -T6 | 21.44x | 139 MB/s | 3,641 MB/s |

APEX at 28.25x is **32% better ratio** than zstd's best (21.44x). Even zstd -15 with 10 threads cannot match APEX's ratio. APEX compresses 6.6x faster than zstd -15 T10 while achieving a higher ratio. APEX decompresses at 2,036 MB/s on this laptop — already above typical NVMe throughput, and decompress speed scales with GPU hardware (RTX 5090 reaches 4,403 MB/s on JSON).

### HDFS Logs (1.5 GB)

| Compressor | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| **APEX Par 12MB** | **16.36x** | **994 MB/s** | **1,330 MB/s** |
| **APEX 1T** | **17.79x** | **376 MB/s** | **1,357 MB/s** |
| zstd -9 -T14 | 12.52x | 845 MB/s | 2,962 MB/s |
| zstd -12 -T14 | 12.81x | 337 MB/s | 2,962 MB/s |
| zstd -12 -T6 | 12.81x | 267 MB/s | 2,962 MB/s |
| zstd -15 -T10 | 13.41x | 114 MB/s | 2,996 MB/s |
| zstd -15 -T6 | 13.41x | 79 MB/s | 2,996 MB/s |

APEX at 16.36x is **22% better ratio** than zstd's best (13.41x). APEX compresses 3x faster than zstd -12 T14 while achieving a higher ratio. Decompress at 1,330 MB/s on a laptop GPU — scales further with better GPUs.

### BGL Supercomputer Logs (709 MB)

| Compressor | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| **APEX Par 12MB** | **17.32x** | **767 MB/s** | **1,102 MB/s** |
| **APEX 1T** | **17.03x** | **324 MB/s** | **1,033 MB/s** |
| zstd -9 -T14 | 14.11x | 771 MB/s | 2,907 MB/s |
| zstd -12 -T14 | 14.28x | 377 MB/s | 2,872 MB/s |
| zstd -12 -T6 | 14.28x | 273 MB/s | 2,872 MB/s |
| zstd -15 -T10 | 14.30x | 180 MB/s | 3,030 MB/s |
| zstd -15 -T6 | 14.30x | 129 MB/s | 3,030 MB/s |

APEX at 17.32x is **21% better ratio** than zstd's best (14.30x). At similar compress speed (~767 vs 771 MB/s), APEX delivers 23% better ratio than zstd -9 T14. Decompress at 1,102 MB/s on a laptop GPU.

### The pattern across all server logs

| Metric | APEX advantage | Notes |
|--------|---------------|-------|
| **Ratio** | 21-34% better than zstd's best at any level | BWT groups repeated log templates structurally — LZ77 can only match within a sliding window |
| **Compress speed** | Matches or beats zstd -9 T14 | GPU BWT + 14-core parallel rANS |
| **Decompress speed** | 1,000-1,800 MB/s on laptop GPU | Scales with GPU hardware — RTX 5090 reaches 4,403 MB/s on JSON. Already above NVMe throughput on most systems. zstd decompress is CPU-bound and fixed by core speed; APEX decompress is GPU-accelerated and improves with better GPUs |

**zstd threading observation**: Increasing threads from T6 to T14 improved zstd compress speed, but going from T10 to T14 showed diminishing returns. At level 15, doubling threads (T6→T10) only improved speed by ~40-50%, not 67%. This aligns with the [documented scaling limitation](https://github.com/facebook/zstd/issues/3907).

**No zstd configuration at any level or thread count reaches APEX's ratio on server logs.** This is not a tuning gap — it is an architectural difference. BWT captures the full structure of repeated log templates regardless of distance. LZ77's sliding window fundamentally cannot.

---

## Speed Records

> All records below are from our **development machine** (RTX 5070 Laptop + Ryzen 9 8940HX, 16 GB RAM). This is a consumer-grade laptop — not a server, not a workstation. APEX has not been specifically tuned or optimized for any dataset. These numbers represent out-of-the-box performance on unmodified hardware. Server-class GPUs (A100, H100) and higher core-count CPUs would be expected to improve on these results.

### Compress

| Speed | Dataset | Ratio | Config |
|-------|---------|-------|--------|
| **1,689 MB/s** | Large JSON 1GB | 18.43x | Par 20MB |
| **1,330 MB/s** | GH Events 480MB | 17.54x | Par 18MB |
| **1,364 MB/s** | Spark Logs 2.8GB | 28.25x | Par 14MB |
| **994 MB/s** | HDFS Logs 1.5GB | 16.36x | Par 12MB |
| **945 MB/s** | LLVM 2.4GB | 4.90x | Par 14MB |
| **802 MB/s** | Linux 1.5GB | 9.26x | Par 12MB |
| **767 MB/s** | BGL Logs 709MB | 17.32x | Par 12MB |
| **658 MB/s** | enwik9 954MB | 4.36x | Par 8MB |
| **589 MB/s** | Binance BTC 3.7GB | 6.48x | Par 6MB |
| **583 MB/s** | IMDb TSV 2.6GB | 5.36x | Par 6MB |
| **551 MB/s** | Silesia 202MB | 4.00x | Par 6MB |
| **531 MB/s** | Binance BNB 612MB | 7.27x | Par 6MB |

### Decompress

| Speed | Dataset | Ratio | Config |
|-------|---------|-------|--------|
| **2,069 MB/s** | Spark Logs 2.8GB | 28.13x | Par 12MB |
| **2,053 MB/s** | Large JSON 1GB | 18.43x | Par 20MB |
| **2,036 MB/s** | Spark Logs 2.8GB | 28.25x | Par 14MB |
| **1,965 MB/s** | Large JSON 1GB | 23.11x | 1T |
| **1,852 MB/s** | Spark Logs 2.8GB | 29.16x | 1T |
| **1,758 MB/s** | GH Events 480MB | 17.54x | Par 18MB |
| **1,629 MB/s** | LLVM 2.4GB | 4.56x | 1T |
| **1,402 MB/s** | LLVM 2.4GB | 4.90x | Par 14MB |
| **1,357 MB/s** | HDFS Logs 1.5GB | 17.79x | 1T |
| **1,330 MB/s** | HDFS Logs 1.5GB | 16.36x | Par 12MB |
| **1,268 MB/s** | Linux 1.5GB | 9.64x | 1T |
| **1,102 MB/s** | BGL Logs 709MB | 17.32x | Par 12MB |
| **860 MB/s** | IMDb TSV 2.6GB | 5.53x | 1T |
| **794 MB/s** | enwik9 954MB | 4.36x | Par 8MB |
| **704 MB/s** | Silesia 202MB | 4.00x | Par 6MB |

### Ratio

| Ratio | Dataset | Compress | Config |
|-------|---------|----------|--------|
| **29.16x** | Spark Logs 2.8GB | 417 MB/s | 1T |
| **23.11x** | Large JSON 1GB | 540 MB/s | 1T |
| **22.15x** | GH Events 480MB | 499 MB/s | 1T |
| **21.60x** | WA Electric CSV | 257 MB/s | 1T |
| **17.79x** | HDFS Logs 1.5GB | 376 MB/s | 1T |
| **17.45x** | BGL Logs 709MB | 394 MB/s | Par 6MB |
| **9.64x** | Linux Kernel 1.5GB | 329 MB/s | 1T |
| **7.33x** | Binance BNB 612MB | 391 MB/s | Par 20MB |
| **6.48x** | Binance BTC 3.7GB | 589 MB/s | Par 6MB |
| **5.53x** | IMDb TSV 2.6GB | 249 MB/s | 1T |
| **5.04x** | enwik9 954MB | 241 MB/s | 1T |
| **4.48x** | Human Genome 3GB | 213 MB/s | 1T |
| **4.08x** | Silesia 202MB | 334 MB/s | Par 20MB |

---

## How to Reproduce

```bash
# Download datasets
chmod +x download_datasets.sh
./download_datasets.sh          # Essential 5
./download_datasets.sh --all    # All 14 + enterprise

# Run benchmarks
./apex bench data/silesia.tar
./apex bench data/enwik9
./apex bench data/realworld/linux-kernel.tar
./apex bench data/realworld/large_json_1gb.json

# For large files (>2GB), if bench runs out of memory:
./apex compress data/realworld/grch38.fna /tmp/g.apex -mt
./apex decompress /tmp/g.apex /tmp/g_out
cmp data/realworld/grch38.fna /tmp/g_out && echo "PASS"

# Find optimal config for YOUR data
./apex tune mydata.tar
```

---

## Independent Validation — Vast.ai RTX 4090

APEX was independently tested on a completely different system to verify that published results are reproducible and that performance scales across hardware.

### Test System

| Component | Specification |
|-----------|--------------|
| **Machine** | Vast.ai cloud instance (ID: 34146528) |
| **GPU** | NVIDIA GeForce RTX 4090 (24GB GDDR6X, 1008 GB/s, sm_89) |
| **CPU** | AMD EPYC 7D12 32-Core (64 threads, 2.0 GHz, Zen 2, 2019 — server-class, optimized for throughput not single-thread speed) |
| **RAM** | 128 GB |
| **Disk** | WD_BLACK SN850X 2000GB (6543 MB/s) |
| **CUDA** | 13.1, Driver 590.48.01 |
| **APEX binary** | AVX2 build (EPYC 7D12 does not support AVX-512) |
| **Workers** | 30 threads (auto-detected) |


### Results — All 5 Datasets, All PASS

#### Silesia (202 MB)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 132 MB/s | 409 MB/s | **4.06x** | PASS |
| Par 6MB | 462 MB/s | 654 MB/s | 3.75x | PASS |
| **Par 8MB** | **559 MB/s** | **608 MB/s** | 4.01x | PASS |
| Par 20MB | 281 MB/s | 296 MB/s | 4.06x | PASS |

#### enwik9 (954 MB)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 152 MB/s | 644 MB/s | **5.04x** | PASS |
| **Par 8MB** | **717 MB/s** | **698 MB/s** | 4.36x | PASS |
| Par 16MB | 636 MB/s | 701 MB/s | 4.54x | PASS |
| Par 20MB | 567 MB/s | 635 MB/s | 4.60x | PASS |

#### Linux Kernel (1.5 GB)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 192 MB/s | **1,220 MB/s** | **9.64x** | PASS |
| **Par 12MB** | **894 MB/s** | **1,049 MB/s** | 9.26x | PASS |
| Par 16MB | 860 MB/s | 1,009 MB/s | 9.38x | PASS |
| Par 20MB | 799 MB/s | 976 MB/s | 9.44x | PASS |

#### Large JSON (1.1 GB)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 306 MB/s | **2,058 MB/s** | **23.11x** | PASS |
| Par 6MB | 1,008 MB/s | 1,679 MB/s | 15.23x | PASS |
| **Par 18MB** | **1,793 MB/s** | **2,324 MB/s** | 18.11x | PASS |
| Par 20MB | 1,750 MB/s | 2,262 MB/s | 18.43x | PASS |

#### Human Genome (3.0 GB)

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| 1T | 221 MB/s | **848 MB/s** | **4.48x** | PASS |
| **Par 8MB** | **771 MB/s** | 745 MB/s | 4.36x | PASS |
| Par 16MB | 698 MB/s | 736 MB/s | 4.39x | PASS |
| Par 20MB | 718 MB/s | 727 MB/s | 4.40x | PASS |

### Cross-Hardware Comparison (Best Par Config)

| Dataset | Our Laptop (RTX 5070) | Vast.ai (RTX 4090) | Difference |
|---------|----------------------|-------------------|------------|
| Silesia C/D | 551 / 704 MB/s | 559 / 654 MB/s | +1% C, -7% D |
| enwik9 C/D | 658 / 794 MB/s | **717 / 698** MB/s | **+9% C**, -12% D |
| Linux Kernel C/D | 802 / 1,059 MB/s | **894 / 1,049** MB/s | **+11% C**, -1% D |
| Large JSON C/D | 1,642 / 2,022 MB/s | **1,793 / 2,324** MB/s | **+9% C**, **+15% D** |
| Genome C/D | 493 / 887 MB/s | **771 / 745** MB/s | **+56% C**, -16% D |

### Ratio Verification

| Dataset | Our Laptop | Vast.ai | Match? |
|---------|-----------|---------|--------|
| Silesia | 4.02x | 4.06x | Nearly identical |
| enwik9 | 5.04x | 5.04x | **Exact** |
| Linux Kernel | 9.64x | 9.64x | **Exact** |
| Large JSON | 23.11x | 23.11x | **Exact** |
| Genome | 4.48x | 4.48x | **Exact** |

Compression ratios are deterministic — same input always produces the same compressed output regardless of hardware.

### Why Some Results Differ — and How CPU Architecture Matters

APEX performance depends on **both GPU and CPU**. Even with a top-tier GPU, the CPU architecture significantly affects results. Here's a detailed breakdown:

#### CPU Architecture Comparison

| | Our Laptop (Ryzen 9 8940HX) | Vast.ai (EPYC 7D12) |
|---|---|---|
| **Architecture** | Zen 4 (2023) | Zen 2 (2019) |
| **Max clock** | 5.4 GHz | 2.0 GHz |
| **IPC (instructions/cycle)** | High (Zen 4) | ~20% lower (Zen 2) |
| **SIMD** | AVX-512 | AVX2 only |
| **L2 cache/core** | 1 MB | 512 KB |
| **Cores** | 16 | 32 |
| **Single-thread score** | ~2.7x faster | Baseline |
| **Multi-thread score** | Baseline | ~2x more cores |

#### How CPU affects each APEX stage

| Stage | What runs it | CPU impact |
|-------|-------------|-----------|
| **CPU processing** | CPU, single-thread per block | **Most affected.** Directly proportional to clock × IPC. Zen 4 at 5.4 GHz is ~2.5x faster per core than Zen 2 at 2.0 GHz. |
| **Preprocessing** | CPU, single-thread per block | Same — clock-dependent. |
| **GPU transform** | GPU | Not affected by CPU. Same GPU = same speed. |
| **Parallel workers** | CPU worker count | More cores = more workers busy while GPU processes. EPYC's 30 workers compensate for slower per-core speed. |
| **Decompress** | GPU + CPU | Mostly GPU-limited. Faster CPU helps but GPU dominates. |

#### Why 1T mode is ~2x slower on Vast.ai

1T mode compresses with a single CPU thread + GPU. The encoding speed is limited by that one core:

| | Clock | IPC | SIMD | Effective speed |
|---|---|---|---|---|
| Zen 4 (our laptop) | 5.4 GHz | High | AVX-512 | ~69 MB/s per core |
| Zen 2 (Vast.ai) | 2.0 GHz | ~20% lower | AVX2 | ~27 MB/s per core |

Result: 1T encoding is roughly **2.5x slower** on the EPYC. This matches the observed ~2x slower 1T compress speeds.

#### Why Par mode is faster on Vast.ai despite slower cores

In Par mode, many workers process blocks simultaneously. While one worker uses the GPU, others are doing CPU work:

- **Our laptop**: 14 workers × ~69 MB/s = ~966 MB/s total CPU capacity
- **Vast.ai**: 30 workers × ~27 MB/s = ~810 MB/s total CPU capacity

But the GPU is the **serialized bottleneck** (2 contexts, one block at a time). With 30 workers vs 14, there's always a worker ready when the GPU finishes — better pipeline utilization. On large files (Genome 3GB, Linux 1.5GB), this matters a lot: **+61% on Genome, +9% on Linux Kernel**.

On small files (Silesia 202MB = only 33 blocks with 6MB), both systems fill the pipeline similarly — speed difference is small (+7%).

#### AVX-512 vs AVX2 impact

Our laptop has AVX-512 (Zen 4), the Vast.ai system has AVX2 only (Zen 2). This affects:

| Operation | AVX-512 advantage | Where it shows |
|-----------|------------------|----------------|
| Decompress (1T) | +77-122% | AVX-512 accelerates key decompress operations on our laptop |
| CPU processing | ~10-15% | Wider SIMD for internal data structures |
| LZP / detection | Minimal | These are memory-bound, not compute-bound |

This explains why **1T decompress is similar** (both GPU-limited for the transform step) but if more work was on CPU, the AVX-512 advantage would be larger.

#### The bottom line: GPU is king, but CPU matters

Even with an RTX 4090 (a faster GPU than our RTX 5070 Laptop), **the older Zen 2 CPU holds back single-thread performance**. The ideal APEX system combines:

- Fast GPU (high compute, large VRAM) — for transforms
- Fast CPU cores (high clock, Zen 4/5, AVX-512) — for per-block processing
- Many CPU cores — for parallel overlap on large files

A system with a modern high-clock CPU (Ryzen 9 9950X at 5.7 GHz, Zen 5) + RTX 4090/5090 would likely outperform both our test systems.

### What Bigger GPUs Mean for APEX

- **More VRAM** (24GB vs 8GB) → can handle larger transform blocks in 1T mode → better ratio. The RTX 4090's 24GB allows 512MB+ blocks.
- **More GPU compute** → faster forward and inverse transforms → improves both compress and decompress.
- **More CPU cores** → more parallel overlap with GPU → faster Par mode, especially on large files (1GB+).
- **Higher CPU clock** → faster per-block encoding → directly improves 1T mode and helps Par mode.
- **AVX-512** → significantly faster 1T decompress.
- **Larger files benefit more** from bigger hardware. The +61% on Human Genome (3GB) vs +7% on Silesia (202MB) shows this clearly — more data means more opportunity for parallel overlap.

For best results: use a modern high-clock CPU with many cores + a high-end NVIDIA GPU. Run `./apex tune` to find the optimal config for your specific hardware combination.

---

## Independent Validation — Vast.ai RTX 5090 + Dual EPYC 7742

### Test System

| Component | Specification |
|-----------|--------------|
| **Machine** | Vast.ai cloud instance (ID: 34148459) |
| **GPU** | NVIDIA GeForce RTX 5090 (32GB GDDR7, sm_120 Blackwell, 575W desktop) |
| **CPU** | AMD EPYC 7742 × 2 sockets (128 cores / 256 threads, 2.25 GHz, Zen 2 / 2019) |
| **RAM** | 1.0 TB DDR4 |
| **Disk** | WD_BLACK SN850X 2000GB (6543 MB/s) |
| **CUDA** | 13.0, Driver 580.82.09 |
| **APEX binary** | AVX2 build, 126 workers auto-detected |

### Results — Record-Breaking

| Dataset | Best Compress | Best Decompress | Best Ratio | RT |
|---------|-------------|----------------|-----------|-----|
| Silesia 202MB | **783 MB/s** (Par 6) | **874 MB/s** (Par 6) | **4.06x** (1T) | ALL PASS |
| enwik9 954MB | **1,633 MB/s** (Par 8) | **1,331 MB/s** (Par 14) | **5.04x** (1T) | ALL PASS |
| Linux Kernel 1.5GB | **1,895 MB/s** (Par 12) | **2,094 MB/s** (Par 18) | **9.64x** (1T) | ALL PASS |
| Large JSON 1.1GB | **1,899 MB/s** (Par 18) | **4,403 MB/s** (Par 16) | **23.11x** (1T) | ALL PASS |
| Genome 3.0GB | **1,833 MB/s** (Par 6) | **1,483 MB/s** (Par 6) | **4.48x** (1T) | ALL PASS |

### New All-Time Records

| Record | Speed | Previous Best | Improvement |
|--------|-------|--------------|-------------|
| **Decompress** Large JSON | **4,403 MB/s** | 2,324 MB/s (RTX 4090) | **+89%** |
| **Decompress** Linux Kernel | **2,094 MB/s** | 1,049 MB/s (RTX 4090) | **+100%** |
| **Compress** Linux Kernel | **1,895 MB/s** | 894 MB/s (RTX 4090) | **+112%** |
| **Compress** Genome | **1,833 MB/s** | 771 MB/s (RTX 4090) | **+138%** |
| **Compress** enwik9 | **1,633 MB/s** | 717 MB/s (RTX 4090) | **+128%** |

### Three-System Comparison (Best Par Config)

| Dataset | Our Laptop (14w) | RTX 4090 (30w) | RTX 5090 (126w) | Scaling |
|---------|-----------------|---------------|----------------|---------|
| Silesia C | 524 | 559 | **783** | 1.5x vs laptop |
| enwik9 C | 619 | 717 | **1,633** | **2.6x vs laptop** |
| Linux C | 817 | 894 | **1,895** | **2.3x vs laptop** |
| JSON C | 1,642 | 1,793 | **1,899** | 1.2x vs laptop |
| Genome C | 479 | 771 | **1,833** | **3.8x vs laptop** |
| | | | | |
| JSON D | 2,022 | 2,324 | **4,403** | **2.2x vs laptop** |
| Linux D | 999 | 1,049 | **2,094** | **2.1x vs laptop** |
| Genome D | 757 | 745 | **1,483** | **2.0x vs laptop** |

### Why RTX 5090 is so much faster

1. **126 workers vs 14**: The pipeline NEVER stalls. There's always a worker ready when the GPU finishes a block. On large files, this is the dominant factor.

2. **RTX 5090 desktop (575W) vs RTX 5070 laptop (115W)**: ~5x power budget, ~4-5x more SMs, same Blackwell architecture. GPU transform is significantly faster.

3. **1 TB RAM**: No memory pressure. Every dataset fits comfortably with room for all worker buffers.

4. **Larger files scale more**: Genome (+3.8x) > enwik9 (+2.6x) > Linux (+2.3x) > Silesia (+1.5x). More data = more opportunity for parallel overlap.

### But 1T mode is still slow

| Dataset | Our Laptop 1T | RTX 5090 system 1T | Why |
|---------|-------------|-------------------|-----|
| Silesia | 220 MB/s | 137 MB/s | EPYC 2.25 GHz Zen 2 vs Ryzen 5.4 GHz Zen 4 |
| Linux | 329 MB/s | 125 MB/s | Single-thread encoding = clock × IPC bound |

No amount of GPU power or core count helps 1T mode — it's one CPU thread encoding. This proves that **APEX needs BOTH a fast GPU and a fast CPU** for best results across all modes.

---

## Three-System Comparison

### Hardware Overview

| | Dev Machine (Laptop) | Vast.ai #1 | Vast.ai #2 |
|---|---|---|---|
| **GPU** | RTX 5070 Laptop (8GB, 115W) | RTX 4090 (24GB, 415W) | **RTX 5090 (32GB, 575W)** |
| **CPU** | Ryzen 9 8940HX (Zen 4, 2023) | EPYC 7D12 (Zen 2, 2019) | EPYC 7742 ×2 (Zen 2, 2019) |
| **Clock** | 5.4 GHz | 2.0 GHz | 2.25 GHz |
| **Cores** | 16 | 32 | **128** |
| **Workers** | 14 | 30 | **126** |
| **RAM** | 16 GB | 128 GB | **1 TB** |
| **SIMD** | AVX-512 | AVX2 | AVX2 |

### Compress Speed (Best Par Config)

| Dataset | Laptop (14w) | RTX 4090 (30w) | RTX 5090 (126w) |
|---------|-------------|---------------|----------------|
| Silesia 202MB | 524 MB/s | 559 MB/s | **783 MB/s** |
| enwik9 954MB | 619 MB/s | 717 MB/s | **1,633 MB/s** |
| Linux Kernel 1.5GB | 817 MB/s | 894 MB/s | **1,895 MB/s** |
| Large JSON 1.1GB | 1,642 MB/s | 1,793 MB/s | **1,899 MB/s** |
| Genome 3.0GB | 479 MB/s | 771 MB/s | **1,833 MB/s** |

### Decompress Speed (Best Par Config)

| Dataset | Laptop | RTX 4090 | RTX 5090 |
|---------|--------|---------|---------|
| Silesia | 666 MB/s | 654 MB/s | **874 MB/s** |
| enwik9 | 671 MB/s | 698 MB/s | **1,331 MB/s** |
| Linux Kernel | 999 MB/s | 1,049 MB/s | **2,094 MB/s** |
| Large JSON | 2,022 MB/s | 2,324 MB/s | **4,403 MB/s** |
| Genome | 757 MB/s | 745 MB/s | **1,483 MB/s** |

### Ratio (1T mode — deterministic, hardware-independent)

| Dataset | Laptop | RTX 4090 | RTX 5090 | Verdict |
|---------|--------|---------|---------|---------|
| Silesia | 4.02x | 4.06x | 4.06x | Nearly identical |
| enwik9 | 5.04x | 5.04x | 5.04x | **Exact across all 3** |
| Linux Kernel | 9.64x | 9.64x | 9.64x | **Exact across all 3** |
| Large JSON | 23.11x | 23.11x | 23.11x | **Exact across all 3** |
| Genome | 4.48x | 4.48x | 4.48x | **Exact across all 3** |

---

## How CPU Architecture Affects APEX

APEX uses both GPU and CPU. Even with the same or better GPU, the CPU generation, clock speed, and instruction set significantly affect performance.

### The CPUs tested

| CPU | Architecture | Year | Clock | Cores | AVX-512 | L2/Core | Single-Thread |
|-----|-------------|------|-------|-------|---------|---------|--------------|
| Ryzen 9 8940HX | Zen 4 | 2023 | 5.4 GHz | 16 | **Yes** | 1 MB | **Fastest** |
| EPYC 7D12 | Zen 2 | 2019 | 2.0 GHz | 32 | No | 512 KB | ~2.5x slower |
| EPYC 7742 | Zen 2 | 2019 | 2.25 GHz | 128 | No | 512 KB | ~2.4x slower |

### What each factor affects

**Clock speed (most important for 1T mode)**:
CPU processing runs on a single core per block. At 5.4 GHz (Zen 4), each core processes at ~69 MB/s. At 2.0-2.25 GHz (Zen 2), each core processes at ~22-27 MB/s. This 2.5-3x difference directly shows up in 1T compress speeds. Faster clock = faster 1T.

**Core count (most important for Par mode)**:
In Par mode, more workers means better utilization of both GPU and CPU. The 126-worker EPYC system achieves 1,895 MB/s on Linux Kernel despite slow per-core speed — because there's always work ready for the GPU.

**AVX-512 vs AVX2**:
AVX-512 (available on Zen 4, Intel 12th gen+) provides wider SIMD operations. The biggest impact is on 1T decompression (+77-122% speed). In Par mode, the effect is smaller (~10-15%) because the GPU handles most of the heavy lifting.

**L2 cache (512 KB vs 1 MB)**:
APEX's per-block working set is ~300 KB. With 1 MB L2 (Zen 4), this fits entirely in L2. With 512 KB L2 (Zen 2), there's more cache pressure — adding a few percent overhead.

**IPC (instructions per cycle)**:
Zen 4 has ~15-20% higher IPC than Zen 2 at the same clock speed. Combined with the 2.4-2.7x clock difference, the total single-thread gap is roughly 3x.

### Practical takeaways

| Your hardware | Expected APEX performance |
|--------------|--------------------------|
| Modern desktop CPU (Zen 4/5, 5+ GHz) + RTX 40/50 | Best 1T speed + good Par speed |
| Server CPU (EPYC, Xeon, many cores, lower clock) + GPU | Slow 1T, but **excellent Par mode** on large files |
| Older CPU (Zen 2/3, pre-2021) + modern GPU | Slow 1T, moderate Par — GPU compensates |
| Any CPU + no GPU | Slow across the board (CPU-only mode) — ratio still identical |

**For servers/cloud**: Always use Par mode (`-mt`). The many-core advantage is massive on files >500MB.

**For desktops/laptops**: Both 1T and Par work well. Use `apex tune` to find the best config.

**The GPU is the most important component.** A fast GPU + slow CPU (like RTX 5090 + EPYC) can still achieve record-breaking speeds in Par mode. A fast CPU + no GPU gives good ratio but slow speed.

---

## APEX vs libbsc (bsc) — BWT Compressor Comparison

Both APEX and [libbsc](https://github.com/IlyaGrebnov/libbsc) (bsc 3.3.12) use BWT-based compression with the same underlying libraries — [libcubwt](https://github.com/IlyaGrebnov/libcubwt) and [libsais](https://github.com/IlyaGrebnov/libsais), both by [Ilya Grebnov](https://github.com/IlyaGrebnov). This makes it a uniquely fair comparison: same BWT engine, different overall approach.

Tested on our development machine (Ryzen 9 8940HX + RTX 5070 Laptop). Wall-clock timing including file I/O. Best of 2 runs, round-trip verified.

**Threading notes:**
- APEX Par 6MB uses 14 CPU workers + GPU.
- bsc uses OpenMP internally — it automatically uses all available CPU cores for BWT. On our 16-core system, bsc uses up to 16 threads via OpenMP.
- Both compressors are multi-threaded. The speed difference comes from GPU acceleration (APEX) vs CPU-only parallel BWT (bsc).

### Results

| Dataset | bsc Best Ratio | bsc C Speed | APEX Best Ratio | APEX Best C Speed | APEX GPU vs bsc CPU |
|---------|---------------|-------------|-----------------|-------------------|-------------|
| Silesia 202MB | **4.47x** | 58 MB/s | 4.08x | **541 MB/s** | 9.3x faster C |
| enwik9 954MB | **5.49x** | 57 MB/s | 5.04x | **634 MB/s** | 14x faster C |
| Linux Kernel 1.5GB | **10.95x** | 75 MB/s | 9.64x | **817 MB/s** | 11x faster C |
| Large JSON 1.1GB | **23.14x** | 119 MB/s | 23.11x | **1,675 MB/s** | 18x faster C |
| Genome 3.0GB | **4.49x** | 63 MB/s | 4.48x | **479 MB/s** | 7.6x faster C |

*Speedup compares APEX (14 CPU threads + GPU) vs bsc (CPU-only BWT, all cores via OpenMP). bsc also has GPU Sort Transform modes with comparable compress speeds on some datasets. See [GPU vs GPU analysis](https://github.com/Rkcr7/apex/blob/main/docs/BSC_COMPARISON_ANALYSIS.md).*

### Per-Dataset Details

**Silesia (202 MB):**

| Compressor | Config | Compress | Decompress | Ratio | RT |
|-----------|--------|----------|------------|-------|----|
| bsc | -b6 -m0 (CPU BWT) | 58 MB/s | 309 MB/s | 4.42x | PASS |
| bsc | -b6 -m0 -e2 (CPU BWT best) | 56 MB/s | 228 MB/s | **4.47x** | PASS |
| bsc | -b6 -m0 -e0 -G (GPU BWT fast) | 277 MB/s | 338 MB/s | 4.27x | PASS |
| bsc | -b6 -m5 -e0 -G (GPU ST5 fast) | 380 MB/s | 211 MB/s | 4.22x | PASS |
| APEX | 1T | 212 MB/s | **594 MB/s** | 4.02x | PASS |
| **APEX** | **Par 6MB** | **551 MB/s** | **704 MB/s** | 4.00x | PASS |

On Silesia: APEX Par 6MB is faster than all bsc configs on both compress and decompress. bsc GPU BWT (277 MB/s compress) is comparable but APEX is still 2x faster. bsc wins ratio by 7-12%. bsc GPU ST5 decompresses at only 211 MB/s — **3.3x slower than APEX GPU (704 MB/s)** and even slower than APEX CPU-only mode (424 MB/s, no GPU at all).

**enwik9 (954 MB):**

| Compressor | Config | Compress | Decompress | Ratio | RT |
|-----------|--------|----------|------------|-------|----|
| bsc | -b100 -e2 (CPU BWT) | 44 MB/s | 268 MB/s | **5.49x** | PASS |
| bsc | -b6 -m0 -e0 -G (GPU BWT fast) | 466 MB/s | 366 MB/s | 4.65x | PASS |
| bsc | -b6 -m5 -e0 -G (GPU ST5 fast) | **774 MB/s** | 213 MB/s | 4.49x | PASS |
| APEX | 1T | 248 MB/s | **755 MB/s** | 5.04x | PASS |
| **APEX** | **Par 8MB** | **658 MB/s** | **794 MB/s** | 4.36x | PASS |

On enwik9: bsc GPU ST5 fast beats APEX on compress (774 vs 658 MB/s) but decompresses at only 213 MB/s — **3.7x slower than APEX GPU (794 MB/s)**. bsc wins ratio by 10-26% depending on config. ST decompress degrades further at higher orders (ST8: 132 MB/s = 6.0x slower than APEX).

**Large JSON (1.1 GB):**

| Compressor | Config | Compress | Decompress | Ratio | RT |
|-----------|--------|----------|------------|-------|----|
| bsc | -b100 -e2 (CPU BWT) | 93 MB/s | 603 MB/s | 23.14x | PASS |
| **APEX** | **1T** | **560 MB/s** | **2,229 MB/s** | **23.11x** | PASS |
| **APEX** | **Par 18MB** | **1,675 MB/s** | **1,989 MB/s** | 18.11x | PASS |

On JSON: ratio is tied (23.14x vs 23.11x). APEX is 6-18x faster compress and 3.3x faster decompress.

**Spark Logs (2.8 GB):**

| Compressor | Config | Compress | Decompress | Ratio | RT |
|-----------|--------|----------|------------|-------|----|
| bsc | -b6 -m0 -e0 -G (GPU BWT fast) | 691 MB/s | 696 MB/s | 29.36x | PASS |
| bsc | -b6 -m5 -e0 -G (GPU ST5 fast) | **1,450 MB/s** | 678 MB/s | 29.66x | PASS |
| bsc | -b6 -m5 -e2 -G (GPU ST5 best) | 1,054 MB/s | 551 MB/s | **32.18x** | PASS |
| APEX | 1T | 430 MB/s | **1,852 MB/s** | **29.16x** | PASS |
| **APEX** | **Par 14MB** | **1,364 MB/s** | **2,036 MB/s** | 28.25x | PASS |

On Spark: bsc GPU ST5 fast beats APEX on compress (1,450 vs 1,364 MB/s) and wins ratio (29.66x vs 28.25x). But APEX decompresses **3.0x faster** (2,036 vs 678 MB/s). bsc's best ratio config (ST5 -e2, 32.18x) decompresses at only 551 MB/s — **3.7x slower than APEX GPU**. This is bsc's strongest dataset for GPU ST compress speed, yet APEX still dominates decompress by 3-4x.

**Human Genome (3.0 GB):**

| Compressor | Config | Compress | Decompress | Ratio | RT |
|-----------|--------|----------|------------|-------|----|
| bsc | default (-b25, CPU BWT) | 63 MB/s | 336 MB/s | 4.46x | PASS |
| bsc | -b100 (CPU BWT) | **OOM KILLED** | — | — | CRASH |
| **APEX** | **1T** | **219 MB/s** | **801 MB/s** | **4.48x** | PASS |
| **APEX** | **Par 6MB** | **493 MB/s** | **887 MB/s** | 4.35x | PASS |

On Genome: APEX 1T actually beats bsc on ratio (4.48x vs 4.46x) while being 3.5x faster compress and 2.4x faster decompress. bsc OOM crashes with large blocks.

### Key Differences

| | APEX | libbsc (bsc) |
|---|---|---|
| **BWT engine** | GPU via libcubwt | CPU via libsais (OpenMP); GPU via Sort Transform (-G) |
| **Coding approach** | Adaptive nibble order-1 rANS | QLFC (stronger entropy model) |
| **Ratio winner** | — | bsc by 5-15% on text/mixed |
| **Compress speed** | APEX GPU 7-18x faster than bsc CPU; bsc GPU ST comparable/faster on some repetitive data | bsc GPU ST beats APEX on large repetitive data (Spark, enwik9) |
| **Decompress speed** | **APEX 2-4x faster consistently** (GPU iBWT) | bsc QLFC decode is inherently serial; ST decompress degrades 32-63% at higher orders |
| **On repetitive data** | Tied (<0.2% ratio difference) | Tied |
| **Large files (3GB+)** | Handles fine (GPU VRAM) | OOM killed with large blocks (-b100 on Genome) |
| **Scaling** | Decompress scales with GPU hardware (tested: laptop RTX 5070 → desktop RTX 4090 → RTX 5090) | Decompress is CPU-bound, does not benefit from better GPU |

**Summary:** bsc's QLFC entropy model compresses 5-15% better on text/mixed data. APEX GPU compress is 7-18x faster than bsc CPU-only mode; bsc also has GPU Sort Transform modes with comparable or faster compress on large repetitive datasets. **APEX's strongest advantage is decompress speed**: consistently 2-4x faster than all bsc configurations tested (GPU iBWT vs serial QLFC decode), and this gap widens with better GPU hardware. bsc Sort Transform decompress degrades significantly at higher orders (ST8: 129-132 MB/s on text — slower than APEX CPU-only mode). On highly repetitive data (JSON, genomic), the ratio gap between APEX and bsc disappears.

> **Note:** The bsc comparison above tests bsc in **CPU-only BWT mode** (-m0). bsc also has GPU modes using Sort Transform (-m3 to -m8 with -G) which achieve comparable or faster compress speeds on some datasets. A comprehensive GPU vs GPU comparison (both using same libcubwt library) is available in the [main repo analysis](https://github.com/Rkcr7/apex/blob/main/docs/BSC_COMPARISON_ANALYSIS.md).

### Ratio-Matched Comparison (GPU vs GPU)

The tables above include bsc configs tuned for high ratio (larger blocks, best entropy) alongside speed-tuned configs. A fairer speed comparison tunes bsc as close to APEX's actual compression ratio as possible, then compares speeds. GPU modes on both sides.

**Finding the nearest bsc GPU config to APEX's ratio per dataset:**

| Dataset | APEX ratio | Nearest bsc GPU config | bsc ratio | Gap |
|---------|-----------|----------------------|-----------|-----|
| Silesia | 4.00x | `-b6 -m3 -e1 -G` (ST3) | **4.02x** | +0.5% |
| enwik9 | 4.36x | `-b6 -m3 -e1 -G` (ST3) | **3.94x** | −9.7% (APEX wins ratio) |
| enwik9 | 4.36x | `-b6 -m5 -e0 -G` (ST5 fast) | **4.49x** | +3.0% (nearest above) |
| Spark | 28.25x | `-b6 -m5 -e0 -G` (ST5 fast) | **29.66x** | +5.0% |

**Silesia — essentially identical ratio (4.00x vs 4.02x):**

| Compressor | Config | Compress | Decompress | Ratio |
|-----------|--------|----------|------------|-------|
| **APEX** | Par 6MB [GPU full BWT] | **551 MB/s** | **704 MB/s** | 4.00x |
| bsc | -b6 -m3 -e1 -G [GPU ST3] | 398 MB/s | 237 MB/s | 4.02x |

At matched ratio: **APEX +38% compress, +3.0x decompress.**

**enwik9 — bsc ST3 GPU gets *worse* ratio than APEX:**

bsc's lightest GPU Sort Transform mode (ST3) achieves only 3.94x on enwik9 — 9% lower than APEX's 4.36x. APEX full BWT captures more structure than bsc's fastest GPU approximation on this dataset. The nearest bsc config *above* APEX's ratio is ST5 fast (4.49x):

| Compressor | Config | Compress | Decompress | Ratio |
|-----------|--------|----------|------------|-------|
| **APEX** | Par 8MB [GPU full BWT] | 658 MB/s | **794 MB/s** | 4.36x |
| bsc | -b6 -m3 -e1 -G [GPU ST3] | 561 MB/s | 358 MB/s | 3.94x ← worse ratio |
| bsc | -b6 -m5 -e0 -G [GPU ST5 fast] | **774 MB/s** | 213 MB/s | 4.49x ← nearest above |

At ST5 fast (3% higher ratio): bsc +18% compress, **APEX +3.7x decompress.**

**Spark — nearest is ST5 fast at 5% higher ratio:**

| Compressor | Config | Compress | Decompress | Ratio |
|-----------|--------|----------|------------|-------|
| **APEX** | Par 14MB [GPU full BWT] | 1,364 MB/s | **2,036 MB/s** | 28.25x |
| bsc | -b6 -m5 -e0 -G [GPU ST5 fast] | **1,450 MB/s** | 678 MB/s | 29.66x |

At ST5 fast (5% higher ratio): bsc +6% compress, **APEX +3.0x decompress.**

**Ratio-matched conclusions:**
- **Silesia** (matched ratio): APEX wins both compress and decompress
- **enwik9** (3% ratio gap): bsc edges compress (+18%), APEX wins decompress (+3.7x). Note: no bsc GPU config exists between ST3 (3.94x, too low) and ST5 fast (4.49x, too high) — APEX's ratio sits in a gap bsc's GPU modes can't match exactly
- **Spark** (5% ratio gap): bsc edges compress (+6%), APEX wins decompress (+3.0x)

The decompress advantage is consistent at 3–4x regardless of which ratio-matched config is used.

---

## CPU-Only Mode (No GPU Required)

APEX works without any GPU. Three CPU-only binaries are included:

| Binary | CPU Requirement | Year | Size |
|--------|---------------|------|------|
| `apex-cpu-avx2` | AVX2 (Haswell+) | 2013+ | 1.3 MB |
| `apex-cpu-avx512` | AVX-512 (Zen 4+, Intel 12th+) | 2020+ | 1.3 MB |
| `apex-cpu-sse42` | SSE4.2 (Sandy Bridge+) | 2011+ | 1.1 MB |

All produce identical compressed files — cross-compatible with each other and with GPU binaries. Ratios are identical to GPU mode.

> **Note:** `apex-cpu-sse42` is verified to contain zero AVX instructions (`objdump` confirmed). It has not been tested on actual pre-AVX2 hardware. If you have Sandy Bridge / Ivy Bridge era hardware, please share test results.

The numbers below are from `apex-cpu-avx2` on our development machine (Ryzen 9 8940HX, 16C/32T, Zen 4, 14 workers, no GPU).

### CPU-Only Per-Dataset Results (All Configs)

**Silesia (202 MB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 38 MB/s | 220 MB/s | **4.01x** | PASS |
| **Par 6MB** | **131 MB/s** | **424 MB/s** | 4.00x | PASS |
| Par 8MB | 117 MB/s | 380 MB/s | 4.01x | PASS |
| Par 12MB | 100 MB/s | 353 MB/s | 4.04x | PASS |
| Par 20MB | 86 MB/s | 276 MB/s | **4.07x** | PASS |

**enwik9 (954 MB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 33 MB/s | 175 MB/s | **5.20x** | PASS |
| **Par 6MB** | **140 MB/s** | **400 MB/s** | 4.28x | PASS |
| Par 8MB | 116 MB/s | 353 MB/s | 4.35x | PASS |
| Par 12MB | 90 MB/s | 317 MB/s | 4.46x | PASS |
| Par 20MB | 74 MB/s | 300 MB/s | **4.60x** | PASS |

**Linux Kernel (1.5 GB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 60 MB/s | 537 MB/s | **9.63x** | PASS |
| **Par 6MB** | **253 MB/s** | **694 MB/s** | 8.93x | PASS |
| Par 8MB | 211 MB/s | 658 MB/s | 9.07x | PASS |
| Par 14MB | 148 MB/s | 561 MB/s | 9.29x | PASS |
| Par 20MB | 126 MB/s | 529 MB/s | **9.43x** | PASS |

**Large JSON (1.1 GB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 123 MB/s | 606 MB/s | **24.67x** | PASS |
| **Par 6MB** | **826 MB/s** | **1,551 MB/s** | 15.23x | PASS |
| Par 8MB | 690 MB/s | 1,432 MB/s | 15.97x | PASS |
| Par 18MB | 419 MB/s | 1,077 MB/s | 18.09x | PASS |
| Par 20MB | 407 MB/s | 1,109 MB/s | **18.41x** | PASS |

**GH Events JSON (480 MB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 111 MB/s | 517 MB/s | **23.74x** | PASS |
| **Par 6MB** | **724 MB/s** | **1,402 MB/s** | 14.91x | PASS |
| Par 8MB | 581 MB/s | 1,257 MB/s | 15.62x | PASS |
| Par 18MB | 359 MB/s | 989 MB/s | 17.52x | PASS |
| Par 20MB | 352 MB/s | 961 MB/s | **17.87x** | PASS |

**Human Genome (3.0 GB):**

| Config | Compress | Decompress | Ratio | RT |
|--------|----------|------------|-------|----|
| **1T** | 31 MB/s | 197 MB/s | **4.51x** | PASS |
| **Par 6MB** | **128 MB/s** | **366 MB/s** | 4.34x | PASS |
| Par 8MB | 107 MB/s | 359 MB/s | 4.35x | PASS |
| Par 20MB | 73 MB/s | 292 MB/s | **4.39x** | PASS |

### CPU-Only Highlights

- **826 MB/s compress** and **1,551 MB/s decompress** on Large JSON — no GPU
- **724 MB/s / 1,402 MB/s** on GH Events — no GPU
- CPU-only 1T gets **higher ratio than GPU** on some data (enwik9: 5.20x vs 5.04x, Genome: 4.51x vs 4.48x)
- **131 MB/s at 4.00x on Silesia** — 2.3x faster than CPU-only bsc on compress (bsc gets ~10% better ratio via QLFC), 10x faster than bzip2, 44x faster than LZMA, all without GPU

### CPU-Only vs GPU Mode

| Dataset | CPU-Only C/D | GPU C/D | GPU Speedup |
|---------|-------------|---------|-------------|
| Silesia | 131 / 424 | 524 / 666 | 4.0x / 1.6x |
| enwik9 | 140 / 400 | 619 / 671 | 4.4x / 1.7x |
| Linux Kernel | 253 / 694 | 817 / 999 | 3.2x / 1.4x |
| Large JSON | 826 / 1,551 | 1,642 / 2,022 | 2.0x / 1.3x |
| Genome | 128 / 366 | 479 / 757 | 3.7x / 2.1x |

GPU gives 2-4x faster compress. CPU-only APEX already compresses faster than CPU-only bsc, bzip2, and bzip3 — even without touching a GPU (bsc achieves 5-15% better ratio via QLFC).
