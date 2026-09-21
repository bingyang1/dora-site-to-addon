#!/bin/sh
# dora-sync.sh — Dora.js 真机联调（Live Sync）命令行工具
#
# 协议逆向自官方 VSCode 插件 DoraKit/vscode-extension（linroid.dora），
# 并在 Android 15 / Dora.js 1.8.1 上实测通过。
# 核心：Dora.js 内置 HTTP 服务监听 4000 端口，官方插件只是个 http 客户端，
#       所以没有 VSCode、没有电脑、没有 WiFi 也能联调（走 127.0.0.1）。
#
# 用法:
#   dora-sync.sh ping                       探活（必要时自动把 Dora 拉到前台）
#   dora-sync.sh foreground                 仅把 Dora 拉到前台（需要 am，即 Android shell）
#   dora-sync.sh list                       列出手机里的扩展（uuid / 名称 / 版本 / 作者）
#   dora-sync.sh pull <uuid|名称> [目录]     拉取扩展源码到目录（默认 ./<名称>）
#   dora-sync.sh push <目录> [uuid]          打包（平铺 zip，排除 node_modules）并推送
#   dora-sync.sh watch <目录> [uuid] [秒]    轮询改动，自动推送（默认 3 秒）
#
# 环境变量:
#   DORA_HOST     默认 127.0.0.1（本机 loopback，无需 WiFi）；PC 上用手机局域网 IP
#   DORA_PORT     默认 4000
#   DORA_FG       默认 1：ping/push 前自动 foreground；设 0 关闭
#   DORA_FG_WAIT  前台化后等待秒数，默认 2
#
# 环境差异（重要）:
#   Android shell (Shizuku/Root): 有 am/curl/unzip/tar/md5sum，没有 zip/python3
#                                 → 能 foreground，push 需要外部已打好 zip
#   Linux 终端 (proot Ubuntu):    有 python3/curl/unzip，看不到 /system/bin
#                                 → 能打包 push/pull，但无法自动 foreground
#   建议：在 Linux 终端里跑 pull/push；连不上时在 Android shell 里跑一次
#         am start -n com.linroid.dora/.ui.DoraActivity

set -u

HOST=${DORA_HOST:-127.0.0.1}
PORT=${DORA_PORT:-4000}
BASE="http://$HOST:$PORT"
ACTIVITY="com.linroid.dora/.ui.DoraActivity"
AUTO_FG=${DORA_FG:-1}
FG_WAIT=${DORA_FG_WAIT:-2}
APP_ID="com.linroid.dora"

die() { echo "✗ $*" >&2; exit 1; }
info() { echo "· $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 基础 ----------

ping_once() {
  [ "$(curl -s -m 3 "$BASE/ping" 2>/dev/null)" = "pong" ]
}

# 把 Dora 拉回前台。只有 Android shell 有 am；Linux proot 看不到 /system/bin。
foreground() {
  if have am; then
    am start -n "$ACTIVITY" >/dev/null 2>&1 || return 1
    sleep "$FG_WAIT"
    return 0
  fi
  return 1
}

# 探活失败时的自动恢复 + 排错指引
require_server() {
  ping_once && return 0
  if [ "$AUTO_FG" = "1" ]; then
    info "服务无响应，尝试把 Dora 拉到前台…"
    if foreground && ping_once; then
      info "已前台化，连接恢复（别忘了：同步期间 Dora 必须保持前台）"
      return 0
    fi
    info "无法自动前台化（当前环境没有 am，或仍在后台）"
  fi
  cat >&2 <<EOF

✗ 连不上 $BASE

  排查顺序：
  1) Dora.js 里那个「连接 VSCode」开关还开着吗？（关掉后 4000 端口会消失）
  2) 【最常见】Dora 被切到后台，系统冻结进程 → TCP 直接超时（不是 404，不是拒绝）。
     判据：PID=\$(pidof $APP_ID); cat /proc/\$PID/cgroup | head -3
           cpuset:/background  ← 就是这个坑；前台时是 /foreground
     解法：在 Android shell（Shizuku/Root）里执行
           am start -n $ACTIVITY
     或者把 Dora 与编辑器分屏/小窗，保持它可见。
  3) 端口真的在听吗：netstat -tln | grep $PORT
     （十六进制 0FA0 = 4000；进程属主 uid 应该是 $APP_ID 那个 uid）

