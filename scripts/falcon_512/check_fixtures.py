#!/usr/bin/env python3
"""Reference encoding and independent checks for the committed Falcon test vectors.

The encoder accepts decoded coefficient-domain keys and signature polynomials;
it does not implement key generation, sampling, or a production signer. Existing
vectors came from tprest/falcon.py; their original secret keys/seeds are not recorded
with the fixtures.
Checking them does not reproduce the signer's randomness or certify FN-DSA compliance.
"""

import hashlib
import re
from pathlib import Path

from generate_ntt import Q, derive_forward_roots, evaluation_points


N = 512
PRIME = 2**251 + 17 * 2**192 + 1
NORM_BOUND = 34_034_726
FIXTURES = Path(__file__).resolve().parents[2] / "packages/test_common/src/falcon_512"


def pack(values: list[int]) -> list[int]:
    if len(values) != N or any(not 0 <= value < Q for value in values):
        raise ValueError("expected 512 canonical residues")
    output = []
    for start in range(0, N, 18):
        low = sum(value * Q**i for i, value in enumerate(values[start:start + 9]))
        high = sum(value * Q**i for i, value in enumerate(values[start + 9:start + 18]))
        output.append(low + (high << 128))
    return output


def unpack(packed: list[int]) -> list[int]:
    if len(packed) != 29 or any(not 0 <= value < PRIME for value in packed):
        raise ValueError("expected 29 field elements")
    values = []
    for index, value in enumerate(packed):
        high, low = divmod(value, 2**128)
        widths = (9, 9) if index < 28 else (8, 0)
        for limb, width in zip((low, high), widths):
            if limb >= Q**width:
                raise ValueError("noncanonical packed limb")
            for _ in range(width):
                limb, coefficient = divmod(limb, Q)
                values.append(coefficient)
    return values


def ntt(values: list[int]) -> list[int]:
    """Evaluate the polynomial directly, independently of the Cairo butterfly graph."""
    if len(values) != N:
        raise ValueError("expected degree 512")
    output = []
    for point in evaluation_points(derive_forward_roots(), N):
        result = 0
        for value in reversed(values):
            result = (result * point + value) % Q
        output.append(result)
    return output


def intt(values: list[int]) -> list[int]:
    """Invert by orthogonality of the roots of x^512 + 1."""
    if len(values) != N:
        raise ValueError("expected degree 512")
    output = [0] * N
    for value, point in zip(values, evaluation_points(derive_forward_roots(), N)):
        factor = 1
        inverse = pow(point, -1, Q)
        for i in range(N):
            output[i] = (output[i] + value * factor) % Q
            factor = factor * inverse % Q
    scale = pow(N, -1, Q)
    return [value * scale % Q for value in output]


def multiply(left: list[int], right: list[int]) -> list[int]:
    """Schoolbook negacyclic multiplication, independent of either NTT implementation."""
    if len(left) != N or len(right) != N:
        raise ValueError("expected degree 512")
    output = [0] * N
    for i, a in enumerate(left):
        for j, b in enumerate(right):
            if i + j < N:
                output[i + j] += a * b
            else:
                output[i + j - N] -= a * b
    return [value % Q for value in output]


def hash_to_point(message: int, salt: bytes) -> list[int]:
    if not 0 <= message < PRIME or len(salt) != 40:
        raise ValueError("expected a message felt and 40-byte salt")
    shake = hashlib.shake_256(salt + message.to_bytes(32, "little"))
    size = 2 * N
    while True:
        stream = shake.digest(size)
        words = [int.from_bytes(stream[i:i + 2], "big") for i in range(0, size, 2)]
        values = [word % Q for word in words if word < 5 * Q]
        if len(values) >= N:
            return values[:N]
        size += 136


def encode_public_key(h: list[int]) -> list[int]:
    if len(h) != N or any(not 0 <= value < Q for value in h):
        raise ValueError("expected a canonical coefficient-domain public key")
    return pack(ntt(h))


def encode_signature(h: list[int], s1: list[int], salt: bytes, *, hint: bool) -> list[int]:
    if len(salt) != 40 or len(s1) != N or any(not -(Q // 2) <= v <= Q // 2 for v in s1):
        raise ValueError("expected a 40-byte salt and 512 centered signature coefficients")
    if len(h) != N or any(not 0 <= value < Q for value in h):
        raise ValueError("expected a canonical coefficient-domain public key")
    signature = pack([value % Q for value in s1])
    signature += [int.from_bytes(salt[:20], "little"), int.from_bytes(salt[20:], "little")]
    if hint:
        signature += pack(multiply(s1, h))
    return signature


def center(value: int) -> int:
    value %= Q
    return value if value <= Q // 2 else value - Q


def read_function(path: Path, name: str) -> list[int]:
    match = re.search(rf"pub fn {name}\(\).*?\{{(.*?)\n\}}", path.read_text(), re.S)
    if match is None:
        raise ValueError(f"missing fixture function {name}")
    return [int(value, 0) for value in re.findall(r"0x[0-9a-f]+|\b[0-9]+\b", match[1])]


def main() -> None:
    fixture = FIXTURES / "fixture.cairo"
    rotation = FIXTURES / "rotation_fixture.cairo"
    cases = [(fixture, "public_key", "signature", "msg")]
    cases += [(rotation, "new_public_key", name + "_signature", name + "_hash")
              for name in ("accept_ownership", "second_accept_ownership", "outside_execution")]
    for path, key_name, signature_name, message_name in cases:
        key = read_function(path, key_name)
        signature = read_function(path, signature_name)
        message, = read_function(path, message_name)
        h = intt(unpack(key))
        s1 = [center(value) for value in unpack(signature[:29])]
        salt = b"".join(value.to_bytes(20, "little") for value in signature[29:31])
        if encode_public_key(h) != key or encode_signature(h, s1, salt, hint=True) != signature:
            raise ValueError(f"{signature_name}: encoding or product-hint mismatch")
        point = hash_to_point(message, salt)
        product = multiply(s1, h)
        norm = sum(center(c - p)**2 + s**2 for c, p, s in zip(point, product, s1))
        if norm > NORM_BOUND:
            raise ValueError(f"{signature_name}: signature norm {norm} exceeds {NORM_BOUND}")
        print(f"{path.name}:{signature_name}: encoding, product and norm verified ({norm})")


if __name__ == "__main__":
    main()
