---
name: work-skill
description: "Structure work tasks through four privacy-aware entry cards: intake, stuck, task closeout, and day/week closeout. Use when clarifying a work assignment, recording assumptions and unknowns, stopping an evidence-free debugging loop, closing a task with evidence, or preparing an unsent factual status draft without exposing sensitive work data."
---

# Work Skill

把工作任务整理成可结账的事实，不替用户做业务判断、不替用户排序、不发送消息。输出语言跟随用户。

## 先过数据边界

- 只处理用户手写的通用概述：任务类型、技术症状、时序和量级。
- 不接收真实代码、日志、密钥、内部路径、未公开产品信息或能定位组织与个人的数据。用户已经粘贴时，停止处理并要求重新概述；不要声称可以撤回或“脱敏后继续”。
- 真实证据只留在获准的工作环境；Skill 输出写脱敏摘要或本地证据引用。
- 对外内容只生成并标注「草稿·未发送」。

## 选择入口

只读取本次需要的一张卡：

- 接到任务或需要确认理解：读 [A · 接任务](references/a-intake.md)。
- 连续约 90 分钟没有新证据，或范围/工期发生变化：读 [B · 卡住](references/b-stuck.md)。90 分钟是试用阈值，可按真实节奏调整并记录原因。
- 任务完成、暂停或需要同步：读 [C1 · 任务收尾](references/c1-task-closeout.md)。
- 日终、周终或下一工作单元开始前：读 [C2 · 日终周终](references/c2-period-closeout.md)。

## 共用规则

- 结论必须带证据；没有证据就标 `[无证据·仅判断]`。
- 假设写成 `假设 X；若 X 不成立，则 Y`，并使用任务内唯一编号 `T<n>-=<n>`。
- 未决使用任务内唯一编号 `T<n>-#<n>`；后续逐条结为已解决、仍未解决或已放弃。
- 区分 `已改`、`已测（范围：X）`、`已验证完成（判据：Y）`；写不出括号内容就降一级。
- 允许必要的事实限定词和不确定性表达；删除无证据的自我评价，不删除影响判断所需的范围与风险。
- 工作侧的 PR review、CI 和合并权限由团队既有流程提供；这个 Skill 只守个人负责的接任务、判据、执行记录和结账，不另造一套公司流程。

## 状态

这个 skill 的当前状态由仓库 README 的「状态词」一节定义，本文件不复述——状态会变，写在两处必然有一处陈旧。

只有一件事写在这里不会过期：四张入口卡从未在真实工作流里被调用过，它们的形状只经过虚构任务干跑。任何「这套流程验证过」的说法都不适用于它。
