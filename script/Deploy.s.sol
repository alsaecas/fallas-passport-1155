// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/FallasPassport1155.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        address signer = vm.envAddress("SIGNER_ADDRESS");
        string memory baseURI = vm.envString("BASE_URI");

        vm.startBroadcast(pk);
        FallasPassport1155 c = new FallasPassport1155(baseURI, vm.addr(pk), signer);
        vm.stopBroadcast();

        console2.log("FallasPassport1155 deployed at:", address(c));
    }
}
