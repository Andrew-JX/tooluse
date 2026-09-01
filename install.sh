#!/usr/bin/env bash
# 安装指定 commit 的 tooluse skill。三条不变量：
# 1. 内容只来自 `git archive <SHA>`，不从工作树复制——记录的 SHA 必须等于装上去的内容。
# 2. 只向空位安装。安装器不删除、不替换、不覆盖任何已存在的 skill、常驻文件或 manifest。
# 3. 同一个 SHA 且内容指纹一致时幂等返回；其余冲突一律拒绝，由用户先整体移走旧安装。
#
# 因此这里没有回滚协议、没有备份目录、没有进度日志：一个不会删除用户数据的安装器
# 不需要恢复机制。升级 = 用户备份移走旧安装，再安装新 SHA。
set -euo pipefail

usage() {
  cat <<'EOF'
用法：install.sh --commit <40 位 SHA> [--target <skills 目录>] [--only <skill[,skill...]>]

--target 是最终包含各 skill 目录的目录；默认 ~/.claude/skills。
常驻块写到 target 的父目录：<parent>/tooluse-resident.md。

--target 解析成物理路径后复查护栏：根目录、HOME 本身、本仓库内部一律拒绝，
路径里不允许出现 . 或 .. 段。

不自动升级、不自动回滚。已装同一 SHA 且内容未变时直接幂等返回；
要换 SHA 或目标已有其它内容时，本命令会拒绝并告诉你需要移走哪些路径。
EOF
}
die() {
  echo "错误：$*" >&2
  exit 64
}
# -e 会跟随链接；悬空链接返回假，却仍占住路径。所有安装目标的占位判断必须用这个函数。
path_occupied() { [ -e "$1" ] || [ -L "$1" ]; }
# 解析目录的物理路径。用 unset CDPATH 而不用 `CDPATH= cd`：后者是一次性赋值，
# 静态检查器会当成疑似拼错的空赋值，而这里的意图是显式清掉 CDPATH。
abspath() { (
  unset CDPATH
  cd -- "$1" 2>/dev/null && pwd -P
); }
# 完整权限位：只记可执行位会漏掉目录访问权限、普通文件读写权限和特殊位。
# macOS/BSD 与 GNU stat 参数不同，按系统选择；输入均为已存在路径。
mode_bits() {
  case "$(uname -s)" in
  Darwin | FreeBSD) stat -f '%Lp' "$1" ;;
  *) stat -c '%a' "$1" ;;
  esac
}
# 目录内容指纹：每项记「类型 + 完整权限 + 路径」，文件再记内容哈希，链接记指向目标。
fingerprint() {
  (
    cd "$1" || return 1
    find . ! -name '.tooluse-version' -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' entry; do
      if [ -L "$entry" ]; then
        printf 'l %s -> %s\n' "$entry" "$(readlink "$entry")"
      elif [ -d "$entry" ]; then
        printf 'd%s %s\n' "$(mode_bits "$entry")" "$entry"
      elif [ -f "$entry" ]; then
        printf 'f%s %s %s\n' "$(mode_bits "$entry")" "$entry" "$(shasum -a 256 "$entry" | cut -d' ' -f1)"
      else
        printf 'o%s %s\n' "$(mode_bits "$entry")" "$entry"
      fi
    done | shasum -a 256 | cut -d' ' -f1
  )
}
# 常驻文件同理：内容之外还要盯类型与完整权限。
file_fingerprint() {
  if [ -L "$1" ]; then
    printf 'l -> %s' "$(readlink "$1")" | shasum -a 256 | cut -d' ' -f1
  elif [ -f "$1" ]; then
    printf 'f%s %s' "$(mode_bits "$1")" "$(shasum -a 256 "$1" | cut -d' ' -f1)" | shasum -a 256 | cut -d' ' -f1
  else
    printf 'o%s' "$(mode_bits "$1")" | shasum -a 256 | cut -d' ' -f1
  fi
}

