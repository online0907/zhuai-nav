// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IAgentIDVerifier.sol";
import "./OwnableLite.sol";

/// @title AgentPassport — Agent 护照：给 Agent ID 一本链上信用护照
/// @notice 持有 Agent ID（币安 Agentic Wallet 的 .ai 链上名字）的钱包可以
///         在这里注册一本不可转让的「护照」。合约根据链上可读履历计算
///         0–100 的信用分，并提供公开查询接口，供其他合约/商家在
///         「让某个 AI 代理付款、接单、领取权益之前」先验明正身、按分放行。
///
///         设计要点：
///         - 资格校验可插拔：通过 IAgentIDVerifier 接口完成，官方注册表
///           (SPACE ID Agent ID, ERC-721) 是默认实现，也可切换白名单实现。
///         - 分数全部由链上可验证数据构成（见 _scoreOf 的逐项注释）。
///           EVM 合约读不到「任意地址的历史交易笔数 / 首笔交易时间」
///           （nonce 与历史不对外暴露），因此这两项用「护照年龄 +
///           打卡活跃」近似，并预留 historyBonus 背书位（见下方说明）。
///         - 本合约不托管、不经手任何资产：没有 payable 函数、没有
///           transfer/approve 逻辑；不收集助记词/私钥/API 密钥；
///           不绕过用户确认（注册与打卡都必须由用户本人签名发起）；
///           信用分只是身份信号，本合约不承诺任何收益或回报。
contract AgentPassport is OwnableLite {
    // ------------------------------------------------------------------
    // 数据结构
    // ------------------------------------------------------------------

    struct Passport {
        uint64 registeredAt; // 注册时间（unix 秒）；0 = 未注册
        uint64 lastCheckInDay; // 最近一次打卡的 UTC 日序号（timestamp / 86400）
        uint32 totalCheckInDays; // 累计打卡天数
        uint32 currentStreak; // 当前连续打卡天数
        uint8 historyBonus; // 历史分背书（0–20，见 setHistoryBonus 说明）
    }

    /// @notice 当前使用的 Agent ID 校验器（可由管理员切换）
    IAgentIDVerifier public verifier;

    mapping(address => Passport) private _passports;

    /// @notice 已注册护照总数
    uint256 public totalPassports;

    // ------------------------------------------------------------------
    // 事件
    // ------------------------------------------------------------------

    event PassportRegistered(address indexed user, uint256 timestamp);
    event CheckedIn(address indexed user, uint256 day, uint256 streak, uint256 newScore);
    event VerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
    event HistoryBonusSet(address indexed user, uint256 bonus);

    // ------------------------------------------------------------------
    // 错误
    // ------------------------------------------------------------------

    error AlreadyRegistered();
    error NotRegistered();
    error NoAgentID();
    error VerifierCallFailed();
    error AlreadyCheckedInToday();
    error BonusTooHigh();

    /// @notice 历史分背书上限（总分 100 中历史维度最多占 20 分）
    uint256 public constant MAX_HISTORY_BONUS = 20;

    /// @param verifier_ 初始校验器地址（主网部署时传 ERC721AgentIDVerifier 地址）
    /// @param initialOwner 初始管理员（零地址 = 部署者；经工厂代理部署时显式传入）
    constructor(address verifier_, address initialOwner) OwnableLite(initialOwner) {
        verifier = IAgentIDVerifier(verifier_);
        emit VerifierUpdated(address(0), verifier_);
    }

    // ------------------------------------------------------------------
    // 管理员
    // ------------------------------------------------------------------

    /// @notice 切换 Agent ID 校验器实现（例如从白名单切换到官方注册表校验器）
    function setVerifier(address newVerifier) external onlyOwner {
        emit VerifierUpdated(address(verifier), newVerifier);
        verifier = IAgentIDVerifier(newVerifier);
    }

    /// @notice 写入「历史分背书」（0–20 分）。
    /// @dev 为什么需要背书：钱包的真实历史（首笔交易年龄、总交易笔数）
    ///      在 EVM 内不可读，只能由链下索引器（如 BAS / BscScan 索引）
    ///      计算后回写。本函数是给未来索引预言机预留的入口，当前由
    ///      管理员人工核对后写入。这是本设计中唯一的中心化环节，
    ///      文档中如实披露；其余 80 分全部为链上自动计算。
    function setHistoryBonus(address user, uint8 bonus) external onlyOwner {
        if (_passports[user].registeredAt == 0) revert NotRegistered();
        if (bonus > MAX_HISTORY_BONUS) revert BonusTooHigh();
        _passports[user].historyBonus = bonus;
        emit HistoryBonusSet(user, bonus);
    }

    // ------------------------------------------------------------------
    // 核心写操作（必须由用户本人签名发起，不绕过确认）
    // ------------------------------------------------------------------

    /// @notice 注册护照。调用者必须当前持有 Agent ID（由校验器判定）。
    function register() external {
        if (_passports[msg.sender].registeredAt != 0) revert AlreadyRegistered();

        bool held;
        try verifier.hasAgentID(msg.sender) returns (bool ok) {
            held = ok;
        } catch {
            revert VerifierCallFailed();
        }
        if (!held) revert NoAgentID();

        _passports[msg.sender].registeredAt = uint64(block.timestamp);
        totalPassports += 1;
        emit PassportRegistered(msg.sender, block.timestamp);
    }

    /// @notice 每日打卡（UTC 日界，每地址每天一次），提升活跃分。
    function checkIn() external {
        Passport storage p = _passports[msg.sender];
        if (p.registeredAt == 0) revert NotRegistered();

        uint256 today = block.timestamp / 1 days; // UTC 日序号
        if (p.lastCheckInDay == today) revert AlreadyCheckedInToday();

        // 连续天数：与上次打卡相差恰好 1 天则延续，否则重新计为 1
        if (p.lastCheckInDay != 0 && today == uint256(p.lastCheckInDay) + 1) {
            p.currentStreak += 1;
        } else {
            p.currentStreak = 1;
        }
        p.lastCheckInDay = uint64(today);
        p.totalCheckInDays += 1;

        emit CheckedIn(msg.sender, today, p.currentStreak, getScore(msg.sender));
    }

    // ------------------------------------------------------------------
    // 公开查询接口（供其他合约按分放行——本项目的核心卖点）
    // ------------------------------------------------------------------

    /// @notice 是否已注册护照
    function isRegistered(address user) external view returns (bool) {
        return _passports[user].registeredAt != 0;
    }

    /// @notice 信用分（0–100）。未注册返回 0。
    /// @dev 计分构成（满分 100，全部可验证）：
    ///      - 身份分 20：当前仍持有 Agent ID（实时向注册表校验，
    ///        校验器异常时按 0 计，不让整个查询 revert）；
    ///      - 历史分 0–20：索引背书（见 setHistoryBonus，唯一中心化项）；
    ///      - 资产分 15：BNB 余额档位（≥1:15 / ≥0.1:10 / ≥0.01:5 / >0:2）；
    ///      - 资历分 15：护照年龄（≥30 天:15 / ≥7 天:10 / ≥1 天:5 / 当天:2）
    ///        —— 以「护照年龄」近似钱包资历，因为钱包真实年龄链上不可读；
    ///      - 活跃分 30：累计打卡天数，每天 1 分，30 天封顶。
    function getScore(address user) public view returns (uint256 score) {
        Passport storage p = _passports[user];
        if (p.registeredAt == 0) return 0;

        // 身份分（20）
        try verifier.hasAgentID(user) returns (bool ok) {
            if (ok) score += 20;
        } catch {
            // 校验器故障时身份分按 0 计，查询不中断
        }

        // 历史分（0–20，背书写入时已做上限校验）
        score += p.historyBonus;

        // 资产分（15）：余额是 EVM 内可直接读取的链上数据
        uint256 bal = user.balance;
        if (bal >= 1 ether) score += 15;
        else if (bal >= 0.1 ether) score += 10;
        else if (bal >= 0.01 ether) score += 5;
        else if (bal > 0) score += 2;

        // 资历分（15）：护照年龄近似
        uint256 ageDays = (block.timestamp - p.registeredAt) / 1 days;
        if (ageDays >= 30) score += 15;
        else if (ageDays >= 7) score += 10;
        else if (ageDays >= 1) score += 5;
        else score += 2;

        // 活跃分（30）：累计打卡天数封顶 30
        score += p.totalCheckInDays > 30 ? 30 : p.totalCheckInDays;

        if (score > 100) score = 100;
    }

    /// @notice 读取完整护照信息。
    /// @return registered 是否已注册
    /// @return name Agent ID 名字（校验器无法提供时为空字符串，前端用链下索引补齐）
    /// @return score 当前信用分（0–100）
    /// @return registeredAt 注册时间（unix 秒）
    /// @return totalCheckInDays 累计打卡天数
    /// @return currentStreak 当前连续打卡天数
    /// @return lastCheckInDay 最近打卡的 UTC 日序号
    /// @return historyBonus 历史分背书（0–20）
    function getPassport(address user)
        external
        view
        returns (
            bool registered,
            string memory name,
            uint256 score,
            uint256 registeredAt,
            uint256 totalCheckInDays,
            uint256 currentStreak,
            uint256 lastCheckInDay,
            uint256 historyBonus
        )
    {
        Passport storage p = _passports[user];
        registered = p.registeredAt != 0;
        registeredAt = p.registeredAt;
        totalCheckInDays = p.totalCheckInDays;
        currentStreak = p.currentStreak;
        lastCheckInDay = p.lastCheckInDay;
        historyBonus = p.historyBonus;
        score = getScore(user);
        if (registered) {
            try verifier.agentIDName(user) returns (string memory n) {
                name = n;
            } catch {
                name = "";
            }
        } else {
            name = "";
        }
    }

    /// @notice 分项明细（供前端画出「分数构成条」）
    /// @return identity 身份分（0 或 20）
    /// @return history 历史分（0–20）
    /// @return balanceTier 资产分（0–15）
    /// @return seniority 资历分（0–15）
    /// @return activity 活跃分（0–30）
    function getScoreBreakdown(address user)
        external
        view
        returns (uint256 identity, uint256 history, uint256 balanceTier, uint256 seniority, uint256 activity)
    {
        Passport storage p = _passports[user];
        if (p.registeredAt == 0) return (0, 0, 0, 0, 0);

        try verifier.hasAgentID(user) returns (bool ok) {
            if (ok) identity = 20;
        } catch {}

        history = p.historyBonus;

        uint256 bal = user.balance;
        if (bal >= 1 ether) balanceTier = 15;
        else if (bal >= 0.1 ether) balanceTier = 10;
        else if (bal >= 0.01 ether) balanceTier = 5;
        else if (bal > 0) balanceTier = 2;

        uint256 ageDays = (block.timestamp - p.registeredAt) / 1 days;
        if (ageDays >= 30) seniority = 15;
        else if (ageDays >= 7) seniority = 10;
        else if (ageDays >= 1) seniority = 5;
        else seniority = 2;

        activity = p.totalCheckInDays > 30 ? 30 : p.totalCheckInDays;
    }
}
