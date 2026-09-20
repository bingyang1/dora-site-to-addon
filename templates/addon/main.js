// main.js —— 入口文件，扩展启动时执行一次。
// 这里 module.exports 的属性会被挂到 global，供所有组件直接使用。

if (typeof $dora == 'undefined') {
  console.error('This project runs only in Dora.js.')
  console.error('Please visit https://dorajs.com/ for more information.')
  process.exit(-1)
}

// ---------- 全局依赖 ----------
global.cheerio = require('cheerio')

// ---------- 全局常量（改成目标站点）----------
global.base = 'https://www.example.com'
global.API = global.base

global.HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  Referer: global.base + '/'
}

// 把相对地址补成绝对地址
global.absUrl = function (u) {
  if (!u) return null
  if (/^https?:/.test(u)) return u
  if (u.indexOf('//') === 0) return 'https:' + u
  return global.base + (u.charAt(0) === '/' ? u : '/' + u)
}

// 统一清理文本
global.clean = function (s) {
  return (s || '').replace(/\s+/g, ' ').trim()
}

// ---------- 全局默认请求头 ----------
$http.defaults.headers.common['User-Agent'] = global.HEADERS['User-Agent']

// ---------- 全局组件混入 ----------
$dora.mixin({
  beforeCreate() {
    this.headers = global.HEADERS
  },
  created() {
    // 所有组件数据加载完成后都会执行
  }
})

module.exports = {
  base: global.base,
  HEADERS: global.HEADERS
}

console.info('[MySite] addon started @ ' + global.base)