commit=""
target="$HOME/.claude/skills"
only=""
invocation_dir=$PWD
while [ "$#" -gt 0 ]; do
  case "$1" in
  --commit)
    [ "$#" -ge 2 ] || die "--commit 缺值"
    commit=$2
    shift 2
    ;;
  --target)
    [ "$#" -ge 2 ] || die "--target 缺值"
    target=$2
    shift 2
    ;;
  --only)
    [ "$#" -ge 2 ] || die "--only 缺值"
    only=$2
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    die "未知参数：$1"
    ;;
  esac
done

[[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || die "--commit 必须是完整 40 位 SHA"
case "$target" in /*) ;; *) target="$invocation_dir/$target" ;; esac

script_dir=$(abspath "$(dirname -- "${BASH_SOURCE[0]}")") || die "无法解析脚本所在目录"
root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) || die "install.sh 必须位于 tooluse Git 仓库中"
cd "$root"
resolved=$(git rev-parse --verify "${commit}^{commit}" 2>/dev/null) || die "找不到提交：$commit"
requested=$(printf '%s' "$commit" | tr 'A-F' 'a-f')
[ "$resolved" = "$requested" ] || die "--commit 必须解析为该完整提交"

# skill 清单从固定 SHA 枚举，不在任何地方硬编码第二份。
available=()
while IFS= read -r skill; do
  if [ -n "$skill" ]; then available+=("$skill"); fi
done < <(git ls-tree -d --name-only "$resolved:skills")
[ "${#available[@]}" -gt 0 ] || die "提交中没有 skills/"

known_skill() {
  local candidate=$1
  local known
  for known in "${available[@]}"; do
    if [ "$known" = "$candidate" ]; then return 0; fi
  done
  return 1
}
selected=()
selected_csv=,
if [ -n "$only" ]; then
  IFS=, read -r -a requested_skills <<<"$only"
  [ "${#requested_skills[@]}" -gt 0 ] || die "--only 不能为空"
  for skill in "${requested_skills[@]}"; do
    [[ "$skill" =~ ^[a-z0-9-]+$ ]] || die "--only 只能是 skill 名，不能含路径：$skill"
    known_skill "$skill" || die "提交 $resolved 不含 skill：$skill"
    case "$selected_csv" in *",$skill,"*) die "--only 中重复：$skill" ;; esac
    selected+=("$skill")
    selected_csv="${selected_csv}${skill},"
  done
else
  selected=("${available[@]}")
fi

# 护栏跑两遍：mkdir 之前用「已存在的最深祖先 + 未创建的尾段」判定，避免被拒绝的目标留下目录；
# mkdir 之后再对真实物理路径复查一遍，因为尾段在创建前无法被 pwd -P 规范化。
check_target_guards() {
  local candidate=$1
  [ "$candidate" != "/" ] || die "--target 不能是根目录"
  [ "$candidate" != "${HOME%/}" ] || die "--target 不能是 HOME 本身"
  case "$candidate" in
  "$root" | "$root"/*) die "--target 不能在 tooluse 仓库内：$candidate" ;;
  esac
  [ "$(dirname "$candidate")" != "/" ] || die "--target 的父目录不能是根目录"
}
# 尾段无法被 pwd -P 规范化，所以直接拒绝 . 与 ..，而不是尝试自行解释它们。
reject_dot_segments() {
  local path=$1
  case "/$path/" in
  */../* | */./*) die "--target 不允许出现 . 或 .. 段（请传入不含相对段的路径）：$1" ;;
  esac
}
# 返回「已存在的最深祖先的物理路径 + 尚不存在的尾段」。
resolve_intent() {
  local raw=$1
  local tail_parts=""
  local resolved_head
  local head_part=$raw
  while :; do
    if [ -d "$head_part" ]; then
      resolved_head=$(abspath "$head_part") || return 1
      if [ -n "$tail_parts" ]; then
        printf '%s/%s\n' "${resolved_head%/}" "$tail_parts"
      else
        printf '%s\n' "$resolved_head"
      fi
      return 0
    fi
    case "$head_part" in
    */*)
      tail_parts=${tail_parts:+${head_part##*/}/$tail_parts}
      tail_parts=${tail_parts:-${head_part##*/}}
      head_part=${head_part%/*}
      [ -n "$head_part" ] || head_part=/
      ;;
    *) return 1 ;;
    esac
  done
}

reject_dot_segments "$target"
target=$(resolve_intent "$target") || die "--target 路径无法解析：$target"
reject_dot_segments "$target"
check_target_guards "$target"
[ -z "$(git status --porcelain --untracked-files=all)" ] || die "源仓库不干净；先提交、暂存外移或还原后再安装"

# 冲突时统一的拒绝出口：列出需要用户自己移走的路径，绝不代替用户删除。
refuse_occupied() {
  local reason=$1
  shift
  {
    echo "错误：$reason"
    echo "本安装器只向空位安装，不会删除或替换已存在的内容。"
    echo "请先把下面这些路径整体移到备份位置，再重新运行本命令："
    for path in "$@"; do echo "  $path"; done
  } >&2
  exit 65
}

# target 尚不存在时，不可能有已登记的安装，所以父目录里的 resident 必定不是本安装器写的。
# 这一检必须在 mkdir 之前，否则「拒绝但零写入」就不成立。
pre_resident="$(dirname "$target")/tooluse-resident.md"
if [ ! -d "$target" ] && path_occupied "$pre_resident"; then
  refuse_occupied "将要写入的常驻文件已存在，且目标目录还没有任何已登记的安装。" "$pre_resident"
fi

# 全部拒绝判定都过了，才建目录；建完对真实物理路径复查同一批护栏。
mkdir -p "$target" 2>/dev/null || die "--target 无法创建：$target"
target=$(abspath "$target") || die "--target 无法解析：$target"
check_target_guards "$target"

manifest="$target/.tooluse-version"
resident_target="$(dirname "$target")/tooluse-resident.md"
# manifest 是可解析的普通文件才可作为本安装器记录；任何链接（含悬空）都是占位冲突。
if path_occupied "$manifest" && { [ -L "$manifest" ] || [ ! -f "$manifest" ]; }; then
  refuse_occupied "版本记录路径已被非普通文件或符号链接占用。" "$manifest"
fi
recorded_fingerprint() {
  path_occupied "$manifest" && [ -f "$manifest" ] || return 1
  sed -n "s|^fingerprint=$1=||p" "$manifest" | head -1
}

installed_commit=""
if path_occupied "$manifest"; then
  installed_commit=$(sed -n 's|^tooluse_commit=||p' "$manifest" | head -1)
fi

# 幂等判定：同一个 SHA、同一套 skill、且全部内容指纹一致时，什么都不做直接返回。
if [ -n "$installed_commit" ] && [ "$installed_commit" = "$resolved" ]; then
  installed_set=$(sed -n 's|^skill=||p' "$manifest" | LC_ALL=C sort | tr '\n' ' ')
  requested_set=$(printf '%s\n' "${selected[@]}" | LC_ALL=C sort | tr '\n' ' ')
  unchanged=1
  if [ "$installed_set" != "$requested_set" ]; then
    unchanged=0
  else
    for skill in "${selected[@]}"; do
      want_fp=$(recorded_fingerprint "$skill") || want_fp=""
      if ! path_occupied "$target/$skill" || [ -L "$target/$skill" ] || [ ! -d "$target/$skill" ] ||
        [ -z "$want_fp" ] || [ "$(fingerprint "$target/$skill")" != "$want_fp" ]; then
        unchanged=0
        break
      fi
    done
    want_resident_fp=$(recorded_fingerprint resident) || want_resident_fp=""
    if ! path_occupied "$resident_target" || [ -L "$resident_target" ] || [ -z "$want_resident_fp" ] ||
      [ "$(file_fingerprint "$resident_target")" != "$want_resident_fp" ]; then
      unchanged=0
    fi
  fi
  if [ "$unchanged" -eq 1 ]; then
    printf '已是 %s，且内容未改动，无需重装。\n' "$resolved"
    printf '常驻块：%s\n' "$resident_target"
    exit 0
  fi
fi

# 到这里说明不是幂等情形：要么换 SHA，要么已有内容与记录不符。两种都拒绝，不做原地升级。
occupied=()
if [ -n "$installed_commit" ] && [ "$installed_commit" != "$resolved" ]; then
  while IFS= read -r skill; do
    if [ -n "$skill" ] && path_occupied "$target/$skill"; then occupied+=("$target/$skill"); fi
  done < <(sed -n 's|^skill=||p' "$manifest")
  occupied+=("$manifest")
  if path_occupied "$resident_target"; then occupied+=("$resident_target"); fi
  refuse_occupied "目标已装 tooluse ${installed_commit}，要换成 ${resolved} 属于升级；本安装器不做原地升级。" \
    "${occupied[@]}"
fi
for skill in "${selected[@]}"; do
  if path_occupied "$target/$skill"; then occupied+=("$target/$skill"); fi
done
if path_occupied "$resident_target"; then occupied+=("$resident_target"); fi
if [ "${#occupied[@]}" -gt 0 ]; then
  if path_occupied "$manifest"; then occupied+=("$manifest"); fi
  refuse_occupied "目标已有内容，且与已登记的安装不一致（可能被本地修改、手工安装或部分残留）。" \
    "${occupied[@]}"
fi
# 有 manifest 但相关位置都空：记录与实际不符，同样交给用户处理，不擅自删除记录。
if path_occupied "$manifest"; then
  refuse_occupied "目标存在 ${manifest}，但登记的内容已不在原处；记录与实际不一致。" "$manifest"
fi

# 全部临时目录用 mktemp，不用 PID 命名——PID 会复用，撞上旧残留就会误判。
# stage 一建就注册 trap：等 incoming 也建好再注册，第二次 mktemp 失败就会残留 stage。
stage=$(mktemp -d "${TMPDIR:-/tmp}/tooluse-install.XXXXXX")
incoming=""
cleanup() {
  rm -rf -- "${stage:?}"
  if [ -n "$incoming" ]; then rm -rf -- "${incoming:?}"; fi
}
trap cleanup EXIT
incoming=$(mktemp -d "$target/.tooluse-incoming.XXXXXX")

git archive --format=tar "$resolved" skills resident/tooluse-resident.md | tar -xf - -C "$stage"
[ -f "$stage/resident/tooluse-resident.md" ] || die "提交缺 resident/tooluse-resident.md"
for skill in "${selected[@]}"; do
  [ -f "$stage/skills/$skill/SKILL.md" ] || die "提交缺 skills/$skill/SKILL.md"
done

fingerprints=""
for skill in "${selected[@]}"; do
  cp -R "$stage/skills/$skill" "$incoming/$skill"
  fingerprints="${fingerprints}fingerprint=${skill}=$(fingerprint "$incoming/$skill")
"
done
cp "$stage/resident/tooluse-resident.md" "$incoming/tooluse-resident.md"
chmod 0644 "$incoming/tooluse-resident.md"
fingerprints="${fingerprints}fingerprint=resident=$(file_fingerprint "$incoming/tooluse-resident.md")
"
{
  printf 'tooluse_commit=%s\n' "$resolved"
  printf 'installed_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'resident=%s\n' "$resident_target"
  for skill in "${selected[@]}"; do printf 'skill=%s\n' "$skill"; done
  printf '%s' "$fingerprints"
} >"$incoming/.tooluse-version"

# 只做「移进空位」：上面已确认这些位置都不存在，所以这里不会覆盖任何东西。
# 中途失败会留下部分新目录和 incoming 残留，但用户的旧内容从未被动过。
for skill in "${selected[@]}"; do
  mv "$incoming/$skill" "$target/$skill"
done
mv "$incoming/tooluse-resident.md" "$resident_target"
mv "$incoming/.tooluse-version" "$manifest"

printf '已从 %s 安装：%s\n' "$resolved" "${selected[*]}"
printf '把 %s 的「常驻块」复制进目标项目的 CLAUDE.md 或 AGENTS.md。\n' "$resident_target"
