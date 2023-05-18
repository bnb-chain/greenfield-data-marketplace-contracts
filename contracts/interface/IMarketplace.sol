// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMarketplace {
    event AddOperator(address indexed operator);
    event Buy(address indexed buyer, uint256 indexed groupId);
    event BuyFailed(address indexed buyer, uint256 indexed groupId);
    event CreateGroupFailed(uint32 status, bytes groupName);
    event CreateGroupSuccess(bytes groupName, uint256 indexed tokenId);
    event DeleteGroupFailed(uint32 status, uint256 indexed tokenId);
    event DeleteGroupSuccess(uint256 indexed tokenId);
    event Delist(address indexed owner, uint256 indexed groupId);
    event Initialized(uint8 version);
    event List(address indexed owner, uint256 indexed groupId, uint256 price);
    event RemoveOperator(address indexed operator);
    event UpdateGroupFailed(uint32 status, uint256 indexed tokenId);
    event UpdateGroupSuccess(uint256 indexed tokenId);

    function ERROR_INSUFFICIENT_VALUE() external view returns (string memory);
    function ERROR_INVALID_CALLER() external view returns (string memory);
    function ERROR_INVALID_OPERATION() external view returns (string memory);
    function ERROR_INVALID_RESOURCE() external view returns (string memory);
    function RESOURCE_GROUP() external view returns (uint8);
    function STATUS_FAILED() external view returns (uint32);
    function STATUS_SUCCESS() external view returns (uint32);
    function STATUS_UNEXPECTED() external view returns (uint32);
    function TYPE_CREATE() external view returns (uint8);
    function TYPE_DELETE() external view returns (uint8);
    function TYPE_UPDATE() external view returns (uint8);
    function addOperator(address newOperator) external;
    function buy(uint256 groupId) external payable;
    function callbackGasLimit() external view returns (uint256);
    function claim() external;
    function crossChain() external view returns (address);
    function delist(uint256 groupId) external;
    function failureHandleStrategy() external view returns (uint8);
    function greenfieldCall(
        uint32 status,
        uint8 resoureceType,
        uint8 operationType,
        uint256 resourceId,
        bytes memory callbackData
    ) external;
    function groupHub() external view returns (address);
    function groupToken() external view returns (address);
    function initialize(
        address _crossChain,
        address _groupHub,
        uint256 _callbackGasLimit,
        address _refundAddress,
        uint8 _failureHandleStrategy,
        address _operator,
        uint256 _tax
    ) external;
    function list(uint256 groupId, uint256 price) external;
    function operators(address) external view returns (bool);
    function prices(uint256) external view returns (uint256);
    function refundAddress() external view returns (address);
    function removeOperator(address operator) external;
    function reservedSlots(uint256) external view returns (uint256);
    function retryPackage(uint8) external;
    function setCallbackGasLimit(uint256 _callbackGasLimit) external;
    function setFailureHandleStrategy(uint8 _failureHandleStrategy) external;
    function setRefundAddress(address _refundAddress) external;
    function setTax(uint256 _tax) external;
    function skipPackage(uint8) external;
    function tax() external view returns (uint256);
    function unclaimedFunds(address) external view returns (uint256);
}
