---
name: project-doc-system
description: Set up and grow a project's documentation so an agent can work from documents instead of re-reading the whole codebase. Use when a project has no documentation structure yet, when documents have drifted from the implementation, when deciding which document to write next, when building an index so context stays affordable, or when requiring that every task and bug fix leaves a record. Covers the starting set, growth triggers, single-source rules, and machine gates.
---

# Project Doc System

文档存在的目的只有一个：下一个窗口冷启动时，不用把仓库读一遍就能知道去哪、能改什么、什么已经验证过。达不到这个目的的文档是负债——它要被维护、会过期、还会在过期之后指挥人做错事。

这份 skill 管四件事：一穷二白时写哪几份、索引怎么组织、什么条件下加下一份、怎么保证写下来的东西不烂掉。输出语言跟随用户。

## 0. 脚本在哪

下面的命令必须用**本 skill 目录内**的脚本路径。Skill 安装后当前工作目录是用户的项目，`scripts/` 不在那里，写相对路径会直接 `MODULE_NOT_FOUND`。先确定这个目录：

```bash
SKILL_DIR=<本 SKILL.md 所在目录>   # 例如 ~/.claude/skills/project-doc-system
```

`init-docs.mjs` 是一次性脚手架，从 `$SKILL_DIR` 跑就够了。`check-doc-index.mjs` 不一样——它要进项目的默认验证命令，所以必须**复制进目标项目**再接线；留在 skill 目录里意味着项目的 CI 依赖一个不在项目仓库里的文件，换台机器就失效。

## 1. 先判断项目在哪个阶段

跑一次探测，不要凭印象：

```bash
node "$SKILL_DIR/scripts/init-docs.mjs" --project-root <path> --dry-run
```

它会报告已有什么、缺什么、哪些生长条件已经触发。`--dry-run` 不写任何文件。

## 2. 一穷二白：起始集只有四份

| 文件 | 装什么 | 不装什么 |
|---|---|---|
| `AGENTS.md` | 协作规则、目录清单、指向索引的一行 | 教程、背景介绍、任何会随代码变的描述 |
| `docs/INDEX.md` | 每份文档一行：路径、权威范围、何时读 | 内容摘要 |
| `docs/decisions.md` | 无法从代码恢复的决策理由 | 代码已经说清楚的事 |
| `docs/progress.md` | 每批一行：改了什么、依据、证据、未验证 | 只有成功的记录 |

生成：

```bash
node "$SKILL_DIR/scripts/init-docs.mjs" --project-root <path>
```

它只建这四份，已存在的一律跳过不覆盖。

**为什么不多建几份。** 一份还没有内容的文档，在形式上已经宣称自己是权威，下一个窗口会照着它干活。文档结构是项目真实风险长出来的，不是开局套装：有跨境数据合规就会长出合规文档，有数据库迁移就会长出 schema 文档，没有就不该有。预先建好的空壳只会让索引里全是「待补充」，然后索引本身失去可信度。

## 3. 索引是路由表，不是摘要

`docs/INDEX.md` 每行只有三样东西：**路径 / 权威范围 / 何时读**。

- **不写内容摘要。** 摘要是内容的副本，内容一改摘要就变成假话，而且没有任何门禁守得住它。索引的职责是把人送到正确的文档，不是替代它。
- **不要求每次任务都读。** 单文件、路径明确的修复直接读代码更快，强制读索引只会变成一条没人遵守的规则。索引按**歧义**触发：不确定权威来源在哪、任务跨多个领域、上线或事后复盘、要新增或改动文档入口。
- **权威范围这一栏是关键。** 它回答「这份文档说了算的是什么，说不了算的是什么」。没有这一栏，两份文档会各自宣称同一件事。

索引省下的不是 token，是「找错权威文档」这个失败。省 token 是它的副作用。

## 4. 按需生长

只有触发条件满足了才加下一份。详表见 [references/doc-catalog.md](references/doc-catalog.md)，主干是：

| 加什么 | 触发条件 |
|---|---|
| API 契约文档 + 双向门禁 | 对外路由超过 5 条 |
| 数据模型文档 | 出现第二张迁移表，或第一条不可逆迁移 |
| 部署 runbook、上线自检单 | **第一次生产部署之前** |
| 领域文档 | 同一个领域被追问到第三次 |
| 账本归档（按批次 / 按功能 / 按时间，随项目定） | `progress.md` 超过约 500 行 |
| 目录清单机器门禁 | 顶层目录超过 6 个 |

新增任何一份，同一个提交里必须把它加进 `docs/INDEX.md`，否则门禁会拦。

## 5. 留痕：每批一行

每次任务、每次改 bug，往 `docs/progress.md` 追加一行，四栏：

**改了什么 · 依据 · 证据 · 未验证**

第四栏是全部价值所在。事后查账本，查的从来不是「当时做成了什么」——那个代码里有；查的是**当时知道什么、什么没验证**。只记成功的账本没人会回头看。

证据栏写命令、exit code、提交 SHA，不写「已完成」「测试通过」这类无法核对的词。

## 6. 三条硬规则

1. **单一事实源。** 同一个事实不得同时存在于两处可独立编辑的文档。出现即指定一处为权威，其余改成引用。重复副本是最大的漂移来源——改了一处，另一处立刻变成假话，而且没有任何信号。
2. **禁止快照型文档。** 不写「当前实现是什么样」的镜像文档。当前状态由代码和门禁回答；文档只写仍然生效的**约束**，和无法从代码恢复的**理由**。快照文档必然落后于代码，而它的形式又暗示自己是权威，结果是指挥人去修改正确的实现。
3. **规则被质疑时给验证路径。** 每条写成「必须」的规则，要能回答「不信就去跑哪条命令 / 哪个测试」。做不到就说明它没有门禁，应当改写成带边界的建议。没有门禁的「必须」等于没写。

## 7. 门禁

索引与真实文档双向比对，脚本可直接用：

先把脚本复制进项目（位置随项目惯例，下面以 `scripts/` 为例），再跑：

```bash
cp "$SKILL_DIR/scripts/check-doc-index.mjs" <project-root>/scripts/
node <project-root>/scripts/check-doc-index.mjs --project-root <project-root>
node <project-root>/scripts/check-doc-index.mjs --project-root <project-root> --self-test
```

`--self-test` 遍历所有负向控制，必须先过它再接线。接进项目的默认验证命令，不要留成「需要时手工跑」——不在默认路径上的门禁等于不存在。

项目专属的门禁（API 契约、目录清单、配置与文档一致）形状可移植但内容不可移植，按 [references/gates.md](references/gates.md) 手工配，**每条都要带负向控制**。一个不会失败的门禁保护不了任何东西：把被守护的事实改坏，门禁必须报错，否则它守的不是它声称守的那个属性。

## 8. 报告口径

分清四件事，不要合并：

- **脚手架已生成**：文件建出来了，里面还没有真实内容。
- **内容已填写**：人已经把项目事实写进去了。
- **门禁已接入**：跑在默认验证路径上，且负向控制通过。
- **未验证**：还没有在真实项目上跑完一轮。

生成骨架不等于项目有文档，接入门禁不等于文档准确。
