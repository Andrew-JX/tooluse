#!/usr/bin/env bash
# 仓库自检：只查可判定的结构不变量，不查内容对不对。
# 每条都做过负向控制（见 CHANGELOG 2026-08-26）。任何一条失败即退出码 1。
#
# 第三方逐字副本与上游的逐字比对不在这里，在 scripts/check-vendor-freshness.sh（需联网）。
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
note(){ echo "  ✗ $1"; fail=1; }

# 第三方判据：目录内是否存在 THIRD-PARTY.md 登记，而不是「有没有 SOURCE.md」——
# 用后者会导致「删掉 SOURCE.md 就不再被检查」。
is_vendored(){ grep -qE "^\| \`$1\`" skills/THIRD-PARTY.md 2>/dev/null; }

echo "① frontmatter name 与目录名一致"
for d in skills/*/; do
  n=$(basename "$d"); f="${d}SKILL.md"
  [ -f "$f" ] || { note "$n 缺 SKILL.md"; continue; }
  fm=$(awk '/^name:/{print $2; exit}' "$f")
  [ "$n" = "$fm" ] || note "$n 的 name 是 '$fm'"
done

echo "② 官方 validator（quick_validate.py）"
V=""
for c in "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" \
         "$HOME/.claude/skills/.system/skill-creator/scripts/quick_validate.py"; do
  [ -f "$c" ] && V="$c" && break
done
if [ -z "$V" ]; then
  echo "  – 本机未找到 validator，跳过（不计为通过）"
else
  for d in skills/*/; do
    [ -f "${d}SKILL.md" ] || continue
    python3 "$V" "$d" >/dev/null 2>&1 || note "$(basename "$d") 未通过 validator：$(python3 "$V" "$d" 2>&1 | head -1)"
  done
fi

echo "③ THIRD-PARTY.md 登记的每一项都必须有完整出处"
while IFS= read -r n; do
  [ -d "skills/$n" ] || { note "THIRD-PARTY.md 登记了 $n，但目录不存在"; continue; }
  s="skills/$n/SOURCE.md"
  [ -f "$s" ] || { note "$n 已登记为第三方，但缺 SOURCE.md"; continue; }
  grep -qE '`[0-9a-f]{40}`' "$s" || note "$n/SOURCE.md 没有 40 位 SHA"
  grep -q '许可证' "$s" || note "$n/SOURCE.md 没写许可证"
done < <(grep -oE "^\| \`[a-z0-9-]+\`" skills/THIRD-PARTY.md 2>/dev/null | tr -d '|` ')

echo "④ 有 SOURCE.md 的目录必须在 THIRD-PARTY.md 里登记"
for d in skills/*/; do
  [ -f "${d}SOURCE.md" ] || continue
  n=$(basename "$d")
  is_vendored "$n" || note "$n 有 SOURCE.md 却未登记进 THIRD-PARTY.md"
done

echo "⑤ 第三方内容文件不得有本地未提交改动"
for d in skills/*/; do
  n=$(basename "$d"); is_vendored "$n" || continue
  dirty=$(git status --porcelain -- "$d" 2>/dev/null | grep -v "SOURCE.md" | wc -l | tr -d ' ')
  [ "$dirty" -eq 0 ] || note "第三方 $n 有 $dirty 个未提交改动（内容文件本地不编辑）"
done

echo "⑥ 第三方内容文件历史上只应有收录那一次提交"
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
  echo "  – 浅克隆，git log 不完整，跳过（不计为通过）"
else
  for d in skills/*/; do
    n=$(basename "$d"); is_vendored "$n" || continue
    c=$(git log --format=%H -- "$d" ":(exclude)${d}SOURCE.md" | wc -l | tr -d ' ')
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

[ $fail -eq 0 ] && { echo; echo "全部通过。"; } || { echo; echo "有失败项。"; }
exit $fail
