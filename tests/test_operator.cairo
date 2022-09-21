%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from src.Operator import ServiceCommitment
from lib.helper.common import Helper, Cheatcode

@contract_interface
namespace Main:
    func create_commitment(
        request_id : felt,
        requestor : felt,
        provider : felt,
        amount : felt,
    ) -> (bool):
    end

    func complete_commitment(request_id : felt) -> (bool):
    end

    func get_commitment_of(request_id : felt) -> (commitment : ServiceCommitment):
    end

    func get_token_address() -> (contract_address : felt):
    end

    func get_owner() -> (address):
    end
end

@contract_interface
namespace TOKEN:
    func allowance(owner : felt, spender : felt) -> (remaining : felt):
    end

    func transfer(recipient : felt, amount : felt) -> (success : felt):
    end

    func balance_of(account : felt) -> (balance : felt):
    end

    func set_operator_address(address):
    end

    func get_operator()  -> (address):
    end
end

const ACCOUNT_1_SK = 181218
const ACCOUNT_2_SK = 12345

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    
):  
    alloc_locals
    local token_address
    local operator_address
    
    let (this) = get_contract_address()

    %{ 
        contract = {
            "owner": 0,
            "address": 0,
            "token_address": 0,
        }

        contract["owner"] = 3314416161471744589729114412533623747627160421759877225912647569974596485346

        ids.token_address = contract["token_address"] = deploy_contract("./src/TimeToken.cairo", {
            "owner": contract["owner"],
            "name" : "TIMETOKEN",
            "symbol": "TIME",
            "decimals": 18,
            "initial_supply": 100000000,
            "recipient": contract["owner"]
        }).contract_address

        ids.operator_address = contract["address"] = deploy_contract("./src/Operator.cairo", 
        {
            "owner": contract["owner"],
            "token_address": contract["token_address"]
        }).contract_address


        print("Contract   | Address")
        print("MAIN       | ", hex(contract["address"]))
        print("TIMETOKEN  | ", hex(contract["token_address"]))
        print("THIS       | ", hex(ids.this))

        context.contract = contract
        
    %}

    %{ stop_prank = start_prank(context.contract["owner"], ids.token_address)%}

    TOKEN.set_operator_address(
        contract_address=token_address,
        address=operator_address    
    )

    %{ stop_prank() %}

    __setup_account__()

    return ()
end

func __setup_account__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}():

    let amount = 2000

    tempvar token_address
    tempvar owner

    %{
        ids.token_address = context.contract['token_address']
        ids.owner = context.contract['owner']
    %}
    
    let (account1) = Helper.create_address(ACCOUNT_1_SK)
    let (account2) = Helper.create_address(ACCOUNT_2_SK)

    # Cheatcode.start_prank_on_contract(owner, token_address)
    
    %{ stop_prank = start_prank(context.contract["owner"], ids.token_address)%}

    TOKEN.transfer(
        token_address,
        account1,
        amount
    )

    TOKEN.transfer(
        token_address,
        account2,
        amount   
    )

    %{ stop_prank() %}

    let (balance1) = TOKEN.balance_of(
        token_address,
        account1
    )

    let (balance2) = TOKEN.balance_of(
        token_address,
        account2
    )

    let (owner_balance) = TOKEN.balance_of(
        token_address,
        owner
    )

    assert owner_balance = 100000000 - amount * 2
    assert balance1 = amount
    assert balance2 = amount

    %{
        print("-------------------------------------------")
        print(f"Account funded with 2000 tokens :- ")
        print(f"1. {ids.account1}")
        print(f"2. {ids.account2}")
    %}

    return ()
end

@external
func test_deploy_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    
):  
    tempvar operator_address 
    tempvar token_address
    tempvar owner

    %{ 
        ids.operator_address = context.contract["address"]
        ids.token_address = context.contract["token_address"] 
        ids.owner = context.contract["owner"]
    %}

    let (_owner) = Main.get_owner(
        operator_address
    )

    let (_token_address) = Main.get_token_address(
        operator_address
    )

    let (_operator_address) = TOKEN.get_operator(
        contract_address=token_address
    )

    assert owner = _owner
    assert token_address = _token_address
    assert operator_address = _operator_address

    return ()
