# Implementation of the ECDSA signature verification over the secp256k1 elliptic curve.
# The curve is given by the equation
#   y^2 = x^3 + 7
# over the field Z/p for
#   p = secp256k1_prime = 2 ** 256 - (2 ** 32 + 2 ** 9 + 2 ** 8 + 2 ** 7 + 2 ** 6 + 2 ** 4 + 1).
# The size of the curve is
#   n = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141 (prime).
#
# The generator point for the ECDSA is:
#   G = (
#       0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798,
#       0x483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8
#   )
%lang starknet

from openzeppelin.utils.bigint import BASE, BigInt3, bigint_mul, nondet_bigint3, UnreducedBigInt3
from openzeppelin.utils.constants import  N0, N1, N2, SECP_REM

from starkware.cairo.common.math import assert_nn_le, assert_not_zero

# Represents a point on the elliptic curve.
# The zero point is represented using pt.x=0, as there is no point on the curve with this x value.
struct EcPoint:
    member x : BigInt3
    member y : BigInt3
end

# Computes x * s^(-1) modulo the size of the elliptic curve (N).
func mul_s_inv{range_check_ptr}(x : BigInt3, s : BigInt3) -> (res : BigInt3):
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import pack
        from starkware.python.math_utils import div_mod, safe_div

        N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141
        x = pack(ids.x, PRIME) % N
        s = pack(ids.s, PRIME) % N
        value = res = div_mod(x, s, N)
    %}
    let (res) = nondet_bigint3()

    %{ value = k = safe_div(res * s - x, N) %}
    let (k) = nondet_bigint3()

    let (res_s) = bigint_mul(res, s)
    let n = BigInt3(N0, N1, N2)
    let (k_n) = bigint_mul(k, n)

    # We should now have res_s = k_n + x. Since the numbers are in unreduced form,
    # we should handle the carry.

    tempvar carry1 = (res_s.d0 - k_n.d0 - x.d0) / BASE
    assert [range_check_ptr + 0] = carry1 + 2 ** 127

    tempvar carry2 = (res_s.d1 - k_n.d1 - x.d1 + carry1) / BASE
    assert [range_check_ptr + 1] = carry2 + 2 ** 127

    tempvar carry3 = (res_s.d2 - k_n.d2 - x.d2 + carry2) / BASE
    assert [range_check_ptr + 2] = carry3 + 2 ** 127

    tempvar carry4 = (res_s.d3 - k_n.d3 + carry3) / BASE
    assert [range_check_ptr + 3] = carry4 + 2 ** 127

    assert res_s.d4 - k_n.d4 + carry4 = 0

    let range_check_ptr = range_check_ptr + 4

    return (res=res)
end

# Returns the slope of the elliptic curve at the given point.
# The slope is used to compute pt + pt.
# Assumption: pt != 0.
func compute_doubling_slope{range_check_ptr}(pt : EcPoint) -> (slope : BigInt3):
    # Note that y cannot be zero: assume that it is, then pt = -pt, so 2 * pt = 0, which
    # contradicts the fact that the size of the curve is odd.
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P, pack
        from starkware.python.math_utils import div_mod

        # Compute the slope.
        x = pack(ids.pt.x, PRIME)
        y = pack(ids.pt.y, PRIME)
        value = slope = div_mod(3 * x ** 2, 2 * y, SECP_P)
    %}
    alloc_locals
    let (slope : BigInt3) = nondet_bigint3()

    let (x_sqr : UnreducedBigInt3) = unreduced_sqr(pt.x)    
    let (slope_y : UnreducedBigInt3) = unreduced_mul(slope, pt.y)

    verify_zero(
        UnreducedBigInt3(
        d0=3 * x_sqr.d0 - 2 * slope_y.d0,
        d1=3 * x_sqr.d1 - 2 * slope_y.d1,
        d2=3 * x_sqr.d2 - 2 * slope_y.d2))

    return (slope=slope)
end

