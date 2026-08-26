# 第三方 Skill — 逐字副本

`grilling/` 与 `grill-me/` **不是本仓库写的**，是从上游按固定 SHA 取回的逐字副本。它们和自建 Skill 平铺在同一层，因为 Skill 发现只扫 `skills/` 的直接子目录——多套一层目录会让它们装不上。每个目录内的 `SOURCE.md` 标明出处。

## 硬规矩：本地永不编辑

改动一律提到上游；本仓库要覆盖上游行为时，写进自建 Skill 并在那里说明，**不要改这里的文件**。

理由是本仓库反复引用的那条：同一套规则放两个可独立编辑的位置，就会各自演化，然后没人知道哪份是对的。钉住 SHA 且不编辑，可以把「静默分叉」降级成「可检测的陈旧」——陈旧能靠比对发现，分叉不能。

## 清单

| Skill | 上游 | 路径 | 钉住 SHA | 许可证 |
|---|---|---|---|---|
| `diagnosing-bugs` | mattpocock/skills | `skills/engineering/diagnosing-bugs` | `6654f6b60cd9` | MIT |
| `grilling` | mattpocock/skills | `skills/productivity/grilling` | `6654f6b60cd9` | MIT |
| `codex-cli` | scarletkc/agents | `skills/codex-cli` | `d5a312346adc` | Apache-2.0 |
| `worktree-pr` | scarletkc/agents | `skills/worktree-pr` | `d5a312346adc` | Apache-2.0 |

全部取回于 2026-08-25。每个目录内的 `SOURCE.md` 是该副本的权威记录，上表是汇总。

| 上游 | 版权 | 许可证全文 |
|---|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | Copyright (c) 2026 Matt Pocock | [LICENSE-mattpocock-skills](LICENSE-mattpocock-skills) |
| [scarletkc/agents](https://github.com/scarletkc/agents) | Copyright 2026 scarletkc | [LICENSE-scarletkc-agents](LICENSE-scarletkc-agents) · [NOTICE-scarletkc-agents](NOTICE-scarletkc-agents) |

**`grill-me` 曾经收录，2026-08-26 移除。** 它是个 7 行转发壳，靠 `disable-model-invocation: true` 声明「模型不许自主调用，只能人手动喊」。但官方 `quick_validate.py` 的允许字段只有 `allowed-tools / description / license / metadata / name`——**这个字段不被支持，那道锁根本不存在**。于是它退化成一个 description 模糊、与 `grilling` 抢触发的多余节点。

移除不违反「本地永不编辑」：没有改它的内容，只是不再收录。**触发能力零损失**——`grilling` 自己的 description 明写 `or uses any 'grill' trigger phrases`，「grill me」这类说法本来就由它接。

## 没收录的两个，以及为什么

- **`ux-writing`（scarletkc）与 `scoped-change`（scarletkc）** —— 规则形状已经中文改写并合并进自建的 `scope-bound-editor`，收原文会变成同一套规则的第二份副本。
- **`tdd`（mattpocock）** —— 它的「先写失败测试」与 `scope-bound-editor` A4「逻辑定了再钉测试」直接冲突，两个不能同时装。只把它 anti-patterns 一节的三个形状按判据视角改写进了 `acceptance-author` 第 10 项。

## 怎么核对是否已经陈旧

```bash
./scripts/check-vendor-freshness.sh
```

它读每个 `SOURCE.md` 的钉住 SHA，与上游 main 逐字比对，**只报告不自动更新**。`.github/workflows/vendor-freshness.yml` 每周一自动跑一次，发现分叉就开一个 issue。

有差异说明上游动了。**决定跟不跟是判断，不是自动动作**：确认要跟时重新取回、更新上表的 SHA 与日期，并在变更账本记一行。

## 为什么只有这两个

上游约 35 个 Skill，这里只放挑过的。**逐个读过原文、比对过与自建 Skill 的重叠才收**，不批量搬——把没挑过的搬进来等于把候选表伪装成工具箱。评估结论记在 `CHANGELOG.md`。
