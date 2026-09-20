# 05 · 布局组件：topTab / bottomTab / drawer

布局组件的 `fetch()` **返回的不是 items，而是一个"tab/菜单条目数组"**。
每个条目 `{ title, image, route }`，点击后跳转到对应路由后**在内部渲染**（tab 形式）。

> ⚠️ 注意：布局组件的子页面是在**同一页面内嵌套**渲染的，子组件不要写 `type: 'bottomTab'` 之类，
> 否则会产生嵌套异常（可以用，但体验很怪）。

---

## 1. topTab —— 顶部 tab（最常用）

```js
module.exports = {
  type: 'topTab',
  tabMode: 'fixed',          // auto（默认）| fixed（等宽填满）| scrollable（可滚动）
  fetch() {
    return [
      { title: '电影',   image: $icon('movie'), route: $route('movies') },
      { title: '电视剧', image: $icon('tv'),    route: $route('soap') },
      { title: '动漫',   route: $route('anime') }
    ]
  }
}
```

| 属性 | 说明 |
|---|---|
| `items: object[]` | tab 数组 |
| `tabMode: string` | `auto` / `fixed` / `scrollable` |

条目字段：`title`（必填）、`image`（`$icon()` 或 `$assets()`）、`route`。

---

## 2. bottomTab —— 底部 tab

```js
module.exports = {
  type: 'bottomTab',
  fetch() {
    return [
      { title: '图库', route: $route('photos'), image: $assets('photo.svg') },
      { title: '搜索', route: $route('search'), image: $icon('search') },
      { title: '我的', route: $route('me'),     image: $icon('person') }
    ]
  }
}
```

> **最多支持 5 个**，多余的不会显示。
> 也可以写成静态属性形式（不写 fetch）：`items: [ ... ]`（见官方 api_demo）。

---

## 3. drawer —— 抽屉菜单

```js
module.exports = {
  type: 'drawer',
  fetch() {
    return [
      { title: '电影',   image: $icon('movie'), route: $route('movies') },
      { title: '电视剧', image: $icon('tv'),    route: $route('soap') }
    ]
  }
}
```

---

## 4. 三选一决策

| 场景 | 选 |
|---|---|
| 一个站点的多个大分类（电影/剧集/动漫/综艺） | `topTab`（fixed）+ 每个 tab 一个 list 组件 |
| 多个**功能模块**（首页/搜索/设置/我的） | `bottomTab` |
| 分类特别多（>5）或想做成"网站门户感" | `drawer` |
| 只有一个列表 | 直接 `index.js` 写 `type: 'list'` |

## 5. 完整示例：一个多分类视频站首页

**components/index.js**

```js
module.exports = {
  type: 'topTab',
  tabMode: 'scrollable',
  fetch() {
    const cats = [
      { title: '电影',   id: 6 },
      { title: '连续剧', id: 8 },
      { title: '综艺',   id: 10 },
      { title: '动漫',   id: 12 },
      { title: '短剧',   id: 20 }
    ]
    return cats.map(c => ({
      title: c.title,
      route: $route('list', { cid: c.id, name: c.title })
    }))
  }
}
```

**components/list.js**

```js
const base = 'https://www.example.com'
module.exports = {
  type: 'list',
  searchRoute: $route('search'),
  beforeCreate() {
    this.title = this.args.name || '列表'
  },
  async fetch({ args, page }) {
    const p = page || 1
    const resp = await $http.get(`${base}/vod/${args.cid}-${p}.html`, {
      headers: { Referer: base + '/' }
    })
    const $ = cheerio.load(resp.data)
    const items = []
    $('div.stui-vodlist__box').each((i, el) => {
      const $el = $(el)
      const href = $el.find('h4 a').attr('href') || ''
      const cover = $el.find('a.stui-vodlist__thumb').attr('style') || ''
      const m = cover.match(/url\((.*?)\)/)
      items.push({
        title: $el.find('h4').text().trim(),
        style: 'vod',
        image: m ? abs(m[1]) : null,
        label: $el.find('p').text().trim(),
        route: $route('detail', { url: abs(href), title: $el.find('h4').text().trim() })
      })
    })
    return { nextPage: items.length ? p + 1 : null, items }
  }
}
function abs(u) { return /^https?:/.test(u) ? u : base + (u.startsWith('/') ? u : '/' + u) }
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
      { headers: { Referer: base + '/' } }
    )
    const $ = cheerio.load(resp.data)
    const items = []
    $('div.stui-vodlist__box').each((i, el) => { /* 同上解析 */ })
    return { title: kw + ' 的搜索结果', nextPage: items.length ? p + 1 : null, items }
  }
}
```

> 注意 `list.js` 与 `search.js` 里都要能访问 `base` 与 `abs()`；
> 建议把公共函数/常量放 `main.js` 的 `module.exports`（会挂到 global），比如 `global.base`、`global.absUrl`。