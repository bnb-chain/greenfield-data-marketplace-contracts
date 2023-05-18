// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Script.sol";

import "../contracts/deployer.sol";
import "../contracts/marketplace.sol";

contract DeployScript is Script {
    uint256 constant public callbackGasLimit = 1000000; // TODO: TBD
    uint8 constant public failureHandleStrategy = 0; // BlockOnFail
    uint256 constant public tax = 100; // 1%

    address public operator;

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
    }

    function run() public {
        vm.startBroadcast(operator);
        Deployer deployer = new Deployer();
        console.log("deployer address: %s", address(deployer));
        Marketplace marketplace = new Marketplace();
        console.log("implMarketplace address: %s", address(marketplace));

        address proxyAdmin = deployer.calcCreateAddress(address(deployer), uint8(1));
        require(proxyAdmin == deployer.proxyAdmin(), "wrong proxyAdmin address");
        console.log("proxyAdmin address: %s", proxyAdmin);
        address proxyMarketplace = deployer.calcCreateAddress(address(deployer), uint8(2));
        require(proxyMarketplace == deployer.proxyMarketplace(), "wrong proxyMarketplace address");
        console.log("proxyMarketplace address: %s", proxyMarketplace);

        refundAddress = proxyMarketplace;
        deployer.deploy(
            address(marketplace),
            owner,
            crossChain,
            groupHub,
            callbackGasLimit,
            refundAddress,
            failureHandleStrategy,
            tax
        );
        vm.stopBroadcast();
    }
}