EOF
  return 1
}

# 从 /addon 的 JSON 里解析 uuid：支持 uuid 本身 / displayName / 包名 三种引用
resolve_uuid() {
  ref=$1
  case "$ref" in
    ????????-????-????-????-????????????) echo "$ref"; return 0 ;;
  esac
  json=$(curl -s -m 8 "$BASE/addon") || return 1
  [ -n "$json" ] || return 1
  if have python3; then
    printf '%s' "$json" | python3 -c '
import sys, json
ref = sys.argv[1]
for a in json.load(sys.stdin):
    if ref in (a.get("uuid"), a.get("displayName"), a.get("name")):
        print(a.get("uuid")); break
' "$ref"
  else
    printf '%s' "$json" | tr '}' '\n' | grep -F "$ref" | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4
  fi
}

# 目录内容指纹（用于 watch）
dir_hash() {
  find "$1" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' \
       -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1
}

tmpfile() {
  t=$(mktemp 2>/dev/null) && [ -n "$t" ] && { echo "$t"; return 0; }
  echo "/tmp/${1:-dora}-$$.zip"
}

# ---------- 子命令 ----------

cmd_ping() {
  require_server || exit 1
  echo "pong ✓  $BASE"
}

cmd_foreground() {
  if foreground; then
    echo "✓ 已把 Dora 拉到前台（$ACTIVITY）"
  else
    echo "✗ 当前环境没有 am —— 请在 Android shell（Shizuku/Root）里执行："
    echo "  am start -n $ACTIVITY"
    return 1
  fi
}

cmd_list() {
  require_server || exit 1
  json=$(curl -s -m 8 "$BASE/addon") || die "请求 /addon 失败"
  case "$json" in
    \[*) : ;;
    *) die "返回内容不是扩展列表：$(printf '%s' "$json" | head -c 200)" ;;
  esac
  if have python3; then
    printf '%s' "$json" | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("共 %d 个扩展：" % len(d))
for a in d:
    print("  %-18s %-8s %-14s %-24s %s" % (
        a.get("displayName", ""), a.get("version", ""), a.get("author", ""),
        a.get("name", ""), a.get("uuid", "")))
print("")
print("  列：显示名 / 版本 / 作者 / 包名 / uuid")
'
  else
    echo "（无 python3，原样输出 JSON；uuid 字段就是 pull 要用的值）"
    printf '%s\n' "$json"
  fi
}

cmd_pull() {
  ref=${1:-}
  [ -n "$ref" ] || die "用法: dora-sync.sh pull <uuid|名称> [目录]"
  dest=${2:-}
  require_server || exit 1
  uuid=$(resolve_uuid "$ref") || true
  [ -n "${uuid:-}" ] || die "没找到匹配的扩展：$ref（先跑 list）"
  [ -n "$dest" ] || dest="./$ref"

  mkdir -p "$dest" || die "无法创建目录：$dest"
  tmp=$(tmpfile pull)
  info "拉取 $uuid …"
  curl -s -m 30 -o "$tmp" "$BASE/addon/$uuid?pull" || die "下载失败"
  size=$(wc -c < "$tmp" | tr -d ' ')
  [ "${size:-0}" -gt 200 ] || { rm -f "$tmp"; die "返回内容异常（${size}B）——uuid 可能不对"; }

  if have unzip; then
    unzip -o -q "$tmp" -d "$dest" || { rm -f "$tmp"; die "解压失败"; }
  elif have python3; then
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp" "$dest" \
      || { rm -f "$tmp"; die "解压失败"; }
  else
    rm -f "$tmp"; die "需要 unzip 或 python3 才能解压"
  fi
  rm -f "$tmp"
  echo "✓ 已同步到 $dest（${size} 字节，平铺 zip：根目录就是 package.json）"
  echo "  改完这样推回去：dora-sync.sh push $dest $uuid"
}

