#!/usr/bin/env node
// Create the starting documentation set for a project, and report which growth
// triggers already fire.
//
// It writes four files and nothing else. A document that exists before it has
// content still claims to be authoritative, and the next window will work from
// it. Everything past the starting set is added when its trigger fires; see
// references/doc-catalog.md.

import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

function parseArgs(argv) {
  const args = { dryRun: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--project-root") args.projectRoot = argv[i + 1];
    else if (argv[i] === "--docs-dir") args.docsDir = argv[i + 1];
    else if (argv[i] === "--dry-run") args.dryRun = true;
  }
  if (!args.projectRoot) throw new Error("--project-root 是必填的");
  if (!existsSync(args.projectRoot)) throw new Error(`项目根目录不存在：${args.projectRoot}`);
  args.docsDir = args.docsDir ?? "docs";
  return args;
}

// --- the starting set -------------------------------------------------------

const AGENTS_SECTION = `
## 文档

- 索引：\`{DOCS}/INDEX.md\`。不确定权威来源在哪、任务跨多个领域、上线或复盘时读它。单文件且路径明确的修复直接读代码。
- 每批工作往 \`{DOCS}/progress.md\` 追加一行：改了什么 · 依据 · 证据 · 未验证。
- 无法从代码恢复的决策理由写进 \`{DOCS}/decisions.md\`。
- 不写镜像当前实现的快照文档。当前状态由代码和门禁回答。
- 同一事实只在一处维护，其余位置引用它。
- 写成「必须」的规则要有机器门禁，否则改写成带边界的建议。

## 目录清单

<!-- machine-checked: architecture-manifest -->

| 目录 | 作用 |
|---|---|

新增或删除目录时同步这张表。顶层目录超过 6 个时给它配门禁。
`;

const INDEX = `# 文档索引

这是路由表，不是摘要。每行只回答三件事：文档在哪、它说了算的是什么、什么时候该读它。

**不要在这里写内容摘要。** 摘要是内容的副本，内容一改它就变成假话，而且没有门禁守得住。

新增任何文档，在同一个提交里加进下表。

| 文档 | 权威范围 | 何时读 |
|---|---|---|
| \`decisions.md\` | 无法从代码恢复的决策理由 | 想改一个看起来多余的设计之前 |
| \`progress.md\` | 每批工作的证据与未验证项 | 排查回归、复盘、接手他人未完成的批次 |
`;

const DECISIONS = `# 决策日志

只记**无法从代码恢复**的东西：为什么选了这条路、放弃了哪条、当时的约束是什么。代码已经说清楚的事不写。

一条决策一节。被推翻时不要删除原节，追加一节说明推翻的理由并标注前一节作废——被推翻的理由本身就是后来人最需要的信息。

<!-- 模板
## <日期> · <一句话结论>

**约束**：当时不能动的是什么。
**放弃的方案**：以及放弃的理由。
**作废条件**：什么情况下这条决策应当被重新审视。
-->
`;

const PROGRESS = `# 批次账本

每次任务、每次改 bug 追加一行。

**「未验证」那一栏是这份文档的全部价值。** 事后来查账本，查的不是当时做成了什么（代码里有），是当时知道什么、什么没验证。证据栏写命令、exit code、提交 SHA，不写「已完成」「测试通过」这种无法核对的词。

超过约 500 行时归档一批旧记录。按批次、按功能还是按时间切随项目定，没有强制轴；只要归档目录在索引里登记，入口这份只留当期。

| 日期 | 改了什么 | 依据 | 证据 | 未验证 |
|---|---|---|---|---|
`;

function plannedFiles(docsDir) {
  return [
    { path: `${docsDir}/INDEX.md`, content: INDEX },
    { path: `${docsDir}/decisions.md`, content: DECISIONS },
    { path: `${docsDir}/progress.md`, content: PROGRESS },
  ];
}

// --- growth triggers --------------------------------------------------------

function has(root, ...candidates) {
  return candidates.some((candidate) => existsSync(join(root, candidate)));
}

// `.github/workflows` 存在不等于会部署——只跑测试或 lint 的仓库占多数。
// 报错的成本不对称：假阳性会催生一份空的 runbook，而空壳在形式上已经宣称自己是权威。
// 所以这里读内容，只认真正把产物送出去的动作。
const DEPLOY_MARKERS = /\b(deploy|kubectl|helm|flyctl|vercel|netlify|docker\/build-push-action|docker\s+push)\b|^\s*environment:/im;

function hasDeployWorkflow(root) {
  const dir = join(root, ".github/workflows");
  if (!existsSync(dir)) return false;
  return readdirSync(dir)
    .filter((name) => name.endsWith(".yml") || name.endsWith(".yaml"))
    .some((name) => DEPLOY_MARKERS.test(readFileSync(join(dir, name), "utf8")));
}

