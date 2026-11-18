// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IAgentIDVerifier.sol";
import "./OwnableLite.sol";

/// @title AllowlistVerifier — 白名单校验器（退路方案）
/// @notice 用途：当官方注册表的集成方式尚未最终确认、或需要先给
///         种子用户/演示账号开通注册时，管理员可把 Agent Passport 的
///         校验器临时切换为本合约，由管理员人工核实 Agent ID 后
///         把地址加入白名单（可同时登记其 .ai 名字用于展示）。
///         正式上线时应切换回 ERC721AgentIDVerifier（官方注册表自动校验）。
/// @dev 本合约的存在是为了保证项目在任何情况下都能跑通完整流程，
///      它不是正式的资格来源——SUBMISSION/文档中会如实说明当前所用校验器。
contract AllowlistVerifier is IAgentIDVerifier, OwnableLite {
    constructor() OwnableLite(address(0)) {}

    mapping(address => bool) public allowed;
    mapping(address => string) private _names;

    event AllowedSet(address indexed user, bool allowed);
    event NameSet(address indexed user, string name);

    /// @notice 把地址加入/移出白名单
    function setAllowed(address user, bool isAllowed) external onlyOwner {
        allowed[user] = isAllowed;
        emit AllowedSet(user, isAllowed);
    }

    /// @notice 登记该地址对应的 .ai 名字（仅展示用）
    function setName(address user, string calldata name) external onlyOwner {
        _names[user] = name;
        emit NameSet(user, name);
    }

    /// @inheritdoc IAgentIDVerifier
    function hasAgentID(address user) external view override returns (bool) {
        return allowed[user];
    }

    /// @inheritdoc IAgentIDVerifier
    function agentIDName(address user) external view override returns (string memory) {
        return _names[user];
    }
}
