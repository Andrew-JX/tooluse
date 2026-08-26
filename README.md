# tooluse

一组交付类 Skill：**先把「做完是什么样」写死，再实施，再由不共享盲区的窗口复核。**
针对的是 AI 交付最常见的失败——测试全绿、摘要漂亮，而东西是坏的。

## 安装

```bash
git clone https://github.com/Andrew-JX/tooluse.git
cp -r tooluse/skills/* ~/.claude/skills/
```

只装其中几个：

```bash
cp -r tooluse/skills/acceptance-author ~/.claude/skills/
```

Codex 用 `~/.codex/skills/`。不支持 Skills 的工具直接把对应 `SKILL.md` 贴进上下文；
审查角色另有一份可填的模板：`skills/evidence-led-reviewer/assets/reviewer-role-prompt.md`。

## 有什么

**交付三件套**——按顺序用，价值全在「判据在实现之前就冻结」：

| | 做什么 |
|---|---|
| `acceptance-author` | 实现前起草判据，并主动攻击它的假绿灯：每条判据都要写出一个「通过它但产品仍然错」的实现 |
| `evidence-bound-executor` | 按冻结的判据实施，交接可穷举、可复核的证据，而不是完成摘要 |
| `evidence-led-reviewer` | 从固定的候选提交独立重建事实，按实际影响而非语气给 finding 定级 |

**单独用**：

| | 做什么 |
|---|---|
| `scope-bound-editor` | 改动只做必要的那一点；产物只写最终状态，不写被否掉的方案；一个事实只有一个家；行为改了扫一遍抄写点 |
| `grilling` | 开工前一轮轮追问，把很松的想法逼成一组能落地的决定。说「grill me」就触发 |
| `diagnosing-bugs` | 难 bug 与性能回归：先建一个能稳定变红的紧环，再复现、假设、插桩 |
| `worktree-pr` | 一个任务值不值得单开 worktree；从集成分支切、主工作树保持可用、交付前与未动过的 baseline 对比 |
| `codex-cli` | 把一段活派给 Codex CLI 跑：定模型、effort、沙箱权限，以及怎么读回结果 |

## 什么时候不用

一晚上内、单模块、可回滚、不涉及安全数据权限发布的小活，三件套都不触发——
写一句可证伪的判据、完成后查真实 diff 就够。

`scope-bound-editor` 是例外，它没有下限：那一格里的改动最容易顺手重构、把讨论残留写进产物。

## 边界

- 判据能保证尺子不漂，**不能保证尺子本身是对的**。
- 角色名不是权限边界。**同一个窗口里的第二遍检查不算独立复核**——要换一个不共享你盲区的读者：
  另一个模型的窗口、另一个客户端、另一家 CLI。
- 浮动工作区只能出 `ADVISORY`，正式审查必须对着冻结的 candidate。

## 许可

自建内容 MIT（[LICENSE](LICENSE)）。`skills/` 下带 `SOURCE.md` 的目录与 `scripts/vendor/`
是第三方逐字副本，各自适用上游许可证，见 [NOTICE](NOTICE)。

`parked/` 里的东西不安装，见 [parked/README.md](parked/README.md)。
改这个包之前先看 [CONTRIBUTING.md](CONTRIBUTING.md)。
