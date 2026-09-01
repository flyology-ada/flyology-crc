#!/usr/bin/env python3
"""Generate the audited all-platform CRC performance comparison report."""

from __future__ import annotations

import argparse
import csv
import re
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path


SUMMARY_PATTERN = re.compile(
    r"^(?P<algorithm>CRC-(?:16|32|64)/\S+)\s+"
    r"bytes=\s*(?P<bytes>\d+)\s+"
    r"Ada speedup=\s*(?P<speedup>\S+)\s+"
    r"CI=\[\s*(?P<low>[^,]+),\s*(?P<high>[^\]]+)\]\s+"
    r"verdict=(?P<verdict>\S+)\s*$"
)

VERDICT_LABELS = {
    "CONTENDER_FASTER": "Flyology faster",
    "INCONCLUSIVE": "CI parity",
    "REFERENCE_FASTER": "crc-fast faster",
}


@dataclass(frozen=True)
class Summary:
    speedup: float
    low: float
    high: float
    verdict: str


def parse_raw(path: Path) -> dict[tuple[str, int], tuple[list[float], list[float]]]:
    cells: dict[tuple[str, int], tuple[list[float], list[float]]] = defaultdict(
        lambda: ([], [])
    )
    with path.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            algorithm = row["algorithm"].strip()
            size = int(row["bytes"].strip())
            reference, contender = cells[(algorithm, size)]
            reference.append(float(row["reference_crc_fast_ns"].strip()))
            contender.append(float(row["contender_flyology_crc_ns"].strip()))
    return dict(cells)


def parse_summary(path: Path) -> dict[tuple[str, int], Summary]:
    summaries: dict[tuple[str, int], Summary] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = SUMMARY_PATTERN.match(line)
        if match is None:
            continue
        key = (match["algorithm"], int(match["bytes"]))
        if key in summaries:
            raise ValueError(f"duplicate summary cell {key!r} in {path}")
        verdict = match["verdict"]
        if verdict not in VERDICT_LABELS:
            raise ValueError(f"unknown verdict {verdict!r} in {path}")
        summaries[key] = Summary(
            speedup=float(match["speedup"]),
            low=float(match["low"]),
            high=float(match["high"]),
            verdict=verdict,
        )
    return summaries


def format_ns(value: float) -> str:
    if value < 1_000.0:
        return f"{value:.3f}"
    return f"{value:,.1f}"


def load_platform(
    label: str,
    raw_path: Path,
    summary_path: Path,
    expected_cells: int,
    expected_samples: int,
) -> tuple[
    str,
    dict[tuple[str, int], tuple[list[float], list[float]]],
    dict[tuple[str, int], Summary],
]:
    raw = parse_raw(raw_path)
    summaries = parse_summary(summary_path)
    if set(raw) != set(summaries):
        missing_raw = sorted(set(summaries) - set(raw))
        missing_summary = sorted(set(raw) - set(summaries))
        raise ValueError(
            f"{label}: raw/summary cells differ; missing raw={missing_raw}, "
            f"missing summary={missing_summary}"
        )
    if len(raw) != expected_cells:
        raise ValueError(f"{label}: expected {expected_cells} cells, found {len(raw)}")
    for key, (reference, contender) in raw.items():
        if len(reference) != expected_samples or len(contender) != expected_samples:
            raise ValueError(
                f"{label}: expected {expected_samples} paired samples for {key!r}, "
                f"found {len(reference)} reference and {len(contender)} contender"
            )
    return label, raw, summaries


def render(
    platforms: list[
        tuple[
            str,
            dict[tuple[str, int], tuple[list[float], list[float]]],
            dict[tuple[str, int], Summary],
        ]
    ],
) -> str:
    lines = [
        "# Flyology CRC performance comparison",
        "",
        "Times are median nanoseconds per operation across the raw paired samples. "
        "Speedup and 95% confidence intervals are the paired `flyology_bench` "
        "results (`crc-fast / Flyology`), so values above 1 favor Flyology. "
        "`CI parity` means the 95% interval contains 1.000; no practical "
        "tolerance band is applied.",
        "",
        "## Summary",
        "",
        "| Platform | Cells | Flyology faster | CI parity | crc-fast faster |",
        "|---|---:|---:|---:|---:|",
    ]
    for label, raw, summaries in platforms:
        counts = Counter(summary.verdict for summary in summaries.values())
        lines.append(
            f"| {label} | {len(raw)} | {counts['CONTENDER_FASTER']} | "
            f"{counts['INCONCLUSIVE']} | {counts['REFERENCE_FASTER']} |"
        )

    for label, raw, summaries in platforms:
        lines.extend(
            [
                "",
                f"## {label}",
                "",
                "| Algorithm | Bytes | crc-fast median ns/op | Flyology median ns/op | "
                "Speedup | 95% CI | Verdict |",
                "|---|---:|---:|---:|---:|---:|---|",
            ]
        )
        for key in sorted(raw, key=lambda item: (item[1], item[0])):
            algorithm, size = key
            reference, contender = raw[key]
            summary = summaries[key]
            lines.append(
                f"| {algorithm} | {size:,} | "
                f"{format_ns(statistics.median(reference))} | "
                f"{format_ns(statistics.median(contender))} | "
                f"{summary.speedup:.6f}x | "
                f"[{summary.low:.6f}, {summary.high:.6f}] | "
                f"{VERDICT_LABELS[summary.verdict]} |"
            )
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--platform",
        action="append",
        nargs=3,
        metavar=("LABEL", "RAW_CSV", "SUMMARY"),
        required=True,
        help="add one platform's raw CSV and flyology_bench summary",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--expected-cells", type=int, default=100)
    parser.add_argument("--expected-samples", type=int, default=1_000)
    arguments = parser.parse_args()

    platforms = [
        load_platform(
            label,
            Path(raw),
            Path(summary),
            arguments.expected_cells,
            arguments.expected_samples,
        )
        for label, raw, summary in arguments.platform
    ]
    arguments.output.write_text(render(platforms), encoding="utf-8")


if __name__ == "__main__":
    main()
