#!/usr/bin/env python3
"""Run every executable declared by the nested tests crate."""

from __future__ import annotations

import argparse
import subprocess
import tomllib
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
TEST_MANIFEST = REPOSITORY_ROOT / "tests" / "alire.toml"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run every test executable declared in tests/alire.toml."
    )
    parser.add_argument(
        "bin_directory",
        type=Path,
        help="Directory containing the built test executables.",
    )
    return parser.parse_args()


def declared_executables() -> list[str]:
    with TEST_MANIFEST.open("rb") as manifest_file:
        manifest = tomllib.load(manifest_file)

    executables = manifest.get("executables")
    if not isinstance(executables, list) or not executables:
        raise SystemExit(f"No executables are declared in {TEST_MANIFEST}")
    if not all(isinstance(name, str) and name for name in executables):
        raise SystemExit(f"Invalid executable declaration in {TEST_MANIFEST}")
    if len(executables) != len(set(executables)):
        raise SystemExit(f"Duplicate executable declaration in {TEST_MANIFEST}")
    return executables


def main() -> None:
    arguments = parse_arguments()
    bin_directory = arguments.bin_directory.resolve()
    executables = declared_executables()

    missing = [name for name in executables if not (bin_directory / name).is_file()]
    if missing:
        formatted = "\n".join(f"  {name}" for name in missing)
        raise SystemExit(f"Missing test executables in {bin_directory}:\n{formatted}")

    for name in executables:
        executable = bin_directory / name
        print(f"Running {name}", flush=True)
        subprocess.run([executable], check=True)

    print(f"All {len(executables)} declared test executables passed.")


if __name__ == "__main__":
    main()
