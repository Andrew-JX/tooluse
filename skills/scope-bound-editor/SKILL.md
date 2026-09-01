---
name: scope-bound-editor
description: Pull an existing edit back to the requested scope and remove process residue or duplicate truth. Use for an explicitly surgical change, a spreading diff, or an artifact containing discarded options, duplicated facts, or stale snapshots.
---

# Scope-Bound Editor

日常预防由安装器写到 skills 目录父级的 `tooluse-resident.md` 承担；本 skill 用于已经需要收缩的改动或产物。

## 改动边界

1. **界外不动。** 只改请求点名的面；范围外问题单独报告。兼容层只在确有旧状态用户时写，已有实现、标准库、平台能力、已装依赖可用时不另造一套。
2. **界内穷尽。** 按被请求的行为搜兄弟：同类调用方、文案、约定、元数据逐一改或说明为什么不改。既有类别的必填字段和命名惯例属于请求本身。
3. **只问有后果的边界。** 必须替用户作不可逆或明显有后果的选择才问；日常实现决定不变成确认关卡。
4. **逻辑确定再钉测试。** 行为和失败路径都要覆盖，但不把尚在讨论的逻辑用测试和文档反向固化。

## 产物边界

1. **只写最终状态。** 标题、提交、注释、导出文件不记录被否方案或这场对话的过程；注释只解释代码恢复不出的理由。
2. **一个事实一个家。** 可独立编辑的副本改成指向具体文件和符号的指针；独立分发产物和界面专属细节例外。
3. **不快照快变值。** 长寿文档记录约束和查询位置，不手填版本、部署 SHA、计数或当前运行状态。
4. **扫抄写点。** 行为变更后搜旧措辞，检查 help、集中字符串、文档、随包 metadata 与链接锚点。

完整事故形态见 [references/incidents.md](references/incidents.md)。

## 边界

从零新建文件时，最小 diff 的邻近保留要求不适用；其余规则仍适用。纯机器格式（porcelain、TSV、JSON）不加说明性文字，缺席也是契约，说明走 stderr 或人类路径。

## 出处

A 的规则形状来自 scarletkc/agents 的 `scoped-change`，B 来自其 `ux-writing`（均 Apache-2.0）；本文件是中文改写与合并。标准库/平台/已装依赖优先的判断顺序取自 DietrichGebert/ponytail（MIT），均非逐字复制。
