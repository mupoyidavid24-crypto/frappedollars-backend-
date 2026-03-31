from __future__ import annotations

import re
import unicodedata


BASE36_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
TAG_LENGTH = 13
SYSTEM_PREFIX = 410_000_000
MAGIC_RANGE = 10_000_000
MAX_SIGNED_INT = 2_147_483_647

FNV64_OFFSET = 0xCBF29CE484222325
FNV64_PRIME = 0x100000001B3
FNV32_OFFSET = 0x811C9DC5
FNV32_PRIME = 0x01000193


def normalize_trade_id(raw_trade_id: str) -> str:
    normalized = unicodedata.normalize("NFKC", raw_trade_id)
    normalized = normalized.strip().lower()
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized


def fnv1a64_utf8(normalized_trade_id: str) -> int:
    value = FNV64_OFFSET
    for byte in normalized_trade_id.encode("utf-8", "strict"):
        value ^= byte
        value = (value * FNV64_PRIME) % (1 << 64)
    return value


def fnv1a32_utf8(normalized_trade_id: str) -> int:
    value = FNV32_OFFSET
    for byte in normalized_trade_id.encode("utf-8", "strict"):
        value ^= byte
        value = (value * FNV32_PRIME) % (1 << 32)
    return value


def base36_lower_unsigned(value: int) -> str:
    if value == 0:
        return "0"

    digits: list[str] = []
    current = value
    while current > 0:
        current, digit = divmod(current, 36)
        digits.append(BASE36_ALPHABET[digit])
    return "".join(reversed(digits))


def make_trade_tag(raw_trade_id: str) -> str:
    normalized = normalize_trade_id(raw_trade_id)
    full_base36 = base36_lower_unsigned(fnv1a64_utf8(normalized))
    if len(full_base36) < TAG_LENGTH:
        full_base36 = full_base36.rjust(TAG_LENGTH, "0")
    return full_base36[-TAG_LENGTH:]


def make_magic_number(raw_trade_id: str) -> int:
    normalized = normalize_trade_id(raw_trade_id)
    suffix = fnv1a32_utf8(normalized) % MAGIC_RANGE
    magic = SYSTEM_PREFIX + suffix
    if magic < 0 or magic > MAX_SIGNED_INT:
        raise ValueError("magic number out of signed 32-bit range")
    return magic


def make_broker_comment(raw_trade_id: str) -> str:
    return f"FRP|v1|t={make_trade_tag(raw_trade_id)}"


def build_trade_identity(raw_trade_id: str) -> dict[str, int | str]:
    normalized = normalize_trade_id(raw_trade_id)
    trade_tag = make_trade_tag(normalized)
    magic_number = make_magic_number(normalized)
    return {
        "normalized_trade_id": normalized,
        "trade_tag": trade_tag,
        "magic_number": magic_number,
        "broker_comment": f"FRP|v1|t={trade_tag}",
        "tag_namespace": 1,
    }