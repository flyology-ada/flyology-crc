#!/usr/bin/env python3
"""Generate Flyology CRC's private Ada catalogue from versioned source data."""

from __future__ import annotations

import argparse
import pathlib
import sys
import tomllib


EXPECTED_NAMES = {
    16: [
        "ARC", "CDMA2000", "CMS", "DDS_110", "DECT_R", "DECT_X", "DNP",
        "EN_13757", "GENIBUS", "GSM", "IBM_3740", "IBM_SDLC",
        "ISO_IEC_14443_3_A", "KERMIT", "LJ1200", "M17", "MAXIM_DOW",
        "MCRF4XX", "MODBUS", "NRSC_5", "OPENSAFETY_A", "OPENSAFETY_B",
        "PROFIBUS", "RIELLO", "SPI_FUJITSU", "T10_DIF", "TELEDISK",
        "TMS37157", "UMTS", "USB", "XMODEM",
    ],
    32: [
        "AIXM", "AUTOSAR", "BASE91_D", "BZIP2", "CD_ROM_EDC", "CKSUM",
        "ISCSI", "ISO_HDLC", "JAMCRC", "MEF", "MPEG_2", "XFER",
    ],
    64: ["ECMA_182", "GO_ISO", "MS", "NVME", "REDIS", "WE", "XZ"],
}

CATALOGUE_SOURCE = "https://reveng.sourceforge.io/crc-catalogue/all.htm"

FIELDS = ("polynomial", "initial", "final_xor", "check", "residue")

# Private fold-by-eight layout. The positions and exponents are implementation
# geometry rather than catalogue policy; see THIRD_PARTY_NOTICES.md.
EXPONENTS = {
    16: [
        0, 32 * 3, 32 * 5, 32 * 31, 32 * 33, 32 * 3, 32 * 2, 0, 0,
        32 * 27, 32 * 29, 32 * 23, 32 * 25, 32 * 19, 32 * 21,
        32 * 15, 32 * 17, 32 * 11, 32 * 13, 32 * 7, 32 * 9,
        32 * 63, 32 * 65,
    ],
    32: [
        0, 32 * 3, 32 * 5, 32 * 31, 32 * 33, 32 * 3, 32 * 2, 0, 0,
        32 * 27, 32 * 29, 32 * 23, 32 * 25, 32 * 19, 32 * 21,
        32 * 15, 32 * 17, 32 * 11, 32 * 13, 32 * 7, 32 * 9,
        32 * 63, 32 * 65,
    ],
    64: [
        0, 64 * 2, 64 * 3, 64 * 16, 64 * 17, 64 * 2, 64, 0, 0,
        64 * 14, 64 * 15, 64 * 12, 64 * 13, 64 * 10, 64 * 11,
        64 * 8, 64 * 9, 64 * 6, 64 * 7, 64 * 4, 64 * 5,
        64 * 32, 64 * 33,
    ],
}

U64_MASK = (1 << 64) - 1


def reverse_bits(value: int, width: int) -> int:
    result = 0
    for _ in range(width):
        result = (result << 1) | (value & 1)
        value >>= 1
    return result


def folding_key(width: int, polynomial: int, reflected: bool, exponent: int) -> int:
    if width in (16, 32):
        if exponent < 32:
            return 0
        value = 0x080000000
        for _ in range(exponent - 31):
            value <<= 1
            if value & 0x100000000:
                value ^= polynomial
        return reverse_bits(value, 64) >> 31 if reflected else (value << 32) & U64_MASK

    if exponent <= 64:
        return 0
    value = 0x8000000000000000
    iterations = exponent - (64 if reflected else 63)
    for _ in range(iterations):
        mask = U64_MASK if value >> 63 else 0
        value = ((value << 1) & U64_MASK) ^ (mask & polynomial)
    return reverse_bits(value, 64) if reflected else value


