// components/index.js —— 点击扩展图标后进入的第一个页面（必需）
// 常用三种写法，按需选一种，其余删掉。

// ===== 写法 1：直接一个列表（最简单）=====
// module.exports = {
//   type: 'list',
//   title: '首页',
//   async fetch({ page }) {
//     const p = page || 1
//     const resp = await $http.get(`${base}/vod/6-${p}.html`, { headers: HEADERS })
//     const items = [] // ← 用 cheerio 解析
//     return { nextPage: p + 1, items }
//   }
// }

// ===== 写法 2：顶部 tab（多分类，最常用）=====
module.exports = {
  type: 'topTab',
  tabMode: 'scrollable',
  fetch() {
    return [
      { title: '电影', route: $route('list', { cid: 6, name: '电影' }) },
      { title: '连续剧', route: $route('list', { cid: 8, name: '连续剧' }) },
      { title: '综艺', route: $route('list', { cid: 10, name: '综艺' }) },
      { title: '动漫', route: $route('list', { cid: 12, name: '动漫' }) }
    ]
  }
}

// ===== 写法 3：底部 tab（多功能模块）=====
// module.exports = {
//   type: 'bottomTab',
//   fetch() {
//     return [
//       { title: '首页', route: $route('list', { cid: 6 }), image: $icon('home') },
//       { title: '搜索', route: $route('search'), image: $icon('search') },
//       { title: '我的', route: $route('me'), image: $icon('person') }
//     ]
//   }
// }
