# Changelog

All notable changes to Flyology CRC will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-09-01

### Added

- Added warning-as-error release builds to every CI platform. ([commit e1ccf48])
- Added an exact-SHA x86-64 qualification workflow that compares warning
  behavior and complete VPCLMUL object code between releases.
  ([commit 76c3b8b], [commit 0468dbb], [commit 6db7e05],
  [commit a5cb23a])

### Fixed

- Marked the output-only x86-64 CRC-32C VPCLMUL scalar-tail assembly block as
  volatile, allowing warning-strict GNAT builds without changing the generated
  object code or CRC hot path. ([commit fddc658], [commit 4d1e0b4])

## [0.1.0] - 2026-09-01

### Added

- Added an allocation-free Ada API for all 50 named CRC-16, CRC-32, and CRC-64
  parameter sets in the RevEng CRC Catalogue, plus caller-defined parameters,
  incremental calculation, reset, and checksum combination.
  ([commit 9bfb933])
- Added runtime-selected AArch64 CRC, PMULL, and EOR3 implementations and
  x86-64 SSE4.2, PCLMULQDQ, AVX-512, and VPCLMULQDQ implementations, with a
  portable scalar fallback and no dependency on the general `flyology` crate.
  ([commit 9bfb933])
- Added exhaustive catalogue and boundary tests, a locked Rust correctness
  oracle, and paired `flyology_bench` comparisons covering every algorithm on
  macOS ARM64, Linux ARM64, and Linux x86-64. ([commit 9bfb933],
  [commit 38f507f])
- Added generated catalogue verification, warning-checked GNATdoc coverage,
  third-party provenance, design documentation, and multi-platform CI.
  ([commit 9bfb933], [commit d517a58], [commit efe12a7], [commit d5d14e2])

[Unreleased]: https://github.com/flyology-ada/flyology-crc/compare/flyology_crc/v0.1.1...HEAD
[0.1.1]: https://github.com/flyology-ada/flyology-crc/compare/flyology_crc/v0.1.0...flyology_crc/v0.1.1
[0.1.0]: https://github.com/flyology-ada/flyology-crc/commit/672792abaf5edb43716a62d08593d65a97fa68c9
[commit 9bfb933]: https://github.com/flyology-ada/flyology-crc/commit/9bfb93336536b6b069795366e321c87fd02416ef
[commit d517a58]: https://github.com/flyology-ada/flyology-crc/commit/d517a58241db166a8e127342f92a729c5ae9b100
[commit efe12a7]: https://github.com/flyology-ada/flyology-crc/commit/efe12a7f83b20b3b10814b3d3bf61746bd32af58
[commit d5d14e2]: https://github.com/flyology-ada/flyology-crc/commit/d5d14e23a46c689e4d96b9ba3a382ea3381c9877
[commit 38f507f]: https://github.com/flyology-ada/flyology-crc/commit/38f507f58bf216a50751a659f695dd501735ee2c
[commit fddc658]: https://github.com/flyology-ada/flyology-crc/commit/fddc6584d2b61a3ec0a470075fed1c96af9694c2
[commit e1ccf48]: https://github.com/flyology-ada/flyology-crc/commit/e1ccf481921bdc24086ce491cf2dc91beb416d07
[commit 76c3b8b]: https://github.com/flyology-ada/flyology-crc/commit/76c3b8b858829b9693602b170392a49190f5a6b6
[commit 0468dbb]: https://github.com/flyology-ada/flyology-crc/commit/0468dbbed8fe7a01ee2e42d25e51f082bed6c8f0
[commit 6db7e05]: https://github.com/flyology-ada/flyology-crc/commit/6db7e056eeac11e274b4235e6ea533fb843b0dae
[commit 4d1e0b4]: https://github.com/flyology-ada/flyology-crc/commit/4d1e0b45e5c567b2b42a68335c6f276bca1836a7
[commit a5cb23a]: https://github.com/flyology-ada/flyology-crc/commit/a5cb23a28c2f9d1e5548cf510f5126ca5a453315
