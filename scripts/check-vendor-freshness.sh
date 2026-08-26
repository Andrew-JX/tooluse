#!/usr/bin/env bash
# 核对 skills/ 下第三方逐字副本的两件事，它们是不同的结论，不许合并：
#   ① 本地 vs 钉住的 SHA —— 不一致 = 本地被改过，危险，退出码 1
#   ② 钉住的 SHA vs 上游 main —— 不一致 = 上游前进了，正常，只报告
# 取不到上游时是「未知」，既不是一致也不是陈旧；有未知即退出码 1。
# 只报告，不自动更新——跟不跟是判断，不是自动动作。
#
# 已知边界：只比对本地已有的文件。上游新增了文件而本地没有，这里看不见。
# 注意：变量后紧跟中文标点时必须写 ${var}——UTF-8 locale 下 bash 会把多字节字符的
# 首字节吞进变量名，配合 set -u 直接崩。C locale 不会，所以这类 bug 极易被环境藏住。
# 覆盖范围：skills/*/ 与 scripts/vendor/，凡带 SOURCE.md 的目录。
set -uo pipefail
cd "$(dirname "$0")/.."

drift=0; moved=0; unknown=0; checked=0

fetch() { # repo sha relpath outfile -> 0 ok / 1 fail
  curl -sf --max-time 20 "https://raw.githubusercontent.com/$1/$2/$3" -o "$4"
}

for d in skills/*/ scripts/vendor/; do
  src="${d}SOURCE.md"
  [ -f "$src" ] || continue
  name=$(basename "$d")
  repo=$(grep -oE 'github\.com/[^)]+' "$src" | head -1 | sed 's|github.com/||')
  upath=$(grep -E '^\| 路径' "$src" | grep -oE '`[^`]+`' | tr -d '`')
  pin=$(grep -E '^\| 钉住 SHA' "$src" | grep -oE '`[0-9a-f]{40}`' | tr -d '`')

  if [ -z "$repo" ] || [ -z "$upath" ] || [ -z "$pin" ]; then
    echo "??  $name: SOURCE.md 解析失败（repo/路径/40位SHA 缺一）"
    unknown=$((unknown+1)); continue
  fi

  # 目录内除 SOURCE.md 外的全部文件都要比对，不只 SKILL.md
  while IFS= read -r f; do
    rel="${f#"$d"}"
    case "$rel" in LICENSE-*) continue;; esac  # 许可证全文另有出处，不逐字比
    checked=$((checked+1))
    tmp=$(mktemp)
    if ! fetch "$repo" "$pin" "$upath/$rel" "$tmp"; then
      echo "??  $name/$rel: 取不到钉住版本，未知"
      unknown=$((unknown+1)); rm -f "$tmp"; continue
    fi
    if ! cmp -s "$tmp" "$f"; then
      echo "✗   $name/$rel: 本地与钉住的 ${pin:0:12} 不一致 —— 本地被改过"
      drift=$((drift+1)); rm -f "$tmp"; continue
    fi
    rm -f "$tmp"
    # 本地 == pin，再看上游 main 有没有前进
    tmp2=$(mktemp)
    if ! fetch "$repo" main "$upath/$rel" "$tmp2"; then
      echo "??  $name/$rel: 取不到上游 main，无法判断是否有更新"
      unknown=$((unknown+1)); rm -f "$tmp2"; continue
    fi
    if cmp -s "$tmp2" "$f"; then
      echo "✓   $name/$rel"
    else
      echo "⚠   $name/$rel: 上游 main 已更新，本地仍是 ${pin:0:12}"
      echo "      diff: curl -sf https://raw.githubusercontent.com/$repo/main/$upath/$rel | diff - $f"
      moved=$((moved+1))
    fi
    rm -f "$tmp2"
  done < <(find "$d" -type f ! -name SOURCE.md | sort)
done

echo
echo "比对 ${checked} 个文件：本地漂移 ${drift}，上游已更新 ${moved}，未知 ${unknown}"
if [ "$unknown" -gt 0 ]; then
  echo "有未知项——本次结果不构成「与上游一致」的证明。"
fi
if [ "$drift" -gt 0 ]; then
  echo "有本地漂移：第三方副本本地不编辑，请还原或提到上游。"
fi
if [ "$moved" -gt 0 ]; then
  echo "上游已前进：跟不跟是判断。决定跟进时重新取回、更新 SOURCE.md 的 SHA 与日期、在 CHANGELOG 记一行。"
fi
if [ "$drift" -eq 0 ] && [ "$unknown" -eq 0 ] && [ "$moved" -eq 0 ]; then
  echo "全部与钉住版本及上游 main 一致。"
fi
[ "$drift" -eq 0 ] && [ "$unknown" -eq 0 ]
