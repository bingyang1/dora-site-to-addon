#!/usr/bin/env bash
# probe_site.sh —— 站点侦察helper
#
# 用途：抓目标站点的 HTML，快速判断它属于哪种"配方"，并给出选择器线索。
#
# 用法:
#   sh probe_site.sh <URL> [保存文件名]
# 示例:
#   sh probe_site.sh https://www.example.com
#
# 依赖: curl（若没有会提示）

set -u

URL="${1:-}"
OUT="${2:-/sdcard/Download/dora/_work/probe.html}"

if [ -z "$URL" ]; then
  echo "用法: sh probe_site.sh <URL> [保存文件名]"
  exit 1
fi

UA='Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'

if ! command -v curl >/dev/null 2>&1; then
  echo "[x] 没有 curl，请先安装：apt install curl  或  pkg install curl"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "[*] 抓取 $URL"
curl -sSL --max-time 25 -A "$UA" -H "Accept-Language: zh-CN,zh;q=0.9" -o "$OUT" "$URL"
SIZE=$(wc -c < "$OUT" | tr -d ' ')

echo "[✓] 已保存: $OUT ($SIZE bytes)"
echo

echo "===== 站点指纹 ====="
for sig in "stui-vodlist" "mac-vodlist" "module-item" "public-list-box" "player_aaaa" "MacPlayer" "__NUXT__" "__NEXT_DATA__" "__INITIAL_STATE__" "window.__DATA__" "m3u8" "data-original" "lazyload"; do
  if grep -q "$sig" "$OUT" 2>/dev/null; then
    echo "  ✓ 命中: $sig"
  fi
done

echo
echo "===== 标题 ====="
grep -o '<title>[^<]*</title>' "$OUT" 2>/dev/null | head -1

echo
echo "===== 疑似列表容器（出现次数最多的 class）====="
grep -o 'class="[^"]*"' "$OUT" 2>/dev/null | sed 's/class="//;s/"//' | tr ' ' '\n' | \
  grep -E 'list|item|box|card|vod|post|article' | sort | uniq -c | sort -rn | head -15

echo
echo "===== 疑似分页 / 搜索链接 ====="
grep -oE '(href|action)="[^"]*(page|vodsearch|search|list)[^"]*"' "$OUT" 2>/dev/null | sort -u | head -15

echo
echo "===== 疑似接口 (api/json) ====="
grep -oE '"[^"]*api[^"]*"' "$OUT" 2>/dev/null | sort -u | head -15
grep -oE '/api/[A-Za-z0-9_/\-]+' "$OUT" 2>/dev/null | sort -u | head -15
grep -oE '[A-Za-z0-9_/\-]+\.json' "$OUT" 2>/dev/null | sort -u | head -15

echo
echo "提示：看到 stui-vodlist / mac-vodlist 说明极可能是苹果CMS，直接照抄 reference/08-site-recipes.md 的配方 A。"
echo "     看到 __NUXT__ / __NEXT_DATA__ / /api/ 说明有现成接口，优先用配方 B。"
echo "     也可以直接打开 $OUT 看 HTML 结构，或用浏览器 F12 抓 XHR。"