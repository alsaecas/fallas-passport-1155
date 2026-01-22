// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract FallasPassport1155 is ERC1155, Ownable, EIP712 {
    using ECDSA for bytes32;

    address public signer;

    mapping(address => mapping(uint256 => bool)) public claimed;
    mapping(bytes32 => bool) public usedNonces;

    bytes32 private constant MINT_TYPEHASH =
        keccak256("Mint(address to,uint256 checkpointId,uint256 deadline,bytes32 nonce)");

    event SignerUpdated(address indexed newSigner);
    event CheckpointMinted(address indexed to, uint256 indexed checkpointId);

    constructor(string memory baseURI, address initialOwner, address initialSigner)
        ERC1155(baseURI)
        Ownable(initialOwner)
        EIP712("FallasPassport", "1")
    {
        signer = initialSigner;
    }

    function setSigner(address newSigner) external onlyOwner {
        signer = newSigner;
        emit SignerUpdated(newSigner);
    }

    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    function mintWithSig(address to, uint256 checkpointId, uint256 deadline, bytes32 nonce, bytes calldata sig)
        external
    {
        require(block.timestamp <= deadline, "expired");
        require(!claimed[to][checkpointId], "already claimed");
        require(!usedNonces[nonce], "nonce used");

        bytes32 structHash = keccak256(abi.encode(MINT_TYPEHASH, to, checkpointId, deadline, nonce));

        bytes32 digest = _hashTypedDataV4(structHash);
        address recovered = digest.recover(sig);
        require(recovered == signer, "bad sig");

        usedNonces[nonce] = true;
        claimed[to][checkpointId] = true;

        _mint(to, checkpointId, 1, "");
        emit CheckpointMinted(to, checkpointId);
    }
}
