# workSkill 唯一真本迁移契约

## 0. 目标与边界

把可安装的 `work-skill` 从公开作品集仓库迁到私人工作系统，并保证活跃文件只有一份：

- 唯一可安装源码：`E:\workspace_DIP\workSkill\skill\work-skill\`
- 私人运行记忆：`E:\workspace_DIP\workSkill\log\`，不得进入 Git、全局 Skill 或公开仓库
- 全局发现入口：`C:\Users\15942\.agents\skills\work-skill`，必须是指向唯一源码的目录联接，不得是副本
- `mj-portfolio` 保留页面上的 `work-skill` 数据项，但删除物理 Skill 包，并把来源说明改成私人本地维护
- 旧版根 `SKILL.md` 与 `cards/` 先进入 DIP 本地 Git 基线，再从活跃工作树删除；需要时从历史恢复，不保留 archive 副本

本批只做 workSkill 迁移。不新增 Agent Skill Eval、Skills CLI / skills.sh 或 agentmemory，不 push、merge、tag 或发布。

## 1. 锚点与阶段清单

### 1.1 冻结阶段

`mj-portfolio` 冻结提交只允许新增本契约：

- `tooluse/contracts/2026-08-09-workskill-canonicalization.md`

该提交同时作为 `mj contract SHA` 与 `mj baseline SHA`。

DIP 冻结阶段只允许：

- 新建 `E:\workspace_DIP\workSkill\.gitignore`，内容必须忽略 `log/`
- 在 `E:\workspace_DIP\workSkill` 初始化本地 Git
- 建立 DIP baseline 提交；该提交可跟踪冻结前已有的根 `SKILL.md`、`cards/` 与 `.gitignore`，不得跟踪 `log/`

### 1.2 实现阶段 · mj-portfolio

允许修改：

- `src/data/toolShares.zh.ts`
- `tooluse/README.md`
- `tooluse/CHANGELOG.md`

允许删除：

- `tooluse/skills/work-skill/SKILL.md`
- `tooluse/skills/work-skill/agents/openai.yaml`
- `tooluse/skills/work-skill/references/a-intake.md`
- `tooluse/skills/work-skill/references/b-stuck.md`
- `tooluse/skills/work-skill/references/c1-task-closeout.md`
- `tooluse/skills/work-skill/references/c2-period-closeout.md`

实现 candidate 不得修改本契约。

### 1.3 实现阶段 · E:\workspace_DIP\workSkill

最终允许跟踪的活跃文件清单：

- `.gitignore`
- `README.md`
- `skill/work-skill/SKILL.md`
- `skill/work-skill/agents/openai.yaml`
- `skill/work-skill/references/a-intake.md`
- `skill/work-skill/references/b-stuck.md`
- `skill/work-skill/references/c1-task-closeout.md`
- `skill/work-skill/references/c2-period-closeout.md`

根 `SKILL.md` 与 `cards/` 在 baseline 中留存后，必须从 candidate 的活跃工作树删除。

### 1.4 环境状态

允许删除并重建这一个目录联接：

- `C:\Users\15942\.agents\skills\work-skill`

不得修改其他全局 Skill。

## 2. 私人 log 保护清单

冻结前只读取文件元数据与哈希，不读取正文：

| 文件 | 冻结前长度 | SHA-256 |
|---|---:|---|
| `log/_找人地图.md` | 373 | `754EA5FE16FACDC3CEB790DE62FAAD70CF9280F54164E9F11A3F5A31AE60B15F` |
| `log/_术语表.md` | 350 | `D08522660D75F2E6BE7CE121BA146EE32212F989F4807E47651C96B88DD32E7F` |

实现期间不得读取、改写、移动或复制这两份文件。

## 3. 实施要求

1. DIP baseline 提交完成后，记录 SHA，再开始迁移。
2. 把 mj baseline 中的精简 `work-skill` 包机械迁移到 `skill/work-skill/`，不得顺手改写 Skill 内容或状态。
3. DIP 新建 `README.md`，只解释三层：可安装源码、私人 log、阶段性沉淀 `E:\studyspace\4*.md`；明确旧版规则和 cards 只在 baseline 历史中恢复。
4. DIP candidate 提交只包含 §1.3 清单所描述的迁移结果。
5. mj 页面数据保留恰好一个 `id: 'work-skill'` 条目，状态保持「尚未实测」；更新 `source`、`usedIn` 与 `installNote`，不得暴露私人 log 文件内容。
6. `tooluse/README.md` 明确三个开发流程 Skill 随本站仓库维护，`work-skill` 在私人本地源维护；四者状态均不因迁移升级。
7. `tooluse/CHANGELOG.md` 记录本次真本迁移与已经生成的 DIP baseline/candidate；mj candidate 写成「本行所在提交」，不得在提交生成前伪造或预测自己的 SHA。
8. 重建全局目录联接后，从全局路径读取到的 `SKILL.md` 必须与 DIP 唯一源码为同一文件内容。

## 4. 验收判据

| # | 类型 | 判据 | 度量与假绿灯防护 |
|---|---|---|---|
| 1 | 机器 | `mj-portfolio` 构建通过 | 在 mj candidate 上运行 `npm run build`，要求 exit 0；构建不代替人工排版验收 |
| 2 | 机器 | mj candidate 的改动集合与 §1.2 完全一致 | `git diff --name-only <mj-baseline>..<mj-candidate>` 与 `git ls-files --others --exclude-standard` 取并集，逐字比较；契约文件出现在实现 diff 即失败 |
| 3 | 机器 | DIP candidate 的 tracked 文件集合与 §1.3 完全一致 | `git -C E:\workspace_DIP\workSkill ls-files` 排序后逐字比较；仅看普通 diff 会漏新文件，因此必须枚举索引 |
| 4 | 机器 | DIP 活跃工作树只有一个 `SKILL.md`，且根 `SKILL.md` 与 `cards/` 均不存在 | 在排除 `.git` 的工作树中枚举 `SKILL.md`；分别 `Test-Path` 根文件和 cards；Git 历史中的旧内容不算活跃副本 |
| 5 | 机器 | 迁移后的 Skill 包逐文件等于 mj baseline 中的发布包 | 对 §1.2 删除清单中的每个源文件用 `git show <mj-baseline>:<path>` 取内容，与 DIP 对应目标做 SHA-256 比较；只比较文件名不构成通过 |
| 6 | 机器 | §2 两份私人 log 未变化且未进入 DIP Git | 重新计算长度与 SHA-256，逐项对照 §2；`git -C ... ls-files -- log` 必须为空，`git check-ignore` 必须命中两份文件 |
| 7 | 机器 | DIP baseline 能恢复旧根规则与每张旧 card，而 DIP candidate 不再把它们作为活跃文件 | 先用 `git ls-tree -r --name-only <dip-baseline> -- cards` 枚举 baseline 中的 card 集合，再对根 `SKILL.md` 与枚举结果逐项运行 `git show`；对 candidate 检查这些路径不存在；只删除不留恢复锚点即失败 |
| 8 | 机器 | 全局 `work-skill` 是指向 §0 唯一源码的 Junction，且全局/源码 `SKILL.md` 哈希相同 | `Get-Item` 核 `LinkType` 和 resolved target，再计算两条路径 SHA-256；普通复制即使内容相同也失败 |
| 9 | 机器 | 页面数据仍有且只有一个 `work-skill`，状态未升级，来源说明不再声称随本站仓库维护 | 对 `toolShares` 的 `id` 精确计数并读取该对象字段；同时比较 baseline/candidate 的整个 `toolShares` 元素数相等，防止顺手新增第三方工具 |
| 10 | 机器 | README 与 CHANGELOG 如实区分公开仓库 Skill、私人 Skill 源和私人 log | grep 关键词并人工通读对应段落；不得写入 §2 文件正文、个人姓名或组织信息 |
| 11 | 机器 | 两个仓库 candidate 均已固定且工作区干净，本批未 push | 分别记录两个 candidate SHA、`git status --short` 为空；mj 的远端引用在本批前后相同 |
| 12 | 人工 | 用户在 1280px 与 375px 各看一次 tooluse 页面，`work-skill` 卡片仍存在，更新后的来源/安装说明无截断、重叠、横向溢出或内层滚动 | 验收者是用户；执行方只能写「未验证，待用户确认」 |

## 5. 限定词、冲突与已知假绿灯

- “唯一源码”只指 DIP candidate 活跃工作树中的可安装 `work-skill` 包；Git 历史不是活跃副本。
- “全局”指当前 Windows 用户目录 `C:\Users\15942\.agents\skills`，不代表其他机器。
- “未变化”只指 §2 已冻结的文件长度和 SHA-256。
- “页面保留”指 `toolShares` 数据项及实际渲染，不代表 mj 继续保存 Skill 源文件。
- 冻结阶段清单与实现阶段清单按阶段分开，不混用文件集合口径。
- 新规则没有被本契约引入；既有 acceptance-author 规则全部检查当前契约，不使用“下批生效”豁免。

冲突检查：本批允许本地提交但禁止 push，与三锚点和两个本地仓库 candidate 兼容。私人 log 被要求保留但同时必须排除于 Git 和 Skill 联接之外，不冲突。
