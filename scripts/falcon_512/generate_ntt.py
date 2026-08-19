#!/usr/bin/env python3
"""Verify and generate the Falcon-512 NTT sources used by openzeppelin_account.

The forward roots are derived from q = 12289 and sqrt(-1) = 1479. At each recursive
level, the canonical square root of every previous evaluation point is the smaller
representative of the pair ``r`` and ``q-r``. This fully determines the root order used
by the recursive Falcon transform.

The executable checks cover the root construction, the iterative Cairo engine, inverse
and pointwise-product paths, and the fully unrolled production transform. The generated
operation graph is interval-checked to ensure that felt arithmetic does not wrap and that
every shifted output fits the u128 reduction path.

Run without arguments to execute the checks. Pass ``--write`` to regenerate and format:

    packages/account/src/falcon_512/ntt/{bitrev,roots_felt,roots_scaled,falcon512_fast}.cairo
"""

import argparse
import random
import subprocess
import tomllib
from dataclasses import dataclass
from pathlib import Path


Q = 12289
SQR1 = 1479
I2 = 6145
STARK_PRIME = 2**251 + 17 * 2**192 + 1
SIZES = [2, 4, 8, 16, 32, 64, 128, 256, 512]
QBITS = Q.bit_length()
FWD_GROWTH_BITS = (Q + 1).bit_length()
INV_GROWTH_BITS = (2 * Q).bit_length()
PRODUCT_BITS = 2 * QBITS
SAFE_BITS = 126

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKSPACE_VERSION = tomllib.loads((REPO_ROOT / "Scarb.toml").read_text())["workspace"][
    "package"
]["version"]
NTT_DIR = REPO_ROOT / "packages/account/src/falcon_512/ntt"
BITREV_OUT = NTT_DIR / "bitrev.cairo"
ROOTS_FELT_OUT = NTT_DIR / "roots_felt.cairo"
ROOTS_SCALED_OUT = NTT_DIR / "roots_scaled.cairo"
FAST_OUT = NTT_DIR / "falcon512_fast.cairo"


