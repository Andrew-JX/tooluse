#!/usr/bin/env node
// Bidirectional gate between docs/INDEX.md and the documents that actually
// exist. This is the one portable check in the doc system: an index nobody
// verifies rots exactly like the documents it points at, and a rotted index is
// worse than none because it is trusted.
//
// --self-test breaks each check on purpose and requires it to report. A gate
// that cannot fail protects nothing.

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

function parseArgs(argv) {
  const args = { selfTest: false, docsDir: "docs" };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--project-root") args.projectRoot = argv[i + 1];
    else if (argv[i] === "--docs-dir") args.docsDir = argv[i + 1];
    else if (argv[i] === "--self-test") args.selfTest = true;
  }
  if (!args.projectRoot) throw new Error("--project-root 是必填的");
  return args;
}

function loadContext({ projectRoot, docsDir }) {
  const absolute = join(projectRoot, docsDir);
  if (!existsSync(absolute)) throw new Error(`找不到文档目录：${absolute}`);
  const indexPath = join(absolute, "INDEX.md");
  if (!existsSync(indexPath)) throw new Error(`找不到索引：${indexPath}`);

  return {
    index: readFileSync(indexPath, "utf8"),
    // Nested paths stay listed relative to the docs directory.
    documents: listMarkdown(absolute, ""),
  };
}

function listMarkdown(root, prefix) {
  return readdirSync(join(root, prefix), { withFileTypes: true }).flatMap((entry) => {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) return relative === "archive" ? [] : listMarkdown(root, relative);
    return entry.name.endsWith(".md") && entry.name !== "INDEX.md" ? [relative] : [];
  });
}

function indexedPaths(index) {
  // Rows look like: | `decisions.md` | scope | when to read |
  return [...index.matchAll(/^\|\s*`([^`]+\.md)`\s*\|/gm)].map((m) => m[1]);
}

const checks = [
  {
    id: "index-covers-documents",
    describe: "每份文档都在索引里",
    run({ index, documents }) {
      const listed = indexedPaths(index);
      return documents.filter((doc) => !listed.includes(doc)).map((doc) => `${doc} 存在，但没写进 INDEX.md`);
    },
    breaks: [(ctx) => ({ ...ctx, documents: [...ctx.documents, "unlisted-doc.md"] })],
  },
  {
    id: "index-points-at-real-documents",
    describe: "索引里的每一行都指向真实存在的文档",
    run({ index, documents }) {
      return indexedPaths(index).filter((path) => !documents.includes(path)).map((path) => `INDEX.md 里有 \`${path}\`，文档目录里没有它`);
    },
    breaks: [(ctx) => ({ ...ctx, index: `${ctx.index}\n| \`ghost.md\` | 幽灵 | 永远 |\n` })],
  },
  {
    id: "rows-declare-scope-and-trigger",
    // Without these two columns two documents will each claim the same fact,
    // and nobody knows when the index is worth opening.
    describe: "索引每行都写了权威范围和何时读",
    run({ index }) {
      const rows = [...index.matchAll(/^\|\s*`([^`]+\.md)`\s*\|([^|]*)\|([^|]*)\|/gm)];
      const listed = indexedPaths(index);
      if (rows.length !== listed.length) return ["有文档行不是「路径 / 权威范围 / 何时读」三栏格式"];
      return rows.filter(([, , scope, when]) => scope.trim() === "" || when.trim() === "").map(([, path]) => `\`${path}\` 缺少权威范围或何时读`);
    },
    breaks: [(ctx) => ({ ...ctx, index: ctx.index.replace(/^\|\s*`([^`]+\.md)`\s*\|([^|]*)\|/m, "| `$1` |  |") })],
  },
  {
    id: "index-has-no-summaries",
    // A summary is a copy of the content. The content changes, the copy lies,
    // and no gate can catch it. The index routes; it does not restate.
    describe: "索引没有膨胀成摘要",
    run({ index }) {
      const rows = [...index.matchAll(/^\|\s*`([^`]+\.md)`\s*\|([^|]*)\|([^|]*)\|/gm)];
      return rows.filter(([, , scope, when]) => scope.trim().length > 60 || when.trim().length > 60).map(([, path]) => `\`${path}\` 的索引行过长，索引在往摘要退化`);
    },
    breaks: [(ctx) => ({ ...ctx, index: ctx.index.replace(/^\|\s*`([^`]+\.md)`\s*\|([^|]*)\|/m, `| \`$1\` | ${"内容摘要".repeat(20)} |`) })],
  },
];

function report(context) {
  let failed = 0;
  for (const check of checks) {
    const problems = check.run(context);
    if (problems.length === 0) {
      console.log(`  ok   ${check.id} · ${check.describe}`);
    } else {
      failed += 1;
      console.log(`  FAIL ${check.id} · ${check.describe}`);
      for (const problem of problems) console.log(`         ${problem}`);
    }
  }
  return failed;
}

function selfTest(context) {
  let failed = 0;
  for (const check of checks) {
    check.breaks.forEach((mutate, index) => {
      if (check.run(mutate(structuredClone(context))).length > 0) {
        console.log(`  ok   ${check.id}[${index}] 被破坏时确实报错`);
      } else {
        failed += 1;
        console.log(`  FAIL ${check.id}[${index}] 被破坏后仍然通过，这个检查守不住它声称保护的东西`);
      }
    });
  }
  return failed;
}

try {
  const args = parseArgs(process.argv.slice(2));
  const context = loadContext(args);
  console.log(args.selfTest ? "文档索引门禁 · 负向控制" : "文档索引门禁");
  const failures = args.selfTest ? selfTest(context) : report(context);
  console.log(failures === 0 ? "全部通过" : `${failures} 项失败`);
  process.exit(failures === 0 ? 0 : 1);
} catch (error) {
  console.error(`error: ${error.message}`);
  process.exit(2);
}
