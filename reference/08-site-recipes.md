# 08 · 实战配方（按站点类型选）

> 用法：先判定站点属于哪一类，然后照抄配方改常量即可。
> 所有配方都遵循同一套路：**抓列表 → 映射 items → 点击进详情 → 详情交给内置组件**。

---

## 配方 A · 苹果CMS / maccms / stui 视频站（最常见）

**识别特征**（任一命中即是）：
- HTML 含 `stui-vodlist__box` / `stui-vodlist__thumb` / `mac-vodlist`
- 分类页 URL：`/vod/6-2.html`（`/vod/{分类id}-{页码}.html`）
- 有 `/vodsearch/----------{page}---.html?wd=关键词`（或 `/index.php/vod/search.html?wd=`）
- 详情页含 `player_aaaa` 或 `MacPlayer` 变量

**工程结构**

```
package/
├── package.json          # dependencies: cheerio；contributes.search = "search"
├── main.js               # global.base / global.cheerio / global.absUrl
├── assets/{icon.png, prefs.json}
└── components/
    ├── index.js          # topTab：各分类
    ├── list.js           # 分类列表（分页）
    ├── detail.js         # 详情（线路按钮）
    ├── play.js           # type:'video' 播放
    └── search.js         # 搜索
```

**main.js**
```js
if (typeof $dora == 'undefined') { console.error('Only Dora.js'); process.exit(-1) }
global.cheerio = require('cheerio')
global.base = 'https://www.example.com'       // ★ 改成目标站点
global.absUrl = function (u) {
  if (!u) return null
  if (/^https?:/.test(u)) return u
  return base + (u.startsWith('/') ? u : '/' + u)
}
global.HEADERS = { 'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36', Referer: base + '/' }
module.exports = {}
```

**components/index.js**
```js
module.exports = {
  type: 'topTab',
  tabMode: 'scrollable',
  fetch() {
    return [
      { title: '电影',   route: $route('list', { cid: 6,  name: '电影' }) },
      { title: '连续剧', route: $route('list', { cid: 8,  name: '连续剧' }) },
      { title: '综艺',   route: $route('list', { cid: 10, name: '综艺' }) },
      { title: '动漫',   route: $route('list', { cid: 12, name: '动漫' }) }
    ]
  }
}
```

**components/list.js**（核心解析，`search.js` 复用同一函数）
```js
function parseList($) {
  const items = []
  $('div.stui-vodlist__box').each((i, el) => {
    const $el = $(el)
    const title = $el.find('h4').text().trim()
    const href = $el.find('h4 a').attr('href') || ''
    const styleAttr = $el.find('a.stui-vodlist__thumb').attr('style') || ''
    const m = styleAttr.match(/url\(['"]?(.*?)['"]?\)/)
    const image = m ? absUrl(m[1]) : $el.find('img').attr('data-original')
    const label = $el.find('p').text().trim()
    if (!title) return
    items.push({
      title,
      style: 'vod',
      image: image ? absUrl(image) : null,
      label,
      route: $route('detail', { url: absUrl(href), title })
    })
  })
  return items
}

module.exports = {
  type: 'list',
  searchRoute: $route('search'),
  beforeCreate() { this.title = this.args.name || '列表' },
  async fetch({ args, page }) {
    const p = page || 1
    try {
      const resp = await $http.get(`${base}/vod/${args.cid}-${p}.html`, { headers: HEADERS })
      const items = parseList(cheerio.load(resp.data))
      if (!items.length && p > 1) return { nextPage: null, items: [] }
      return { nextPage: p + 1, items }
    } catch (e) {
      this.error = '加载失败：' + e.message
      return { items: [] }
    }
  }
}
```

**components/detail.js**（把详情页里的播放线路做成按钮）
```js
module.exports = {
  type: 'list',
  async fetch({ args }) {
    const resp = await $http.get(args.url, { headers: HEADERS })
    const html = resp.data
    const $ = cheerio.load(html)

    // 线路：MacPlayer 的 player_aaaa 或页面的线路 tab
    const playLists = []
    const mm = html.match(/player_aaaa\s*=\s*(\{[\s\S]*?\})/)
    if (mm) {
      try {
        const info = JSON.parse(mm[1])
        playLists.push({ name: info.from || '线路1', url: info.url })
      } catch (e) {}
    }
    // 兜底：抓页面里的 m3u8/mp4
    if (!playLists.length) {
      const m2 = html.match(/https?:\\?\/\\?\/[^"'\s]+?\.(m3u8|mp4)[^"'\s]*/i)
      if (m2) playLists.push({ name: '默认线路', url: m2[0].replace(/\\/g, '') })
    }

    const info = $('.stui-content__detail p').text().replace(/\s+/g, ' ').trim()
    const cover = $('.stui-content__thumb img').attr('data-original')

    const items = playLists.map(pl => ({
      title: '▶ ' + pl.name,
      style: 'simple',
      image: $icon('play_circle_filled', 'blue'),
      onClick() { $router.to($route('play', { url: pl.url, title: args.title })) }
    }))

    items.unshift({
      title: '简介',
      style: 'richContent',
      content: { url: args.url, html: `<p>${info}</p>` }
    })

    return { title: args.title || '详情', image: cover ? absUrl(cover) : null, items }
  }
}
```

