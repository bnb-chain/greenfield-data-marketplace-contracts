// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@bnb-chain/greenfield-contracts-sdk/GroupApp.sol";
import "@bnb-chain/greenfield-contracts-sdk/interface/IERC721NonTransferable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../lib/RLPDecode.sol";
import "../lib/RLPEncode.sol";

contract Marketplace is ReentrancyGuard, GroupApp {
    using RLPDecode for *;
    using RLPEncode for *;

    /*----------------- system contracts -----------------*/
    address public groupToken;

    /*----------------- storage -----------------*/
    // admins
    mapping(address => bool) public operators;

    // group ID => item price
    mapping(uint256 => uint256) public prices;
    // address => uncliamed amount
    mapping(address => uint256) public unclaimedFunds;

    uint256 public tax; // 10000 = 100%

    // placeHolder reserved for future usage
    uint256[50] public reservedSlots;

    /*----------------- event/modifier -----------------*/
    event List(address indexed owner, uint256 indexed groupId, uint256 price);
    event Delist(address indexed owner, uint256 indexed groupId);
    event Buy(address indexed buyer, uint256 indexed groupId);
    event BuyFailed(address indexed buyer, uint256 indexed groupId);
    event AddOperator(address indexed operator);
    event RemoveOperator(address indexed operator);

    modifier onlyOwner(uint256 groupId) {
        require(msg.sender == IERC721NonTransferable(groupToken).ownerOf(groupId), "MarketPlace: only owner");
        _;
    }

    modifier onlyOperator() {
        require(_isOperator(msg.sender), "MarketPlace: only operator");
        _;
    }

    function initialize(
        address _crossChain,
        address _groupHub,
        uint256 _callbackGasLimit,
        address _refundAddress,
        uint8 _failureHandleStrategy,
        address _operator,
        uint256 _tax
    ) public initializer {
        require(_operator != address(0), "MarketPlace: invalid operator");
        operators[_operator] = true;

        tax = _tax;
        groupToken = IGroupHub(_groupHub).ERC721Token();

        __base_app_init_unchained(_crossChain, _callbackGasLimit, _refundAddress, _failureHandleStrategy);
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

    function list(uint256 groupId, uint256 price) external onlyOwner(groupId) {
        prices[groupId] = price;
        emit List(msg.sender, groupId, price);
    }

    function delist(uint256 groupId) external onlyOwner(groupId) {
        delete prices[groupId];
        emit Delist(msg.sender, groupId);
    }

    function buy(uint256 groupId) external payable {
        uint256 price = prices[groupId];
        require(price > 0, "MarketPlace: not for sale");
        require(msg.value == price, "MarketPlace: wrong price");

        address _owner = IERC721NonTransferable(groupToken).ownerOf(groupId);
        _buy(_owner, groupId, msg.sender);
    }

    function claim() external nonReentrant {
        uint256 amount = unclaimedFunds[msg.sender];
        require(amount > 0, "MarketPlace: no unclaimed funds");
        unclaimedFunds[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "MarketPlace: claim failed");
    }

    /*----------------- admin functions -----------------*/
    function addOperator(address newOperator) public onlyOperator {
        operators[newOperator] = true;
        emit AddOperator(newOperator);
    }

    function removeOperator(address operator) public onlyOperator {
        delete operators[operator];
        emit RemoveOperator(operator);
    }

    function retryPackage(uint8) external override onlyOperator {
        _retryGroupPackage();
    }

    function skipPackage(uint8) external override onlyOperator {
        _skipGroupPackage();
    }

    function setTax(uint256 _tax) external onlyOperator {
        require(_tax < 10_000, "MarketPlace: invalid tax");
        tax = _tax;
    }

    function setCallbackGasLimit(uint256 _callbackGasLimit) external onlyOperator {
        _setCallbackGasLimit(_callbackGasLimit);
    }

    function setRefundAddress(address _refundAddress) external onlyOperator {
        _setRefundAddress(_refundAddress);
    }

    function setFailureHandleStrategy(uint8 _failureHandleStrategy) external onlyOperator {
        _setFailureHandleStrategy(_failureHandleStrategy);
    }

    /*----------------- internal functions -----------------*/
    function _buy(address _owner, uint256 groupId, address buyer) internal {
        address[] memory members = new address[](1);
        members[0] = buyer;
        _updateGroup(_owner, groupId, GroupStorage.UpdateGroupOpType.AddMembers, members, "");
    }

    function _isOperator(address account) internal view returns (bool) {
        return operators[account];
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
        (address owner, address buyer, uint256 price, bool success) = _decodeCallbackData(_callbackData);
        if (!success) {
            revert("MarketPlace: invalid callback data");
        }

        if (_status == STATUS_SUCCESS) {
            uint256 taxAmount = (price * tax) / 10_000;
            unclaimedFunds[owner] += price - taxAmount;
            emit Buy(buyer, _tokenId);
        } else {
            unclaimedFunds[buyer] += price;
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
