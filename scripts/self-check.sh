#!/usr/bin/env bash
# 仓库自检：只查可判定的结构不变量，不查内容对不对。
# 每条都做过负向控制：把被守护的事实改坏，对应那条必须报错。做过的那一轮
# 见 2026-08-26 前后的 commit（CHANGELOG.md 已于 c175400 删除，账本改记在
# commit message 里，见 CONTRIBUTING 第 3 条）。任何一条失败即退出码 1。
#
# 不做联网比对：vendored 的是提示词文本，钉住即可，上游前进不构成本地缺陷。
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
skipped=0
strict=0
# 只看 $1 会漏掉后面的拼错：`--strict --stict` 会静默通过，而 CI 命令正是
# 「先写对、后面再接东西」的典型形状。所以卡参数个数，不只卡内容。
if [ $# -gt 1 ]; then
  echo "用法：$0 [--strict]（多余参数：$*）" >&2
  exit 64
fi
case "${1:-}" in
"") ;;
--strict) strict=1 ;;
*)
  echo "用法：$0 [--strict]" >&2
  exit 64
  ;;
esac
note() {
  echo "  ✗ $1"
  fail=1
}
skip() {
  echo "  – $1"
  skipped=$((skipped + 1))
}

# 第三方判据：以 NOTICE 的登记表为准，不是「有没有 SOURCE.md」——
# 用后者会导致「删掉 SOURCE.md 就不再被检查」。NOTICE 因许可证要求必须存在。
is_vendored() { grep -q "\`skills/$1/\`" NOTICE 2>/dev/null; }

echo "① frontmatter name 与目录名一致"
for d in skills/*/; do
  n=$(basename "$d")
  f="${d}SKILL.md"
  [ -f "$f" ] || {
    note "$n 缺 SKILL.md"
    continue
  }
  fm=$(awk '/^name:/{print $2; exit}' "$f")
  [ "$n" = "$fm" ] || note "$n 的 name 是 '$fm'"
done

echo "② 官方 validator（quick_validate.py）"
# 优先用仓库内 vendored 的那份：门禁只在作者本机生效等于没有门禁
V=""
for c in "scripts/vendor/quick_validate.py" \
  "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" \
  "$HOME/.claude/skills/.system/skill-creator/scripts/quick_validate.py"; do
  [ -f "$c" ] && V="$c" && break
done
if [ -z "$V" ]; then
  note "未找到 validator——本仓库已 vendored 一份，找不到说明文件缺失"
elif ! python3 -c "import yaml" 2>/dev/null; then
  skip "缺 PyYAML，validator 未运行"
else
  for d in skills/*/; do
    [ -f "${d}SKILL.md" ] || continue
    python3 "$V" "$d" >/dev/null 2>&1 || note "$(basename "$d") 未通过 validator：$(python3 "$V" "$d" 2>&1 | head -1)"
  done
fi

echo "③ NOTICE 登记的每一项都必须有完整出处"
while IFS= read -r n; do
  [ -d "skills/$n" ] || {
    note "NOTICE 登记了 ${n}，但目录不存在"
    continue
  }
  s="skills/$n/SOURCE.md"
  [ -f "$s" ] || {
    note "$n 已登记为第三方，但缺 SOURCE.md"
    continue
  }
  grep -qE '`[0-9a-f]{40}`' "$s" || note "$n/SOURCE.md 没有 40 位 SHA"
  grep -q '许可证' "$s" || note "$n/SOURCE.md 没写许可证"
done < <(grep -oE "\`skills/[a-z0-9-]+/\`" NOTICE 2>/dev/null | tr -d '`' | sed 's|skills/||; s|/||')

