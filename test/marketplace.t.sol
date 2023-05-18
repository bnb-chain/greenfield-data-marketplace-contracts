// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "../contracts/deployer.sol";
import "../contracts/interface/IMarketplace.sol";

contract MarketplaceTest is Test {
    uint256 constant public callbackGasLimit = 1000000; // TODO: TBD
    uint8 constant public failureHandleStrategy = 0; // BlockOnFail
    uint256 constant public tax = 100; // 1%

    address public operator;
    address public proxyMarketplace;

    address public crossChain;
    address public groupHub;
    address public owner;
    address public refundAddress;

    function setUp() public {
        uint256 privateKey = uint256(vm.envBytes32("OP_PRIVATE_KEY"));
        operator = vm.addr(privateKey);
        console.log("operator balance: %s", operator.balance/1e18);

        privateKey = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        owner = vm.addr(privateKey);
        console.log("owner: %s", owner);

        crossChain = vm.envAddress("CROSS_CHAIN");
        console.log("crossChain address: %s", crossChain);

        groupHub = vm.envAddress("GROUP_HUB");
        console.log("groupHub address: %s", groupHub);

        proxyMarketplace = 0xf195Dc7F063cb7A475dA604E0EB1854B2C7dAA28; // get this from deploy script's log
    }

    function testList() public {
        // failed with unexisted group
        vm.expectRevert("ERC721: invalid token ID");
        IMarketplace(proxyMarketplace).list(1, 1e18);
    }
}
