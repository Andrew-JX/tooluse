#!/usr/bin/env bash
# 核对 skills/ 下第三方逐字副本是否已与上游分叉。
# 只报告，不自动更新——跟不跟是判断，不是自动动作。
set -uo pipefail
cd "$(dirname "$0")/.."

stale=0
for d in skills/*/; do
  src="$d/SOURCE.md"
  [ -f "$src" ] || continue
  name=$(basename "$d")
  repo=$(grep -oE 'github\.com/[^)]+' "$src" | head -1 | sed 's|github.com/||')
  path=$(grep -E '^\| 路径' "$src" | grep -oE '`[^`]+`' | tr -d '`')
  pin=$(grep -E '^\| 钉住 SHA' "$src" | grep -oE '`[0-9a-f]{7,40}`' | tr -d '`')
  [ -n "$repo" ] && [ -n "$path" ] || { echo "?? $name: SOURCE.md 解析失败"; continue; }

  # 必须落盘比对：$(...) 会吃掉尾换行，直接哈希会永远不等
  tmp=$(mktemp)
  curl -sf --max-time 20 "https://raw.githubusercontent.com/$repo/main/$path/SKILL.md" -o "$tmp" \
    || { echo "?? $name: 取不到上游，跳过"; rm -f "$tmp"; continue; }

  if cmp -s "$tmp" "$d/SKILL.md"; then
    rm -f "$tmp"
    echo "✓  $name  与上游 main 一致（钉 ${pin:0:12}）"
  else
    rm -f "$tmp"
    echo "⚠  $name  上游已改，本地仍是 ${pin:0:12}"
    echo "     diff: curl -sf https://raw.githubusercontent.com/$repo/main/$path/SKILL.md | diff - ${d%/}/SKILL.md"
    stale=$((stale+1))
  fi
done

echo
if [ $stale -gt 0 ]; then
  echo "$stale 个已陈旧。决定跟进时：重新取回、更新 SOURCE.md 的 SHA 与日期、在 CHANGELOG 记一行。"
else
  echo "全部与上游一致。"
fi
exit 0