# Returns the slope of the line connecting the two given points.
# The slope is used to compute pt0 + pt1.
# Assumption: pt0.x != pt1.x (mod secp256k1_prime).
func compute_slope{range_check_ptr}(pt0 : EcPoint, pt1 : EcPoint) -> (slope : BigInt3):
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P, pack
        from starkware.python.math_utils import div_mod

        # Compute the slope.
        x0 = pack(ids.pt0.x, PRIME)
        y0 = pack(ids.pt0.y, PRIME)
        x1 = pack(ids.pt1.x, PRIME)
        y1 = pack(ids.pt1.y, PRIME)
        value = slope = div_mod(y0 - y1, x0 - x1, SECP_P)
    %}
    alloc_locals
    let (slope) = nondet_bigint3()

    let x_diff = BigInt3(d0=pt0.x.d0 - pt1.x.d0, d1=pt0.x.d1 - pt1.x.d1, d2=pt0.x.d2 - pt1.x.d2)      
    let (x_diff_slope : UnreducedBigInt3) = unreduced_mul(x_diff, slope)

    verify_zero(
        UnreducedBigInt3(
        d0=x_diff_slope.d0 - pt0.y.d0 + pt1.y.d0,
        d1=x_diff_slope.d1 - pt0.y.d1 + pt1.y.d1,
        d2=x_diff_slope.d2 - pt0.y.d2 + pt1.y.d2))

    return (slope)
end

# Given a point 'pt' on the elliptic curve, computes pt + pt.
func ec_double{range_check_ptr}(pt : EcPoint) -> (res : EcPoint):
    if pt.x.d0 == 0:
        if pt.x.d1 == 0:
            if pt.x.d2 == 0:
                return (pt)
            end
        end
    end
    alloc_locals
    let (slope : BigInt3) = compute_doubling_slope(pt)
    let (slope_sqr : UnreducedBigInt3) = unreduced_sqr(slope)

    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P, pack

        slope = pack(ids.slope, PRIME)
        x = pack(ids.pt.x, PRIME)
        y = pack(ids.pt.y, PRIME)

        value = new_x = (pow(slope, 2, SECP_P) - 2 * x) % SECP_P
    %}
    let (new_x : BigInt3) = nondet_bigint3()

    %{ value = new_y = (slope * (x - new_x) - y) % SECP_P %}
    let (new_y : BigInt3) = nondet_bigint3()

    verify_zero(
        UnreducedBigInt3(
        d0=slope_sqr.d0 - new_x.d0 - 2 * pt.x.d0,
        d1=slope_sqr.d1 - new_x.d1 - 2 * pt.x.d1,
        d2=slope_sqr.d2 - new_x.d2 - 2 * pt.x.d2))

    let (x_diff_slope : UnreducedBigInt3) = unreduced_mul(
        BigInt3(d0=pt.x.d0 - new_x.d0, d1=pt.x.d1 - new_x.d1, d2=pt.x.d2 - new_x.d2), slope)

    verify_zero(
        UnreducedBigInt3(
        d0=x_diff_slope.d0 - pt.y.d0 - new_y.d0,
        d1=x_diff_slope.d1 - pt.y.d1 - new_y.d1,
        d2=x_diff_slope.d2 - pt.y.d2 - new_y.d2))

    return (EcPoint(new_x, new_y))
end

