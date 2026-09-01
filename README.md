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

Flyology CRC was compared with pinned
[`crc-fast` 1.10.0](https://github.com/awesomized/crc-fast-rust/tree/3a853cc7daf2cd47cc4466f198680cabdfb0b5fa)
using paired, order-balanced `flyology_bench` measurements. Each platform
covered all 50 algorithms at 1 KiB and 1 MiB, with 1,000 paired samples per
cell. A result is classified as faster only when its paired 95% confidence
interval excludes parity.

| Platform | Cells | Flyology faster | CI parity | `crc-fast` faster |
|---|---:|---:|---:|---:|
| macOS ARM64 | 100 | 100 | 0 | 0 |
| Linux ARM64 | 100 | 98 | 2 | 0 |
| Linux x86-64 | 100 | 83 | 17 | 0 |
| **Total** | **300** | **281** | **19** | **0** |

<details>
<summary>Show all 50 algorithms across both sizes and three platforms</summary>

Each cell is `crc-fast / Flyology` median ns/op followed by the paired speedup. **P** marks CI parity; every unmarked cell statistically favors Flyology.

| Algorithm | macOS ARM64 1 KiB | macOS ARM64 1 MiB | Linux ARM64 1 KiB | Linux ARM64 1 MiB | Linux x86-64 1 KiB | Linux x86-64 1 MiB |
|---|---:|---:|---:|---:|---:|---:|
| CRC-16/ARC | `21.769 / 19.998` (1.086732x) | `15,192.7 / 14,806.0` (1.025649x) | `85.169 / 82.219` (1.036577x) | `61,405.1 / 61,042.0` (1.006809x) | `40.086 / 37.114` (1.080465x) | `21,013.1 / 20,827.5` (1.008161x) |
| CRC-16/CDMA2000 | `28.712 / 25.130` (1.142775x) | `22,723.5 / 18,371.8` (1.237445x) | `106.728 / 96.904` (1.100325x) | `79,649.8 / 71,103.5` (1.121233x) | `48.824 / 43.079` (1.135342x) | `29,412.2 / 29,368.6` (1.001852x) **P** |
| CRC-16/CMS | `28.712 / 25.148` (1.140903x) | `22,738.6 / 18,375.0` (1.239713x) | `106.728 / 97.623` (1.095699x) | `79,622.3 / 71,087.1` (1.119931x) | `48.701 / 43.110` (1.129601x) | `29,410.2 / 29,364.0` (1.003549x) |
| CRC-16/DDS_110 | `28.712 / 25.126` (1.142827x) | `22,734.9 / 18,384.6` (1.237618x) | `106.821 / 98.024` (1.092202x) | `79,660.7 / 71,134.2` (1.118814x) | `48.747 / 42.943` (1.134842x) | `29,409.0 / 29,363.9` (1.002882x) |
| CRC-16/DECT_R | `28.717 / 25.146` (1.143272x) | `22,737.5 / 18,365.4` (1.238688x) | `106.821 / 97.622` (1.095268x) | `79,650.0 / 71,083.0` (1.121355x) | `48.595 / 42.946` (1.131880x) | `29,401.2 / 29,365.1` (1.001557x) **P** |
| CRC-16/DECT_X | `28.707 / 25.122` (1.141939x) | `22,833.3 / 18,496.8` (1.236249x) | `106.525 / 97.625` (1.093607x) | `79,680.0 / 71,105.8` (1.121529x) | `48.796 / 42.774` (1.137177x) | `29,418.5 / 29,364.8` (1.000115x) **P** |
| CRC-16/DNP | `21.190 / 20.026` (1.056536x) | `15,135.4 / 14,744.8` (1.026902x) | `84.718 / 82.219` (1.032684x) | `61,355.9 / 60,999.0` (1.004846x) | `40.044 / 36.825` (1.089206x) | `21,005.4 / 20,825.5` (1.010346x) |
| CRC-16/EN_13757 | `28.712 / 25.126` (1.142807x) | `22,733.3 / 18,365.4` (1.238275x) | `106.823 / 96.824` (1.103861x) | `79,622.7 / 71,085.1` (1.119439x) | `48.267 / 42.758` (1.127776x) | `29,402.1 / 29,371.7` (1.001414x) **P** |
| CRC-16/GENIBUS | `28.717 / 25.140` (1.142470x) | `22,820.9 / 18,490.4` (1.237750x) | `106.888 / 97.624` (1.096590x) | `79,521.3 / 70,982.5` (1.120208x) | `48.390 / 42.768` (1.130699x) | `29,401.6 / 29,370.0` (0.999935x) **P** |
| CRC-16/GSM | `28.712 / 25.130` (1.141810x) | `23,075.0 / 18,685.9` (1.233103x) | `106.821 / 96.905` (1.101618x) | `79,587.0 / 71,058.4` (1.120295x) | `48.225 / 42.982` (1.120752x) | `29,400.5 / 29,373.1` (0.999309x) **P** |
| CRC-16/IBM_3740 | `28.712 / 25.126` (1.142403x) | `22,831.4 / 18,496.8` (1.236349x) | `106.820 / 97.625` (1.096121x) | `79,606.0 / 71,077.0` (1.119810x) | `48.888 / 42.777` (1.140051x) | `29,403.6 / 29,366.8` (1.001248x) **P** |
| CRC-16/IBM_SDLC | `21.260 / 20.003` (1.058760x) | `15,164.1 / 14,770.8` (1.027041x) | `85.618 / 81.919` (1.039775x) | `61,374.5 / 61,007.1` (1.006970x) | `39.871 / 37.063` (1.076303x) | `21,009.9 / 20,831.8` (1.007921x) |
| CRC-16/ISO_IEC_14443_3_A | `21.700 / 20.052` (1.082067x) | `15,169.2 / 14,776.0` (1.027470x) | `85.288 / 82.019` (1.038849x) | `61,365.1 / 61,005.1` (1.005820x) | `40.056 / 38.606` (1.035873x) | `21,009.2 / 20,855.9` (1.008245x) |
| CRC-16/KERMIT | `21.645 / 20.042` (1.079193x) | `15,200.6 / 14,812.5` (1.026972x) | `85.124 / 81.818` (1.037535x) | `61,319.0 / 60,972.2` (1.006686x) | `39.690 / 37.063` (1.072209x) | `21,013.2 / 20,859.9` (1.007424x) |
| CRC-16/LJ1200 | `28.712 / 25.155` (1.141532x) | `22,800.0 / 18,416.6` (1.239206x) | `106.523 / 97.622` (1.094198x) | `79,630.7 / 71,087.1` (1.119664x) | `48.529 / 43.020` (1.128521x) | `29,416.8 / 29,400.2` (0.999208x) **P** |
| CRC-16/M17 | `28.712 / 25.138` (1.141687x) | `22,783.3 / 18,416.6` (1.238212x) | `106.728 / 96.823` (1.104431x) | `79,562.3 / 71,003.2` (1.120912x) | `48.400 / 43.210` (1.121661x) | `29,419.3 / 29,383.5` (1.001130x) **P** |
| CRC-16/MAXIM_DOW | `21.270 / 19.990` (1.061888x) | `15,192.7 / 14,794.3` (1.027652x) | `84.153 / 82.219` (1.025122x) | `61,317.0 / 60,958.0` (1.005054x) | `40.620 / 37.114` (1.093176x) | `21,005.1 / 20,843.3` (1.009539x) |
| CRC-16/MCRF4XX | `21.779 / 20.011` (1.087413x) | `15,197.9 / 14,804.7` (1.026386x) | `85.239 / 82.821` (1.030681x) | `61,423.8 / 61,013.5` (1.007585x) | `39.685 / 37.071` (1.070387x) | `21,013.9 / 20,848.6` (1.006721x) |
| CRC-16/MODBUS | `21.719 / 20.032` (1.083562x) | `15,166.6 / 14,781.2` (1.025796x) | `85.209 / 82.223` (1.032715x) | `61,317.0 / 60,960.0` (1.006296x) | `39.713 / 37.088` (1.070531x) | `21,006.2 / 20,825.2` (1.008936x) |
| CRC-16/NRSC_5 | `21.794 / 19.998` (1.088566x) | `15,171.9 / 14,778.6` (1.026495x) | `85.120 / 81.929` (1.036182x) | `61,329.2 / 60,962.0` (1.005081x) | `39.687 / 37.062` (1.069624x) | `21,007.0 / 20,827.4` (1.007848x) |
| CRC-16/OPENSAFETY_A | `28.717 / 25.155` (1.140856x) | `22,783.3 / 18,407.0` (1.238327x) | `106.628 / 97.622` (1.097991x) | `79,686.8 / 71,099.5` (1.120614x) | `47.864 / 43.349` (1.104634x) | `29,414.1 / 29,368.3` (1.000066x) **P** |
| CRC-16/OPENSAFETY_B | `28.717 / 25.155` (1.141800x) | `22,795.8 / 18,458.3` (1.236745x) | `106.628 / 97.622` (1.094460x) | `79,636.3 / 71,107.8` (1.118555x) | `47.803 / 43.133` (1.109818x) | `29,411.0 / 29,364.6` (1.002546x) |
| CRC-16/PROFIBUS | `28.717 / 25.138` (1.142864x) | `22,812.5 / 18,468.0` (1.236906x) | `106.827 / 97.622` (1.096546x) | `79,638.8 / 71,081.0` (1.121250x) | `48.386 / 43.119` (1.125067x) | `29,402.8 / 29,363.0` (1.001937x) **P** |
| CRC-16/RIELLO | `21.784 / 20.024` (1.086172x) | `15,184.9 / 14,789.1` (1.028092x) | `85.222 / 82.826` (1.025617x) | `61,274.9 / 60,941.5` (1.005622x) | `39.859 / 37.066` (1.069979x) | `21,012.1 / 20,830.4` (1.009486x) |
| CRC-16/SPI_FUJITSU | `28.722 / 25.155` (1.142620x) | `22,837.5 / 18,500.0` (1.237464x) | `106.420 / 97.622` (1.093846x) | `79,606.0 / 71,048.1` (1.121086x) | `47.911 / 43.099` (1.109876x) | `29,414.9 / 29,366.4` (1.002259x) |
| CRC-16/T10_DIF | `28.717 / 25.130` (1.143519x) | `22,858.4 / 18,512.8` (1.236537x) | `106.522 / 96.831` (1.099788x) | `79,690.8 / 71,111.8` (1.121714x) | `48.390 / 43.053` (1.123932x) | `29,359.2 / 29,318.4` (0.999636x) **P** |
| CRC-16/TELEDISK | `28.717 / 25.155` (1.141792x) | `22,875.0 / 18,522.5` (1.235720x) | `106.523 / 97.622` (1.094466x) | `79,655.3 / 71,085.0` (1.121030x) | `48.429 / 43.183` (1.120970x) | `29,408.2 / 29,366.0` (0.999893x) **P** |
| CRC-16/TMS37157 | `21.824 / 20.007` (1.089343x) | `15,257.8 / 14,862.0` (1.026497x) | `85.300 / 82.019` (1.041961x) | `61,347.6 / 60,955.8` (1.005528x) | `39.839 / 37.073` (1.071496x) | `21,013.9 / 20,830.0` (1.008798x) |
| CRC-16/UMTS | `28.717 / 25.179` (1.141780x) | `22,887.5 / 18,530.4` (1.237234x) | `106.523 / 97.623` (1.097020x) | `79,648.5 / 71,091.2` (1.120114x) | `48.454 / 43.340` (1.119600x) | `29,415.2 / 29,366.9` (1.002136x) |
| CRC-16/USB | `21.252 / 20.001` (1.059565x) | `15,236.9 / 14,841.2` (1.026006x) | `85.618 / 81.788` (1.040423x) | `61,356.0 / 61,002.0` (1.006068x) | `39.866 / 37.063` (1.076760x) | `21,006.4 / 20,821.1` (1.010978x) |
| CRC-16/XMODEM | `28.717 / 25.167` (1.140595x) | `22,862.5 / 18,512.8` (1.236590x) | `106.522 / 97.625` (1.092040x) | `79,677.3 / 71,081.0` (1.121437x) | `48.449 / 43.125` (1.126195x) | `29,412.6 / 29,367.2` (1.002877x) |
| CRC-32/AIXM | `28.605 / 25.415` (1.126950x) | `22,887.5 / 18,471.2` (1.240639x) | `104.824 / 97.732` (1.080621x) | `79,633.7 / 71,086.1` (1.120562x) | `48.068 / 42.861` (1.124485x) | `29,400.9 / 29,362.3` (1.002301x) |
| CRC-32/AUTOSAR | `20.807 / 20.070` (1.037230x) | `15,210.9 / 14,815.1` (1.026373x) | `84.817 / 81.623` (1.037635x) | `61,319.0 / 60,970.2` (1.006254x) | `40.612 / 36.616` (1.107669x) | `21,005.4 / 20,823.1` (1.009519x) |
| CRC-32/BASE91_D | `20.647 / 20.045` (1.027017x) | `15,540.3 / 15,115.9` (1.025826x) | `84.740 / 81.622` (1.037548x) | `61,362.0 / 60,960.0` (1.006882x) | `39.904 / 37.605` (1.061512x) | `21,006.6 / 20,856.8` (1.006457x) |
| CRC-32/BZIP2 | `28.661 / 25.981` (1.109000x) | `23,850.0 / 19,128.2` (1.246381x) | `105.493 / 97.737` (1.083590x) | `79,644.3 / 71,101.5` (1.120158x) | `48.720 / 42.861` (1.137643x) | `29,401.9 / 29,386.1` (1.002319x) |
| CRC-32/CD_ROM_EDC | `20.658 / 20.062` (1.025430x) | `15,354.2 / 14,958.3` (1.026837x) | `84.020 / 81.623` (1.022639x) | `61,316.8 / 60,939.5` (1.006078x) | `39.594 / 36.647` (1.077628x) | `21,010.5 / 20,846.3` (1.008465x) |
| CRC-32/CKSUM | `28.656 / 25.407` (1.130705x) | `22,825.0 / 18,420.2` (1.240804x) | `106.019 / 97.671` (1.086858x) | `79,557.0 / 71,048.2` (1.120307x) | `47.842 / 42.825` (1.119707x) | `29,399.9 / 29,368.0` (1.001945x) |
| CRC-32/ISCSI | `16.925 / 16.139` (1.043236x) | `10,614.1 / 10,530.8` (1.007026x) | `74.948 / 74.489` (1.008118x) | `57,946.8 / 58,010.2` (0.999806x) **P** | `31.184 / 31.090` (1.002627x) | `21,701.8 / 21,725.8` (0.999171x) **P** |
| CRC-32/ISO_HDLC | `17.201 / 16.078` (1.069035x) | `10,559.8 / 10,510.9` (1.005087x) | `76.183 / 74.943` (1.011909x) | `57,891.5 / 57,947.8` (0.999882x) **P** | `39.900 / 36.290` (1.098542x) | `21,004.0 / 20,826.1` (1.010136x) |
| CRC-32/JAMCRC | `20.874 / 20.283` (1.028023x) | `15,104.1 / 14,718.8` (1.026146x) | `82.826 / 81.622` (1.018419x) | `61,340.5 / 60,974.5` (1.007192x) | `39.677 / 36.624` (1.082563x) | `21,007.7 / 20,822.5` (1.010959x) |
| CRC-32/MEF | `20.859 / 20.284` (1.026720x) | `15,112.0 / 14,723.9` (1.026304x) | `84.019 / 81.621` (1.028406x) | `61,343.5 / 60,949.8` (1.006267x) | `39.630 / 36.626` (1.081339x) | `21,011.3 / 20,823.0` (1.009485x) |
| CRC-32/MPEG_2 | `28.966 / 25.612` (1.127441x) | `22,245.9 / 17,833.3` (1.245950x) | `106.625 / 97.731` (1.087773x) | `79,581.7 / 71,058.4` (1.119780x) | `48.181 / 42.867` (1.125321x) | `29,404.9 / 29,363.6` (1.001741x) **P** |
| CRC-32/XFER | `28.971 / 25.728` (1.124803x) | `22,208.4 / 17,794.6` (1.248648x) | `106.022 / 97.787` (1.088865x) | `79,663.7 / 71,101.5` (1.119313x) | `48.252 / 42.833` (1.127732x) | `29,402.3 / 29,369.6` (0.999809x) **P** |
| CRC-64/ECMA_182 | `28.559 / 24.089` (1.178240x) | `22,231.1 / 17,875.0` (1.243765x) | `100.825 / 91.992` (1.094298x) | `79,658.0 / 71,128.2` (1.119061x) | `47.371 / 39.770` (1.189740x) | `29,410.0 / 29,362.4` (1.002312x) |
| CRC-64/GO_ISO | `21.104 / 19.388` (1.089754x) | `14,770.9 / 14,591.2` (1.011491x) | `79.025 / 74.418` (1.061232x) | `61,339.5 / 60,916.8` (1.006059x) | `38.862 / 34.447` (1.128594x) | `21,000.0 / 20,828.7` (1.008825x) |
| CRC-64/MS | `20.329 / 19.383` (1.051080x) | `14,770.8 / 14,593.8` (1.012518x) | `79.021 / 74.570` (1.066111x) | `61,353.9 / 60,935.2` (1.006745x) | `37.972 / 34.490` (1.101751x) | `21,010.4 / 20,850.0` (1.009610x) |
| CRC-64/NVME | `21.098 / 19.380` (1.090232x) | `14,773.4 / 14,596.4` (1.012554x) | `80.817 / 73.819` (1.086050x) | `61,407.0 / 60,964.1` (1.007520x) | `39.804 / 34.463` (1.155601x) | `20,998.3 / 20,821.4` (1.009277x) |
| CRC-64/REDIS | `20.351 / 19.378` (1.054517x) | `14,794.2 / 14,613.3` (1.013015x) | `79.462 / 75.221` (1.054213x) | `61,247.1 / 60,835.0` (1.007073x) | `37.687 / 34.607` (1.084487x) | `21,006.2 / 20,822.5` (1.010185x) |
| CRC-64/WE | `28.803 / 24.170` (1.181280x) | `22,212.2 / 17,842.9` (1.244772x) | `100.820 / 90.754` (1.110286x) | `79,518.7 / 71,029.8` (1.119734x) | `45.461 / 39.646` (1.144913x) | `29,396.5 / 29,363.1` (0.999674x) **P** |
| CRC-64/XZ | `21.197 / 19.383` (1.097304x) | `14,763.0 / 14,588.6` (1.011735x) | `79.221 / 74.819` (1.059465x) | `61,259.5 / 60,847.1` (1.005408x) | `48.618 / 34.454` (1.407575x) | `21,001.4 / 20,827.0` (1.006976x) |

</details>

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