**components/play.js**
```js
module.exports = {
  type: 'video',
  async fetch({ args }) {
    return {
      title: args.title,
      url: args.url,
      headers: HEADERS
    }
  }
}
```

**components/search.js**
```js
module.exports = {
  type: 'list',
  async fetch({ args, page }) {
    const p = page || 1
    const kw = args.keyword || ''
    const resp = await $http.get(
      `${base}/vodsearch/----------${p}---.html?wd=${encodeURIComponent(kw)}&submit=`,
      { headers: HEADERS }
    )
    const items = parseList(cheerio.load(resp.data))   // 同 list.js 的 parseList
    return { title: `${kw} 的搜索结果`, nextPage: items.length ? p + 1 : null, items }
  }
}
```

**package.json 关键片段**
```json
{
  "categories": ["video"],
  "contributes": { "search": "search" },
  "dependencies": { "cheerio": "^1.0.0-rc.12" }
}
```

> 💡 不同 maccms 主题的选择器不一样。除了 `stui-*`，常见的还有：
> `mac-vodlist`（MacCMS 默认蓝色主题）、`.module-item`（海螺主题）、`.public-list-box`。
> **一定要先抓真实 HTML 确认选择器**，别硬套。

---

## 配方 B · JSON 接口站（最省事，首选）

只要接口返回 JSON，**不要用 cheerio**，直接映射。

```js
module.exports = {
  type: 'list',
  async fetch({ args, page }) {
    const p = page || 1
    const resp = await $http.post(`${API}/v1/video/list`,        // POST 也行
      { cate_id: args.cid, page: p, page_size: 20 },
      { headers: { token: $prefs.get('token') || '' } }
    )
    const list = resp.data.data || []
    return {
      nextPage: list.length >= 20 ? p + 1 : null,
      items: list.map(v => ({
        title: v.title,
        style: 'live',
        image: v.thumb || v.cover,
        viewerCount: v.play_count,
        label: v.category_name,
        route: $route('player', { id: v.id, title: v.title })
      }))
    }
  }
}
```

**components/player.js**
```js
module.exports = {
  type: 'video',
  async fetch({ args }) {
    const resp = await $http.get(`${API}/v1/video/info?videoId=${args.id}`)
    let url = resp.data.result.url
    if (url && !/^https?:/.test(url)) url = API + url
    return { title: args.title, url, headers: { Referer: API + '/' } }
  }
}
```

**找接口的技巧**：
1. 用 `http_request` 请求页面，看是否有 `window.__NUXT__` / `window.__INITIAL_STATE__` / `__NEXT_DATA__`
2. 直接在页面 HTML 里正则搜 `"api":` / `/api/` / `.json`
3. 从移动端 H5 抓（很多站点 H5 版接口最简单，无签名）
4. 常见 REST 形态：`/api/v1/{module}/list?page=1&limit=20`

---

## 配方 C · 图片站（壁纸 / 相册）

```js
// components/index.js
module.exports = {
  type: 'list',
  translucent: true,
  async fetch({ page }) {
    const p = page || 1
    const resp = await $http.get(`${base}/api/photos?page=${p}&limit=30`, { headers: HEADERS })
    const list = resp.data.data || []
    return {
      nextPage: list.length ? p + 1 : null,
      items: list.map(ph => ({
        title: ph.title || '',
        style: 'gallery',
        image: ph.thumb || ph.url,
        summary: ph.author,
        spanCount: 12,
        route: $route('@image', { url: ph.url, title: ph.title })   // ★ 直接用内置图片组件
      }))
    }
  }
}
```

HTML 解析版：
```js
const $ = cheerio.load(html)
$('.item img').each((i, el) => {
  const src = $(el).attr('data-original') || $(el).attr('src')     // ★ 懒加载属性
  items.push({ style: 'gallery', image: absUrl(src), title: $(el).attr('alt'), route: $route('@image', { url: absUrl(src) }) })
})
```

