import json
import unittest
from pathlib import Path
from unittest.mock import patch

from check_fixtures import (
    N, Q, check_cairo_parameters, encode_signature, hash_to_point, intt,
    multiply, ntt, pack, unpack,
)
from check_resources import (
    BUDGETS, MAX_BYTECODE_FELTS, MAX_CLASS_BYTES, serialized_class_size, validate_sizes,
)


class EncodingTests(unittest.TestCase):
    def test_reference_parameters_match_cairo(self):
        check_cairo_parameters()

    def test_parameter_mismatch_is_rejected(self):
        read_text = Path.read_text
        for filename, old, new in (
            ("zq.cairo", "Q: u16 = 12289", "Q: u16 = 12287"),
            ("falcon.cairo", "34034726", "34034727"),
            ("packing.cairo", "PACKED_SLOTS: u32 = 29", "PACKED_SLOTS: u32 = 30"),
            ("verifier_impls.cairo", "SALT_FELTS: u32 = 2", "SALT_FELTS: u32 = 3"),
        ):
            with self.subTest(filename=filename):
                def changed_source(path, *args, **kwargs):
                    source = read_text(path, *args, **kwargs)
                    return source.replace(old, new) if path.name == filename else source

                with patch.object(Path, "read_text", changed_source):
                    with self.assertRaisesRegex(ValueError, "expected"):
                        check_cairo_parameters()

    def test_packing_round_trip_at_bounds(self):
        for values in ([0] * N, [Q - 1] * N, [i % Q for i in range(N)]):
            self.assertEqual(unpack(pack(values)), values)

    def test_noncanonical_limbs_preserve_digits_but_are_rejected(self):
        for index, extra in ((0, Q**9), (0, Q**9 << 128), (28, Q**8), (28, 1 << 128)):
            packed = pack([1] * N)
            packed[index] += extra
            with self.assertRaises(ValueError):
                unpack(packed)

    def test_invalid_shapes_and_ranges(self):
        for values in ([], [Q] * N, [-1] * N):
            with self.assertRaises(ValueError):
                pack(values)
        for values in ([], [0] * 30, [-1] * 29):
            with self.assertRaises(ValueError):
                unpack(values)
        with self.assertRaises(ValueError):
            hash_to_point(-1, bytes(40))
        with self.assertRaises(ValueError):
            encode_signature([0] * N, [0] * N, bytes(41), hint=True)

    def test_transform_and_negacyclic_product(self):
        values = [i * 7 % Q for i in range(N)]
        self.assertEqual(intt(ntt(values)), values)
        x = [0, 1] + [0] * (N - 2)
        last = [0] * (N - 1) + [1]
        self.assertEqual(multiply(x, last), [Q - 1] + [0] * (N - 1))

    def test_signature_layouts_share_the_direct_prefix(self):
        h, s1, salt = [1] * N, [0] * N, bytes(range(40))
        direct = encode_signature(h, s1, salt, hint=False)
        hinted = encode_signature(h, s1, salt, hint=True)
        self.assertEqual(len(direct), 31)
        self.assertEqual(len(hinted), 60)
        self.assertEqual(hinted[:31], direct)
        self.assertEqual(direct[29].to_bytes(20, "little"), salt[:20])
        self.assertEqual(direct[30].to_bytes(20, "little"), salt[20:])

    def test_hash_to_point_reference(self):
        salt = (1).to_bytes(20, "little") + (2).to_bytes(20, "little")
        point = hash_to_point(3, salt)
        self.assertEqual(point[:8], [2750, 10132, 11472, 1877, 11061, 11208, 12103, 6446])
        self.assertEqual(len(point), N)


class ResourceTests(unittest.TestCase):
    def test_limits_accept_exact_budget(self):
        validate_sizes(dict(BUDGETS, class_bytes=MAX_CLASS_BYTES))

    def test_each_budget_rejects_overflow_and_empty_artifacts(self):
        for name, limit in BUDGETS.items():
            for bad_value in (limit + 1, 0):
                with self.subTest(name=name, bad_value=bad_value):
                    values = dict(BUDGETS, class_bytes=1, **{name: bad_value})
                    with self.assertRaisesRegex(ValueError, "budget"):
                        validate_sizes(values)

    def test_protocol_limits_are_checked_before_budgets(self):
        for name, cap in (("sierra_felts", MAX_BYTECODE_FELTS),
                          ("casm_felts", MAX_BYTECODE_FELTS), ("class_bytes", MAX_CLASS_BYTES)):
            with self.subTest(name=name):
                values = dict(BUDGETS, class_bytes=1)
                values[name] = cap + 1
                with self.assertRaisesRegex(ValueError, "declaration limit"):
                    validate_sizes(values)

    def test_protocol_limits_accept_the_exact_boundary(self):
        with patch.dict(BUDGETS, sierra_felts=MAX_BYTECODE_FELTS, casm_felts=MAX_BYTECODE_FELTS):
            validate_sizes(dict(BUDGETS, class_bytes=MAX_CLASS_BYTES))

    def test_serialized_class_uses_string_abi_and_omits_debug_info(self):
        artifact = {
            "sierra_program": ["0x1"], "contract_class_version": "0.1.0",
            "entry_points_by_type": {"EXTERNAL": [], "L1_HANDLER": [], "CONSTRUCTOR": []},
            "abi": [{"type": "function", "name": "validate"}],
            "sierra_program_debug_info": {"type_names": []},
        }
        declared = {k: v for k, v in artifact.items() if k != "sierra_program_debug_info"}
        declared["abi"] = json.dumps(artifact["abi"])
        expected = len(json.dumps(declared, separators=(",", ":")).encode())
        self.assertEqual(serialized_class_size(artifact), expected)
        self.assertEqual(serialized_class_size(declared), expected)


if __name__ == "__main__":
    unittest.main()
