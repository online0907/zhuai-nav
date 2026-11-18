// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title OwnableLite — 极简版单管理员权限（避免引入外部依赖库）
/// @notice 只有 owner 可以调用带 onlyOwner 的管理函数。
///         owner 权限仅限于：切换校验器、写入历史分背书、设置演示阈值，
///         不涉及用户资产（本项目合约不托管、不经手任何资产）。
abstract contract OwnableLite {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    /// @param initialOwner 初始管理员；传零地址时默认为部署者 msg.sender。
    ///        经 CREATE2 工厂等代理部署时，构造函数里的 msg.sender 是工厂
    ///        合约而非真实部署者，此时必须显式传入真实管理员地址。
    constructor(address initialOwner) {
        owner = initialOwner == address(0) ? msg.sender : initialOwner;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice 移交管理员权限（新地址为零地址时视为放弃，谨慎使用）
    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