> 图片站注意：
> - 懒加载（`data-original` / `data-src` / `srcset` / `background-image`）要单独处理
> - 缩略图给 `image`，原图给 `$route('@image', {url})`，**不要用缩略图当原图**

---

## 配方 D · 文章 / 资讯站

```js
// 列表
{
  style: 'article',
  title: item.title,
  summary: item.summary,
  image: item.cover,
  time: item.pubDate,
  author: { name: item.author },
  route: $route('post', { url: item.link })
}

// components/post.js
module.exports = {
  type: 'article',
  async fetch({ args }) {
    const resp = await $http.get(args.url, { headers: HEADERS })
    const $ = cheerio.load(resp.data)
    $('script,style,.ad,.ads,.comment,.nav,.footer,.sidebar').remove()
    const title = $('h1').text().trim() || $('title').text().trim()
    const content = $('.article-content, .post-content, #content, article').first()
    return {
      title,
      time: $('time').text() || $('.date').text(),
      author: { name: $('.author').text().trim() },
      content: {
        url: args.url,                 // ★ 让相对路径图片能正确加载
        html: content.html() || $.html()
      }
    }
  }
}
```

> 若站点提供 RSS（`/feed`）或 JSON（`/wp-json/wp/v2/posts`），**优先用接口**，比解析 HTML 稳。

---

## 配方 E · 需要登录 / 带 Token 的站

1. 在 `assets/prefs.json` 里加 `token` / `cookie` 输入项
2. 在 `main.js` 里统一注入请求头

```json
{ "token": { "type": "password", "default": null, "title": "登录 Token" } }
```

```js
// main.js
$dora.mixin({
  beforeCreate() {
    const token = $prefs.get('token')
    this.apiHeaders = { 'User-Agent': 'Mozilla/5.0 ...', 'Authorization': token ? 'Bearer ' + token : '' }
  }
})
```

**扫码登录（进阶）**：用 `type:'webview'` 打开登录页 → 在 `onPageFinished` 里读 `this.cookies` →
存 `$storage.put('cookie', ...)` → 后面所有请求带上。

```js
module.exports = {
  type: 'webview',
  async fetch() { return { url: base + '/login' } },
  onPageFinished(url) {
    if (url.indexOf('index') > -1 || url.indexOf('home') > -1) {
      $storage.put('cookie', JSON.stringify(this.cookies))
      $ui.toast('登录成功，请返回')
      this.finish()
    }
  }
}
```
之后请求里加 `headers: { Cookie: JSON.parse($storage.get('cookie') || '{}')['SESSION'] }`
（或在 `main.js` 里设为 `$http.defaults.headers.common.Cookie`）。

---

## 配方 F · 强反爬 / 全 JS 渲染站（最后手段）

如果 API 被签名加密、又没有 H5 接口，用 WebView 嗅探：

```
components/index.js  →  type:'webview'  打开站点
      ↓ 注入 scripts/dom.js 拦截视频/请求
      ↓ $dora.sendEvent('found', {url})
onEvent  →  $router.to($route('@video', {url}))
```

`scripts/dom.js`：
```js
(function () {
  if (window.__dora_hooked) return
  window.__dora_hooked = true
  // 1) 拦截 <video>
  setInterval(function () {
    var v = document.querySelector('video')
    if (v && v.currentSrc) $dora.sendEvent('video', { url: v.currentSrc })
  }, 1500)
  // 2) 拦截 XHR（抓 m3u8）
  var open = XMLHttpRequest.prototype.open
  XMLHttpRequest.prototype.open = function (m, u) {
    if (/\.m3u8|\.mp4|\/play/.test(u)) $dora.sendEvent('video', { url: u })
    return open.apply(this, arguments)
  }
})()
```

> ⚠️ WebView 方案体验差、易被检测，**只在无路可走时使用**，并在 README 里注明。

---

## 配方速查

| 站点类型 | index.js | 列表 style | 详情 | 依赖 |
|---|---|---|---|---|
| maccms 视频站 | topTab | `vod` | video + selectors | cheerio |
| JSON 接口站 | list 或 topTab | `live` / `vod` | video | 无 |
| 图片/壁纸站 | list | `gallery` | `@image` | cheerio 或 无 |
| 文章/资讯站 | list | `article` | article | cheerio |
| 音乐站 | list | `simple` | audio | 无 |
| 论坛/贴吧 | bottomTab | `simple` | article | cheerio |
| 搜索聚合 | list | `article` | `@article` | 无 |