// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IAgentIDVerifier — Agent ID 持有资格校验接口（可插拔）
/// @notice Agent Passport 不把「什么是 Agent ID」写死在本合约里，
///         而是通过本接口向外部校验器询问。这样做有两个好处：
///         1) 官方注册表地址/校验方式如有调整，只需由管理员把校验器
///            换成新实现，护照合约本身不用重新部署；
///         2) 在注册表集成尚未确认的阶段，可以临时换成白名单校验器
///            (AllowlistVerifier) 给种子用户开通注册，之后再切回官方注册表。
/// @dev 红线：本接口只做「只读校验」，不涉及任何密钥、签名或资产操作。
interface IAgentIDVerifier {
    /// @notice 判断某地址当前是否持有一个有效的 Agent ID（.ai 名字）。
    /// @param user 待校验的钱包地址
    /// @return held true = 持有 Agent ID
    function hasAgentID(address user) external view returns (bool held);

    /// @notice 读取某地址的 Agent ID 名字（例如 "fomome.ai"）。
    /// @dev 并非所有注册表都支持链上反查名字（SPACE ID 的 .ai 注册表
    ///      不支持按地址枚举 tokenId，链上无法可靠反查名字字符串）。
    ///      实现方在无法提供名字时应返回空字符串 ""，调用方不得
    ///      把空字符串当作「没有 Agent ID」——持有判断只认 hasAgentID。
    /// @param user 待查询的钱包地址
    /// @return name 名字字符串，可能为空
    function agentIDName(address user) external view returns (string memory name);
}
