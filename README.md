# tooluse

交付纪律，加上开工前和收尾的几个 Skill：**判据先冻结，再实施，再由不共享盲区的窗口复核。**
针对 AI 交付最常见的失败——测试全绿、摘要漂亮，而东西是坏的。

## 用法

### 把链接给 Agent

> 读 `https://github.com/Andrew-JX/tooluse` 的 README，只加载与当前任务命中的 Skill；
> 结束时说明哪条规则改变了你的行动、哪条被跳过。

Skill 需要安装才会被自动加载。只给链接时，Agent 读到的是这个 README，不会加载 `skills/` 下的正文。

### 安装

```bash
git clone https://github.com/Andrew-JX/tooluse.git
cp -r tooluse/skills/* ~/.claude/skills/
```

只装其中几个：

```bash
cp -r tooluse/skills/acceptance-author ~/.claude/skills/
```

Codex 用 `~/.codex/skills/`。不支持 Skills 的工具，把对应 `SKILL.md` 贴进上下文；
审查角色另有一份可填模板：`skills/evidence-led-reviewer/assets/reviewer-role-prompt.md`。

## 包含什么

**交付三件套**，按顺序用。价值全在「判据在实现之前就冻结」：

| Skill | 做什么 |
|---|---|
| `acceptance-author` | 实现前起草判据，并攻击它的假绿灯：每条判据都要写出一个「通过它但产品仍然错」的实现 |
| `evidence-bound-executor` | 按冻结的判据实施，交接可穷举、可复核的证据，而不是完成摘要 |
| `evidence-led-reviewer` | 从固定的候选提交独立重建事实，按实际影响而非语气给 finding 定级 |

**单独用**：

| Skill | 做什么 |
|---|---|
| `scope-bound-editor` | 改动只做必要的那一点；产物只写最终状态，不写被否掉的方案；一个事实只有一个家；行为改了扫一遍抄写点 |
| `project-doc-system` | 建文档骨架并按触发条件生长：路由式索引控住上下文成本，索引门禁配负向控制 |
| `thinking-toolkit` | 卡住时先选方法再回答：问题层 / 理解层 / 可信层 / 方案层 / 抉择层，十个方法按层路由 |

## 方法

四条不变量。不编号——它们不是步骤，是任何时候都不许违反的条件。

**〔冻结〕判据先于实现，且冻结。**
实现开始后放宽的判据等同于没有判据。目标和硬约束在跟 AI 讨论之前用自己的话写一遍；
之后再写，写下的已经是模型的措辞。改动再小也适用。

**〔事实〕审查看仓库事实，不看摘要。**
角色名不是权限边界，同一个窗口里的第二遍检查不算独立复核。
独立性来自不共享盲区的读者：另一个模型的窗口、另一个客户端、另一家 CLI，让它对着提交自己去读。

**〔拍板〕由人拍板，不外包，放行前要能说明改了什么。**
实现错就重做，判据错回〔冻结〕重新冻结。

**〔不消失〕未决不许静默消失。**
结论只有三种：达成 / 未达成 / 未验证。「部分关闭」不写成「已关闭」，
上一轮的遗留不在新报告里消失。

### 验证强度按影响升档，与改动大小无关

判高影响看五条：**会不会伤到用户、碰不碰数据与权限、有没有安全面、爆炸半径多大、坏了能不能恢复。**

| | 做什么 |
|---|---|
| 低影响 | 写一句可证伪的判据，完成后查真实 diff |
| 高影响 | contract / baseline / candidate 三个 SHA、干净 worktree、独立复核、按风险做负向验证 |

发布触发一次影响评估，不自动升档。

## 什么时候不用

五条判据一条都不命中的低影响改动：三件套不触发，写一句可证伪的判据、完成后查真实 diff 就够。

判的是影响，不是耗时，也不是改了几个文件——一个晚上改完的认证回调，按工时是小活，按影响是高危。

例外：`scope-bound-editor` 没有下限，这一格的改动最容易顺手重构、把讨论残留写进产物。

## 不在这个包里

问清需求、写实现、TDD、代码审查、诊断 bug 用上游
[mattpocock/skills](https://github.com/mattpocock/skills)：

```bash
claude plugins install mattpocock-skills   # 或会话里 /plugin install mattpocock-skills
npx skills@latest add mattpocock/skills    # Codex 等，勾上 setup-matt-pocock-skills
```

只用其中一种装法；两种都用会得到每个 Skill 两份。以
[上游 README](https://github.com/mattpocock/skills#installation-30-second-setup) 为准。
本仓库不复制、不 vendor、不跟进它的版本。

无法安装时，在提示里写死：

> 遇到软件变更，去读 `https://github.com/mattpocock/skills` 的 `skills/engineering/`，
> 只加载与当前任务命中的那个；读不到就明说「不可用」，不要凭记忆假装加载。

它的链子有前提：`implement` 要 spec 或 ticket；`code-review` 要固定 diff 基线、
来源 issue/spec 和已配置的 issue tracker；`grill-with-docs` 会拉 `domain-modeling`
并维护 `CONTEXT.md`。缺这些前提时该链子不适用，明确的小改动直接实现。

## 已知限制

- 判据能保证尺子不漂，不能保证尺子本身是对的。四层门禁会对着一条写错的判据一致地给绿灯。
- 浮动工作区只能出 `ADVISORY`，正式审查必须对着冻结的 candidate。
- 换一个不共享盲区的读者只是降低共享盲区，不是独立性的证明——两个不同模型漏掉同一处，是发生过的。
- 规则来自一个人踩过的坑。没被抓住的事故不产生规则，本包也没有让它们浮出来的机制。
- 信任模型只覆盖人，不覆盖文件。冻结的判据、交接文件、`contracts/` 都会被 agent 当权威事实
  读取并执行，而「谁有权冻结判据」只靠 git 写权限，没有签名或授权层。单人仓库不构成问题；
  接受外部贡献或多人协作时，不受信来源写进仓库的文字会被当成流程指令，这一层本包没有。

## 许可

自建内容 MIT（[LICENSE](LICENSE)）。`skills/` 全部自建。`scripts/vendor/`
是第三方逐字副本，适用上游许可证，见 [NOTICE](NOTICE)。

改这个包之前先看 [CONTRIBUTING.md](CONTRIBUTING.md)。