function countMarkdown(root, docsDir) {
  const absolute = join(root, docsDir);
  if (!existsSync(absolute)) return 0;
  return readdirSync(absolute).filter((name) => name.endsWith(".md")).length;
}

function topLevelDirectories(root) {
  return readdirSync(root, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !e.name.startsWith(".") && !["node_modules", "dist", "build", "target", "vendor"].includes(e.name))
    .map((e) => e.name);
}

function triggers(root, docsDir) {
  const found = [];
  const dirs = topLevelDirectories(root);

  if (has(root, "deploy", "ops", "Dockerfile", "docker-compose.yml", "compose.yaml") || hasDeployWorkflow(root)) {
    found.push("检测到部署相关文件 → 第一次生产部署之前需要 runbook 和上线自检单");
  }
  if (has(root, "migrations", "drizzle", "prisma", "alembic", "db/migrate")) {
    found.push("检测到数据库迁移 → 出现第二张迁移表或第一条不可逆迁移时需要数据模型文档");
  }
  const progressPath = join(root, docsDir, "progress.md");
  if (existsSync(progressPath)) {
    const lines = readFileSync(progressPath, "utf8").split("\n").length;
    if (lines > 500) {
      found.push(`${docsDir}/progress.md 已 ${lines} 行 → 该归档一批旧记录了。按批次、按功能还是按时间切随项目定，只要归档目录进索引、入口只留当期`);
    }
  }
  if (countMarkdown(root, docsDir) >= 10) {
    found.push(`${docsDir}/ 下已有 10 份以上文档 → 索引已是必需，且需要机器门禁守住它`);
  }
  if (dirs.length > 6) {
    found.push(`顶层目录 ${dirs.length} 个（${dirs.join("、")}）→ 需要给 AGENTS.md 的目录清单配门禁`);
  }
  if (has(root, "package.json")) {
    // 一个生长信号读不到，不该丢掉其余全部信号——探测是尽力而为，不是全有或全无
    let scripts = null;
    try {
      scripts = Object.keys(JSON.parse(readFileSync(join(root, "package.json"), "utf8")).scripts ?? {});
    } catch {
      found.push("package.json 存在但无法解析 → 已跳过门禁探测，其余信号不受影响");
    }
    if (scripts && !scripts.some((name) => /^(test|check|verify|lint)/.test(name))) {
      found.push("package.json 里没有 test/check/verify/lint 类命令 → 目前没有任何机器门禁，文档里的「必须」都无法被守住");
    }
  }
  return found;
}

// --- main -------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv.slice(2));
  const { projectRoot, docsDir, dryRun } = args;

  console.log(dryRun ? "探测（不写任何文件）" : "生成起始集");
  console.log(`  项目根：${projectRoot}`);

  const files = plannedFiles(docsDir);
  const agentsPath = join(projectRoot, "AGENTS.md");
  const agentsExists = existsSync(agentsPath);
  const agentsHasSection = agentsExists && readFileSync(agentsPath, "utf8").includes("machine-checked: architecture-manifest");

  const actions = files.map((file) => ({
    path: file.path,
    content: file.content,
    action: existsSync(join(projectRoot, file.path)) ? "已存在，跳过" : "新建",
  }));
  actions.push({
    path: "AGENTS.md",
    content: AGENTS_SECTION.replaceAll("{DOCS}", docsDir),
    action: agentsHasSection ? "已有文档小节，跳过" : agentsExists ? "追加文档与目录清单小节" : "新建",
  });

  console.log("\n起始集：");
  for (const item of actions) console.log(`  ${item.action.padEnd(20)} ${item.path}`);

  if (!dryRun) {
    mkdirSync(join(projectRoot, docsDir), { recursive: true });
    for (const item of actions) {
      if (item.action.includes("跳过")) continue;
      const absolute = join(projectRoot, item.path);
      if (item.action === "追加文档与目录清单小节") {
        writeFileSync(absolute, `${readFileSync(absolute, "utf8").trimEnd()}\n${item.content}`, "utf8");
      } else {
        writeFileSync(absolute, item.path === "AGENTS.md" ? `# ${relative("..", projectRoot) || "项目"} · 协作规则\n${item.content}` : item.content, "utf8");
      }
    }
  }

  const fired = triggers(projectRoot, docsDir);
  console.log("\n已触发的生长条件：");
  if (fired.length === 0) console.log("  无。起始集之外暂时不需要加文档。");
  else for (const line of fired) console.log(`  · ${line}`);

  console.log("\n下一步：起始集只是骨架，里面还没有项目事实。");
  console.log("把真实的规则、决策和边界填进去之前，不要声称项目有文档。");
}

try {
  main();
} catch (error) {
  console.error(`error: ${error.message}`);
  process.exit(2);
}
