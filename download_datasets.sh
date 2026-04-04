#!/bin/bash
# ============================================================================
# APEX Benchmark Dataset Downloader
# Downloads all 14 benchmark datasets used in BENCHMARKS.md
#
# Usage:
#   ./scripts/download_datasets.sh              # Download essential 5 datasets
#   ./scripts/download_datasets.sh --all        # Download all 14 datasets
#   ./scripts/download_datasets.sh --essential   # Download essential 5 (default)
#   ./scripts/download_datasets.sh --list        # List all datasets and status
#   ./scripts/download_datasets.sh --help        # Show help
#
# Essential 5 (~6.6 GB download, ~8.4 GB on disk):
#   1. Silesia Corpus     (202 MB) — universal mixed benchmark
#   2. enwik9             (954 MB) — large text benchmark
#   3. Linux Kernel       (1.5 GB) — source code tarball
#   4. Large JSON         (1.1 GB) — repetitive JSON (2 GB/s decompress!)
#   5. Human Genome       (3.0 GB) — DNA reference genome (BWT showcase)
#
# All 14 (~20 GB download, ~17 GB on disk):
#   Essential 5 + enwik8, GH Events, LLVM Source, Chromium Source,
#   Wiki SQL, WA Electric CSV, Firefox, Taxi Parquet, Pizza&Chili English
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
RW_DIR="$DATA_DIR/realworld"

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

# Counters
DOWNLOADED=0
SKIPPED=0
FAILED=0
TOTAL=0

