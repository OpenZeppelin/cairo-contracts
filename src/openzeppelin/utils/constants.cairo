# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (utils/constants.cairo)

%lang starknet

#
# Numbers
#

const UINT8_MAX = 256

#
# Interface Ids
#

# ERC165
const IERC165_ID = 0x01ffc9a7
const INVALID_ID = 0xffffffff

# Account
const IACCOUNT_ID = 0xf10dbd44

# ERC721
const IERC721_ID = 0x80ac58cd
const IERC721_RECEIVER_ID = 0x150b7a02
const IERC721_METADATA_ID = 0x5b5e139f
const IERC721_ENUMERABLE_ID = 0x780e9d63

# SECP_REM is defined by the equation:
#   secp256k1_prime = 2 ** 256 - SECP_REM.
const SECP_REM = 2 ** 32 + 2 ** 9 + 2 ** 8 + 2 ** 7 + 2 ** 6 + 2 ** 4 + 1

# The following constants represent the size of the secp256k1 curve:
#   n = N0 + BASE * N1 + BASE**2 * N2.
const N0 = 0x8a03bbfd25e8cd0364141
const N1 = 0x3ffffffffffaeabb739abd
const N2 = 0xfffffffffffffffffffff