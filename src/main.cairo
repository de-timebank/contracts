%lang starknet

from starkware.cairo.common.math import assert_nn, assert_le_felt
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from starkware.cairo.common.signature import verify_ecdsa_signature

struct Signature:
    member r : felt
    member s : felt
end

@contract_interface
namespace TOKEN:
    func balance_of(account : felt) -> (balance : felt):
    end

    func approve(spender : felt, amount : felt) -> (success : felt):
    end

    func approve_to_operator(
        owner : felt, amount : felt
    ) -> (success : felt):
    end

    func transfer_from(sender : felt, recipient : felt, amount : felt) -> (success : felt):
    end
end

struct ServiceCommitment:
    member requestor : felt
    member provider : felt
    member amount : felt
    member is_completed : felt
    # member requestor_signature: felt
    # member provider_signature: felt
end

@storage_var
func _owner() -> (address):
end

@storage_var
func _service_commitment(request_id : felt) -> (commitment : ServiceCommitment):
end

@storage_var
func _time_token_address() -> (address):
end

@storage_var
func _commitment_is_exists(request_id) -> (bool):
end


#
# 	Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner, token_address
):
    _owner.write(owner)
    _time_token_address.write(token_address)
    return ()
end

@external
func create_commitment{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    request_id : felt,
    requestor : felt,
    provider : felt,
    amount : felt,
) -> (bool):
    _owner_only()

    _check_if_commitment_exist(request_id)
    
    # check if requestor has enough balance
    with_attr error_message("OPERATOR: REQUESTOR BALANCE IS INSUFFICIENT"):
        let (token_address) = _time_token_address.read()
        let (balance) = TOKEN.balance_of(contract_address=token_address, account=requestor)
        assert_le_felt(amount, balance)
    end

    # let (operator_address) = get_contract_address()

    # approve `amount` of allowance to server`s contract account
    TOKEN.approve_to_operator(
        contract_address=token_address,
        owner=requestor,
        amount=amount,
    )

    # create new commitment
    let new_commitment = ServiceCommitment(
        requestor=requestor, provider=provider, amount=amount, is_completed=FALSE
    )

    _service_commitment.write(request_id, new_commitment)

    _commitment_is_exists.write(request_id, TRUE)

    return (TRUE)
end

@external
func complete_commitment{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(request_id : felt) -> (bool):
    alloc_locals

    _owner_only()

    let (commitment : ServiceCommitment) = get_commitment_of(request_id)

    with_attr error_message("OPERATOR: SERVICE COMMITMENT HAS ALREADY BEEN COMPLETED"):
        assert commitment.is_completed = FALSE
    end

    # set service state to TRUE
    let new_commitment = ServiceCommitment(
        requestor=commitment.requestor,
        provider=commitment.provider,
        amount=commitment.amount,
        is_completed=TRUE,
    )

    _service_commitment.write(request_id, new_commitment)

    # transfer `amount` to `provider`

    let (token_address) = get_token_address()

    TOKEN.transfer_from(
        contract_address=token_address,
        sender=commitment.requestor,
        recipient=commitment.provider,
        amount=commitment.amount,
    )

    return (TRUE)
end

#
#   Getter
#

@view
func get_commitment_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    request_id : felt
) -> (commitment : ServiceCommitment):
    let (commitment : ServiceCommitment) = _service_commitment.read(request_id)
    return (commitment)
end

@view
func get_token_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    address
):
    let (contract_address) = _time_token_address.read()
    return (contract_address)
end

@view
func get_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (address):
    let (address) = _owner.read()
    return (address)
end

#
# 	Internal
#

func _owner_only{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    with_attr error_message("OPERATOR: CALLER IS NOT THE CONTRACT OWNER"):
        let (caller) = get_caller_address()
        let (owner) = _owner.read()
        assert caller = owner
    end

    return ()
end

func _check_if_commitment_exist{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(request_id):
    with_attr error_message("OPERATOR: COMMITMENT OF REQUEST ID {request_id} ALREADY EXISTS"):
        let (is_exist) = _commitment_is_exists.read(request_id)
        assert is_exist = FALSE
    end
    return ()
end