// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IAgentIDVerifier.sol";
import "./OwnableLite.sol";

/// @dev ERC-721 最小只读接口（只需要 balanceOf）
interface IERC721Minimal {
    function balanceOf(address owner_) external view returns (uint256);
}

/// @title ERC721AgentIDVerifier — 基于 ERC-721 注册表的 Agent ID 校验器
/// @notice 官方 Agent ID 是 SPACE ID 在 BNB Chain 上发行的 ERC-721 身份 NFT：
///         注册表合约 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///         （链上实测：name() = "SPACE ID Agent ID"，symbol() = "AI"；
///           一个钱包恰好持有 1 枚，不可转让）。
///         因此「持有 Agent ID」等价于 balanceOf(user) > 0。
/// @dev 注册表地址可由管理员更新（例如官方将来迁移注册表时使用）。
///      agentIDName 在本实现中返回空字符串：该注册表不支持
///      tokenOfOwnerByIndex 按地址枚举，链上无法可靠地由地址反查名字；
///      名字展示由前端通过 SPACE ID / BAS 等链下索引器解析（仅展示用，
///      不影响持有资格判断）。
contract ERC721AgentIDVerifier is IAgentIDVerifier, OwnableLite {
    /// @notice Agent ID 注册表（ERC-721）合约地址
    address public registry;

    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    error BadRegistryCall();

    /// @param registry_ Agent ID 注册表地址（BSC 主网官方地址见上方说明）
    /// @param initialOwner 初始管理员（零地址 = 部署者；经工厂代理部署时显式传入）
    constructor(address registry_, address initialOwner) OwnableLite(initialOwner) {
        registry = registry_;
        emit RegistryUpdated(address(0), registry_);
    }

    /// @notice 管理员更新注册表地址
    function setRegistry(address newRegistry) external onlyOwner {
        emit RegistryUpdated(registry, newRegistry);
        registry = newRegistry;
    }

    /// @inheritdoc IAgentIDVerifier
    function hasAgentID(address user) external view override returns (bool) {
        if (registry == address(0)) return false;
        // 用 try/catch 包裹外部调用：注册表异常时返回 false 而不是让
        // 调用方整体 revert，便于上层合约给出明确的业务错误。
        try IERC721Minimal(registry).balanceOf(user) returns (uint256 bal) {
            return bal > 0;
        } catch {
            return false;
        }
    }

    /// @inheritdoc IAgentIDVerifier
    /// @dev 链上无法由地址反查名字（见合约头注释），返回空字符串。
    function agentIDName(address) external pure override returns (string memory) {
        return "";
    }
}
