%lang starknet

from starkware.cairo.common.uint256 import Uint256, assert_uint256_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.math import assert_nn, assert_le_felt
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from src.token.i_budi_credit import IBudiCredit
from openzeppelin.access.ownable.library import Ownable

struct ServiceCommitment {
    requestor: felt,
    provider: felt,
    amount: Uint256,
    is_completed: felt,
}

//
// EVENTS
//

@event
func service_committed(request_id: felt, requestor: felt, provider: felt, amount: felt) {
}

@event
func commitment_completed(request_id: felt, timestamp: felt) {
}

//
// STORAGE VARS
//

@storage_var
func commitments(request_id: felt) -> (commitment: ServiceCommitment) {
}

@storage_var
func credit_contract_address() -> (contract_address: felt) {
}

//
// CONSTRUCTOR
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, credit_class_hash: felt
) {
    Ownable.initializer(owner);

    let (this) = get_contract_address();

    let (calldata) = alloc();
    assert calldata[0] = this;

    // deploy new erc20 token here
    let (contract_address) = deploy(
        class_hash=credit_class_hash,
        contract_address_salt=0,
        constructor_calldata_size=1,
        constructor_calldata=calldata,
        deploy_from_zero=0,
    );

    credit_contract_address.write(value=contract_address);

    return ();
}

//
// EXTERNALS
//

@external
func mint_for_new_user{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt
) {
    Ownable.assert_only_owner();
    let (credit_address) = credit_contract_address.read();
    IBudiCredit.new_user_mint(contract_address=credit_address, recipient=recipient);
    return ();
}

@external
func create_commitment{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    request_id: felt, requestor: felt, provider: felt, amount: Uint256
) -> (bool: felt) {
    Ownable.assert_only_owner();

    // check if requestor has enough balance
    with_attr error_message("BUDI OPERATOR: requestor balance is insufficient") {
        let (token_address) = credit_contract_address.read();
        let (balance: Uint256) = IBudiCredit.balanceOf(
            contract_address=token_address, account=requestor
        );
        assert_uint256_le(amount, balance);
    }

    let (this) = get_contract_address();
    let (token_address) = credit_contract_address.read();

    // approve `amount` of allowance to this contract
    IBudiCredit.operator_delegate_approve(
        contract_address=token_address, requestor=requestor, amount=amount
    );

    // create new commitment
    commitments.write(
        request_id,
        ServiceCommitment(
        requestor=requestor, provider=provider, amount=amount, is_completed=FALSE
        ),
    );

    return (TRUE,);
}

@external
func complete_commitment{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(request_id: felt) -> (bool: felt) {
    Ownable.assert_only_owner();

    let (commitment: ServiceCommitment) = commitments.read(request_id);

    // set service state to TRUE
    commitments.write(
        request_id,
        ServiceCommitment(
        requestor=commitment.requestor,
        provider=commitment.provider,
        amount=commitment.amount,
        is_completed=TRUE,
        ),
    );

    // transfer `amount` to `provider`
    let (token_address) = credit_contract_address.read();

    IBudiCredit.transferFrom(
        contract_address=token_address,
        sender=commitment.requestor,
        recipient=commitment.provider,
        amount=commitment.amount,
    );

    return (TRUE,);
}

//
// VIEWS
//

@view
func get_commitment_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    request_id: felt
) -> (commitment: ServiceCommitment) {
    let (commitment: ServiceCommitment) = commitments.read(request_id);
    return (commitment,);
}

@view
func get_token_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    contract_address: felt
) {
    let (contract_address) = credit_contract_address.read();
    return (contract_address,);
}
