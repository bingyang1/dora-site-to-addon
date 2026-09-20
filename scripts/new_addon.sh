#!/usr/bin/env bash
# new_addon.sh —— Dora.js 扩展脚手架
#
# 用法:
#   sh new_addon.sh <输出目录> [显示名称] [作者]
# 示例:
#   sh new_addon.sh /sdcard/Download/dora/my-site "我的站点" "yourname"
#
# 生成结构:
#   <输出目录>/package/{package.json,main.js,README.md,assets/,components/,scripts/}

set -u

OUT="${1:-}"
DISPLAY_NAME="${2:-我的站点}"
AUTHOR="${3:-yourname}"

if [ -z "$OUT" ]; then
  echo "用法: sh new_addon.sh <输出目录> [显示名称] [作者]"
  exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$SKILL_DIR/templates/addon"

if [ ! -d "$TPL" ]; then
  echo "[x] 找不到模板目录: $TPL"
  exit 1
fi

PKG="$OUT/package"

if [ -e "$PKG" ]; then
  echo "[!] $PKG 已存在，若确认覆盖请先手动删除"
  exit 1
fi

mkdir -p "$PKG/assets" "$PKG/components" "$PKG/scripts"
cp -r "$TPL/." "$PKG/"

# ---- 生成 uuid（优先 python3，其次 uuidgen，最后 /proc 随机）----
UUID=""
if command -v python3 >/dev/null 2>&1; then
  UUID=$(python3 -c "import uuid;print(uuid.uuid4())")
elif command -v uuidgen >/dev/null 2>&1; then
  UUID=$(uuidgen | tr 'A-Z' 'a-z')
elif [ -r /proc/sys/kernel/random/uuid ]; then
  UUID=$(cat /proc/sys/kernel/random/uuid)
else
  UUID=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')
fi

# ---- 包名：拼音/英文小写连字符 ----
SLUG=$(echo "$DISPLAY_NAME" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
[ -z "$SLUG" ] && SLUG="my-site"

# ---- 替换占位符 ----
sed -i "s/00000000-0000-4000-8000-000000000000/$UUID/" "$PKG/package.json"
sed -i "s/\"name\": \"dorajs-my-site\"/\"name\": \"dorajs-$SLUG\"/" "$PKG/package.json"
sed -i "s/\"displayName\": \"我的站点\"/\"displayName\": \"$DISPLAY_NAME\"/" "$PKG/package.json"
sed -i "s/\"name\": \"yourname\"/\"name\": \"$AUTHOR\"/" "$PKG/package.json"
sed -i "s/^# 我的站点/# $DISPLAY_NAME/" "$PKG/README.md" 2>/dev/null || true

echo "[✓] 已创建扩展工程: $OUT"
echo "    uuid      = $UUID"
echo "    displayName = $DISPLAY_NAME"
echo "    author    = $AUTHOR"
echo
echo "下一步:"
echo "  1. 编辑 $PKG/main.js        —— 改 global.base 为你的站点"
echo "  2. 编辑 $PKG/components/*.js —— 写解析逻辑"
echo "  3. 放一个图标到 $PKG/assets/icon.png"
echo "  4. python3 $SKILL_DIR/scripts/check_addon.py $OUT"
echo "  5. sh $SKILL_DIR/scripts/build_dora.sh $OUT"
