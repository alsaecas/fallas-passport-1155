// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

interface IFallasPassport1155 {
    function mintWithSig(address to, uint256 checkpointId, uint256 deadline, bytes32 nonce, bytes calldata sig) external;

    function claimed(address to, uint256 checkpointId) external view returns (bool);
}

contract Mint is Script {
    // Must match your contract constants:
    // EIP712("FallasPassport","1")
    string internal constant NAME = "FallasPassport";
    string internal constant VERSION = "1";

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal constant MINT_TYPEHASH =
        keccak256("Mint(address to,uint256 checkpointId,uint256 deadline,bytes32 nonce)");

    function _domainSeparator(address verifyingContract) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                verifyingContract
            )
        );
    }

    function _hashTypedData(address verifyingContract, bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(verifyingContract), structHash));
    }

    function run() external {
        address contractAddr = vm.envAddress("CONTRACT_ADDRESS");
        address to = vm.envAddress("TO");
        uint256 checkpointId = vm.envUint("CHECKPOINT_ID");

        // Private key that corresponds to the contract's `signer` address
        uint256 signerPk = vm.envUint("SIGNER_PK");

        // Wallet that actually broadcasts the tx and pays gas (fund it with CAM)
        uint256 callerPk = vm.envUint("CALLER_PK");

        // Short expiry is fine for tests; override with env if you want
        uint256 deadline = vm.envOr("DEADLINE", block.timestamp + 300); // 5 min

        // You can provide NONCE via env, otherwise we make one deterministically (unique enough for testing)
        bytes32 nonce =
            vm.envOr("NONCE", keccak256(abi.encodePacked("mint", to, checkpointId, block.timestamp, contractAddr)));

        // Build struct hash
        bytes32 structHash = keccak256(abi.encode(MINT_TYPEHASH, to, checkpointId, deadline, nonce));

        // EIP-712 digest
        bytes32 digest = _hashTypedData(contractAddr, structHash);

        // Sign with SIGNER_PK
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        IFallasPassport1155 passport = IFallasPassport1155(contractAddr);

        // Optional: show whether already claimed
        bool already = passport.claimed(to, checkpointId);
        console2.log("Already claimed?", already);
        require(!already, "Already claimed");

        vm.startBroadcast(callerPk);
        passport.mintWithSig(to, checkpointId, deadline, nonce, sig);
        vm.stopBroadcast();

        console2.log("Minted checkpointId:", checkpointId, "to:", to);
    }
}
