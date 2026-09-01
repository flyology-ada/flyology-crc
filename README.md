# Flyology CRC

Flyology CRC is a standalone, allocation-free Ada library for CRC-16, CRC-32,
and CRC-64. It implements 50 named parameter sets from Greg Cook's
[RevEng CRC Catalogue](https://reveng.sourceforge.io/crc-catalogue/all.htm):
31 CRC-16 algorithms, 12 CRC-32 algorithms, and 7 CRC-64 algorithms. The API
also supports caller-defined parameters, incremental calculation, and checksum
combination, with no runtime dependency on the general `flyology` crate.

```ada
with Flyology_CRC.Width_32;

Checksum :=
  Flyology_CRC.Width_32.Compute
    (Flyology_CRC.Width_32.ISCSI, Data);
```

## Algorithms and implementation

The implementation combines a portable width-generic table core with carry-
less-multiplication folding. Runtime dispatch selects AArch64 CRC, PMULL, and
EOR3 paths or x86-64 SSE4.2, PCLMULQDQ, AVX-512, and VPCLMULQDQ paths when the
host supports them, while retaining the scalar table fallback.

The parameter catalogue is maintained by Greg Cook and links to the standards
and literature behind each named CRC. The generic folding design builds on
Intel's PCLMULQDQ CRC paper; CRC-32 instruction-fusion work builds on Peter
Cawley's `fast-crc32` and Dougall Johnson's Apple M1 analysis; and checksum
combination builds on Mark Adler's generalized GF(2) matrix method. Exact
source links, adaptation notes, copyrights, and licenses are in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Building and testing

Build the library with Alire:

```sh
alr build
```

The public API uses leading GNATdoc comments. Install GNATdoc with Alire, then
generate warning-checked HTML documentation with the maintained script:

```sh
alr install --prefix=.alire/gnatdoc gnatdoc_bin=26.0.0
tools/generate_docs.sh
```

The generated site is written to `docs/gnatdoc/html`. The script documents
only the four caller-facing package specifications; its staging step removes
private implementation parts so GNATdoc warnings measure public API coverage.

The predefined catalogue is generated from
`catalogue/crc-catalogue.toml`. Verify that committed generated sources are
current with:

```sh
python3 tools/generate_catalogue.py --check
```

The nested `tests` crate contains exhaustive catalogue, streaming, reset,
combine, and custom-parameter tests. Its second executable links a locked Rust
static library and compares all algorithms directly with the pinned oracle over
boundary-sized deterministic inputs.

GitHub Actions builds and runs every declared test executable on Linux x86-64,
the scalar fallback, Linux ARM64, and macOS ARM64. It also verifies generated
catalogue sources and requires warning-free public GNATdocs.

## Benchmarked performance

Flyology CRC was compared with pinned `crc-fast` 1.10.0 using paired,
order-balanced `flyology_bench` measurements. Each platform covered all 50
algorithms at 1 KiB and 1 MiB, with 1,000 paired samples per cell. A result is
classified as faster only when its paired 95% confidence interval excludes
parity.

| Platform | Cells | Flyology faster | CI parity | `crc-fast` faster |
|---|---:|---:|---:|---:|
| macOS ARM64 | 100 | 100 | 0 | 0 |
| Linux ARM64 | 100 | 98 | 2 | 0 |
| Linux x86-64 | 100 | 83 | 17 | 0 |
| **Total** | **300** | **281** | **19** | **0** |

These figures describe the reviewed paired measurements on the recorded hosts
and builds; they are comparative results, not portable absolute timings.

The nested `benchmarks` crate uses `flyology_bench` for paired, balanced
comparisons. The Rust oracle must be built in release mode before building the
Rust-linked tests or benchmarks:

```sh
cd oracle/rust
cargo rustc --release --locked -- --print native-static-libs
```

Pass the printed native libraries through
`FLYOLOGY_CRC_ORACLE_SYSTEM_LIBRARIES` when building the Ada executable. Run
the repository power-profile detector immediately before collecting timings,
and give the comparison executable a path for its raw CSV samples.

The initial API and benchmark contract, including the exact oracle identity,
are recorded in `docs/design/initial-contract.md`.
