import unittest

from check_fixtures import N, Q, encode_signature, hash_to_point, intt, multiply, ntt, pack, unpack
from check_resources import BUDGETS, validate_sizes


class EncodingTests(unittest.TestCase):
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
        validate_sizes(dict(BUDGETS))

    def test_each_budget_rejects_overflow_and_empty_artifacts(self):
        for name, limit in BUDGETS.items():
            for bad_value in (limit + 1, 0):
                with self.subTest(name=name, bad_value=bad_value):
                    values = dict(BUDGETS, **{name: bad_value})
                    with self.assertRaises(ValueError):
                        validate_sizes(values)


if __name__ == "__main__":
    unittest.main()
