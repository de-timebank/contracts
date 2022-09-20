%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.signature import verify_ecdsa_signature

from lib.helper.common import Cheatcode, Helper

struct Signature:
    member r : felt
    member s : felt
end

@contract_interface
namespace TOKEN:
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

    func transfer_from(sender : felt, recipient : felt, amount : felt) -> (success : felt):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : felt):
    end

    func approve(spender: felt, amount: felt) -> (success: felt):
    end

    func approve_to_operator(
         owner : felt, amount : felt) -> (success : felt):
    end
end

const ACCOUNT_INIT_BALANCE = 2000

@external
func __setup__{syscall_ptr : felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> ():
    %{
        context.contract = {
            "minter": 0,
            "address": 0
        }

        context.accounts = [
            181218,
            12345    
        ]

        context.contract["minter"] = 3314416161471744589729114412533623747627160421759877225912647569974596485346

        context.contract["address"] = deploy_contract("./src/token/erc20x.cairo", {
            "owner": 12345,
            "name" : "TIMETOKEN",
            "symbol": "TIME",
            "decimals": 18,
            "initial_supply": 100000000,
            "recipient": context.contract["minter"]
        }).contract_address
    %}  

    __setup_account__()

    return ()
end

func __setup_account__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():

    alloc_locals

    local accounts: felt*

    tempvar token_address
    tempvar minter

    %{
        from starkware.crypto.signature.signature import private_to_stark_key

        ids.token_address = context.contract['address']
        ids.minter = context.contract['minter']

        ids.accounts = accounts = segments.add()

        for i, sk in enumerate(context.accounts):
            public_address = private_to_stark_key(sk)
            memory[accounts + i] = public_address

        stop_prank = start_prank(ids.minter, ids.token_address)
    %}
    
    TOKEN.transfer(
        token_address,
        accounts[0],
        ACCOUNT_INIT_BALANCE
    )

    TOKEN.transfer(
        token_address,
        accounts[1],
        ACCOUNT_INIT_BALANCE
    )

    %{ stop_prank() %}

    let (balance1) = TOKEN.balance_of(
        token_address,
        accounts[0]
    )

    let (balance2) = TOKEN.balance_of(
        token_address,
        accounts[1]
    )

    let (minter_balance) = TOKEN.balance_of(
        token_address,
        minter
    )

    assert minter_balance = 100000000 - ACCOUNT_INIT_BALANCE * 2
    assert balance1 = ACCOUNT_INIT_BALANCE
    assert balance2 = ACCOUNT_INIT_BALANCE

    %{
        print("-------------------------------------------")
        print(f"Account funded with 2000 tokens :- ")
        print(f"1. {memory[accounts]}")
        print(f"2. {memory[accounts + 1]}")
    %}

    return ()
end

@external
func test_setup{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return ()
end

@external
func test_create_contract{syscall_ptr : felt*, range_check_ptr}():
    tempvar minter 
    tempvar contract_address

    %{ 
        ids.minter = context.contract['minter']
        ids.contract_address = context.contract['address'] 
    %}

    let (total_supply) = TOKEN.total_supply(contract_address)
    let (name) = TOKEN.name(contract_address)
    let (symbol) = TOKEN.symbol(contract_address)
    let (decimals) = TOKEN.decimals(contract_address)

    assert decimals = 18
    assert symbol = 'TIME'
    assert name = 'TIMETOKEN'
    assert total_supply = 100000000

    return ()
end

@external
func test_transfer{syscall_ptr : felt*, range_check_ptr}():
    let transfer_amount = 100

    tempvar sender
    tempvar recipient
    tempvar contract_address

    %{
        from starkware.crypto.signature.signature import private_to_stark_key

        ids.contract_address = context.contract['address']

        sender_sk = context.accounts[0]
        ids.sender = private_to_stark_key(sender_sk)
        
        recipient_sk = context.accounts[1]
        ids.recipient = private_to_stark_key(recipient_sk)

        start_prank(ids.sender, ids.contract_address)
    %}

    TOKEN.transfer(contract_address=contract_address, recipient=recipient, amount=transfer_amount)

    let (recipient_balance) = TOKEN.balance_of(contract_address=contract_address, account=recipient)

    let (sender_balance) = TOKEN.balance_of(contract_address=contract_address, account=sender)

    assert recipient_balance = ACCOUNT_INIT_BALANCE + transfer_amount
    assert sender_balance = ACCOUNT_INIT_BALANCE - transfer_amount

    return ()
end

@external
func test_transfer_with_insufficient_balance{syscall_ptr : felt*, range_check_ptr}():
    let transfer_amount = 10000000000000000000

    tempvar sender
    tempvar recipient
    tempvar contract_address

    %{
        from starkware.crypto.signature.signature import private_to_stark_key

        ids.contract_address = context.contract['address']

        sender_sk = context.accounts[0]
        ids.sender = private_to_stark_key(sender_sk)
        
        recipient_sk = context.accounts[1]
        ids.recipient = private_to_stark_key(recipient_sk)

        start_prank(ids.sender, ids.contract_address)
    %}

    %{ expect_revert(error_message="ERC20: transfer amount exceeds balance") %}

    TOKEN.transfer(contract_address=contract_address, recipient=recipient, amount=transfer_amount)

    return ()
end

@external
func test_approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let amount = 100

    tempvar owner
    tempvar spender
    tempvar contract_address

    %{
        from starkware.crypto.signature.signature import private_to_stark_key

        ids.contract_address = context.contract['address']
        ids.owner = private_to_stark_key(context.accounts[0])
        ids.spender = private_to_stark_key(context.accounts[1])
    %}

    # Cheatcode.start_prank_on_contract(owner,  contract_address)

    %{ stop_prank = start_prank(ids.owner,  ids.contract_address) %}
    
    TOKEN.approve(
        contract_address,
        spender,
        amount
    )

    %{ stop_prank() %}

    let (allowance) = TOKEN.allowance(
        contract_address,
        owner,
        spender
    )

    assert allowance = amount

    return ()
end

@external
func test_spend_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    test_approve()

    let amount = 100
    let recipient = 987654321

    tempvar owner
    tempvar contract_address

    %{
        from starkware.crypto.signature.signature import private_to_stark_key

        ids.contract_address = context.contract['address']
        ids.owner = private_to_stark_key(context.accounts[0])
    %}

    let (owner_balance_before) = TOKEN.balance_of(
        contract_address,
        owner
    )

    let (recipient_balance_before) = TOKEN.balance_of(
        contract_address,
        recipient
    )

    %{ 
        spender = private_to_stark_key(context.accounts[1])
        stop_prank = start_prank(spender, ids.contract_address) 
    %}

    TOKEN.transfer_from(
        contract_address,
        owner,
        recipient,
        amount
    )

    %{ stop_prank() %}

    let (recipient_balance) = TOKEN.balance_of(
        contract_address,
        recipient
    )

    let (owner_balance) = TOKEN.balance_of(
        contract_address,
        owner
    )

    assert owner_balance = owner_balance_before - amount
    assert recipient_balance = recipient_balance_before + amount

    return ()
end
