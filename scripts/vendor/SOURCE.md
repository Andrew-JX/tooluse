# quick_validate.py — 第三方逐字副本，本地不编辑

本目录**不是本仓库写的**。

| | |
|---|---|
| 上游 | [anthropics/skills](https://github.com/anthropics/skills) |
| 路径 | `skills/skill-creator/scripts` |
| 钉住 SHA | `3b3fad96af16a10759d930941b4520ba0c40edae` |
| 取回日期 | 2026-08-26 |
| 许可证 | Apache-2.0 — Copyright 2026 Anthropic, PBC，全文见 [LICENSE-anthropics-skills.txt](LICENSE-anthropics-skills.txt) |

收它的理由：`self-check.sh` 第 ② 条要跑官方 validator，而 CI 机器上没有 skill-creator，
那一步一直显示「未找到，跳过」——**一条只在作者本机生效的门禁等于没有门禁**。

**改动一律提到上游。** 跑 `scripts/check-vendor-freshness.sh` 核对是否已与上游分叉。
