// 一个最小但完整可跑的 Dora.js 扩展
// 站点/接口：必应每日壁纸公开接口（无需 key、无需 cheerio）
// 价值：演示「接口站」配方的全部要点 —— 分页、字段映射、@image 内置页面、prefs、actions

if (typeof $dora == 'undefined') {
  console.error('This project runs only in Dora.js.')
  console.error('Please visit https://dorajs.com/ for more information.')
  process.exit(-1)
}

global.API = 'https://www.bing.com'

// 不同地区的壁纸不同，通过 prefs.json 配置
global.getMkt = function () {
  return $prefs.get('mkt') || 'zh-CN'
}

global.HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
}

global.pad2 = function (n) {
  return n < 10 ? '0' + n : '' + n
}

// 把 yyyymmdd 变成 2026-09-20
global.formatDate = function (s) {
  if (!s || s.length !== 8) return s
  return s.substr(0, 4) + '-' + s.substr(4, 2) + '-' + s.substr(6, 2)
}

console.info('[BingWallpaper] started, mkt = ' + global.getMkt())