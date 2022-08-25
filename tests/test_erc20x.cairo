%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.signature import verify_ecdsa_signature

@contract_interface
namespace ERC20:
    func total_supply() -> (totalSupply : felt):
    end

    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func balance_of(account : felt) -> (balance : felt):
    end

    func transfer(recipient : felt, amount : felt) -> (success : felt):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : felt):
    end

    func delegate_approve(
        spender : felt, amount : felt, owner : felt, message : felt, owner_signature : (felt, felt)
    ) -> (success : felt):
    end
end

func before{syscall_ptr : felt*, range_check_ptr}() -> (contract_address : felt):
    %{
        from starkware.crypto.signature.signature import (
            private_to_stark_key, 
        )

        private_key = 12345
        owner = private_to_stark_key(private_key)

        start_prank(owner)
    %}

    alloc_locals

    local contract_address : felt

    let (caller_addr) = get_caller_address()
    let token_name = 'TIMETOKEN'
    let token_symbol = 'TIME'

    %{
        args = [
            ids.token_name,
            ids.token_symbol,
            18,
            500000,
            ids.caller_addr
        ]

        ids.contract_address = deploy_contract("./src/token/erc20x.cairo", args).contract_address
    %}

    return (contract_address)
end

@external
func test_create_contract{syscall_ptr : felt*, range_check_ptr}():
    let (contract_address) = before()

    let (caller) = get_caller_address()

    let (total_supply) = ERC20.total_supply(contract_address)
    let (name) = ERC20.name(contract_address)
    let (symbol) = ERC20.symbol(contract_address)
    let (decimals) = ERC20.decimals(contract_address)
    let (balance) = ERC20.balance_of(contract_address, caller)

    assert decimals = 18
    assert symbol = 'TIME'
    assert balance = 1000
    assert name = 'TIMETOKEN'
    assert total_supply = 1000

    return ()
end

@external
func test_transfer{syscall_ptr : felt*, range_check_ptr}():
    let (contract_address) = before()
    let (caller) = get_caller_address()

    %{
        start_prank(
                   caller_address=123,
                   target_contract_address=ids.contract_address
               )
    %}

    ERC20.transfer(contract_address=contract_address, recipient=321, amount=20)

    let (recipient_balance) = ERC20.balance_of(contract_address=contract_address, account=321)

    let (sender_balance) = ERC20.balance_of(contract_address=contract_address, account=caller)

    assert recipient_balance = 20
    assert sender_balance = 1000 - 20

    return ()
end

@external
func test_delegate_approve{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals

    local owner
    local message_hash
    local signature : (felt, felt)

    let (local contract_address) = before()

    let message = 'collatz conjecture'

    %{
        from starkware.crypto.signature.signature import (
            pedersen_hash, private_to_stark_key, sign
        )

        private_key = 12345
        message_hash = pedersen_hash(ids.message)
        signature = sign(message_hash, private_key)

        # create starknet key from private_key
        ids.owner = private_to_stark_key(private_key)
        ids.message_hash = message_hash  

        memory[(fp + 2)] = signature[0]
        memory[(fp + 2) + 1] = signature[1]

        # ids.signature[0] = signature[0]
        # ids.signature[1] = signature[1]

        print(f'Public key : {ids.owner}')
        print(f'Message hash : {message_hash}')
        print("Signature :- ")
        print(f'\tr: {signature[0]}')
        print(f'\ts: {signature[1]}')
    %}

    let spender = 321
    let allowance = 69420

    ERC20.delegate_approve(
        contract_address=contract_address,
        spender=spender,
        amount=allowance,
        owner=owner,
        message=message_hash,
        owner_signature=signature,
    )

    let (approved_allowance) = ERC20.allowance(contract_address, owner, spender)

    assert allowance = approved_allowance

    return ()
end

@external
func test_delegate_approve_with_invalid_sign{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}():
    alloc_locals

    local owner
    local message_hash
    local fake_signature : (felt, felt)

    let (local contract_address) = before()

    let message = 'amogus'

    %{
        from starkware.crypto.signature.signature import (
            pedersen_hash, private_to_stark_key, sign
        )

        # address of the true owner of the token to be approved
        private_key = 12345
        ids.owner = private_to_stark_key(private_key)

        # create a fake key for the invalid sign
        sk = 999
        ids.message_hash = pedersen_hash(ids.message)
        signature = sign(ids.message_hash, sk)

        memory[(fp + 2)] = signature[0]
        memory[(fp + 2) + 1] = signature[1]
    %}

    let spender = 321
    let allowance = 69420

    %{ expect_revert(error_message="Invalid signature") %}

    ERC20.delegate_approve(
        contract_address, spender, allowance, owner, message_hash, fake_signature
    )

    return ()
end
