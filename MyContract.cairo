%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

// struct Number:
//     member a : felt
//     member b : felt
//     member c : felt
// end

struct Signature {
    r: felt,
    s: felt,
}

@storage_var
func _signature() -> (res: (sig: Signature, num: felt)) {
}

@external
func set_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    signature: Signature, number: felt
) -> (res: felt) {
    _signature.write((signature, number));
    return (69,);
}

@external
func get_signature{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    sig: Signature, num: felt
) {
    let (res) = _signature.read();
    return (sig=res.sig, num=res.num);
}
