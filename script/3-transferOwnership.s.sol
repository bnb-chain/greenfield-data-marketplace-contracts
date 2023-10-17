// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../contracts/interface/IMarketplace.sol";
import {Marketplace} from "../contracts/Marketplace.sol";

contract UpgradeScript is Script {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    address public owner;
    address public newOwner;

    address public proxyAdmin;
    address public proxyMarketPlace;
    address public oldImplMarketPlace;

    function setUp() public {
        uint256 privateKey = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        owner = vm.addr(privateKey);
        console.log("init owner: %s", owner);

        proxyAdmin = vm.envAddress("PROXY_ADMIN");
        console.log("proxyAdmin address: %s", proxyAdmin);

        proxyMarketPlace = vm.envAddress("PROXY_MP");
        console.log("proxyMarketPlace address: %s", proxyMarketPlace);

        newOwner = vm.envAddress("NEW_OWNER");
        console.log("newOwner address: %s", newOwner);
    }

    function run() public {
        vm.startBroadcast(owner);
        IMarketplace(proxyMarketPlace).grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        ProxyAdmin(proxyAdmin).transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