# ---- Helpers ---------------------------------------------------------------

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
log_skip()  { echo -e "${YELLOW}[SKIP]${NC} $* (already exists)"; }
log_err()   { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# Check if a command exists
need_cmd() {
    if ! command -v "$1" &>/dev/null; then
        log_err "Required command '$1' not found. Install it and retry."
        exit 1
    fi
}

# Download a file with retries and progress
download() {
    local url="$1" dest="$2" retries=3
    for attempt in $(seq 1 $retries); do
        if wget -q --show-progress --tries=2 --timeout=30 -O "$dest" "$url" 2>&1; then
            return 0
        fi
        [ $attempt -lt $retries ] && log_info "  Retry $((attempt+1))/$retries..."
        rm -f "$dest"
    done
    return 1
}

# Download and process a dataset. Skips if target already exists.
# Usage: fetch_dataset <name> <target_path> <size_desc> <download_fn>
fetch_dataset() {
    local name="$1" target="$2" size="$3"
    shift 3
    TOTAL=$((TOTAL + 1))

    if [ -f "$target" ] && [ -s "$target" ]; then
        log_skip "$name ($size) — $target"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    log_info "Downloading $name ($size)..."
    if "$@"; then
        if [ -f "$target" ] && [ -s "$target" ]; then
            local actual_size
            actual_size=$(du -h "$target" | cut -f1)
            log_ok "$name — $actual_size → $target"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            log_err "$name — file missing or empty after download"
            FAILED=$((FAILED + 1))
            return 1
        fi
    else
        log_err "$name — download failed"
        rm -f "$target" 2>/dev/null
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# ---- Dataset download functions --------------------------------------------

dl_silesia() {
    local tmp="$DATA_DIR/silesia.zip"
    download "https://sun.aei.polsl.pl/~sdeor/corpus/silesia.zip" "$tmp" || return 1
    mkdir -p "$DATA_DIR/silesia"
    unzip -qo "$tmp" -d "$DATA_DIR/silesia/"
    (cd "$DATA_DIR" && tar cf silesia.tar silesia/)
    rm -f "$tmp"
}

dl_enwik8() {
    local tmp="$DATA_DIR/enwik8.zip"
    download "https://mattmahoney.net/dc/enwik8.zip" "$tmp" || return 1
    (cd "$DATA_DIR" && unzip -qo enwik8.zip)
    rm -f "$tmp"
}

dl_enwik9() {
    local tmp="$DATA_DIR/enwik9.zip"
    download "https://mattmahoney.net/dc/enwik9.zip" "$tmp" || return 1
    (cd "$DATA_DIR" && unzip -qo enwik9.zip)
    rm -f "$tmp"
}

dl_linux_kernel() {
    local tmp="$RW_DIR/linux-6.12.tar.xz"
    download "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.tar.xz" "$tmp" || return 1
    log_info "  Decompressing xz (this takes a moment)..."
    xz -d "$tmp"
    mv "$RW_DIR/linux-6.12.tar" "$RW_DIR/linux-kernel.tar"
}

dl_gh_events() {
    local tmp="$RW_DIR/gh_events.json.gz"
    download "https://data.gharchive.org/2024-01-01-0.json.gz" "$tmp" || return 1
    gunzip -f "$tmp"
    mv "$RW_DIR/gh_events.json.gz" "$RW_DIR/gh_events.json" 2>/dev/null || true
}

dl_large_json() {
    # Large JSON is built by concatenating multiple hours of GitHub Archive
    local h0="$RW_DIR/_gh_h0.json.gz" h1="$RW_DIR/_gh_h1.json.gz"
    download "https://data.gharchive.org/2024-01-01-0.json.gz" "$h0" || return 1
    download "https://data.gharchive.org/2024-01-01-1.json.gz" "$h1" || return 1
    gunzip -f "$h0" "$h1"
    cat "$RW_DIR/_gh_h0.json" "$RW_DIR/_gh_h1.json" > "$RW_DIR/large_json_1gb.json"
    rm -f "$RW_DIR/_gh_h0.json" "$RW_DIR/_gh_h1.json"
}

dl_llvm_source() {
    local tmp="$RW_DIR/llvm-project.tar.xz"
    # Use the latest release tarball (smaller download than full git clone)
    log_info "  Cloning LLVM (shallow, ~800MB download)..."
    if git clone --depth 1 --single-branch https://github.com/llvm/llvm-project.git "$RW_DIR/_llvm_tmp" 2>&1; then
        log_info "  Creating tar archive..."
        (cd "$RW_DIR" && tar cf llvm-source.tar _llvm_tmp/)
        rm -rf "$RW_DIR/_llvm_tmp"
    else
        rm -rf "$RW_DIR/_llvm_tmp"
        return 1
    fi
}

dl_chromium_source() {
    log_info "  Downloading Chromium source tarball (~1.4GB compressed)..."
    local tmp="$RW_DIR/chromium-source.tar.gz"
    # Use a recent stable tag archive from GitHub mirror
    if download "https://chromium.googlesource.com/chromium/src/+archive/refs/tags/131.0.6778.264.tar.gz" "$tmp"; then
        log_info "  Extracting (4.6GB, takes a moment)..."
        mkdir -p "$RW_DIR/_chromium_tmp"
        tar xzf "$tmp" -C "$RW_DIR/_chromium_tmp/" 2>/dev/null || true
        (cd "$RW_DIR" && tar cf chromium-source.tar _chromium_tmp/)
        rm -rf "$RW_DIR/_chromium_tmp" "$tmp"
    else
        rm -f "$tmp"
        log_err "  Chromium download failed. Manual setup:"
        log_err "    Install depot_tools, run: fetch chromium && tar cf chromium-source.tar src/"
        return 1
    fi
}

dl_wiki_sql() {
    local tmp="$RW_DIR/wiki_sql.sql.gz"
    download "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-page.sql.gz" "$tmp" || return 1
    gunzip -f "$tmp"
}

dl_wa_electric() {
    download "https://data.wa.gov/api/views/f6w7-q2d2/rows.csv?accessType=DOWNLOAD" \
        "$RW_DIR/wa_electric.csv" || return 1
}

dl_firefox() {
    local tmp="$RW_DIR/firefox.tar.bz2"
    download "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" "$tmp" || return 1
    log_info "  Decompressing bzip2..."
    bzip2 -df "$tmp"
    # bzip2 -d removes .bz2 extension, resulting file is firefox.tar
}

dl_taxi_parquet() {
    download "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet" \
        "$RW_DIR/taxi.parquet" || return 1
}

dl_english() {
    local tmp="$RW_DIR/english.gz"
    download "http://pizzachili.dcc.uchile.cl/texts/nlang/english.gz" "$tmp" || return 1
    gunzip -f "$tmp"
}

dl_genome() {
    local tmp="$RW_DIR/grch38.fna.gz"
    download "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" \
        "$tmp" || return 1
    log_info "  Decompressing genome (~3GB)..."
    gunzip -f "$tmp"
    mv "$RW_DIR/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna" "$RW_DIR/grch38.fna" 2>/dev/null || true
}

# ---- Dataset sets ----------------------------------------------------------

download_essential() {
    echo ""
    echo -e "${BOLD}=== APEX Essential Datasets (5 datasets, ~8.4 GB on disk) ===${NC}"
    echo ""

    fetch_dataset "Silesia Corpus"   "$DATA_DIR/silesia.tar"            "202 MB" dl_silesia
    fetch_dataset "enwik9"           "$DATA_DIR/enwik9"                 "954 MB" dl_enwik9
    fetch_dataset "Linux Kernel"     "$RW_DIR/linux-kernel.tar"         "1.5 GB" dl_linux_kernel
    fetch_dataset "Large JSON"       "$RW_DIR/large_json_1gb.json"      "1.1 GB" dl_large_json
    fetch_dataset "Human Genome"     "$RW_DIR/grch38.fna"               "3.0 GB" dl_genome
}

download_all() {
    echo ""
    echo -e "${BOLD}=== APEX Complete Benchmark Suite (14 datasets, ~17 GB on disk) ===${NC}"
    echo ""

    # Essential 5
    fetch_dataset "1. Silesia Corpus"     "$DATA_DIR/silesia.tar"            "202 MB"  dl_silesia
    fetch_dataset "2. enwik8"             "$DATA_DIR/enwik8"                 "96 MB"   dl_enwik8
    fetch_dataset "3. enwik9"             "$DATA_DIR/enwik9"                 "954 MB"  dl_enwik9
    fetch_dataset "4. Linux Kernel"       "$RW_DIR/linux-kernel.tar"         "1.5 GB"  dl_linux_kernel
    fetch_dataset "5. GH Events JSON"     "$RW_DIR/gh_events.json"           "480 MB"  dl_gh_events
    fetch_dataset "6. LLVM Source"        "$RW_DIR/llvm-source.tar"          "2.4 GB"  dl_llvm_source
    fetch_dataset "7. Chromium Source"    "$RW_DIR/chromium-source.tar"      "4.6 GB"  dl_chromium_source
    fetch_dataset "8. Large JSON"         "$RW_DIR/large_json_1gb.json"      "1.1 GB"  dl_large_json
    fetch_dataset "9. Wiki SQL"           "$RW_DIR/wiki_sql.sql"             "101 MB"  dl_wiki_sql
    fetch_dataset "10. WA Electric CSV"   "$RW_DIR/wa_electric.csv"          "65 MB"   dl_wa_electric
    fetch_dataset "11. Firefox"           "$RW_DIR/firefox.tar"              "79 MB"   dl_firefox
    fetch_dataset "12. Taxi Parquet"      "$RW_DIR/taxi.parquet"             "48 MB"   dl_taxi_parquet
    fetch_dataset "13. Pizza&Chili English" "$RW_DIR/english"                "2.1 GB"  dl_english
    fetch_dataset "14. Human Genome"      "$RW_DIR/grch38.fna"               "3.0 GB"  dl_genome
}

list_datasets() {
    echo ""
    echo -e "${BOLD}=== APEX Benchmark Datasets ===${NC}"
    echo ""
    printf "%-4s %-25s %8s  %-40s  %s\n" "#" "Dataset" "Size" "Path" "Status"
    printf "%-4s %-25s %8s  %-40s  %s\n" "---" "-------------------------" "--------" "----------------------------------------" "------"

    check_file() {
        local path="$1"
        if [ -f "$path" ] && [ -s "$path" ]; then
            local sz; sz=$(du -h "$path" | cut -f1)
            echo -e "${GREEN}${sz}${NC}"
        else
            echo -e "${RED}MISSING${NC}"
        fi
    }

    local datasets=(
        "1|Silesia Corpus|202 MB|$DATA_DIR/silesia.tar|*"
        "2|enwik8|96 MB|$DATA_DIR/enwik8|"
        "3|enwik9|954 MB|$DATA_DIR/enwik9|*"
        "4|Linux Kernel|1.5 GB|$RW_DIR/linux-kernel.tar|*"
        "5|GH Events JSON|480 MB|$RW_DIR/gh_events.json|"
        "6|LLVM Source|2.4 GB|$RW_DIR/llvm-source.tar|"
        "7|Chromium Source|4.6 GB|$RW_DIR/chromium-source.tar|"
        "8|Large JSON|1.1 GB|$RW_DIR/large_json_1gb.json|*"
        "9|Wiki SQL|101 MB|$RW_DIR/wiki_sql.sql|"
        "10|WA Electric CSV|65 MB|$RW_DIR/wa_electric.csv|"
        "11|Firefox|79 MB|$RW_DIR/firefox.tar|"
        "12|Taxi Parquet|48 MB|$RW_DIR/taxi.parquet|"
        "13|Pizza&Chili English|2.1 GB|$RW_DIR/english|"
        "14|Human Genome|3.0 GB|$RW_DIR/grch38.fna|*"
    )

    for entry in "${datasets[@]}"; do
        IFS='|' read -r num name size path essential <<< "$entry"
        local status; status=$(check_file "$path")
        local tag=""
        [ -n "$essential" ] && tag=" (essential)"
        printf "%-4s %-25s %8s  %-40s  %b\n" "$num" "$name$tag" "$size" "${path#$PROJECT_DIR/}" "$status"
    done

    echo ""
    echo "  * = included in --essential (5 datasets)"
    echo ""
    echo "  Total on disk: $(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)"
}

show_help() {
    cat <<'HELP'
APEX Benchmark Dataset Downloader

Usage:
  ./scripts/download_datasets.sh [OPTION]

Options:
  --essential, -e   Download 5 key datasets (~8.4 GB):
                      Silesia, enwik9, Linux Kernel, Large JSON, Human Genome
  --all, -a         Download all 14 benchmark datasets (~17 GB)
  --list, -l        Show all datasets and their download status
  --help, -h        Show this help

Default (no args) downloads the essential 5 datasets.

Requirements:
  wget, unzip, xz, gunzip, bzip2, tar, git (for LLVM clone)

Examples:
  ./scripts/download_datasets.sh              # Essential 5
  ./scripts/download_datasets.sh --all        # All 14
  ./scripts/download_datasets.sh --list       # Check status

Datasets are stored in:
  data/                    — Standard benchmarks (Silesia, enwik8/9)
  data/realworld/          — Real-world datasets (kernel, LLVM, genome, etc.)
HELP
}

# ---- Main ------------------------------------------------------------------

main() {
    need_cmd wget
    need_cmd unzip
    need_cmd tar

    mkdir -p "$DATA_DIR" "$RW_DIR"

    local mode="${1:---essential}"

    case "$mode" in
        --all|-a)
            download_all
            ;;
        --essential|-e|"")
            download_essential
            ;;
        --list|-l)
            list_datasets
            return 0
            ;;
        --help|-h)
            show_help
            return 0
            ;;
        *)
            log_err "Unknown option: $mode"
            echo "Run with --help for usage."
            return 1
            ;;
    esac

    # Summary
    echo ""
    echo -e "${BOLD}=== Summary ===${NC}"
    echo "  Downloaded: $DOWNLOADED"
    echo "  Skipped:    $SKIPPED (already present)"
    [ $FAILED -gt 0 ] && echo -e "  ${RED}Failed:     $FAILED${NC}"
    echo "  Total:      $TOTAL datasets"
    echo ""

    if [ $FAILED -gt 0 ]; then
        echo -e "${YELLOW}Some downloads failed. Run again to retry — existing files are skipped.${NC}"
        return 1
    fi

    echo "  Disk usage: $(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)"
    echo ""
    echo "  Run benchmarks:"
    echo "    ./build/release/apex bench data/silesia.tar"
    echo "    ./build/release/apex tune data/enwik9"
    echo ""
}

main "$@"
