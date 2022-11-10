%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IBudiCredit {
    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func totalSupply() -> (totalSupply: Uint256) {
    }

    func decimals() -> (decimals: felt) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func increaseAllowance(spender: felt, added_value: Uint256) -> (success: felt) {
    }

    func decreaseAllowance(spender: felt, subtracted_value: Uint256) -> (success: felt) {
    }

    func new_user_mint(recipient: felt) {
    }

    func operator_delegate_approve(requestor: felt, amount: Uint256) {
    }
}
