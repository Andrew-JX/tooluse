# 第三方 Skill — 逐字副本

`grilling/` 与 `grill-me/` **不是本仓库写的**，是从上游按固定 SHA 取回的逐字副本。它们和自建 Skill 平铺在同一层，因为 Skill 发现只扫 `skills/` 的直接子目录——多套一层目录会让它们装不上。每个目录内的 `SOURCE.md` 标明出处。

## 硬规矩：本地永不编辑

改动一律提到上游；本仓库要覆盖上游行为时，写进自建 Skill 并在那里说明，**不要改这里的文件**。

理由是本仓库反复引用的那条：同一套规则放两个可独立编辑的位置，就会各自演化，然后没人知道哪份是对的。钉住 SHA 且不编辑，可以把「静默分叉」降级成「可检测的陈旧」——陈旧能靠比对发现，分叉不能。

## 清单

| Skill | 上游 | 路径 | 许可证 |
|---|---|---|---|
| `grilling` | [mattpocock/skills](https://github.com/mattpocock/skills) | `skills/productivity/grilling` | MIT |
| `grill-me` | [mattpocock/skills](https://github.com/mattpocock/skills) | `skills/productivity/grill-me` | MIT |

- **取回 SHA**：`6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`
- **取回日期**：2026-08-25
- **版权**：Copyright (c) 2026 Matt Pocock，许可证全文见 [LICENSE-mattpocock-skills](LICENSE-mattpocock-skills)

`grill-me` 只是一个转发壳，正文在 `grilling`，**两个必须一起装**，否则 `grill-me` 触发后会指向不存在的 Skill。

## 怎么核对是否已经陈旧

```bash
curl -sf "https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md" | diff - skills/grilling/SKILL.md
```

有差异说明上游动了。**决定跟不跟是判断，不是自动动作**：确认要跟时重新取回、更新上表的 SHA 与日期，并在变更账本记一行。

## 为什么只有这两个

上游约 35 个 Skill，这里只放真实用过的。没用过就没有评价的资格，把没用过的搬进来等于把候选表伪装成工具箱。
