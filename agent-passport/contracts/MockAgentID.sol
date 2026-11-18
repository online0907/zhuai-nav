// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockAgentID — 仅供本地测试的 Agent ID 注册表替身
/// @notice 模拟官方 SPACE ID Agent ID 注册表（ERC-721）的最小行为：
///         只有 balanceOf 会被 ERC721AgentIDVerifier 用到。
///         本合约不会部署到主网。
contract MockAgentID {
    string public name = "SPACE ID Agent ID";
    string public symbol = "AI";

    mapping(address => uint256) private _balances;

    /// @notice 测试用：给某地址「发」一个 Agent ID
    function mint(address to) external {
        _balances[to] += 1;
    }

    /// @notice 测试用：模拟注销/失去 Agent ID
    function burnAll(address from) external {
        _balances[from] = 0;
    }

    function balanceOf(address owner_) external view returns (uint256) {
        return _balances[owner_];
    }
}