def folding_mu(width: int, polynomial: int, reflected: bool) -> int:
    if width in (16, 32):
        value = 0x100000000
        quotient = 0
        for _ in range(33):
            quotient = (quotient << 1) & U64_MASK
            if value & 0x100000000:
                quotient |= 1
                value ^= polynomial
            value = (value << 1) & U64_MASK
        return reverse_bits(quotient, 64) >> 31 if reflected else quotient

    high = 1
    low = 0
    quotient = 0
    for _ in range(64 if reflected else 65):
        quotient = (quotient << 1) & U64_MASK
        if high != 0:
            quotient |= 1
            low ^= polynomial
        high = low >> 63
        low = (low << 1) & U64_MASK
    return reverse_bits(quotient, 64) if reflected else quotient


def folding_polynomial(width: int, polynomial: int, reflected: bool) -> int:
    if width == 16:
        if not reflected:
            return polynomial
        original = (polynomial >> 16) & 0xFFFF
        return (reverse_bits(original, 16) << 1) | 1
    if width == 32:
        if not reflected:
            return polynomial | (1 << 32)
        return (reverse_bits(polynomial & 0xFFFFFFFF, 32) << 1) | 1
    if not reflected:
        return polynomial
    return ((reverse_bits(polynomial, 64) << 1) & U64_MASK) | 1


def folding_keys(width: int, polynomial: int, reflected: bool) -> list[int]:
    if width == 16:
        working_polynomial = (polynomial << 16) | (1 << 32)
    elif width == 32:
        working_polynomial = polynomial | (1 << 32)
    else:
        working_polynomial = polynomial

    keys = [
        folding_key(width, working_polynomial, reflected, exponent)
        for exponent in EXPONENTS[width]
    ]
    keys[7] = folding_mu(width, working_polynomial, reflected)
    keys[8] = folding_polynomial(width, working_polynomial, reflected)
    return keys


def load(path: pathlib.Path) -> dict:
    with path.open("rb") as source:
        document = tomllib.load(source)

    if document.get("schema") != 1:
        raise ValueError("unsupported catalogue schema")

    if document.get("catalogue_source") != CATALOGUE_SOURCE:
        raise ValueError(
            "catalogue_source differs from the authoritative parameter source: "
            f"expected {CATALOGUE_SOURCE!r}, "
            f"got {document.get('catalogue_source')!r}"
        )

    if any(len(exponents) != 23 for exponents in EXPONENTS.values()):
        raise ValueError("the pinned fold-by-8 layout must contain exactly 23 keys")

    algorithms = document.get("algorithm")
    if not isinstance(algorithms, list):
        raise ValueError("catalogue must contain [[algorithm]] entries")

    grouped = {width: [] for width in EXPECTED_NAMES}
    for item in algorithms:
        width = item.get("width")
        if width not in grouped:
            raise ValueError(f"unsupported CRC width: {width!r}")
        grouped[width].append(item)
        digits = width // 4
        for field in FIELDS:
            text = item.get(field)
            if not isinstance(text, str) or len(text) != digits:
                raise ValueError(
                    f"{item.get('name', '<unnamed>')}.{field} must have {digits} hex digits"
                )
            try:
                int(text, 16)
            except ValueError as error:
                raise ValueError(
                    f"{item.get('name', '<unnamed>')}.{field} is not hexadecimal"
                ) from error
        if type(item.get("reflected")) is not bool:
            raise ValueError(f"{item.get('name', '<unnamed>')}.reflected must be Boolean")

    for width, expected in EXPECTED_NAMES.items():
        actual = [item.get("name") for item in grouped[width]]
        if actual != expected:
            raise ValueError(
                f"CRC-{width} names/order differ from the pinned oracle:\n"
                f"expected {expected!r}\nactual   {actual!r}"
            )

    document["grouped"] = grouped
    return document


def banner(document: dict) -> str:
    return (
        "--  Generated by tools/generate_catalogue.py; do not edit.\n"
        f"--  Parameter source: {document['catalogue_source']}\n"
        "--  Versioned input: catalogue/crc-catalogue.toml\n\n"
        "--  Folding keys use Flyology CRC's private fold-by-eight layout.\n\n"
    )


def ada_hex(value: str) -> str:
    return f"16#{value.upper()}#"


def ada_u64(value: int) -> str:
    return f"16#{value:016X}#"


