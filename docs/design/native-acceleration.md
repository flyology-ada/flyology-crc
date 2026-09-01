# Native acceleration design

Status: implemented and performance-qualified.

## Decision

Flyology CRC keeps its public API and standalone dependency graph unchanged.
Hardware acceleration is implemented by private Ada child units selected by the
GPR project.  The scalar byte-table implementation remains the correctness
fallback on unsupported architectures, operating systems, or CPUs.

The first accelerated backend targets AArch64 PMULL.  The subsequent x86-64
backend targets PCLMULQDQ and AVX-512/VPCLMULQDQ tiers.  Native
instructions are expressed through GNAT machine vectors and inline assembly;
the shipped library does not contain a C or Rust bridge.

The local `flyology_simd` checkout is implementation evidence, not a dependency.
It demonstrates the machine-vector representation, register constraints,
unaligned loads, byte reversal, source selection, and fail-closed backend
structure.  Carryless multiplication remains CRC-private until the CRC library
is complete and performance-qualified.  Only then may generally useful pieces
be proposed as focused `flyology_simd` changes.

## Arithmetic identity

The folding algorithm follows Intel's generic-polynomial PCLMULQDQ method,
extended to a private 23-key fold-by-eight representation. Folding keys are
determined only by CRC width, polynomial, and reflection. The catalogue
generator emits the keys for predefined algorithms, while caller-created
parameters generate the same keys once without allocation. Detailed
provenance is recorded in `THIRD_PARTY_NOTICES.md`.

The private accelerated path uses this fold-by-eight structure:

- eight 128-bit accumulators consume 128-byte blocks;
- lanes are folded at 112, 96, 80, 64, 48, 32, and 16-byte distances;
- width-specific reduction returns the raw algorithm state;
- CRC-16 uses a scaled 32-bit representation;
- reflected and forward data retain the kernel's register byte order.

Dispatch thresholds, folding distances, key count, vector representation, and
feature facts are private implementation data.  They do not become visible
constants or compatibility promises.

## Dispatch and feature detection

Architecture selection fails closed to scalar.  A feature-specific source file
is the only file compiled with instruction-enabling switches; common dispatch
code stays at the baseline target.  Runtime feature detection completes before
the first native instruction executes.

On macOS AArch64, the detector imports `sysctlbyname` directly and reads the
stable `hw.optional.arm.caps` bit buffer.  It requires both AdvSIMD and PMULL.
On Linux AArch64 with the supported libc boundary, the detector imports
`getauxval`, reads `AT_HWCAP`, and requires `HWCAP_ASIMD` and `HWCAP_PMULL`.
Query failure, a short result, an absent bit, an unsupported libc, or an
unsupported operating system selects scalar.

On x86-64, the detector requires the relevant CPUID feature bits.  AVX-512
selection additionally establishes operating-system register-state support
through XGETBV before entering an AVX-512 leaf.

## Native boundary

The AArch64 leaf uses a 16-byte-aligned, 16-byte GCC `vector_type`.  Its private
operations are unaligned load, XOR, full 16-byte reversal, and the four 64-bit
lane combinations of polynomial carryless multiplication.  The leaf alone is
compiled with `-O3 -march=armv8-a+aes`, the narrow AArch64 extension enabling
AdvSIMD PMULL.

Compile-time checks establish vector size/alignment and C ABI widths.  Primitive
tests compare every carryless-multiply lane form against an independent scalar
polynomial multiplier.  Code-generation checks require PMULL instructions in
the selected leaf and no native instruction in the scalar source set.

## Correctness and performance gates

Every accelerated tier must pass forced-tier differential tests against both
the byte-table implementation and the pinned Rust oracle.  Boundary coverage
includes every length through 256 bytes, larger fold boundaries, all predefined
algorithms, custom reflected and forward parameters, streaming splits, and
guarded tails before a tier is enabled for general inputs.

Performance uses the approved `flyology_bench` paired harness.  The AArch64
campaigns run on macOS and Linux ARM64 under recorded host and power-profile
state.  The x86-64 campaign runs on Linux x86-64.  A tier is complete only
when every predefined algorithm at 1 KiB and 1 MiB is statistically the same
as or faster than the pinned Rust oracle under the contract in
`docs/design/initial-contract.md`.

## Staged implementation

1. Generate and differentially verify all folding keys.
2. Establish fail-closed AArch64 detection and independently tested PMULL
   primitives.
3. Enable generic fold-by-eight and reduction for safe whole-block inputs.
4. Add bounded-tail handling and forced-tier differential coverage.
5. Tune the generic AArch64 path, then add ISCSI and ISO-HDLC
   CRC/PMULL fusion only if required for parity.
6. Implement and test x86-64 PCLMULQDQ, AVX-512, VPCLMULQDQ, and CRC32C fusion
   tiers.
7. Complete all three platform performance campaigns and final review.
8. After CRC is complete, assess reusable primitives for `flyology_simd` PRs.