# Adds two points on the elliptic curve.
# Assumption: pt0.x != pt1.x (however, pt0 = pt1 = 0 is allowed).
# Note that this means that the function cannot be used if pt0 = pt1
# (use ec_double() in this case) or pt0 = -pt1 (the result is 0 in this case).
func fast_ec_add{range_check_ptr}(pt0 : EcPoint, pt1 : EcPoint) -> (res : EcPoint):
    if pt0.x.d0 == 0:
        if pt0.x.d1 == 0:
            if pt0.x.d2 == 0:
                return (pt1)
            end
        end
    end
    if pt1.x.d0 == 0:
        if pt1.x.d1 == 0:
            if pt1.x.d2 == 0:
                return (pt0)
            end
        end
    end
    alloc_locals
    let (slope : BigInt3) = compute_slope(pt0, pt1)
    let (slope_sqr : UnreducedBigInt3) = unreduced_sqr(slope)

    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P, pack

        slope = pack(ids.slope, PRIME)
        x0 = pack(ids.pt0.x, PRIME)
        x1 = pack(ids.pt1.x, PRIME)
        y0 = pack(ids.pt0.y, PRIME)

        value = new_x = (pow(slope, 2, SECP_P) - x0 - x1) % SECP_P
    %}
    let (new_x : BigInt3) = nondet_bigint3()

    %{ value = new_y = (slope * (x0 - new_x) - y0) % SECP_P %}
    let (new_y : BigInt3) = nondet_bigint3()

    verify_zero(
        UnreducedBigInt3(
        d0=slope_sqr.d0 - new_x.d0 - pt0.x.d0 - pt1.x.d0,
        d1=slope_sqr.d1 - new_x.d1 - pt0.x.d1 - pt1.x.d1,
        d2=slope_sqr.d2 - new_x.d2 - pt0.x.d2 - pt1.x.d2))

    let (x_diff_slope : UnreducedBigInt3) = unreduced_mul(
        BigInt3(d0=pt0.x.d0 - new_x.d0, d1=pt0.x.d1 - new_x.d1, d2=pt0.x.d2 - new_x.d2), slope)

    verify_zero(
        UnreducedBigInt3(
        d0=x_diff_slope.d0 - pt0.y.d0 - new_y.d0,
        d1=x_diff_slope.d1 - pt0.y.d1 - new_y.d1,
        d2=x_diff_slope.d2 - pt0.y.d2 - new_y.d2))

    return (EcPoint(new_x, new_y))
end

# Same as fast_ec_add, except that the cases pt0 = ±pt1 are supported.
func ec_add{range_check_ptr}(pt0 : EcPoint, pt1 : EcPoint) -> (res : EcPoint):
    let x_diff = BigInt3(d0=pt0.x.d0 - pt1.x.d0, d1=pt0.x.d1 - pt1.x.d1, d2=pt0.x.d2 - pt1.x.d2)
    let (same_x : felt) = is_zero(x_diff)
    if same_x == 0:
        # pt0.x != pt1.x so we can use fast_ec_add.
        return fast_ec_add(pt0, pt1)
    end

    # We have pt0.x = pt1.x. This implies pt0.y = ±pt1.y.
    # Check whether pt0.y = -pt1.y.
    let y_sum = BigInt3(d0=pt0.y.d0 + pt1.y.d0, d1=pt0.y.d1 + pt1.y.d1, d2=pt0.y.d2 + pt1.y.d2)
    let (opposite_y : felt) = is_zero(y_sum)
    if opposite_y != 0:
        # pt0.y = -pt1.y.
        # Note that the case pt0 = pt1 = 0 falls into this branch as well.
        let ZERO_POINT = EcPoint(BigInt3(0, 0, 0), BigInt3(0, 0, 0))
        return (ZERO_POINT)
    else:
        # pt0.y = pt1.y.
        return ec_double(pt0)
    end
end

# Given 0 <= m < 250, a scalar and a point on the elliptic curve, pt,
# verifies that 0 <= scalar < 2**m and returns (2**m * pt, scalar * pt).
func ec_mul_inner{range_check_ptr}(pt : EcPoint, scalar : felt, m : felt) -> (
        pow2 : EcPoint, res : EcPoint):
    if m == 0:
        assert scalar = 0
        let ZERO_POINT = EcPoint(BigInt3(0, 0, 0), BigInt3(0, 0, 0))
        return (pow2=pt, res=ZERO_POINT)
    end

    alloc_locals
    let (double_pt : EcPoint) = ec_double(pt)
    %{ memory[ap] = (ids.scalar % PRIME) % 2 %}
    jmp odd if [ap] != 0; ap++
    return ec_mul_inner(pt=double_pt, scalar=scalar / 2, m=m - 1)

    odd:
    let (local inner_pow2 : EcPoint, inner_res : EcPoint) = ec_mul_inner(
        pt=double_pt, scalar=(scalar - 1) / 2, m=m - 1)
    # Here inner_res = (scalar - 1) / 2 * double_pt = (scalar - 1) * pt.
    # Assume pt != 0 and that inner_res = ±pt. We obtain (scalar - 1) * pt = ±pt =>
    # scalar - 1 = ±1 (mod N) => scalar = 0 or 2.
    # In both cases (scalar - 1) / 2 cannot be in the range [0, 2**(m-1)), so we get a
    # contradiction.
    let (res : EcPoint) = fast_ec_add(pt0=pt, pt1=inner_res)
    return (pow2=inner_pow2, res=res)
