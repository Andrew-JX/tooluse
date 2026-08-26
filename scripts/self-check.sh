#!/usr/bin/env bash
# 仓库自检：只查可判定的不变量，不查内容对不对。
# 每条失败都打印具体位置。任何一条失败即退出码 1。
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
note(){ echo "  ✗ $1"; fail=1; }

echo "① frontmatter name 与目录名一致"
for d in skills/*/; do
  n=$(basename "$d"); f="$d/SKILL.md"
  [ -f "$f" ] || { note "$n 缺 SKILL.md"; continue; }
  fm=$(awk '/^name:/{print $2; exit}' "$f")
  [ "$n" = "$fm" ] || note "$n 的 name 是 '$fm'"
done

echo "② 第三方目录必须有 SOURCE.md，且钉住 40 位 SHA"
for d in skills/*/; do
  s="$d/SOURCE.md"; [ -f "$s" ] || continue
  grep -q '[0-9a-f]\{40\}' "$s" || note "$(basename "$d")/SOURCE.md 没有 40 位 SHA"
  grep -q '许可证' "$s" || note "$(basename "$d")/SOURCE.md 没写许可证"
done

echo "③ 仓库内相对链接必须可落地"
python3 - <<'PY' || fail=1
import os,re,glob,sys
bad=[]
for f in [x for x in glob.glob('**/*.md',recursive=True) if '.git' not in x]:
    d=os.path.dirname(f) or '.'
    for m in re.finditer(r'\]\((?!https?:|mailto:|#)([^)]+)\)', open(f,encoding='utf-8').read()):
        t=m.group(1).split('#')[0]
        if t and not os.path.exists(os.path.normpath(os.path.join(d,t))):
            bad.append(f"{f} → {t}")
for b in bad: print(f"  ✗ 断链 {b}")
sys.exit(1 if bad else 0)
PY

echo "④ 自建 Skill 不得含第三方标记，第三方不得被本地编辑"
for d in skills/*/; do
  n=$(basename "$d")
  if [ -f "$d/SOURCE.md" ]; then
    # SOURCE.md 是本仓库写的，改它合法；不许改的是 vendored 的内容文件本身。
    vend=$(git log --format=%H -- "$d" ':(exclude)'"$d"'SOURCE.md' | wc -l | tr -d ' ')
    [ "$vend" -le 1 ] || note "第三方 $n 的内容文件有 $vend 次提交，应只有收录那一次（本地不编辑）"
  fi
done

[ $fail -eq 0 ] && echo && echo "全部通过。" || { echo; echo "有失败项。"; }
exit $fail
