// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "@bnb-chain/greenfield-contracts-sdk/interface/IGroupHub.sol";
import "@bnb-chain/greenfield-contracts-sdk/interface/IERC721NonTransferable.sol";

import "../contracts/deployer.sol";
import "../contracts/interface/IMarketplace.sol";

contract MarketplaceTest is Test {
    uint256 constant public callbackGasLimit = 1000000; // TODO: TBD
    uint8 constant public failureHandleStrategy = 0; // BlockOnFail
    uint256 constant public tax = 100; // 1%

    address public operator;
    address public proxyMarketplace;

    address public owner;
    address public crossChain;
    address public groupHub;
    address public groupToken;

    event List(address indexed owner, uint256 indexed groupId, uint256 price);
    event Delist(address indexed owner, uint256 indexed groupId);
    event Buy(address indexed buyer, uint256 indexed groupId);
    event BuyFailed(address indexed buyer, uint256 indexed groupId);

    function setUp() public {
        privateKey = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        owner = vm.addr(privateKey);
        console.log("owner: %s", owner);

        crossChain = vm.envAddress("CROSS_CHAIN");
        console.log("crossChain address: %s", crossChain);

        groupHub = vm.envAddress("GROUP_HUB");
        console.log("groupHub address: %s", groupHub);

        groupToken = IGroupHub(groupHub).ERC721Token();
        proxyMarketplace = 0xf195Dc7F063cb7A475dA604E0EB1854B2C7dAA28; // get this from deploy script's log
    }

    function testList() public {
        // failed with unexisted group
        vm.expectRevert("ERC721: invalid token ID");
        IMarketplace(proxyMarketplace).list(1, 1e18);

        vm.startPrank(groupHub);
        IERC721NonTransferable(groupToken).mint(address(this), 1);
        vm.stopPrank();

        // failed with not group owner
        vm.startPrank(address(0x1234));
        vm.expectRevert("MarketPlace: only group owner");
        IMarketplace(proxyMarketplace).list(1, 1e18);
        vm.stopPrank();

        // success case
        vm.expectEmit(true, true, false, true, proxyMarketplace);
        emit List(address(this), 1, 1e18);
        IMarketplace(proxyMarketplace).list(1, 1e18);
    }

    function testDelist() public {
        // failed with not listed group
        vm.expectRevert("MarketPlace: not listed");
        IMarketplace(proxyMarketplace).delist(1);

        vm.startPrank(groupHub);
        IERC721NonTransferable(groupToken).mint(address(this), 1);
        vm.stopPrank();

        IMarketplace(proxyMarketplace).list(1, 1e18);

        // failed with not group owner
        vm.startPrank(address(0x1234));
        vm.expectRevert("MarketPlace: only group owner");
        IMarketplace(proxyMarketplace).delist(1, 1e18);
        vm.stopPrank();

        // success case
        vm.expectEmit(true, true, false, true, proxyMarketplace);
        emit Delist(address(this), 1);
        IMarketplace(proxyMarketplace).delist(1, 1e18);
    }

    function testBuy() public {
        // failed with not listed group
        vm.expectRevert("MarketPlace: not listed");
        IMarketplace(proxyMarketplace).buy(1, 1e18);

        vm.startPrank(groupHub);
        IERC721NonTransferable(groupToken).mint(address(this), 1);
        vm.stopPrank();

        IMarketplace(proxyMarketplace).list(1, 1e18);

        // failed with not enough fund
        vm.expectRevert("MarketPlace: insufficient fund");
        IMarketplace(proxyMarketplace).buy(1, 1e18);
    }
}