cmd_push() {
  dir=${1:-}
  [ -n "$dir" ] || die "用法: dora-sync.sh push <目录> [uuid]"
  [ -d "$dir" ] || die "目录不存在：$dir"
  [ -f "$dir/package.json" ] || die "$dir 里没有 package.json（联调工程根目录必须是平铺的，不是 package/ 子目录）"

  uuid=${2:-}
  if [ -z "$uuid" ]; then
    uuid=$(sed -n 's/.*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/package.json" | head -1)
  fi
  [ -n "$uuid" ] || die "拿不到 uuid：请在 package.json 里补 uuid，或用第二个参数直接给"

  require_server || exit 1

  # push 只能【更新已存在】的扩展：uuid 不在手机上时服务端照样返回 code:0，但不会生效
  list_json=$(curl -s -m 8 "$BASE/addon")
  case "$list_json" in
    *"$uuid"*) : ;;
    *)
      info "⚠ 手机上还没有 uuid=$uuid 这个扩展"
      info "  Live Sync 只能更新已存在的扩展；首次请先安装 .dora 包（或用手机端「创建扩展」）"
      info "  否则本次 push 会返回 code:0，但扩展不会出现在列表里。"
      ;;
  esac

  tmp=$(tmpfile push); rm -f "$tmp"
  info "打包（平铺 zip + 目录条目，排除 node_modules/.git/.vscode）…"
  # ★★★ 铁律：zip 里必须包含【目录条目】（名字以 / 结尾，如 assets/、components/）★★★
  #   原因：Dora 的解包器（FilePackageProvider）只对目录条目执行 mkdirs()，
  #   遇到文件条目时直接 File(rootDir, "assets/icon.png").createNewFile()。
  #   如果 zip 里没有 "assets/" 这个目录条目，父目录不存在 →
  #       java.io.IOException: No such file or directory  → 安装中止
  #   而 HTTP 依然返回 {"code":0}，看起来像成功了。这是本项目最贵的一个坑。
  #   Python 的 zipfile.write() 【不会】自动生成目录条目；zip -r 和 tar 会自动生成。
  if have python3; then
    python3 - "$dir" "$tmp" <<'PY'
import os, sys, stat, zipfile

src, dst = sys.argv[1], sys.argv[2]
skip_names = {"node_modules", ".git", ".idea", ".vscode", "_work", "dist", ".DS_Store"}
skip_suffix = (".zip", ".dora")

def clean(rel):
    return rel.replace(os.sep, "/")

with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in skip_names)
        # ① 先写本层所有目录条目（保证父目录先于子文件出现在 zip 里）
        for d in dirs:
            rel = clean(os.path.relpath(os.path.join(root, d), src)) + "/"
            zi = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            zi.create_system = 3
            zi.external_attr = (stat.S_IFDIR | 0o755) << 16
            zi.compress_type = zipfile.ZIP_STORED
            z.writestr(zi, b"")
        # ② 再写本层文件
        for f in sorted(files):
            if f in skip_names or f.endswith(skip_suffix):
                continue
            p = os.path.join(root, f)
            z.write(p, clean(os.path.relpath(p, src)))

names = zipfile.ZipFile(dst).namelist()
dirs_n = [n for n in names if n.endswith("/")]
files_n = [n for n in names if not n.endswith("/")]
print("  zip: %d 文件 + %d 目录条目" % (len(files_n), len(dirs_n)))
missing = sorted({os.path.dirname(n) + "/" for n in files_n if os.path.dirname(n)} - set(dirs_n))
if missing:
    print("  ⚠ 以下子目录缺目录条目，App 会解包失败：", missing, file=sys.stderr)
    sys.exit(9)
