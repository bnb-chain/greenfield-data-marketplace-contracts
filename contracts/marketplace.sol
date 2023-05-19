// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@bnb-chain/greenfield-contracts-sdk/GroupApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/interface/IERC721NonTransferable.sol";
import "@bnb-chain/greenfield-contracts-sdk/interface/IERC1155NonTransferable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract Marketplace is ReentrancyGuard, AccessControl, GroupApp {
    using RLPDecode for *;
    using RLPEncode for *;

    /*----------------- constants -----------------*/
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /*----------------- system contracts -----------------*/
    address public groupToken;
    address public memberToken;

    /*----------------- storage -----------------*/
    // group ID => item price
    mapping(uint256 => uint256) public prices;
    // address => uncliamed amount
    mapping(address => uint256) public unclaimedFunds;

    uint256 public transferGasLimit; // 2300 for now
    uint256 public feeRate; // 10000 = 100%

    address fundWallet;

    // placeHolder reserved for future usage
    uint256[50] _reservedSlots;

    /*----------------- event/modifier -----------------*/
    event List(address indexed owner, uint256 indexed groupId, uint256 price);
    event Delist(address indexed owner, uint256 indexed groupId);
    event Buy(address indexed buyer, uint256 indexed groupId);
    event BuyFailed(address indexed buyer, uint256 indexed groupId);

    modifier onlyGroupOwner(uint256 groupId) {
        require(msg.sender == IERC721NonTransferable(groupToken).ownerOf(groupId), "MarketPlace: only group owner");
        _;
    }

    function initialize(
        address _crossChain,
        address _groupHub,
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy,
        uint256 _feeRate,
        address _initAdmin,
        address _fundWallet
    ) public initializer {
        require(_initAdmin != address(0), "MarketPlace: invalid admin address");
        _grantRole(DEFAULT_ADMIN_ROLE, _initAdmin);

        transferGasLimit = 2300;
        feeRate = _feeRate;
        fundWallet = _fundWallet;
        groupToken = IGroupHub(_groupHub).ERC721Token();
        memberToken = IGroupHub(_groupHub).ERC1155Token();

        __base_app_init_unchained(_crossChain, _callbackGasLimit, _failureHandleStrategy);
        __group_app_init_unchained(_groupHub);
    }

    /*----------------- external functions -----------------*/
    function greenfieldCall(
        uint32 status,
        uint8 resoureceType,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    ) external override(GroupApp) {
        require(msg.sender == crossChain, "MarketPlace: invalid caller");

        if (resoureceType == RESOURCE_GROUP) {
            _groupGreenfieldCall(status, operationType, resourceId, callbackData);
        } else {
            revert("MarketPlace: invalid resource type");
        }
    }

    function list(uint256 groupId, uint256 price) external onlyGroupOwner(groupId) {
        prices[groupId] = price;
        emit List(msg.sender, groupId, price);
    }

    function delist(uint256 groupId) external onlyGroupOwner(groupId) {
        require(prices[groupId] > 0, "MarketPlace: not listed");
        delete prices[groupId];
        emit Delist(msg.sender, groupId);
    }

    function buy(uint256 groupId) external payable {
        require(prices[groupId] > 0, "MarketPlace: not listed");
        require(msg.value >= prices[groupId]+_getTotalFee(), "MarketPlace: insufficient fund");

        _buy(groupId);
    }

    function buyBatch(uint256[] calldata groupIds) external payable {
        uint256 totalPrice;
        for (uint256 i = 0; i < groupIds.length; i++) {
            require(prices[groupIds[i]] > 0, "MarketPlace: not listed");
            totalPrice += prices[groupIds[i]];
        }
        require(msg.value >= totalPrice+_getTotalFee(), "MarketPlace: insufficient fund");

        for (uint256 i = 0; i < groupIds.length; i++) {
            _buy(groupIds[i]);
        }
    }

    function claim() external nonReentrant {
        uint256 amount = unclaimedFunds[msg.sender];
        require(amount > 0, "MarketPlace: no unclaimed funds");
        unclaimedFunds[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "MarketPlace: claim failed");
    }

    /*----------------- admin functions -----------------*/
    function addOperator(address newOperator) external {
        grantRole(OPERATOR_ROLE, newOperator);
    }

    function removeOperator(address operator) external {
        revokeRole(OPERATOR_ROLE, operator);
    }

    function setFundWallet(address _fundWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fundWallet = _fundWallet;
    }

    function retryPackage(uint8) external override onlyRole(OPERATOR_ROLE) {
        _retryGroupPackage();
    }

    function skipPackage(uint8) external override onlyRole(OPERATOR_ROLE) {
        _skipGroupPackage();
    }

    function setFeeRate(uint256 _feeRate) external onlyRole(OPERATOR_ROLE) {
        require(_feeRate < 10_000, "MarketPlace: invalid feeRate");
        feeRate = _feeRate;
    }

    function setCallbackGasLimit(uint256 _callbackGasLimit) external onlyRole(OPERATOR_ROLE) {
        _setCallbackGasLimit(_callbackGasLimit);
    }

    function setFailureHandleStrategy(uint8 _failureHandleStrategy) external onlyRole(OPERATOR_ROLE) {
        _setFailureHandleStrategy(_failureHandleStrategy);
    }

    /*----------------- internal functions -----------------*/
    function _buy(uint256 groupId) internal {
        address buyer = msg.sender;
        require(IERC1155NonTransferable(memberToken).balanceOf(buyer, groupId) == 0, "MarketPlace: already purchased");

        address _owner = IERC721NonTransferable(groupToken).ownerOf(groupId);
        address[] memory members = new address[](1);
        members[0] = buyer;
        _updateGroup(_owner, groupId, GroupStorage.UpdateGroupOpType.AddMembers, members, buyer, _encodeCallbackData(_owner, buyer, prices[groupId]));
    }

    function _groupGreenfieldCall(
        uint32 status,
        uint8 operationType,
        uint256 resourceId,
        bytes calldata callbackData
    ) internal override {
        if (operationType == TYPE_UPDATE) {
            _updateGroupCallback(status, resourceId, callbackData);
        } else {
            revert("MarketPlace: invalid operation type");
        }
    }

    function _updateGroupCallback(uint32 _status, uint256 _tokenId, bytes memory _callbackData) internal override {
        (address owner, address buyer, uint256 price, bool ok) = _decodeCallbackData(_callbackData);
        if (!ok) {
            revert("MarketPlace: invalid callback data");
        }

        if (_status == STATUS_SUCCESS) {
            uint256 feeRateAmount = (price * feeRate) / 10_000;
            payable(fundWallet).transfer(feeRateAmount);
            (bool success, ) = payable(owner).call{gas: transferGasLimit, value: price - feeRateAmount}("");
            if (!success) {
                unclaimedFunds[owner] += price - feeRateAmount;
            }
            emit Buy(buyer, _tokenId);
        } else {
            (bool success, ) = payable(buyer).call{gas: transferGasLimit, value: price}("");
            if (!success) {
                unclaimedFunds[buyer] += price;
            }
            emit BuyFailed(buyer, _tokenId);
        }
    }

    function _encodeCallbackData(address owner, address buyer, uint256 price) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](3);
        elements[0] = owner.encodeAddress();
        elements[1] = buyer.encodeAddress();
        elements[2] = price.encodeUint();
        return elements.encodeList();
    }

    function _decodeCallbackData(bytes memory _callbackData)
        internal
        pure
        returns (address owner, address buyer, uint256 price, bool success)
    {
        RLPDecode.Iterator memory iter = _callbackData.toRLPItem().iterator();

        uint256 idx;
        while (iter.hasNext()) {
            if (idx == 0) {
                owner = iter.next().toAddress();
            } else if (idx == 1) {
                buyer = iter.next().toAddress();
            } else if (idx == 2) {
                price = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            idx++;
        }
    }
}
