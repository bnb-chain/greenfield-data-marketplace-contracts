// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IMarketplace {
    event Buy(address indexed buyer, uint256 indexed groupId);
    event BuyFailed(address indexed buyer, uint256 indexed groupId);
    event CreateGroupFailed(uint32 status, bytes groupName);
    event CreateGroupSuccess(bytes groupName, uint256 indexed tokenId);
    event DeleteGroupFailed(uint32 status, uint256 indexed tokenId);
    event DeleteGroupSuccess(uint256 indexed tokenId);
    event Delist(address indexed owner, uint256 indexed groupId);
    event Initialized(uint8 version);
    event List(address indexed owner, uint256 indexed groupId, uint256 price);
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event UpdateGroupFailed(uint32 status, uint256 indexed tokenId);
    event UpdateGroupSuccess(uint256 indexed tokenId);

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function ERROR_INSUFFICIENT_VALUE() external view returns (string memory);
    function ERROR_INVALID_CALLER() external view returns (string memory);
    function ERROR_INVALID_OPERATION() external view returns (string memory);
    function ERROR_INVALID_RESOURCE() external view returns (string memory);
    function OPERATOR_ROLE() external view returns (bytes32);
    function RESOURCE_GROUP() external view returns (uint8);
    function STATUS_FAILED() external view returns (uint32);
    function STATUS_SUCCESS() external view returns (uint32);
    function STATUS_UNEXPECTED() external view returns (uint32);
    function TYPE_CREATE() external view returns (uint8);
    function TYPE_DELETE() external view returns (uint8);
    function TYPE_UPDATE() external view returns (uint8);
    function addOperator(address newOperator) external;
    function buy(uint256 groupId, address refundAddress) external payable;
    function buyBatch(uint256[] memory groupIds, address refundAddress) external payable;
    function callbackGasLimit() external view returns (uint256);
    function claim() external;
    function crossChain() external view returns (address);
    function delist(uint256 groupId) external;
    function failureHandleStrategy() external view returns (uint8);
    function feeRate() external view returns (uint256);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function greenfieldCall(
        uint32 status,
        uint8 resoureceType,
        uint8 operationType,
        uint256 resourceId,
        bytes memory callbackData
    ) external;
    function groupHub() external view returns (address);
    function groupToken() external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function initialize(
        address _initAdmin,
        address _fundWallet,
        uint256 _feeRate,
        address _crossChain,
        address _groupHub,
        uint256 _callbackGasLimit,
        uint8 _failureHandleStrategy
    ) external;
    function list(uint256 groupId, uint256 price) external;
    function memberToken() external view returns (address);
    function prices(uint256) external view returns (uint256);
    function removeOperator(address operator) external;
    function renounceRole(bytes32 role, address account) external;
    function retryPackage(uint8) external;
    function revokeRole(bytes32 role, address account) external;
    function setCallbackGasLimit(uint256 _callbackGasLimit) external;
    function setFailureHandleStrategy(uint8 _failureHandleStrategy) external;
    function setFeeRate(uint256 _feeRate) external;
    function setFundWallet(address _fundWallet) external;
    function skipPackage(uint8) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function transferGasLimit() external view returns (uint256);
    function unclaimedFunds(address) external view returns (uint256);
}