echo "④ 有 SOURCE.md 的目录必须在 NOTICE 里登记"
for d in skills/*/; do
  [ -f "${d}SOURCE.md" ] || continue
  n=$(basename "$d")
  is_vendored "$n" || note "$n 有 SOURCE.md 却未登记进 NOTICE"
done

echo "⑤ 第三方内容文件不得有本地未提交改动"
for d in skills/*/ scripts/vendor/; do
  n=$(basename "$d")
  [ "$n" = vendor ] || is_vendored "$n" || continue
  [ -f "${d}SOURCE.md" ] || continue
  # SOURCE.md 与许可证全文由本仓库管理，不算 vendored 内容
  dirty=$(git status --porcelain -- "$d" 2>/dev/null | grep -vE "SOURCE\.md|LICENSE|NOTICE" | wc -l | tr -d ' ')
  [ "$dirty" -eq 0 ] || note "第三方 $n 有 $dirty 个未提交改动（内容文件本地不编辑）"
done

echo "⑥ 第三方内容文件历史上只应有收录那一次提交"
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  skip "浅克隆，git log 不完整，⑥ 未运行"
else
  for d in skills/*/; do
    n=$(basename "$d")
    is_vendored "$n" || continue
    c=$(git log --format=%H -- "$d" ":(exclude)${d}SOURCE.md" ":(exclude)${d}LICENSE*" ":(exclude)${d}NOTICE*" | wc -l | tr -d ' ')
    [ "$c" -le 1 ] || note "第三方 $n 的内容文件有 $c 次提交（合法跟进上游请在此放宽并记账本）"
  done
fi

echo "⑦ 仓库内相对链接必须可落地"
python3 - <<'PY' || fail=1
import os,re,glob,sys
bad=[]
def strip_code(t):
    # 文档里讨论 markdown 语法时会出现链接写法，那不是链接。
    t=re.sub(r'```.*?```', '', t, flags=re.S)     # 围栏代码块
    t=re.sub(r'`[^`\n]*`', '', t)                 # 行内代码
    return t
for f in [x for x in glob.glob('**/*.md',recursive=True) if '.git' not in x]:
    d=os.path.dirname(f) or '.'
    for m in re.finditer(r'\]\((?!https?:|mailto:|#)([^)]+)\)', strip_code(open(f,encoding='utf-8').read())):
        t=m.group(1).split('#')[0].strip()
        t=re.split(r'\s+["\']', t)[0].strip()      # 剥掉 [a](f.md "标题") 的 title
        if t and not os.path.exists(os.path.normpath(os.path.join(d,t))):
            bad.append(f"{f} → {t}")
for b in bad: print(f"  ✗ 断链 {b}")
sys.exit(1 if bad else 0)
PY

echo "⑧ scripts/vendor 的第三方出处完整"
if [ -d scripts/vendor ]; then
  [ -f scripts/vendor/SOURCE.md ] || note "scripts/vendor 缺 SOURCE.md"
  grep -qE '`[0-9a-f]{40}`' scripts/vendor/SOURCE.md 2>/dev/null || note "scripts/vendor/SOURCE.md 没有 40 位 SHA"
  ls licenses/LICENSE-anthropics-skills.txt >/dev/null 2>&1 || note "缺 anthropics 许可证全文"
  grep -q 'scripts/vendor' NOTICE 2>/dev/null || note "scripts/vendor 未登记进 NOTICE"
fi

echo "⑨ 顶层许可证与 NOTICE 划清了第三方边界"
# LICENSE 保持纯 MIT 正文——夹杂其它内容会让 GitHub 识别成 NOASSERTION，
# 第三方边界声明因此单独放 NOTICE。
[ -f LICENSE ] || note "缺顶层 LICENSE——自建内容默认不授予任何再分发许可"
grep -q 'Permission is hereby granted' LICENSE 2>/dev/null || note "LICENSE 不是可识别的 MIT 正文"
[ -f NOTICE ] || note "缺 NOTICE——没有任何地方声明第三方副本不受 LICENSE 约束"
grep -q 'SOURCE.md' NOTICE 2>/dev/null || note "NOTICE 没有给出第三方副本的判别方法"
grep -q 'NOTICE' README.md 2>/dev/null || note "README 没有指向第三方许可证清单"

