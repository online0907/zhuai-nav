// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./AgentPassport.sol";
import "./OwnableLite.sol";

/// @title DemoMerchant — 演示商家：「代理付款前先验身」
/// @notice 模拟一个商家/平台在接受某个 AI 代理付款（或接单）之前的
///         身份核验环节：向 Agent Passport 查询该代理的信用分，
///         达到门槛才放行。本合约只做查询与判定并发出事件，
///         不经手任何资产、不发起任何转账——真实接入时，商家合约
///         只需在自己的付款函数里加一行同样的校验即可。
contract DemoMerchant is OwnableLite {
    /// @notice 护照合约
    AgentPassport public passport;

    /// @notice 放行门槛（信用分 ≥ threshold 才放行），默认 60
    uint256 public threshold = 60;

    event CheckoutVerdict(address indexed agent, uint256 score, bool allowed);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /// @param initialOwner 初始管理员（零地址 = 部署者；经工厂代理部署时显式传入）
    constructor(address passport_, address initialOwner) OwnableLite(initialOwner) {
        passport = AgentPassport(passport_);
    }

    /// @notice 管理员调整放行门槛（0–100）
    function setThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold <= 100, "threshold > 100");
        emit ThresholdUpdated(threshold, newThreshold);
        threshold = newThreshold;
    }

    /// @notice 验身查询（只读）：返回是否放行、信用分、是否已注册护照
    function verifyAgent(address agent)
        external
        view
        returns (bool allowed, uint256 score, bool registered)
    {
        registered = passport.isRegistered(agent);
        score = passport.getScore(agent);
        allowed = registered && score >= threshold;
    }

    /// @notice 模拟一次结账验身（写事件版，供前端演示调用）。
    /// @dev 不转移任何资产，仅记录判定结果。
    function simulateCheckout(address agent) external returns (bool allowed) {
        uint256 score = passport.getScore(agent);
        allowed = passport.isRegistered(agent) && score >= threshold;
        emit CheckoutVerdict(agent, score, allowed);
    }
}
