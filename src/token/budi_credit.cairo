// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (token/erc20/presets/ERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.token.erc20.library import ERC20
from openzeppelin.access.ownable.library import Ownable

const BUDI_TOKEN_NAME = 'BUDI CREDIT';
const BUDI_TOKEN_SYMBOL = 'BUDI';
const BUDI_TOKEN_DECIMALS = 0;

//
//  CONSTRUCTOR
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    budi_operator_address: felt
) {
    ERC20.initializer(BUDI_TOKEN_NAME, BUDI_TOKEN_SYMBOL, BUDI_TOKEN_DECIMALS);

    // set operator contract as the owner of this token
    Ownable.initializer(budi_operator_address);
    return ();
}

//
// VIEWS
//

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    return ERC20.name();
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    return ERC20.symbol();
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20.total_supply();
    return (totalSupply=totalSupply);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    return ERC20.decimals();
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    return ERC20.balance_of(account);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    return ERC20.allowance(owner, spender);
}

//
// EXTERNALS
//

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.transfer(recipient, amount);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.transfer_from(sender, recipient, amount);
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (success: felt) {
    return ERC20.increase_allowance(spender, added_value);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (success: felt) {
    return ERC20.decrease_allowance(spender, subtracted_value);
}

@external
func new_user_mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt
) {
    Ownable.assert_only_owner();
    ERC20._mint(recipient, Uint256(10, 0));
    return ();
}

// force approve by the operator
@external
func operator_delegate_approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    requestor: felt, amount: Uint256
) {
    Ownable.assert_only_owner();
    let (owner) = Ownable.owner();
    ERC20._approve(owner=requestor, spender=owner, amount=amount);
    return ();
}
