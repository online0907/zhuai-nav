# Agent Passport · 代理护照

币安钱包 **Agent ID 黑客松**参赛作品（提交截止 2026-12-09 16:00 北京时间）。

**一句话**：给每个 Agent ID 一本链上信用护照——AI 代理付款、接单、领权益之前，先验明正身、按分放行。

## 快速开始（本地 demo，零成本）

```bash
# 1. 编译（solc 0.8.26 已放在 tools/）
tools/solc --optimize --optimize-runs 200 --bin --abi --overwrite -o build contracts/*.sol

# 2. 跑测试（35 项，本地 EVM）
.venv/bin/python test/test_passport.py

# 3. 看前端演示：直接用浏览器打开 frontend/index.html
#    未填合约地址时自动进入「演示模式」（模拟数据，可完整点通注册/打卡/验身）
```

## 目录

| 路径 | 内容 |
|---|---|
| `contracts/` | AgentPassport 主合约、两种校验器（官方注册表 / 白名单退路）、演示商家、测试替身 |
| `test/test_passport.py` | 本地测试套件（web3 + eth-tester），35 项全过 |
| `frontend/index.html` | 单页前端：我的护照 + 商家验身演示，演示/主网双模式 |
| `docs/RESEARCH.md` | Agent ID 链上机制调研（注册表实测、名字反查限制、退路） |
| `docs/DEPLOYMENT.md` | 主网 gas 精确估算（合计 ≈0.000083 BNB ≈ $0.049）与三条部署路线 |
| `SUBMISSION.md` | 参赛提交表草稿（部署后填合约地址即可提交） |
| `scripts/estimate_gas.py` | 生成 eth_estimateGas 请求体的小工具 |

## 计分构成（满分 100）

身份 20（实时查官方注册表）+ 历史 0–20（索引背书，唯一中心化项，已披露）
+ 资产 15（BNB 余额档位）+ 资历 15（护照年龄）+ 活跃 30（每日打卡封顶）。

## 红线

不托管资产、不收集密钥、不绕过用户确认、不承诺收益。详见合约头注释与 SUBMISSION.md。
