%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.budi_operator import ServiceCommitment

@contract_interface
namespace IBudiOperator {
    func mint_for_new_user(recipient: felt) {
    }

    func create_commitment(request_id: felt, requestor: felt, provider: felt, amount: Uint256) -> (
        bool: felt
    ) {
    }

    func complete_commitment(request_id: felt) -> (bool: felt) {
    }

    func get_commitment_of(request_id: felt) -> (commitment: ServiceCommitment) {
    }

    func get_token_address() -> (contract_address: felt) {
    }
}