echo "⑩ 随包分发的脚本自带的判据自检"
# 这两个脚本会被复制进用户项目并驱动决策，它们的判据必须自己带正负对照。
# 不在默认路径上跑的自检等于没有自检——所以在这里跑，不留成「需要时手工跑」。
if command -v node >/dev/null 2>&1; then
  node skills/project-doc-system/scripts/init-docs.mjs --self-test >/dev/null 2>&1 ||
    note "init-docs 探测判据自检未通过——触发条件可能在误报或漏报"
else
  skip "没有 node，跳过随包脚本的判据自检"
fi

echo "⑪ 共享块逐字一致且副本集合符合登记，派生副本关键语义未丢失"
# 三个交付 Skill 内嵌 README 的高影响清单等共享块，因为 skill 会脱离仓库单独分发（scope-bound-editor
# B2 的第一类合法副本）。副本合法，漂移不合法——617afbd 就是四份各自漂了一点。
#
# 只比「扫到的副本」不够：把某个消费者的整块删掉、或协调删掉所有副本，集合依旧自洽，门禁会
# 放行——而删掉 authority-boundary 正是安全上最危险的那种改法。所以把预期集合登记在下面：
# 缺 key、缺消费者、多出未登记的消费者、同一文件重复块，全部失败。改消费者集合要同时改这张表，
# 这是故意的摩擦。负向控制：改一个字、删一个消费者、删整个 key、加一个未登记副本，四种都变红。
if ! command -v python3 >/dev/null 2>&1; then
  skip "没有 python3，跳过共享块一致性检查"
else
  python3 - <<'PY' || fail=1
import re,glob,sys,collections

DELIVERY = {
    'README.md',
    'skills/acceptance-author/SKILL.md',
    'skills/evidence-bound-executor/SKILL.md',
    'skills/evidence-led-reviewer/SKILL.md',
}
# 每个 key 必须恰好出现在这些文件里，不多不少。README 是权威家，必须在列。
EXPECTED = {
    'impact-triggers':    DELIVERY,
    'external-anchor':    DELIVERY,
    # project-doc-system 是包里唯一写文件/复制脚本/接 CI 的 skill，授权边界必须内联
    'authority-boundary': DELIVERY | {'skills/project-doc-system/SKILL.md'},
}

# 标记成对扫描，不用成对正则：`(start)(.*?)(end)` 的非贪婪匹配会把嵌套在内部的另一个 key
# 整个吞掉，扫描从外层结束位置继续，被夹带进来的 key 永远不会被看见——协调嵌套四份
# 副本就能连逐字检查一起绕过。所以先把所有标记当 token 列出来，再要求严格不嵌套配对。
MARK=re.compile(r'<!--\s*shared:([a-z0-9-]+):(start|end)\s*-->')
blocks=collections.defaultdict(dict)
bad=False
for f in sorted(x for x in glob.glob('**/*.md',recursive=True) if '.git' not in x):
    src=open(f,encoding='utf-8').read()
    open_key=None; open_end=None
    for m in MARK.finditer(src):
        key,kind=m.group(1),m.group(2)
        if kind=='start':
            if open_key is not None:
                print(f"  ✗ {f}：共享块 {open_key} 未闭合就开了 {key}（不允许嵌套或交叉）"); bad=True
            open_key, open_end = key, m.end()
        else:
            if open_key is None:
                print(f"  ✗ {f}：共享块 {key} 的 end 标记没有对应的 start"); bad=True; continue
            if key != open_key:
                print(f"  ✗ {f}：共享块 {open_key} 被 {key} 的 end 标记提前关闭"); bad=True
            if f in blocks[open_key]:
                print(f"  ✗ 共享块 {open_key} 在 {f} 里出现多次"); bad=True
            blocks[open_key][f]=src[open_end:m.start()]
            open_key=None
    if open_key is not None:
        print(f"  ✗ {f}：共享块 {open_key} 有 start 没有 end"); bad=True

