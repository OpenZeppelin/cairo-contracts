# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.1.0 (token/erc20/utils/TokenTimeLock.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_lt, assert_le
from starkware.cairo.common.uint256 import Uint256, uint256_lt
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import get_block_timestamp, get_contract_address

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

#
# Events
#

@event
func Released(to: felt, value: Uint256):
end

#
# Storage
#

# ERC20 basic token contract being held
@storage_var
func token_() -> (token: felt):
end

# beneficiary of tokens after they are released
@storage_var
func beneficiary_() -> (beneficiary: felt):
end

# timestamp when token release is enabled
@storage_var
func release_time_() -> (release_time: felt):
end

#
# Constructor
# Deploys a timelock instance that is able to hold the token specified, and will only release it to
# `beneficiary` when {release} is invoked after `release_time`. 
# The release time is specified as a Unix timestamp (in seconds).
# 
@constructor
func constructor{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        token: felt,
        beneficiary: felt,
        release_time: felt
    ):
    with_attr error_message("TokenTimeLock: token and beneficiary cannot be set to 0"):
        assert_not_zero(token)
        assert_not_zero(beneficiary)
    end 
    let (current_block_timestamp) = get_block_timestamp()
    with_attr error_message("TokenTimeLock: release time is before current time"):
        assert_lt(current_block_timestamp, release_time)
    end
    token_.write(token)
    beneficiary_.write(beneficiary)
    release_time_.write(release_time)
    return ()
end

#
# Getters
#

# Returns the token being held.
@view
func token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (token: felt):
    let (token) = token_.read()
    return (token)
end

# Returns the beneficiary that will receive the tokens.
@view
func beneficiary{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (beneficiary: felt):
    let (beneficiary) = beneficiary_.read()
    return (beneficiary)
end

# Returns the time when the tokens are released in seconds since Unix epoch (i.e. Unix timestamp).
@view
func release_time{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (release_time: felt):
    let (release_time) = release_time_.read()
    return (release_time)
end

#
# Externals
#

# Transfers tokens held by the timelock to the beneficiary.
# Will only succeed if invoked after the release time.
@external
func release{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (success: felt):
    let (current_block_timestamp) = get_block_timestamp()
    let (release_time) = release_time_.read()
    with_attr error_message("TokenTimeLock: current time is before release time"):
        assert_le(release_time, current_block_timestamp)
    end 
    let (token) = token_.read()
    let (beneficiary) = beneficiary_.read()
    let (contract_address) = get_contract_address()
    let (amount) = IERC20.balanceOf(token, contract_address)
    let (success) = IERC20.transfer(token, beneficiary, amount)
    return (success)
end