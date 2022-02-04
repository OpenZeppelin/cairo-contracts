# SPDX-License-Identifier: MIT
# OpenZeppelin Cairo Contracts (IERC165.cairo)

%lang starknet

@contract_interface
namespace IERC165:
    func supportsInterface(interfaceId: felt) -> (success: felt):
    end
end
