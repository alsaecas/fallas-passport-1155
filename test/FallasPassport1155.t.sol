// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/FallasPassport1155.sol";

contract FallasPassport1155Test is Test {
    FallasPassport1155 passport;

    uint256 ownerPk = 0xA11CE;
    uint256 signerPk = 0xB0B;
    address owner = vm.addr(ownerPk);
    address signer = vm.addr(signerPk);

    address user = address(0x1234);

    bytes32 internal constant MINT_TYPEHASH =
        keccak256("Mint(address to,uint256 checkpointId,uint256 deadline,bytes32 nonce)");

    function setUp() public {
        passport = new FallasPassport1155("ipfs://cid/{id}.json", owner, signer);
    }

    function _domainSeparator(address verifyingContract) internal view returns (bytes32) {
        bytes32 EIP712_DOMAIN_TYPEHASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("FallasPassport")),
                keccak256(bytes("1")),
                block.chainid,
                verifyingContract
            )
        );
    }

    function _digest(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(address(passport)), structHash));
    }

    function _signMint(address to, uint256 checkpointId, uint256 deadline, bytes32 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(MINT_TYPEHASH, to, checkpointId, deadline, nonce));
        bytes32 digest = _digest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    function testMintWithValidSig() public {
        uint256 checkpointId = 1;
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 nonce = keccak256("n1");

        bytes memory sig = _signMint(user, checkpointId, deadline, nonce);

        passport.mintWithSig(user, checkpointId, deadline, nonce, sig);

        assertEq(passport.balanceOf(user, checkpointId), 1);
        assertTrue(passport.claimed(user, checkpointId));
    }

    function testRevertExpired() public {
        uint256 checkpointId = 1;
        uint256 deadline = block.timestamp - 1;
        bytes32 nonce = keccak256("n2");

        bytes memory sig = _signMint(user, checkpointId, deadline, nonce);

        vm.expectRevert("expired");
        passport.mintWithSig(user, checkpointId, deadline, nonce, sig);
    }

    function testRevertBadSig() public {
        uint256 checkpointId = 1;
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 nonce = keccak256("n3");

        // Sign with wrong key
        uint256 wrongPk = 0xCAFE;
        bytes32 structHash = keccak256(abi.encode(MINT_TYPEHASH, user, checkpointId, deadline, nonce));
        bytes32 digest = _digest(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert("bad sig");
        passport.mintWithSig(user, checkpointId, deadline, nonce, sig);
    }

    function testRevertNonceReuse() public {
        uint256 checkpointId1 = 1;
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 nonce = keccak256("n4");

        // First mint uses nonce
        bytes memory sig1 = _signMint(user, checkpointId1, deadline, nonce);
        passport.mintWithSig(user, checkpointId1, deadline, nonce, sig1);

        // Second mint attempts to reuse SAME nonce but with a different checkpointId
        uint256 checkpointId2 = 2;
        bytes memory sig2 = _signMint(user, checkpointId2, deadline, nonce);

        vm.expectRevert("nonce used");
        passport.mintWithSig(user, checkpointId2, deadline, nonce, sig2);
    }

    function testRevertAlreadyClaimed() public {
        uint256 checkpointId = 1;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 nonce1 = keccak256("n5a");
        bytes32 nonce2 = keccak256("n5b");

        passport.mintWithSig(user, checkpointId, deadline, nonce1, _signMint(user, checkpointId, deadline, nonce1));

        vm.expectRevert("already claimed");
        passport.mintWithSig(user, checkpointId, deadline, nonce2, _signMint(user, checkpointId, deadline, nonce2));
    }
}
