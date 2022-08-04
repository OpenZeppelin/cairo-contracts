# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.2.1 (token/erc1155/IERC1155MetadataURI.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IERC1155MetadataURI:

    func uri(id: felt) -> (uri: felt):
    end

end