for key in sorted(set(EXPECTED) | set(blocks)):
    want = EXPECTED.get(key)
    got  = set(blocks.get(key, {}))
    if want is None:
        print(f"  ✗ 共享块 {key} 未登记（出现在 {sorted(got)}）：先在 self-check 的 EXPECTED 里登记"); bad=True; continue
    for f in sorted(want - got):
        print(f"  ✗ 共享块 {key} 应出现在 {f}，实际没有（块被删了，或标记被改坏）"); bad=True
    for f in sorted(got - want):
        print(f"  ✗ 共享块 {key} 出现在未登记的 {f}：要么登记它，要么别用这个标记"); bad=True
    if 'README.md' not in got:
        continue   # 上面已报缺 README
    auth=blocks[key]['README.md']
    for f in sorted(got & want):
        if f != 'README.md' and blocks[key][f] != auth:
            print(f"  ✗ 共享块 {key} 在 {f} 与 README.md 不逐字一致"); bad=True

# 派生副本：reviewer-role-prompt.md 是发给不支持 Skills 的 Agent 的可粘贴清单，必须自包含，
# 只能放压缩版，做不到 byte-identical。逐字比不了，至少保证关键语义没被整段删掉。
#
# needle 必须钉到**具体章节**：上一版把「外部锚点」当全文 needle，结果删掉「本次输入」里的
# 输入字段后，「输出」段里同名词仍然命中，门禁放行——错的不是漏写条件，是 needle 选错了锚点。
def sections(text):
    """按 '## 标题' 切开，返回 {标题: 正文}；标题前的内容归入 ''。"""
    out=collections.defaultdict(str); cur=''
    for line in text.split('\n'):
        if line.startswith('## '):
            cur=line[3:].strip()
        else:
            out[cur]+=line+'\n'
    return out

DERIVED = {
    'skills/evidence-led-reviewer/assets/reviewer-role-prompt.md': [
        ('',     '派生副本登记声明',       ['derived-copy:']),
        ('本次输入', '外部锚点输入字段',     ['外部锚点', '可复核形式']),
        ('本次输入', '三锚点输入字段',     ['Contract SHA', 'Baseline SHA', 'Candidate SHA']),
        ('工作方式', '授权边界：不授权',     ['不能授予工具', '部署或破坏性操作权限']),
        ('工作方式', '授权边界：已批准按未授权', ['已批准', '未授权处理', '宿主']),
        ('严重度', '严重度模型四级',       ['P0：', 'P1：', 'P2：', 'P3：']),
        ('输出',   '结论封顶',             ['仓库内已验证，产品正确性未验证']),
        ('输出',   '锚点缺形式时按无处理',   ['可复核形式']),
    ],
}
import os
for path, checks in sorted(DERIVED.items()):
    if not os.path.exists(path):
        print(f"  ✗ 派生副本文件不存在：{path}"); bad=True; continue
    secs=sections(open(path,encoding='utf-8').read())
    for sec, label, needles in checks:
        if sec and sec not in secs:
            print(f"  ✗ {path} 缺少章节「## {sec}」（派生语义「{label}」无处安放）"); bad=True; continue
        body=secs[sec]
        missing=[n for n in needles if n not in body]
        if missing:
            where=f"「## {sec}」" if sec else "头部"
            print(f"  ✗ {path} 的{where}丢失派生语义「{label}」（缺：{'、'.join(missing)}）"); bad=True

sys.exit(1 if bad else 0)
PY
fi

echo
if [ $fail -ne 0 ]; then
  echo "有失败项。"
elif [ $skipped -gt 0 ]; then
  # 跳过和通过是两种结论，不许合并——和 freshness 的「未知≠一致」同一条规矩
  echo "没有失败项，但有 ${skipped} 项被跳过——本次结果不构成「全部通过」的证明。"
  if [ $strict -eq 1 ]; then
    echo "严格模式下，跳过项视为未通过。"
    fail=2
  fi
else
  echo "全部通过。"
fi
exit $fail
