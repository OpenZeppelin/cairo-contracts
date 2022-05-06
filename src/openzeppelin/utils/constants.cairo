# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts v0.1.0 (utils/constants.cairo)

%lang starknet

#
# Booleans
#

const TRUE = 1
const FALSE = 0

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

# AccessControl
const IACCESSCONTROL_ID = 0x7965db0b

# Timelock
const DONE_TIMESTAMP = 1
const TIMELOCK_ADMIN_ROLE = 0x5f58e3a2316349923ce3780f8d587db2d72378aed66a8261c916544fa6846ca5
const PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1
const CANCELLER_ROLE = 0xfd643c72710c63c0180259aba6b2d05451e3591a24e58b62239378085726f783
const EXECUTOR_ROLE = 0xd8aa0f3194971a2a116679f7c2090f6939c8d4e01a2a8d7e41d55e5351469e63
