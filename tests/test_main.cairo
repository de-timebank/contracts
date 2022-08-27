%lang starknet

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin

from src.main import Signature, ServiceCommitment
from lib.helper.common import Helper, Cheatcode

@contract_interface
namespace Main:
    func create_commitment(
        request_id : felt,
        requestor : felt,
        provider : felt,
        amount : felt,
        message : felt,
        requestor_signature : Signature,
        provider_signature : Signature,
    ) -> (bool):
    end

    func complete_commitment(request_id : felt, message : felt, requestor_signature : Signature) -> (bool):
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
end

const ACCOUNT_1_SK = 181218
const ACCOUNT_2_SK = 12345

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    
):  
    %{ 
        contract = {
            "owner": 0,
            "address": 0,
            "token_address": 0,
        }

        contract["owner"] = 3314416161471744589729114412533623747627160421759877225912647569974596485346

        contract["token_address"] = deploy_contract("./src/token/erc20x.cairo", {
            "name" : "TIMETOKEN",
            "symbol": "TIME",
            "decimals": 18,
            "initial_supply": 100000000,
            "recipient": contract["owner"]
        }).contract_address

        contract["address"] = deploy_contract("./src/main.cairo", 
        {
            "owner": contract["owner"],
            "token_address": contract["token_address"]
        }).contract_address


        print("Contract   | Address")
        print("MAIN       | ", contract["address"])
        print("TIMETOKEN  | ", contract["token_address"])

        context.contract = contract
        
    %}

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

    Cheatcode.start_prank_on_contract(owner, token_address)

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
    tempvar contract_address
    tempvar token_address
    tempvar owner

    %{ 
        ids.contract_address = context.contract["address"]
        ids.token_address = context.contract["token_address"] 
        ids.owner = context.contract["owner"]
    %}

    let (_owner) = Main.get_owner(
        contract_address
    )

    let (_token_address) = Main.get_token_address(
        contract_address
    )

    assert owner = _owner
    assert token_address = _token_address

    return ()
end

@external
func test_create_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():  
    let amount = 690
    let request_id = 1

    alloc_locals 

    let (message) = Helper.pedersen_hash('field elements')

    let (local requestor) = Helper.create_address(ACCOUNT_1_SK)
    let (local req_sign: Signature) = Helper.sign(ACCOUNT_1_SK, message)

    let (local provider) = Helper.create_address(ACCOUNT_2_SK)
    let (local prov_sign: Signature) = Helper.sign(ACCOUNT_2_SK, message)

    _test_create_commitment(
        request_id,
        requestor,
        provider,
        amount,
        message,
        req_sign,
        prov_sign
    )
    
    return ()    
end

@external
func test_create_commitment_with_invalid_signature{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    
):  
    let amount = 690
    let request_id = 1

    alloc_locals 

    let (message) = Helper.pedersen_hash('field elements')

    let (local requestor) = Helper.create_address(ACCOUNT_1_SK)
    let (local req_sign: Signature) = Helper.sign(123123, message)

    let (local provider) = Helper.create_address(ACCOUNT_2_SK)
    let (local prov_sign: Signature) = Helper.sign(ACCOUNT_2_SK, message)

    %{ expect_revert(error_message="TOKEN: UNAUTHORIZED FOR DELEGATE APPROVE") %}

    _test_create_commitment(
        request_id,
        requestor,
        provider,
        amount,
        message,
        req_sign,
        prov_sign
    )
    
    return ()
end

func _test_create_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    request_id,
    requestor,
    provider,
    amount,
    message,
    requestor_signature: Signature,
    provider_signature: Signature
):
    alloc_locals

    local contract_address
    local token_address
    local owner
    
    %{
        ids.contract_address = context.contract['address']
        ids.token_address = context.contract['token_address']
        ids.owner = context.contract['owner']
    %}

    Cheatcode.start_prank_on_contract(
        owner,
        contract_address
    )

    Main.create_commitment(
        contract_address,
        request_id,
        requestor,
        provider,
        amount,
        message,
        requestor_signature,
        provider_signature
    )

    let (owner_allowance) = TOKEN.allowance(
        token_address,
        requestor,
        owner
    )

    assert owner_allowance = amount

    return ()
end

@external
func test_complete_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    
):
    let request_id = 1
    
    alloc_locals

    test_create_commitment()

    local contract_address
    local owner
    
    %{
        ids.contract_address = context.contract['address']
        ids.owner = context.contract['owner']
    %}

    let (message) = Helper.pedersen_hash('field elements')
    let (local requestor_signature: Signature) = Helper.sign(ACCOUNT_1_SK, message)
    
    Main.complete_commitment(
        contract_address,
        request_id,
        message,
        requestor_signature
    )

    let (commitment: ServiceCommitment) = Main.get_commitment_of(
        contract_address,
        request_id
    )

    assert commitment.is_completed = TRUE

    return ()
end