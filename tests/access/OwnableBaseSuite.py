import pytest
from signers import MockSigner
from utils import (
    ZERO_ADDRESS,
    assert_event_emitted,
)


signer = MockSigner(123456789987654321)


class OwnableBase:
    @pytest.mark.asyncio
    async def test_constructor(self, contract_factory):
        ownable, owner, *_ = contract_factory
        expected = await ownable.owner().call()
        assert expected.result.owner == owner.contract_address


    @pytest.mark.asyncio
    async def test_transferOwnership(self, contract_factory):
        ownable, owner, *_ = contract_factory
        new_owner = 123
        await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [new_owner])
        executed_info = await ownable.owner().call()
        assert executed_info.result == (new_owner,)


    @pytest.mark.asyncio
    async def test_transferOwnership_emits_event(self, contract_factory):
        ownable, owner, *_ = contract_factory
        new_owner = 123
        tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'transferOwnership', [new_owner])

        assert_event_emitted(
            tx_exec_info,
            from_address=ownable.contract_address,
            name='OwnershipTransferred',
            data=[
                owner.contract_address,
                new_owner
            ]
        )


    @pytest.mark.asyncio
    async def test_renounceOwnership(self, contract_factory):
        ownable, owner, *_ = contract_factory
        await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])
        executed_info = await ownable.owner().call()
        assert executed_info.result == (ZERO_ADDRESS,)


    @pytest.mark.asyncio
    async def test_renounceOwnership_emits_event(self, contract_factory):
        ownable, owner, *_ = contract_factory
        tx_exec_info = await signer.send_transaction(owner, ownable.contract_address, 'renounceOwnership', [])

        assert_event_emitted(
            tx_exec_info,
            from_address=ownable.contract_address,
            name='OwnershipTransferred',
            data=[
                owner.contract_address,
                ZERO_ADDRESS
            ]
        )
