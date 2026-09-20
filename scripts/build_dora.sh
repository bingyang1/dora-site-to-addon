#!/usr/bin/env bash
# build_dora.sh —— 把工程目录打包成 .dora
#
# 用法:
#   sh build_dora.sh <工程目录> [输出文件]
# 示例:
#   sh build_dora.sh /sdcard/Download/dora/my-site
#     → 读取 my-site/package/package.json 的 displayName + version
#     → 输出 /sdcard/Download/dora/<displayName>-v<version>.dora
#
# 也可指定输出:
#   sh build_dora.sh /sdcard/Download/dora/my-site /tmp/out.dora

set -u

SRC="${1:-}"
OUTFILE="${2:-}"

if [ -z "$SRC" ]; then
  echo "用法: sh build_dora.sh <工程目录> [输出文件]"
  exit 1
fi

# 兼容两种传入方式：工程根目录 或 package 目录本身
if [ -f "$SRC/package/package.json" ]; then
  ROOT="$SRC"
elif [ -f "$SRC/package.json" ]; then
  ROOT="$(dirname "$SRC")"
else
  echo "[x] 找不到 package.json（请在工程根目录或 package 目录下执行）"
  exit 1
fi

PKG="$ROOT/package"

if [ ! -f "$PKG/components/index.js" ]; then
  echo "[!] 警告：缺少 components/index.js，安装后点击图标会没有反应"
fi

NAME=$(sed -n 's/.*"displayName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PKG/package.json" | head -1)
VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PKG/package.json" | head -1)
[ -z "$NAME" ] && NAME="addon"
[ -z "$VER" ] && VER="1.0.0"

if [ -z "$OUTFILE" ]; then
  BASE=$(dirname "$ROOT")
  OUTFILE="$BASE/$NAME-v$VER.dora"
fi

# 不打包这些
EXCLUDES="--exclude=node_modules --exclude=.git --exclude=.DS_Store --exclude=*.dora --exclude=__pycache__"

echo "[*] 打包 $PKG → $OUTFILE"
# 注意：-C ROOT 后只打 package 目录，保证压缩包根部是 package/
# --warning=no-file-changed：Android FUSE 文件系统的 mtime 抖动会误报该警告
tar -czf "$OUTFILE" --warning=no-file-changed --ignore-failed-read $EXCLUDES -C "$ROOT" package
RC=$?

# tar 退出码: 0=成功, 1=有警告(仍然出了包), 2=致命错误
if [ "$RC" -ge 2 ] || [ ! -f "$OUTFILE" ]; then
  echo "[x] 打包失败 (tar exit=$RC)"
  exit 1
fi
if [ "$RC" -eq 1 ]; then
  echo "[!] tar 有非致命警告，包已生成"
fi

SIZE=$(ls -lh "$OUTFILE" | awk '{print $5}')
echo "[✓] 完成: $OUTFILE ($SIZE)"
echo
echo "包内前 10 项（应看到 package/ 开头）:"
tar -tzf "$OUTFILE" | head -10