end

func ec_mul{range_check_ptr}(pt : EcPoint, scalar : BigInt3) -> (res : EcPoint):
    alloc_locals
    let (pow2_0 : EcPoint, local res0 : EcPoint) = ec_mul_inner(pt, scalar.d0, 86)
    let (pow2_1 : EcPoint, local res1 : EcPoint) = ec_mul_inner(pow2_0, scalar.d1, 86)
    let (_, local res2 : EcPoint) = ec_mul_inner(pow2_1, scalar.d2, 84)
    let (res : EcPoint) = ec_add(res0, res1)
    let (res : EcPoint) = ec_add(res, res2)
    return (res)
end

# Verifies that val is in the range [1, N).
func validate_signature_entry{range_check_ptr}(val : BigInt3)-> ():
    assert_nn_le(val.d2, N2)
    assert_nn_le(val.d1, BASE - 1)
    assert_nn_le(val.d0, BASE - 1)

    if val.d2 == N2:
        if val.d1 == N1:
            assert_nn_le(val.d0, N0 - 1)
            return ()
        end
        assert_nn_le(val.d1, N1 - 1)
        return ()
    end

    if val.d2 == 0:
        if val.d1 == 0:
            # Make sure val > 0.
            assert_not_zero(val.d0)
            return ()
        end
    end
    return ()
end

# Verifies a Secp256k1 ECDSA signature.
# Soundness assumptions:
# * public_key_pt is on the curve.
# * All the limbs of public_key_pt.x, public_key_pt.y, msg_hash are in the range [0, 3 * BASE).
func verify_ecdsa{range_check_ptr}(
        public_key_pt : EcPoint, 
        msg_hash : BigInt3, 
        r : BigInt3, 
        s : BigInt3) -> ():
    alloc_locals

    validate_signature_entry(r)
    validate_signature_entry(s)
    # curve generation point
    let gen_pt = EcPoint(
        BigInt3(0xe28d959f2815b16f81798, 0xa573a1c2c1c0a6ff36cb7, 0x79be667ef9dcbbac55a06),
        BigInt3(0x554199c47d08ffb10d4b8, 0x2ff0384422a3f45ed1229a, 0x483ada7726a3c4655da4f))

    # Compute u1 and u2.
    let (u1 : BigInt3) = mul_s_inv(msg_hash, s)
    let (u2 : BigInt3) = mul_s_inv(r, s)

    let (gen_u1) = ec_mul(gen_pt, u1)
    let (pub_u2) = ec_mul(public_key_pt, u2)
    let (res) = ec_add(gen_u1, pub_u2)

    # The following assert also implies that res is not the zero point.
    assert res.x = r
    return ()
end

# Multiplies two values modulo the secp256k1 prime.
# The returned limbs may be above 3 * BASE.
#
# If each of the input limbs is in the range (-x, x), the result's limbs are guaranteed to be
# in the range (-x**2 * (2 ** 35.01), x**2 * (2 ** 35.01)).
#
# This means that if unreduced_mul is called on the result of nondet_bigint3, or the difference
# between two such results, we have:
#   Soundness guarantee: the limbs are in the range (-2**208.6, 2**208.6).
#   Completeness guarantee: the limbs are in the range (-2**207.01, 2**207.01).
func unreduced_mul(a : BigInt3, b : BigInt3) -> (res_low : UnreducedBigInt3):
    # The result of the product is:
    #   sum_{i, j} a.d_i * b.d_j * BASE**(i + j)
    # Since we are computing it mod secp256k1_prime, we replace the term
    #   a.d_i * b.d_j * BASE**(i + j)
    # where i + j >= 3 with
    #   a.d_i * b.d_j * BASE**(i + j - 3) * 4 * SECP_REM
    # since BASE ** 3 = 4 * SECP_REM (mod secp256k1_prime).
    return (
        UnreducedBigInt3(
        d0=a.d0 * b.d0 + (a.d1 * b.d2 + a.d2 * b.d1) * (4 * SECP_REM),
        d1=a.d0 * b.d1 + a.d1 * b.d0 + (a.d2 * b.d2) * (4 * SECP_REM),
        d2=a.d0 * b.d2 + a.d1 * b.d1 + a.d2 * b.d0))
