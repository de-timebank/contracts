%lang starknet

from src.main import Signature

namespace Helper:
    func sign(private_key, message_hash) -> (signature: Signature):
        %{
            from starkware.crypto.signature.signature import sign
            signature = sign(ids.message_hash, ids.private_key)
            memory[ap] = signature[0]
            memory[ap + 1] = signature[1]
        %}
        ap += 2
        return (signature=Signature(r=[ap - 2], s=[ap - 1]))
    end

    func pedersen_hash(message) -> (hash):
        %{
            from starkware.crypto.signature.signature import pedersen_hash
            memory[ap] = pedersen_hash(ids.message)
        %}
        ap += 1
        return (hash=[ap - 1])
    end

    func create_address(private_key) -> (address):
        %{
            from starkware.crypto.signature.signature import private_to_stark_key
            memory[ap] = private_to_stark_key(ids.private_key)
        %}
        ap += 1
        return (address=[ap - 1])
    end
end

namespace Cheatcode:
    func start_prank_on_contract(address, contract_address):
        %{
            start_prank(ids.address, ids.contract_address)
        %}
        return ()
    end

    func start_prank{syscall_ptr : felt*, range_check_ptr}(address):
        %{
            start_prank(ids.address)
        %}
        return ()
    end
end