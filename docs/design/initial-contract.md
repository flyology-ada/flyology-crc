# Flyology CRC initial contract proposal

Status: approved on 2026-08-31 and implemented by the package specifications in
`src/`.

## Objective and reference identities

Flyology CRC is a standalone Ada library for every predefined CRC-16, CRC-32,
and CRC-64 algorithm supported by the pinned functional and performance oracle,
plus caller-defined parameters using the same Rocksoft-model restriction that
input and output reflection agree.

The initial oracle is `crc-fast` 1.10.0 at upstream commit
`3a853cc7daf2cd47cc4466f198680cabdfb0b5fa`. Correctness comparisons and
performance reports must name this exact source identity. Updating the oracle
is a separately reviewed change.

The predefined catalogue identities follow Greg Cook's
[RevEng Catalogue of Parametrised CRC Algorithms](https://reveng.sourceforge.io/crc-catalogue/all.htm).
Polynomial, initial value, final XOR, check, and residue are externally sourced
data; folding values are mathematically derived implementation data. Neither is
Flyology policy. They remain private generated data with provenance adjacent to
the generator output. No polynomial or folding key becomes a visible Ada
constant.

## Initial scope

Included:

- one-shot CRC-16, CRC-32, and CRC-64 calculation;
- incremental calculation with reset and non-consuming result inspection;
- checksum combination for independently processed byte sequences;
- caller-defined width-specific parameters;
- every predefined algorithm listed below;
- specialized one-shot entry points for CRC-32/ISCSI, CRC-32/ISO-HDLC, and
  CRC-64/NVME;
- a portable scalar implementation and later runtime-selected acceleration.

Deferred, so it can be added without changing the initial contract:

- CRC widths other than 16, 32, and 64;
- file I/O, CLI, and public C ABI helpers;
- public dispatch-target strings or implementation-key inspection;
- mismatched input/output reflection;
- heap-backed caches or caller-visible cache controls.

## Public units

The root is `Flyology_CRC`, not `Flyology.CRC`. The flat root keeps this crate
independent of the general `flyology` crate. The public input representation is
Ada's standard stream-element array, so callers do not need a Flyology byte
container.

```ada
with Ada.Streams;
with Interfaces;

package Flyology_CRC is
   subtype Byte is Ada.Streams.Stream_Element;
   subtype Byte_Array is Ada.Streams.Stream_Element_Array;
   subtype Byte_Count is Interfaces.Unsigned_64;
end Flyology_CRC;
```

`Byte_Count` is used only where a sequence length is supplied independently of
an Ada array, notably checksum combination. Its 64-bit range allows combined
sequences to exceed the bounds of any single Ada array.

### CRC-16

```ada
with Interfaces;

package Flyology_CRC.Width_16 is
   subtype Value is Interfaces.Unsigned_16;

   type Algorithm is
     (ARC,
      CDMA2000,
      CMS,
      DDS_110,
      DECT_R,
      DECT_X,
      DNP,
      EN_13757,
      GENIBUS,
      GSM,
      IBM_3740,
      IBM_SDLC,
      ISO_IEC_14443_3_A,
      KERMIT,
      LJ1200,
      M17,
      MAXIM_DOW,
      MCRF4XX,
      MODBUS,
      NRSC_5,
      OPENSAFETY_A,
      OPENSAFETY_B,
      PROFIBUS,
      RIELLO,
      SPI_FUJITSU,
      T10_DIF,
      TELEDISK,
      TMS37157,
      UMTS,
      USB,
      XMODEM);

   type Parameters is private;

   function Parameters_For (Kind : Algorithm) return Parameters;

   function Create
     (Polynomial    : Value;
      Initial_Value : Value;
      Reflected     : Boolean;
      Final_XOR     : Value) return Parameters;

   function Compute
     (Kind : Algorithm;
      Data : Byte_Array) return Value;

   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   type Context is private;

   function Start (Kind : Algorithm) return Context;
   function Start (Configuration : Parameters) return Context;

   procedure Reset (Object : in out Context);
   procedure Update (Object : in out Context; Data : Byte_Array);
   function Result (Object : Context) return Value;

   function Combine
     (Kind              : Algorithm;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

   function Combine
     (Configuration     : Parameters;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

private
   --  Representation remains an implementation decision.
end Flyology_CRC.Width_16;
```

### CRC-32

```ada
with Interfaces;

package Flyology_CRC.Width_32 is
   subtype Value is Interfaces.Unsigned_32;

   type Algorithm is
     (AIXM,
      AUTOSAR,
      BASE91_D,
      BZIP2,
      CD_ROM_EDC,
      CKSUM,
      ISCSI,
      ISO_HDLC,
      JAMCRC,
      MEF,
      MPEG_2,
      XFER);

   type Parameters is private;

   function Parameters_For (Kind : Algorithm) return Parameters;

   function Create
     (Polynomial    : Value;
      Initial_Value : Value;
      Reflected     : Boolean;
      Final_XOR     : Value) return Parameters;

   function Compute
     (Kind : Algorithm;
      Data : Byte_Array) return Value;

   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   function Compute_ISCSI (Data : Byte_Array) return Value;
   function Compute_ISO_HDLC (Data : Byte_Array) return Value;

   type Context is private;

   function Start (Kind : Algorithm) return Context;
   function Start (Configuration : Parameters) return Context;

   procedure Reset (Object : in out Context);
   procedure Update (Object : in out Context; Data : Byte_Array);
   function Result (Object : Context) return Value;

   function Combine
     (Kind              : Algorithm;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

   function Combine
     (Configuration     : Parameters;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

private
   --  Representation remains an implementation decision.
end Flyology_CRC.Width_32;
```

### CRC-64

```ada
with Interfaces;

package Flyology_CRC.Width_64 is
   subtype Value is Interfaces.Unsigned_64;

   type Algorithm is
     (ECMA_182,
      GO_ISO,
      MS,
      NVME,
      REDIS,
      WE,
      XZ);

   type Parameters is private;

   function Parameters_For (Kind : Algorithm) return Parameters;

   function Create
     (Polynomial    : Value;
      Initial_Value : Value;
      Reflected     : Boolean;
      Final_XOR     : Value) return Parameters;

   function Compute
     (Kind : Algorithm;
      Data : Byte_Array) return Value;

   function Compute
     (Configuration : Parameters;
      Data          : Byte_Array) return Value;

   function Compute_NVME (Data : Byte_Array) return Value;

   type Context is private;

   function Start (Kind : Algorithm) return Context;
   function Start (Configuration : Parameters) return Context;

   procedure Reset (Object : in out Context);
   procedure Update (Object : in out Context; Data : Byte_Array);
   function Result (Object : Context) return Value;

   function Combine
     (Kind              : Algorithm;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

   function Combine
     (Configuration     : Parameters;
      Left, Right       : Value;
      Right_Byte_Length : Byte_Count) return Value;

private
   --  Representation remains an implementation decision.
end Flyology_CRC.Width_64;
```

## Proposed behavior

- `Create` accepts every bit pattern of the width-specific modular `Value`.
  `Reflected` controls both Rocksoft `refin` and `refout`; configurations where
  those properties differ are outside the initial contract. There are no
  defaults.
- `Compute` and `Update` borrow `Data` for the duration of the call and retain
  no reference to it.
- `Start` returns a valid, allocation-free context. Context assignment copies
  the calculation state; there is no ownership transfer or finalization.
- `Result` does not mutate or reset the context. Further `Update` operations are
  allowed after observing a result.
- `Reset` restores the selected predefined or custom initial value.
- `Combine` returns the CRC of the logical concatenation represented by `Left`
  and `Right`; `Right_Byte_Length` is the byte length of the sequence whose CRC
  is `Right`.
- Operations do not raise exceptions for values admitted by their parameter
  types. A context is used by one caller at a time; separate contexts share no
  mutable calculation state.
- Dispatch selection, table shape, folding keys, feature detection, and caches
  are private and may change without source compatibility impact.

## Benchmark contract

### Compared implementations

- Oracle: `crc-fast` 1.10.0 commit
  `3a853cc7daf2cd47cc4466f198680cabdfb0b5fa`, built with its locked release
  configuration (`opt-level=3`, LTO, one codegen unit, runtime dispatch, and no
  global `target-cpu=native`).
- Candidate: the exact Flyology CRC commit under review, built with its
  maintained release profile. Safety checks are not globally disabled merely
  to win a benchmark.
- Harness: `flyology_bench` 0.1.1-dev from Flyology-index origin commit
  `bd95746d5c9c31f5b41b611db9ba82a016ceaaa4`. It is a dependency of a nested
  benchmark crate, not of the published CRC library.

Every report records source commits, dependency locks, compiler/toolchain
versions, binary hashes, architecture/feature detection, operating system,
power-profile detector result, and raw paired samples.

### Rust oracle boundary

The pinned Rust oracle is linked into the Ada benchmark executable through a
test-only Rust `staticlib` adapter:

- Rust exposes fixed-signature `extern "C"` functions with explicit exported
  symbol names.  The all-catalogue benchmark prepares an opaque handle outside
  the timed region, then loads the selected `crc-fast` algorithm and invokes
  its normal runtime-dispatched checksum path inside each timed operation.
  Dedicated helper exports remain available for focused specialized-path
  diagnostics but are not used by the all-catalogue acceptance matrix.
- The hot ABI contains only `*const u8`, `usize`, `u32`, and `u64`. It exposes
  no Rust enum, struct, slice, Boolean, allocation, or ownership across the
  boundary.
- A nonzero length requires a non-null pointer valid for that many bytes. Zero
  length is handled without constructing a Rust slice from the caller pointer.
  Rust never retains or modifies the borrowed bytes.
- The adapter builds with `panic = "abort"`; no Rust unwind may cross into Ada.
  Predefined checksum operations have no fallible result in the timed path.
- Ada imports each function directly with `Import`, `Convention => C`, and its
  exact `External_Name`. Compile-time checks establish 8-bit storage elements,
  32/64-bit result widths, pointer-sized C `size_t`, and representable Ada array
  lengths.
- A separate untimed adapter entry point uses explicit integer algorithm IDs,
  status, and an output value for differential correctness coverage. The IDs
  are adapter protocol values, not Rust enum representation values.
- A focused link/ABI test audits the exported symbols and calls every wrapper
  with empty input and `"123456789"` before any performance result is accepted.

The Ada contender remains a direct Ada call. Consequently, diagnostic tiny
buffer results include the Rust C-call boundary; only the 1 KiB and 1 MiB
acceptance cases are used for parity decisions.

### Acceptance suite

The performance gate covers the complete pinned catalogue rather than its
historical headline tables:

- sizes: 1 KiB and 1 MiB;
- algorithms: all 31 CRC-16, 12 CRC-32, and 7 CRC-64 predefined variants;
- one-shot operation over identical bytes, with results consumed so neither
  compiler can remove the calculation.

Diagnostic measurements additionally cover 0, 1, 7, 8, 15, 16, 17, 31, 32,
63, 64, 127, 128, 255, and 256 bytes. These expose dispatch and tail boundaries
but do not silently expand the initial parity gate.

One Ada executable uses `Flyology_Bench.Compare_Batched` to measure the imported
Rust reference and direct Ada contender in adjacent, order-balanced pairs. The
default equal-time policy calibrates each side independently toward the same
timed slice. Each batch performs exactly the requested logical operation count,
combines its returned checksums into a batch-local value, and passes that value
through the Flyology benchmark optimization barrier outside the per-operation
loop.

Runs are serial and use 1,000 retained samples and a 30-second measurement
budget, matching the oracle's maintained benchmark, unless a recorded pilot
shows that the host cannot complete those settings reliably. `flyology_bench`
emits the raw samples, environment metadata, order-effect diagnostics, and
paired circular-block bootstrap interval used by the gate.

For each acceptance case, compute the paired Ada/Rust throughput ratio and its
95% confidence interval:

- better: the interval is entirely above 1.0;
- statistically the same: the interval contains 1.0;
- slower: the interval is entirely below 1.0.

The gate passes only when every acceptance case is better or statistically the
same. Absolute throughput is host-specific; comparisons are valid only within
one matched pair campaign.

The macOS ARM64 performance campaign runs on the local development host. Run
the repository-pinned power-profile detector immediately before each baseline
and comparison and require matching classified profiles and power sources.

The Linux ARM64 campaign runs on a Graviton2 host with AdvSIMD, PMULL, and the
ARM CRC instructions.  Its power profile is unclassified, so report quiet-host,
balanced paired comparisons rather than portable absolute claims.

The x86-64 performance campaign runs on an AWS EC2 `i4i.xlarge` instance in
`us-west-2`, with an Intel Xeon Platinum 8375C exposing PCLMULQDQ, AVX2,
AVX-512, and VPCLMULQDQ. Its power profile is unclassified, so report only
quiet-host, balanced paired comparisons rather than portable absolute claims.

## Repository parity

| Concern | Reference and decision |
| --- | --- |
| Standalone Ada crate shape | Follow `flyology-json` commit `091d2cc21f615a453f031cfbfb0f21d8ab460fd3` for a dependency-minimal library, profile-aware GPR project, maintained test action, and external-consumer checks. |
| SIMD integration | Assess the current local `flyology-simd` 0.1.2-dev checkout at commit `099b8e1b9335452b42c7cbb92311767589f26773` when scalar evidence identifies required operations. Its zero-copy stream-element-array support matches this proposal's public input representation; carryless-multiply support remains to be evaluated. |
| Alire identity | Retain the existing `flyology_crc` name, `0.1.0-dev` version, dual MIT/Apache-2.0 declaration, and GNAT `>=13 & <17` constraint unless separately changed. |
| Tests | Use a nested Alire test crate so oracle/test-only dependencies do not enter the published manifest. |
| Benchmarks | Use a separate nested benchmark crate with `flyology_bench = "=0.1.1-dev"`, a pinned Rust `staticlib` oracle adapter, and an Ada C-import binding. |
| Website and publication | Omit initially. No remote, index publication, stable release, or tag is authorized by this proposal. |

## Approval requested

Approval of this proposal authorizes public API choices 1 through 5 and the
benchmark implementation contract in choice 6:

1. standalone root name `Flyology_CRC` and width children `Width_16`,
   `Width_32`, and `Width_64`;
2. standard stream-element input plus the visible `Byte`, `Byte_Array`, and
   64-bit `Byte_Count` subtypes;
3. the exact visible `Algorithm` enumeration types and literals listed above;
4. private `Parameters` and copyable `Context` types with the operations and
   behavior described above;
5. the three visible specialized one-shot functions;
6. the stated `flyology_bench` acceptance suite, Rust C ABI adapter, Ada import,
   and statistical pass rule.

Approval does not expose or freeze catalogue numeric parameters, table sizes,
folding distances, dispatch thresholds, cache policy, a public native ABI, or
storage representation. The Rust C ABI described above remains test-only.