def derive_forward_roots() -> dict[int, list[int]]:
    """Derive the exact recursive merge-root tables for sizes 2 through 512."""
    canonical_sqrt = {x * x % Q: x for x in range((Q + 1) // 2)}
    tables = {2: [SQR1]}
    points = [SQR1, Q - SQR1]
    for size in SIZES[1:]:
        roots = [canonical_sqrt[point] for point in points]
        tables[size] = roots
        points = [value for root in roots for value in (root, Q - root)]
    return tables


def derive_scaled_inverse_roots(tables: dict[int, list[int]]) -> dict[int, list[int]]:
    return {
        size: [I2 * pow(root, -1, Q) % Q for root in tables[size]] for size in SIZES
    }


def evaluation_points(tables: dict[int, list[int]], size: int) -> list[int]:
    return [value for root in tables[size] for value in (root, Q - root)]


def bitrev_perm(size: int) -> list[int]:
    bits = size.bit_length() - 1
    return [int(f"{index:0{bits}b}"[::-1], 2) for index in range(size)]


def ntt_recursive(values: list[int], tables: dict[int, list[int]]) -> list[int]:
    size = len(values)
    if size == 2:
        product = SQR1 * values[1]
        return [(values[0] + product) % Q, (values[0] - product) % Q]
    even = ntt_recursive(values[0::2], tables)
    odd = ntt_recursive(values[1::2], tables)
    output = []
    for left, right, root in zip(even, odd, tables[size]):
        output.extend(((left + root * right) % Q, (left - root * right) % Q))
    return output


def intt_recursive(values: list[int], tables: dict[int, list[int]]) -> list[int]:
    size = len(values)
    if size == 2:
        return [
            I2 * (values[0] + values[1]) % Q,
            I2 * (values[0] - values[1]) * pow(SQR1, -1, Q) % Q,
        ]
    even = []
    odd = []
    for index, root in enumerate(tables[size]):
        left, right = values[2 * index], values[2 * index + 1]
        even.append(I2 * (left + right) % Q)
        odd.append(I2 * (left - right) * pow(root, -1, Q) % Q)
    even = intt_recursive(even, tables)
    odd = intt_recursive(odd, tables)
    return [coefficient for pair in zip(even, odd) for coefficient in pair]


class Stats:
    def __init__(self) -> None:
        self.max_value = 0

    def see(self, values: list[int]) -> None:
        self.max_value = max(self.max_value, max(values))


def ntt_iterative(values: list[int], tables: dict[int, list[int]], stats: Stats) -> list[int]:
    """Exact integer model of engine.cairo's forward transform and reduction schedule."""
    size = len(values)
    current = [values[index] for index in bitrev_perm(size)]
    bits = QBITS
    bound = Q
    half = 1
    level = 0
    while half != size:
        if bits + FWD_GROWTH_BITS > SAFE_BITS:
            current = [value % Q for value in current]
            bits = QBITS
            bound = Q
        roots = tables[SIZES[level]]
        offset = bound * Q
        output = []
        for block in range(0, size, 2 * half):
            left = current[block : block + half]
            right = current[block + half : block + 2 * half]
            for index, root in enumerate(roots):
                product = root * right[index]
                output.extend((left[index] + product, left[index] + offset - product))
        assert min(output) >= 0
        stats.see(output)
        current = output
        bits += FWD_GROWTH_BITS
        bound *= Q + 1
        half *= 2
        level += 1
    return [value % Q for value in current]


def intt_iterative(
    values: list[int],
    tables: dict[int, list[int]],
    stats: Stats,
    input_bits: int = QBITS,
    input_bound: int = Q,
) -> list[int]:
    """Exact integer model of engine.cairo's inverse transform and reduction schedule."""
    size = len(values)
    scaled = derive_scaled_inverse_roots(tables)
    current = list(values)
    bits = input_bits
    bound = input_bound
    half = size // 2
    level = size.bit_length() - 2
    while True:
        if bits + INV_GROWTH_BITS > SAFE_BITS:
            current = [value % Q for value in current]
            bits = QBITS
            bound = Q
        roots = scaled[SIZES[level]]
        offset = bound * Q
        output = []
        for block in range(0, size, 2 * half):
            odd = []
            for index, root in enumerate(roots):
                left = current[block + 2 * index]
                right = current[block + 2 * index + 1]
                output.append(I2 * (left + right))
                odd.append(root * left + offset - root * right)
            output.extend(odd)
        assert min(output) >= 0
        stats.see(output)
        current = output
        bits += INV_GROWTH_BITS
        bound *= 2 * Q
        if half == 1:
            break
        half //= 2
        level -= 1
    return [current[index] % Q for index in bitrev_perm(size)]


class ConcreteOps:
    @staticmethod
    def mul_const(value: int, constant: int) -> int:
        return value * constant

    @staticmethod
    def add(left: int, right: int) -> int:
        return left + right

    @staticmethod
    def sub(left: int, right: int) -> int:
        return left - right


@dataclass(frozen=True)
class CairoValue:
    name: str
    low: int
    high: int


class CairoOps:
    """Record straight-line Cairo operations together with exact inclusive intervals."""

    def __init__(self) -> None:
        self.lines: list[str] = []
        self.next_id = 0
        self.low = 0
        self.high = Q - 1

    def record(self, expression: str, low: int, high: int) -> CairoValue:
        name = f"v{self.next_id}"
        self.next_id += 1
        self.lines.append(f"    let {name} = {expression};")
        self.low = min(self.low, low)
        self.high = max(self.high, high)
        return CairoValue(name, low, high)

    def mul_const(self, value: CairoValue, constant: int) -> CairoValue:
        return self.record(
            f"{value.name} * {constant}", value.low * constant, value.high * constant
        )

    def add(self, left: CairoValue, right: CairoValue) -> CairoValue:
        return self.record(
            f"{left.name} + {right.name}", left.low + right.low, left.high + right.high
        )

    def sub(self, left: CairoValue, right: CairoValue) -> CairoValue:
        return self.record(
            f"{left.name} - {right.name}", left.low - right.high, left.high - right.low
        )


def ntt_unrolled(values, tables: dict[int, list[int]], ops):
    """Build the recursive NTT operation graph without intermediate modular reductions."""
    size = len(values)
    if size == 2:
        product = ops.mul_const(values[1], SQR1)
        return [ops.add(values[0], product), ops.sub(values[0], product)]
    even = ntt_unrolled(values[0::2], tables, ops)
    odd = ntt_unrolled(values[1::2], tables, ops)
    output = []
    for left, right, root in zip(even, odd, tables[size]):
        product = ops.mul_const(right, root)
        output.extend((ops.add(left, product), ops.sub(left, product)))
    return output


def shift_for_bound(low: int) -> int:
    return 0 if low >= 0 else ((-low + Q - 1) // Q) * Q


def sample_inputs(size: int, rng: random.Random) -> list[list[int]]:
    return [
        [0] * size,
        [Q - 1] * size,
        [1] + [0] * (size - 1),
        list(range(size)),
        *[[rng.randrange(Q) for _ in range(size)] for _ in range(3)],
    ]


def verify(tables: dict[int, list[int]]) -> tuple[CairoOps, list[CairoValue], int]:
    assert SQR1 * SQR1 % Q == Q - 1
    assert I2 * 2 % Q == 1

    for size in SIZES:
        points = evaluation_points(tables, size)
        assert len(points) == size
        assert len(set(points)) == size
        assert all(pow(point, size, Q) == Q - 1 for point in points)

    rng = random.Random(Q)
    stats = Stats()
    for size in SIZES[1:]:
        for values in sample_inputs(size, rng):
            expected = ntt_recursive(values, tables)
            assert ntt_iterative(values, tables, stats) == expected
            assert intt_recursive(expected, tables) == [value % Q for value in values]
            assert intt_iterative(expected, tables, stats) == [value % Q for value in values]

    for _ in range(3):
        left = [rng.randrange(Q) for _ in range(512)]
        right = [rng.randrange(Q) for _ in range(512)]
        left_ntt = ntt_recursive(left, tables)
        right_ntt = ntt_recursive(right, tables)
        products = [a * b for a, b in zip(left_ntt, right_ntt)]
        expected = intt_recursive([value % Q for value in products], tables)
        assert (
            intt_iterative(
                products,
                tables,
                stats,
                input_bits=PRODUCT_BITS,
                input_bound=Q * Q,
            )
            == expected
        )

    points = evaluation_points(tables, 512)
    for basis_index in range(512):
        basis = [0] * 512
        basis[basis_index] = 1
        expected = [pow(point, basis_index, Q) for point in points]
        raw = ntt_unrolled(basis, tables, ConcreteOps())
        assert [value % Q for value in raw] == expected

    trace = CairoOps()
    inputs = [CairoValue(f"f{index}", 0, Q - 1) for index in range(512)]
    outputs = ntt_unrolled(inputs, tables, trace)
    shift = shift_for_bound(trace.low)
    assert shift % Q == 0
    assert min(output.low for output in outputs) + shift >= 0
    assert max(output.high for output in outputs) + shift < 2**128
    assert max(abs(trace.low), trace.high) < STARK_PRIME
    assert stats.max_value < 2**SAFE_BITS

    print("verified deterministic roots and distinct negacyclic evaluation points")
    print("verified iterative NTT, INTT, and unreduced product paths for sizes 4..512")
    print("verified all 512 basis vectors through the generated fast operation graph")
    print(
        f"verified {trace.next_id} generated operations; shifted outputs fit "
        f"{(max(output.high for output in outputs) + shift).bit_length()} bits"
    )
    return trace, outputs, shift


def generated_header(path: Path, description: list[str]) -> str:
    relative = path.relative_to(REPO_ROOT).as_posix()
    lines = [
        "// SPDX-License-Identifier: MIT",
        f"// OpenZeppelin Contracts for Cairo v{WORKSPACE_VERSION} "
        f"({relative.removeprefix('packages/')})",
        "",
        "// Generated by scripts/falcon_512/generate_ntt.py; do not edit by hand.",
        *[f"// {line}" for line in description],
        "// Regenerate with: python3 scripts/falcon_512/generate_ntt.py --write",
        "",
    ]
    return "\n".join(lines) + "\n"


def format_table(name: str, values: list[int], value_type: str) -> str:
    body = ", ".join(str(value) for value in values)
    return f"const {name}: [{value_type}; {len(values)}] = [{body}];\n"


def emit_dispatch(function_name: str, doc: str, names: dict[int, str]) -> str:
    branches = []
    for size in SIZES:
        branches.append(f"    if degree == {size} {{\n        {names[size]}.span()\n    }}")
    return (
        f"\n{doc}pub fn {function_name}(degree: u32) -> Span<felt252> {{\n"
        + " else ".join(branches)
        + ' else {\n        panic!("no root table for degree")\n    }\n}\n'
    )


def render_roots_felt(tables: dict[int, list[int]]) -> str:
    output = [
        generated_header(
            ROOTS_FELT_OUT,
            [
                "Forward merge roots derived recursively from q = 12289 and sqrt(-1) = 1479,",
                "choosing the smaller representative of each modular square-root pair.",
            ],
        ),
        "//! Forward NTT root tables as felts (generated).\n\n",
    ]
    names = {}
    for size in SIZES:
        name = f"phi{2 * size}_roots_zq_felt"
        names[size] = name
        output.append(format_table(name, tables[size], "felt252"))
    output.append(
        emit_dispatch(
            "get_even_roots_felt",
            "/// Forward merge roots for a power-of-two transform degree from 2 through 512.\n",
            names,
        )
    )
    return "".join(output)


def render_roots_scaled(tables: dict[int, list[int]]) -> str:
    scaled = derive_scaled_inverse_roots(tables)
    output = [
        generated_header(
            ROOTS_SCALED_OUT,
            [
                "Inverse roots derived from the deterministic forward roots and prescaled by",
                "I2 = 2^-1 mod q for the inverse transform's split butterflies.",
            ],
        ),
        "//! I2-scaled inverse NTT root tables (generated).\n\n",
    ]
    names = {}
    for size in SIZES:
        name = f"phi{2 * size}_roots_zq_inv_scaled"
        names[size] = name
        output.append(format_table(name, scaled[size], "felt252"))
    output.append(
        emit_dispatch(
            "get_scaled_inv_roots",
            "/// I2-prescaled inverse roots for a power-of-two transform degree from 2 through "
            "512.\n",
            names,
        )
    )
    return "".join(output)


def render_bitrev() -> str:
    return "".join(
        [
            generated_header(
                BITREV_OUT,
                [
                    "Self-inverse bit-reversal permutation for n = 512, used to map between",
                    "natural coefficient order and the recursive transform's leaf order.",
                ],
            ),
            "//! Bit-reversal permutation table (generated).\n\n",
            format_table("BITREV_512", bitrev_perm(512), "u16").replace(
                "const", "pub(crate) const", 1
            ),
            "\n/// The 512-entry bit-reversal permutation as a span.\n",
            "pub fn bitrev_512() -> Span<u16> {\n    BITREV_512.span()\n}\n",
        ]
    )


def wrapped(items: list[str], indent: str = "    ", width: int = 100) -> str:
    lines = []
    current = indent
    for item in items:
        token = f"{item},"
        if len(current) + len(token) + 1 > width and current.strip():
            lines.append(current.rstrip())
            current = indent + token + " "
        else:
            current += token + " "
    if current.strip():
        lines.append(current.rstrip())
    return "\n".join(lines)


def render_fast(
    trace: CairoOps, outputs: list[CairoValue], shift: int
) -> str:
    input_params = [f"f{index}: felt252" for index in range(512)]
    input_names = [f"f{index}" for index in range(512)]
    reduced_names = [f"r{index}" for index in range(512)]
    return_type = "(" + ", ".join("Falcon512Zq" for _ in outputs) + ")"
    output = [
        generated_header(
            FAST_OUT,
            [
                "Fully unrolled Falcon-512 forward NTT for n = 512 and q = 12289.",
                "The generator checks exact integer bounds and reduces each output once.",
            ],
        ),
        "//! Generated Falcon-512 forward NTT.\n//!\n",
        "//! Inputs are 512 coefficients in `[0, 12289)`. The unchecked entry points rely\n",
        "//! on callers to enforce that precondition. Outputs are reduced to the same range.\n\n",
        "use openzeppelin_corelib_imports::bounded_int::{\n",
        "    BoundedInt, DivRemHelper, UnitInt, bounded_int_div_rem, upcast,\n",
        "};\n",
        "use openzeppelin_corelib_imports::integer::{\n",
        "    U128sFromFelt252Result, u128s_from_felt252,\n",
        "};\n\n",
        "type Falcon512Zq = BoundedInt<0, 12288>;\n",
        "type Falcon512Q = UnitInt<12289>;\n",
        "type U128AsBounded = BoundedInt<0, 340282366920938463463374607431768211455>;\n\n",
        "const FALCON512_Q_NZ: NonZero<Falcon512Q> = 12289;\n",
        f"const SHIFT: felt252 = {shift};\n\n",
        "impl Falcon512FastDivRemImpl of DivRemHelper<U128AsBounded, Falcon512Q> {\n",
        "    type DivT = BoundedInt<0, 27689996494502275487295516920153650>;\n",
        "    type RemT = Falcon512Zq;\n",
        "}\n\n",
        "#[inline(always)]\n",
        "fn felt252_as_u128(value: felt252) -> u128 {\n",
        "    // Exact generated bounds put canonical shifted outputs below 2^128.\n",
        "    match u128s_from_felt252(value) {\n",
        "        U128sFromFelt252Result::Narrow(low) => low,\n",
        "        U128sFromFelt252Result::Wide((_, low)) => low,\n",
        "    }\n",
        "}\n\n",
        "#[inline(always)]\n",
        "fn ntt_falcon512_fast_inner(\n",
        wrapped(input_params),
        f"\n) -> {return_type} {{\n",
        "\n".join(trace.lines),
        "\n",
    ]
    for value, name in zip(outputs, reduced_names):
        output.extend(
            [
                f"    let {name}_bounded: U128AsBounded = ",
                f"upcast(felt252_as_u128({value.name} + SHIFT));\n",
                f"    let (_, {name}) = bounded_int_div_rem({name}_bounded, FALCON512_Q_NZ);\n",
            ]
        )
    output.extend(["    (\n", wrapped(reduced_names, "        "), "\n    )\n}\n\n"])
    output.extend(
        [
            "/// Test-only felt wrapper for the generated Falcon-512 forward NTT.\n",
            "#[cfg(test)]\n",
            "pub fn ntt_falcon512_fast_unchecked(mut f: Span<felt252>) -> Array<felt252> {\n",
            "    assert(f.len() == 512, 'fast NTT: bad length');\n",
            "    let boxed = f.multi_pop_front::<512>().unwrap();\n",
            "    let [\n",
            wrapped(input_names, "        "),
            "\n    ] = boxed.unbox();\n",
            "    let (\n",
            wrapped(reduced_names, "        "),
            "\n    ) = ntt_falcon512_fast_inner(\n",
            wrapped(input_names, "        "),
            "\n    );\n",
            "    array![\n",
            wrapped([f"upcast({name})" for name in reduced_names], "        "),
            "\n    ]\n",
            "}\n\n",
            "/// Computes the Falcon-512 forward NTT from canonical `u16` coefficients.\n",
            "///\n",
            "/// Inputs must be in `[0, 12289)`; violating that precondition may return an\n",
            "/// invalid transform. Outputs are reduced to the same range.\n",
            "pub fn ntt_falcon512_fast_u16_unchecked(mut f: Span<u16>) -> Array<u16> {\n",
            "    assert(f.len() == 512, 'fast NTT: bad length');\n",
            "    let boxed = f.multi_pop_front::<512>().unwrap();\n",
            "    let [\n",
            wrapped(input_names, "        "),
            "\n    ] = boxed.unbox();\n",
            "    let (\n",
            wrapped(reduced_names, "        "),
            "\n    ) = ntt_falcon512_fast_inner(\n",
            wrapped([f"{name}.into()" for name in input_names], "        "),
            "\n    );\n",
            "    array![\n",
            wrapped([f"upcast({name})" for name in reduced_names], "        "),
            "\n    ]\n",
            "}\n",
        ]
    )
    return "".join(output)


def write_generated(tables: dict[int, list[int]], trace, outputs, shift: int) -> None:
    rendered = {
        BITREV_OUT: render_bitrev(),
        ROOTS_FELT_OUT: render_roots_felt(tables),
        ROOTS_SCALED_OUT: render_roots_scaled(tables),
        FAST_OUT: render_fast(trace, outputs, shift),
    }
    for path, source in rendered.items():
        path.write_text(source)
        subprocess.run(["scarb", "fmt", str(path)], cwd=REPO_ROOT, check=True)
        print(f"wrote {path.relative_to(REPO_ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="regenerate the Cairo sources")
    args = parser.parse_args()

    tables = derive_forward_roots()
    trace, outputs, shift = verify(tables)
    if args.write:
        write_generated(tables, trace, outputs, shift)


if __name__ == "__main__":
    main()
