# SPDX-License-Identifier: MIT
# OpenZeppelin Contracts for Cairo v0.3.1 (token/erc20/presets/ERC20.cairo)

%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin

from openzeppelin.access.ownable.library import Ownable

@storage_var
func _owner() -> (address):
end

@storage_var
func _operator() -> (address):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt,
    name : felt,
    symbol : felt,
    decimals : felt,
    initial_supply : felt,
    recipient : felt,
):
    _owner.write(owner)
    ERC20.initializer(name, symbol, decimals)
    ERC20._mint(recipient, initial_supply)
    return ()
end

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20.name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20.symbol()
    return (symbol)
end

@view
func total_supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    totalSupply : felt
):
    let (totalSupply : felt) = ERC20.total_supply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (decimals) = ERC20.decimals()
    return (decimals)
end

@view
func balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : felt):
    let (balance : felt) = ERC20.balance_of(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : felt):
    let (remaining : felt) = ERC20.allowance(owner, spender)
    return (remaining)
end

@view
func get_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (address):
    let (operator) = _operator.read()
    return (operator)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : felt
) -> (success : felt):
    ERC20.transfer(recipient, amount)
    return (TRUE)
end

@external
func transfer_from{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : felt
) -> (success : felt):
    ERC20.transfer_from(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : felt
) -> (success : felt):
    ERC20.approve(spender, amount)
    return (TRUE)
end

@external
func increase_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, added_value : felt
) -> (success : felt):
    ERC20.increase_allowance(spender, added_value)
    return (TRUE)
end

@external
func decrease_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, subtracted_value : felt
) -> (success : felt):
    ERC20.decrease_allowance(spender, subtracted_value)
    return (TRUE)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : felt
) -> (success : felt):
    _operator_only()

    ERC20._mint(recipient, amount)
    return (TRUE)
end

# Only operator can call this function,
# this allow operator to approve `owner`'s token for itself
#
# Should put owner's signature verification
#
@external
func approve_to_operator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, amount : felt
) -> (success : felt):
    let (caller) = get_caller_address()

    with_attr error_message("TIMETOKEN: Only operator can call this function."):
        let (operator) = _operator.read()
        assert operator = caller
    end

    ERC20._approve(owner, caller, amount)

    return (TRUE)
end

@external
func set_operator_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address
):
    with_attr error_message("TIMETOKEN: Only owner can call this function."):
        let (caller) = get_caller_address()
        let (owner) = _owner.read()
        assert caller = owner
    end

    with_attr error_message("TIMETOKEN: Operator address has already been set."):
        let (operator) = _operator.read()
        assert operator = FALSE
    end

    _operator.write(address)

    return ()
end

#
# Internal
#

func _operator_only{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    with_attr error_message("TIMETOKEN: Only operator can call this function."):
        let (caller) = get_caller_address()
        let (operator) = _operator.read()
        assert caller = operator
    end
    return ()
end
