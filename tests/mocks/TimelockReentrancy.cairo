# SPDX-License-Identifier: MIT

%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.alloc import alloc

from openzeppelin.account.library import AccountCallArray

const AMOUNT = 5
const SALT = 5417

@contract_interface
namespace ITimelock:
    func execute(
        call_array_len: felt,
        call_array: AccountCallArray*,
        calldata_len: felt,
        calldata: felt*,
        predecessor: felt,
        salt: felt,
    ):
    end
end

@storage_var
func balance() -> (res : felt):
end

@storage_var
func count() -> (res : felt):
end

@external
func increase_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(amount : felt):
    alloc_locals

    # initial balance increase
    let (res) = balance.read()
    balance.write(res + amount)

    # checks number of calls
    let (_count) = count.read()
    if _count != 0:
        return ()
    end
    count.write(1)

    let (sender : felt) = get_caller_address()
    let (self : felt) = get_contract_address()

    let (call_array : AccountCallArray*) = alloc()
    assert call_array[0] = AccountCallArray(
        to=self,
        selector=1530486729947006463063166157847785599120665941190480211966374137237989315360,
        data_offset=0,
        data_len=1
    )

    let (calldata : felt*) = alloc()
    assert calldata[0] = AMOUNT

    # reentrant call
    ITimelock.execute(sender, 1, call_array, 1, calldata, 0, SALT)
    return ()
end

@view
func get_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (res : felt):
    let (res) = balance.read()
    return (res)
end
