# Flyology CRC

Flyology CRC is an allocation-free Ada library for CRC-16, CRC-32, and CRC-64.
It includes all 50 predefined algorithms supported by the pinned
[`crc-fast` 1.10.0](https://github.com/awesomized/crc-fast-rust/tree/3a853cc7daf2cd47cc4466f198680cabdfb0b5fa)
oracle, caller-defined parameters, incremental calculation, and checksum
combination. The crate has no runtime dependency on the general `flyology`
crate.

```ada
with Flyology_CRC.Width_32;

Checksum :=
  Flyology_CRC.Width_32.Compute
    (Flyology_CRC.Width_32.ISCSI, Data);
```

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

Algorithm provenance and third-party license notices are consolidated in
`THIRD_PARTY_NOTICES.md`.