def ada_keys(width: int, polynomial: str, reflected: bool, indentation: str) -> str:
    values = folding_keys(width, int(polynomial, 16), reflected)
    lines = []
    for index, value in enumerate(values):
        opening = "(" if index == 0 else " "
        lines.append(f"{indentation}{opening}{index:2d} => {ada_u64(value)}")
    return ",\n".join(lines) + ")"


def generate_spec(document: dict) -> str:
    result = banner(document)
    result += "with Flyology_CRC.Width_16;\nwith Flyology_CRC.Width_32;\nwith Flyology_CRC.Width_64;\n\n"
    result += "private package Flyology_CRC.Generated_Catalogue is\n"
    for width in EXPECTED_NAMES:
        result += (
            f"   type Parameters_{width} is record\n"
            f"      Polynomial    : Width_{width}.Value;\n"
            f"      Initial_Value : Width_{width}.Value;\n"
            "      Reflected     : Boolean;\n"
            f"      Final_XOR     : Width_{width}.Value;\n"
            "      Keys          : Folding_Keys;\n"
            "   end record;\n\n"
            f"   function Lookup (Kind : Width_{width}.Algorithm) return Parameters_{width};\n\n"
        )
    result += "end Flyology_CRC.Generated_Catalogue;\n"
    return result


def generate_body(document: dict) -> str:
    result = banner(document)
    result += "package body Flyology_CRC.Generated_Catalogue is\n\n"
    for width, items in document["grouped"].items():
        result += f"   function Lookup (Kind : Width_{width}.Algorithm) return Parameters_{width} is\n"
        result += "   begin\n      case Kind is\n"
        for item in items:
            reflected = "True" if item["reflected"] else "False"
            result += (
                f"         when Width_{width}.{item['name']} =>\n"
                "            return\n"
                f"              (Polynomial    => {ada_hex(item['polynomial'])},\n"
                f"               Initial_Value => {ada_hex(item['initial'])},\n"
                f"               Reflected     => {reflected},\n"
                f"               Final_XOR     => {ada_hex(item['final_xor'])},\n"
                "               Keys          =>\n"
                f"{ada_keys(width, item['polynomial'], item['reflected'], '                 ')});\n"
            )
        result += f"      end case;\n   end Lookup;\n\n"
    result += "end Flyology_CRC.Generated_Catalogue;\n"
    return result


def generate_test_checks(document: dict) -> str:
    result = banner(document)
    result += "with Flyology_CRC.Width_16;\nwith Flyology_CRC.Width_32;\nwith Flyology_CRC.Width_64;\n\n"
    result += "package Generated_CRC_Checks is\n"
    for width, items in document["grouped"].items():
        result += (
            f"   Check_{width} : constant array (Flyology_CRC.Width_{width}.Algorithm) of\n"
            f"     Flyology_CRC.Width_{width}.Value :=\n"
            "       ("
        )
        for index, item in enumerate(items):
            prefix = "" if index == 0 else "        "
            suffix = ",\n" if index + 1 < len(items) else ");\n\n"
            result += (
                f"{prefix}Flyology_CRC.Width_{width}.{item['name']} => "
                f"{ada_hex(item['check'])}{suffix}"
            )
    result += "end Generated_CRC_Checks;\n"
    return result


def write_if_changed(path: pathlib.Path, content: str) -> None:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail when generated files differ")
    arguments = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parents[1]
    document = load(root / "catalogue" / "crc-catalogue.toml")
    outputs = {
        root / "src" / "generated" / "flyology_crc-generated_catalogue.ads": generate_spec(document),
        root / "src" / "generated" / "flyology_crc-generated_catalogue.adb": generate_body(document),
        root / "tests" / "src" / "generated_crc_checks.ads": generate_test_checks(document),
    }

    if arguments.check:
        stale = [path for path, content in outputs.items() if not path.exists() or path.read_text(encoding="utf-8") != content]
        if stale:
            for path in stale:
                print(f"stale generated file: {path.relative_to(root)}", file=sys.stderr)
            return 1
        return 0

    for path, content in outputs.items():
        write_if_changed(path, content)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, ValueError) as error:
        print(f"catalogue generation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