PY
    rc=$?
    [ "$rc" = "0" ] || { rm -f "$tmp"; die "打包失败（缺少目录条目，rc=$rc）"; }
  elif have zip; then
    # zip -r 会自动带上目录条目，可以放心用
    ( cd "$dir" && zip -qr "$tmp" . -x 'node_modules/*' '.git/*' '.vscode/*' ) || die "zip 打包失败"
  else
    die "需要 python3 或 zip 才能打包 —— Android shell 两者都没有，请在 Linux 终端环境里跑 push"
  fi
  [ -s "$tmp" ] || { rm -f "$tmp"; die "打出来的 zip 是空的"; }

  # zip 里的 uuid 必须和手机上的目标扩展一致 —— App 就是按 zip 里 package.json 的 uuid 认领的。
  # 手机手动安装时可能会分配新的 uuid，所以这里按参数对齐。
  if have python3; then
    zip_uuid=$(python3 -c 'import sys,zipfile,json
z=zipfile.ZipFile(sys.argv[1])
print(json.loads(z.read("package.json").decode("utf-8")).get("uuid",""))' "$tmp" 2>/dev/null)
    if [ -n "${zip_uuid:-}" ] && [ "$zip_uuid" != "$uuid" ]; then
      info "把 zip 内 package.json 的 uuid 由 $zip_uuid 改成 $uuid（对齐手机上的扩展）"
      python3 - "$tmp" "$uuid" <<'PY'
import sys, zipfile, json, os
dst, new_uuid = sys.argv[1], sys.argv[2]
tmp2 = dst + '.new'
with zipfile.ZipFile(dst) as zin, zipfile.ZipFile(tmp2, 'w', zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == 'package.json':
            j = json.loads(data.decode('utf-8'))
            j['uuid'] = new_uuid
            data = json.dumps(j, ensure_ascii=False, indent=2).encode('utf-8')
        zout.writestr(item, data)
os.replace(tmp2, dst)
PY
      [ -f "$tmp" ] || die "重写 zip 失败"
    fi
  fi

  info "推送到手机（字段名 file，平铺 zip）…"
  resp=$(curl -s -m 30 -F "file=@$tmp" "$BASE/addon") || { rm -f "$tmp"; die "上传失败"; }
  rm -f "$tmp"
  echo "$resp"
  case "$resp" in
    *'"code":0'*) echo "✓ 推送成功（手机端应提示「xxx 已更新」）" ;;
    *) die "推送返回异常，检查 Dora 是否在前台、工程结构是否为平铺" ;;
  esac
}

cmd_watch() {
  dir=${1:-}
  [ -n "$dir" ] || die "用法: dora-sync.sh watch <目录> [uuid] [秒]"
  uuid=${2:-}
  interval=${3:-3}
  [ -d "$dir" ] || die "目录不存在：$dir"
  if [ -z "$uuid" ]; then
    uuid=$(sed -n 's/.*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/package.json" | head -1)
  fi
  [ -n "$uuid" ] || die "拿不到 uuid（package.json 或第二个参数）"
  require_server || exit 1

  echo "👀 监视 $dir（每 ${interval}s 检查，Ctrl+C 退出）"
  last=$(dir_hash "$dir")
  while :; do
    sleep "$interval"
    cur=$(dir_hash "$dir")
    if [ "$cur" != "$last" ]; then
      echo "[$(date +%H:%M:%S)] 检测到改动 → 推送"
      cmd_push "$dir" "$uuid" || echo "  推送失败，等下次改动"
      last=$(dir_hash "$dir")
    fi
  done
}

# ---------- 入口 ----------

cmd=${1:-help}
[ $# -gt 0 ] && shift

case "$cmd" in
  ping)       cmd_ping ;;
  foreground|fg) cmd_foreground ;;
  list|ls)    cmd_list ;;
  pull)       cmd_pull "$@" ;;
  push)       cmd_push "$@" ;;
  watch)      cmd_watch "$@" ;;
  *)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac