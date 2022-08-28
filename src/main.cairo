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

#
# 	Constructor
#

@contract_interface
namespace TOKEN:
    func balance_of(account : felt) -> (balance : felt):
    end

    func approve(spender : felt, amount : felt) -> (success : felt):
    end

    func delegate_approve(
        owner : felt,
        spender : felt, 
        amount : felt, 
        message : felt, 
        owner_signature : Signature
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
    message : felt,
    requestor_signature : Signature,
    provider_signature : Signature,
) -> (bool):
    _owner_only()

    # check if requestor has enough balance
    with_attr error_message("MAIN: REQUESTOR BALANCE IS INSUFFICIENT"):
        let (token_address) = _time_token_address.read()
        let (balance) = TOKEN.balance_of(contract_address=token_address, account=requestor)
        assert_le_felt(amount, balance)
    end

    # with_attr error_message("SERVICE REQUEST: INVALID SIGNATURE FOR PROVIDER"):
    #     verify_ecdsa_signature()
    # end

    # let (caller) = get_caller_address()
    let (contract_owner) = _owner.read()

    # approve `amount` of allowance to server`s contract account
    TOKEN.delegate_approve(
        contract_address=token_address,
        owner=requestor,
        spender=contract_owner,
        amount=amount,
        message=message,
        owner_signature=requestor_signature,
    )

    # create new commitment
    let new_commitment = ServiceCommitment(
        requestor=requestor, provider=provider, amount=amount, is_completed=FALSE
    )

    _service_commitment.write(request_id, new_commitment)

    return (TRUE)
end

@external
func complete_commitment{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(request_id : felt, message : felt, requestor_signature : Signature) -> (bool):
    alloc_locals

    let (commitment : ServiceCommitment) = get_commitment_of(request_id)

    # verify signature
    with_attr error_message("MAIN: UNAUTHORIZED DUE TO INVALID SIGNATURE"):
        verify_ecdsa_signature(
            message=message,
            public_key=commitment.requestor,
            signature_r=requestor_signature.r,
            signature_s=requestor_signature.s,
        )
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
    with_attr error_message("SERVICE REQUEST : CALLER IS NOT THE CONTRACT OWNER"):
        let (caller) = get_caller_address()
        let (owner) = _owner.read()
        assert caller = owner
    end

    return ()
end
