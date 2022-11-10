%lang starknet

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from src.i_budi_operator import IBudiOperator
from src.token.i_budi_credit import IBudiCredit
from src.budi_operator import ServiceCommitment

const owner_address = 0x03c5f6712775ac575E0a89D0933e8A6754dDcDB6d00bbE237c13C8756AFB5d6B;

@storage_var
func operator_address() -> (res: felt) {
}

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar _operator_address;
    %{
        token_class_hash = declare("src/token/budi_credit.cairo").class_hash
        operator_address = deploy_contract("src/budi_operator.cairo", {
            "owner" : ids.owner_address,
            "credit_class_hash" : token_class_hash
        }).contract_address

        ids._operator_address = operator_address
    %}
    operator_address.write(value=_operator_address);

    return ();
}

@external
func test_mint_for_new_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let new_user_address = 0x123456789;

    let (operator_contract) = operator_address.read();
    let (token_address) = IBudiOperator.get_token_address(contract_address=operator_contract);

    %{ stop_prank   = start_prank(ids.owner_address, ids.operator_contract) %}

    IBudiOperator.mint_for_new_user(contract_address=operator_contract, recipient=new_user_address);

    %{ stop_prank() %}

    let (user_balance: Uint256) = IBudiCredit.balanceOf(
        contract_address=token_address, account=new_user_address
    );

    assert user_balance.low = 10;
    assert user_balance.high = 0;

    return ();
}

@external
func test_create_commitment{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    test_mint_for_new_user();

    let req_id = 0x1231512;
    let requestor = 0x123456789;
    let provider = 0x666;
    let amount = Uint256(5, 0);

    let (operator_contract) = operator_address.read();

    %{ stop_prank = start_prank(ids.owner_address, ids.operator_contract) %}

    IBudiOperator.create_commitment(
        contract_address=operator_contract,
        request_id=req_id,
        requestor=requestor,
        provider=provider,
        amount=amount,
    );

    %{ stop_prank() %}
    return ();
}

@external
func test_fail_create_commitment_insufficient_balance{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    let req_id = 0x1231512;
    let requestor = 0x123456789;
    let provider = 0x666;
    let amount = Uint256(5, 0);

    let (operator_contract) = operator_address.read();

    %{
        stop_prank = start_prank(ids.owner_address, ids.operator_contract)
        expect_revert(error_message="BUDI OPERATOR: requestor balance is insufficient")
    %}

    IBudiOperator.create_commitment(operator_contract, req_id, requestor, provider, amount);

    %{ stop_prank() %}
    return ();
}

@external
func test_complete_commitment{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    test_create_commitment();

    let req_id = 0x1231512;
    let (operator_contract) = operator_address.read();

    %{ stop_prank = start_prank(ids.owner_address, ids.operator_contract) %}

    IBudiOperator.complete_commitment(operator_contract, req_id);

    %{ stop_prank() %}

    let (commitment: ServiceCommitment) = IBudiOperator.get_commitment_of(
        operator_contract, req_id
    );

    let (token_address) = IBudiOperator.get_token_address(contract_address=operator_contract);

    let (p_balance: Uint256) = IBudiCredit.balanceOf(contract_address=token_address, account=0x666);

    assert commitment.is_completed = TRUE;
    assert p_balance = Uint256(5, 0);

    return ();
}
