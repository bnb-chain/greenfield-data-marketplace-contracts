// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./marketplace.sol";

contract Deployer {
    address public proxyAdmin;
    address public proxyMarketplace;
    address public implMarketplace;

    bool public deployed;

    constructor() {
        /*
            @dev deploy workflow
            a. Generate contracts addresses in advance first while deploy `Deployer`
            c. Deploy the proxy contracts, checking if they are equal to the generated addresses before
        */
        proxyAdmin = calcCreateAddress(address(this), uint8(1));
        proxyMarketplace = calcCreateAddress(address(this), uint8(2));

        // 1. proxyAdmin
        address deployedProxyAdmin = address(new ProxyAdmin());
        require(deployedProxyAdmin == proxyAdmin, "invalid proxyAdmin address");
    }

    function deploy(
        address _implMarketplace,
        address _owner,
        address _crossChain,
        address _groupHub,
        uint256 _callbackGasLimit,
        address _refundAddress,
        uint8 _failureHandleStrategy,
        uint256 _tax
    ) public {
        require(!deployed, "only not deployed");
        deployed = true;

        require(_isContract(_implMarketplace), "invalid implMarketplace");
        implMarketplace = _implMarketplace;

        // 1. deploy proxy contract
        address deployedProxyMarketplace = address(new TransparentUpgradeableProxy(implMarketplace, proxyAdmin, ""));
        require(deployedProxyMarketplace == proxyMarketplace, "invalid proxyMarketplace address");

        // 2. transfer admin ownership
        ProxyAdmin(proxyAdmin).transferOwnership(_owner);
        require(ProxyAdmin(proxyAdmin).owner() == _owner, "invalid proxyAdmin owner");

        // 3. init marketplace
        Marketplace(payable(proxyMarketplace)).initialize(
            _crossChain, _groupHub, _callbackGasLimit, _refundAddress, _failureHandleStrategy, _owner, _tax
        );
    }

    function calcCreateAddress(address _deployer, uint8 _nonce) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), _deployer, _nonce)))));
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
