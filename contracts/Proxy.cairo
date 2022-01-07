%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import delegate_call

@storage_var
func impl_address() -> (address : felt):
end

@external
func constructor{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(impl_address_ : felt):
    impl_address.write(value=impl_address_)
    return ()
end

@external
func __default__{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        selector: felt,
        calldata_len: felt,
        calldata: felt*
    ) -> (
        retdata_len: felt,
        retdata: felt*
    ):
    let (address) = impl_address.read()

    let (retdata_size: felt, retdata: felt*) = delegate_call(
        contract_address=address,
        function_selector=selector,
        calldata_size=calldata_len,
        calldata=calldata
    )

    return (retdata_len=retdata_size, retdata=retdata)
end