end

# Computes the square of the given value modulo the secp256k1 prime.
# It has the same guarantees as in unreduced_mul(a, a).
func unreduced_sqr(a : BigInt3) -> (res_low : UnreducedBigInt3):
    tempvar twice_d0 = a.d0 * 2
    return (
        UnreducedBigInt3(
        d0=a.d0 * a.d0 + (a.d1 * a.d2) * (2 * 4 * SECP_REM),
        d1=twice_d0 * a.d1 + (a.d2 * a.d2) * (4 * SECP_REM),
        d2=twice_d0 * a.d2 + a.d1 * a.d1))
end

# Verifies that the given unreduced value is equal to zero modulo the secp256k1 prime.
# Completeness assumption: val's limbs are in the range (-2**210.99, 2**210.99).
# Soundness assumption: val's limbs are in the range (-2**250, 2**250).
func verify_zero{range_check_ptr}(val : UnreducedBigInt3):
    let q = [ap]
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P
        q, r = divmod(pack(ids.val, PRIME), SECP_P)
        assert r == 0, f"verify_zero: Invalid input {ids.val.d0, ids.val.d1, ids.val.d2}."
        ids.q = q % PRIME
    %}
    let q_biased = [ap + 1]
    q_biased = q + 2 ** 127; ap++
    [range_check_ptr] = q_biased; ap++

    tempvar r1 = (val.d0 + q * SECP_REM) / BASE
    assert [range_check_ptr + 1] = r1 + 2 ** 127
    # This implies r1 * BASE = val.d0 + q * SECP_REM (as integers).

    tempvar r2 = (val.d1 + r1) / BASE
    assert [range_check_ptr + 2] = r2 + 2 ** 127
    # This implies r2 * BASE = val.d1 + r1 (as integers).
    # Therefore, r2 * BASE**2 = val.d1 * BASE + r1 * BASE.

    assert val.d2 = q * (BASE / 4) - r2
    # This implies q * BASE / 4 = val.d2 + r2 (as integers).
    # Therefore,
    #   q * BASE**3 / 4 = val.d2 * BASE**2 + r2 * BASE ** 2 =
    #   val.d2 * BASE**2 + val.d1 * BASE + r1 * BASE =
    #   val.d2 * BASE**2 + val.d1 * BASE + val.d0 + q * SECP_REM =
    #   val + q * SECP_REM.
    # Hence, val = q * (BASE**3 / 4 - SECP_REM) = q * (2**256 - SECP_REM).

    let range_check_ptr = range_check_ptr + 3
    return ()
end

# Returns 1 if x == 0 (mod secp256k1_prime), and 0 otherwise.
func is_zero{range_check_ptr}(x : BigInt3) -> (res : felt):
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P, pack
        x = pack(ids.x, PRIME) % SECP_P
    %}
    %{ memory[ap] = int(x == 0) %}
    tempvar x_is_zero
    if x_is_zero != 0:
        verify_zero(UnreducedBigInt3(d0=x.d0, d1=x.d1, d2=x.d2))
        return (res=1)
    end

    %{
        from starkware.cairo.common.cairo_secp.secp_utils import SECP_P
        from starkware.python.math_utils import div_mod

        value = x_inv = div_mod(1, x, SECP_P)
    %}
    let (x_inv) = nondet_bigint3()
    let (x_x_inv) = unreduced_mul(x, x_inv)

    # Check that x * x_inv = 1 to verify that x != 0.
    verify_zero(UnreducedBigInt3(
        d0=x_x_inv.d0 - 1,
        d1=x_x_inv.d1,
        d2=x_x_inv.d2))
    return (res=0)
end