end

@external
func test_create_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():  
    let amount = 690
    let request_id = 0x03d71275146e09c853bdbf180c329a404b27259b4029d66d8c6f38619286a05b 

    alloc_locals 

    let (local requestor) = Helper.create_address(ACCOUNT_1_SK)
    let (local provider) = Helper.create_address(ACCOUNT_2_SK)

    _test_create_commitment(
        request_id,
        requestor,
        provider,
        amount,
    )
    
    return ()    
end

@external
func test_fail_create_commitment_with_existing_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    alloc_locals 
    
    test_create_commitment()
    
    let amount = 90
    let request_id = 0x03d71275146e09c853bdbf180c329a404b27259b4029d66d8c6f38619286a05b

    let (local requestor) = Helper.create_address(ACCOUNT_1_SK)
    let (local provider) = Helper.create_address(ACCOUNT_2_SK)

    %{ expect_revert(error_message=f"OPERATOR: Commitment for request ID `{ids.request_id}` already exists.")%}

    _test_create_commitment(
        request_id,
        requestor,
        provider,
        amount,
    )

    return ()   
end

func _test_create_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    request_id,
    requestor,
    provider,
    amount,
):
    alloc_locals

    local operator_address
    local token_address
    local owner
    
    %{
        ids.operator_address = context.contract['address']
        ids.token_address = context.contract['token_address']
        ids.owner = context.contract['owner']
    %}

    %{ 
        operator_stop_prank = start_prank(ids.owner, ids.operator_address)
        token_stop_prank = start_prank(ids.operator_address, ids.token_address)
    %}

    Main.create_commitment(
        operator_address,
        request_id,
        requestor,
        provider,
        amount,
    )

    %{ 
        operator_stop_prank() 
        token_stop_prank()
    %}

    let (operator_allowance) = TOKEN.allowance(
        token_address,
        requestor,
        operator_address 
    )

    assert operator_allowance = amount

    return ()
end

@external
func test_complete_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    
):
    let request_id = 0x03d71275146e09c853bdbf180c329a404b27259b4029d66d8c6f38619286a05b

    test_create_commitment()

    _complete_commitment(request_id)

    return ()
end

@external
func test_fail_complete_already_completed_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
):
    let request_id = 0x03d71275146e09c853bdbf180c329a404b27259b4029d66d8c6f38619286a05b

    test_complete_commitment()

    %{ expect_revert(error_message="OPERATOR: Service commitment has already been completed.") %}

    _complete_commitment(request_id)

    return ()  
end

@external
func _complete_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    request_id
):
    alloc_locals
    local operator_address
    local token_address
    local owner 
    
    %{
        ids.operator_address = context.contract['address']
        ids.token_address = context.contract['token_address']
        ids.owner = context.contract['owner']
    %}

    let (commitment: ServiceCommitment) = Main.get_commitment_of(
        operator_address,
        request_id
    )

    let (operator_allowance_before) = TOKEN.allowance(
        token_address,
        commitment.requestor,
        operator_address    
    )

    let (provider_balance_before) = TOKEN.balance_of(
        token_address,
        commitment.provider
    )
    
    %{ 
        operator_stop_prank = start_prank(ids.owner, ids.operator_address)
        token_stop_prank = start_prank(ids.operator_address, ids.token_address)
    %}
    
    Main.complete_commitment(
        operator_address,
        request_id
    )

    %{ 
        operator_stop_prank()
        token_stop_prank()
    %}

    let (operator_allowance) = TOKEN.allowance(
        token_address,
        commitment.requestor,
        owner
    )

    let (provider_balance) = TOKEN.balance_of(
        token_address,
        commitment.provider
    )

    assert commitment.is_completed + 1 = TRUE
    assert provider_balance = provider_balance_before + commitment.amount
    assert operator_allowance = operator_allowance_before - commitment.amount

    return ()
end