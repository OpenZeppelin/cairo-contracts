"""Regression checks for the packed transform's generation-time safety conditions."""

import unittest
from unittest.mock import patch

import generate_ntt as g


class PackedBoundsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables = g.derive_forward_roots()
        trace = g.CairoOps()
        cls.outputs = g.ntt_unrolled(
            [g.CairoValue(f"f{i}", 0, g.Q - 1) for i in range(512)], cls.tables, trace,
        )
        cls.shift = g.shift_for_bound(trace.low)

    def test_shift_must_preserve_residues_and_nonnegativity(self):
        for shift in (self.shift + 1, 0, -g.Q):
            with self.subTest(shift=shift), self.assertRaises(AssertionError):
                g.packed_bounds(self.outputs, shift)

    def test_radix_must_separate_channels_and_avoid_field_wrap(self):
        maximum = max(value.high + self.shift for value in self.outputs)
        for radix in (maximum, 2**128):
            with self.subTest(radix=radix), self.assertRaises(AssertionError):
                g.packed_bounds(self.outputs, self.shift, radix)

    def test_remainder_quotient_must_fit_u128(self):
        # This radix still gives a packed output below P but needs a wider quotient.
        with self.assertRaises(AssertionError):
            g.packed_bounds(self.outputs, self.shift, 2**126)

    def test_signed_node_interval_cannot_alias_field_elements(self):
        for sign in (-1, 1):
            value = g.CairoValue("x", sign * (g.STARK_PRIME // 2),
                                 sign * (g.STARK_PRIME // 2))
            with self.subTest(sign=sign), self.assertRaises(AssertionError):
                g.BoundedCairoOps().mul_const(value, 2)

    def test_native_remainders_at_channel_and_key_boundaries(self):
        maximum, offset, _, _ = g.packed_bounds(self.outputs, self.shift)
        for low in (0, 1, maximum, g.PACKED_RADIX - 1):
            for high in (0, 1, maximum):
                for key in (0, 1, g.Q - 1, 2**16 - 1):
                    difference = low * key + offset - high
                    self.assertGreaterEqual(difference, 0)
                    self.assertLess(difference // g.Q, 2**128)
                    self.assertEqual(difference % g.Q, (low * key - high) % g.Q)

    def test_graph_rejects_oversized_inputs(self):
        with patch.object(g, "PACKED_RADIX", 2**130), self.assertRaises(AssertionError):
            g.render_packed(self.tables, self.outputs, self.shift)


if __name__ == "__main__":
    unittest.main()
