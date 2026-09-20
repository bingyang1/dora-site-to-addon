# 03 · list 组件（最常用）

> 适合展示列表类数据。**90% 的站点只是把网页列表映射成 items。**

## 1. 额外成员

| 成员 | 类型 | 说明 |
|---|---|---|
| `items` | `object[]` | 列表条目数组 |
| `page` | `any?` | 当前页参数 |
| `nextPage` | `any?` | 下一页参数；`null` 表示没有更多（不再触发加载更多） |
| `append(items)` | `function` | 手动往列表追加条目 |

## 2. 分页机制

```js
module.exports = {
  type: 'list',
  async fetch({ args, page }) {
    const p = page || 1                       // ★ 首次 page 是 null
    const resp = await $http.get(`https://api.example.com/list?page=${p}`)
    const list = resp.data.data
    return {
      nextPage: list.length ? p + 1 : null,   // ★ null = 没更多了
      items: list.map(post => ({
        title: post.title,
        style: 'simple'
      }))
    }
  }
}
```

- `fetch` 里的 `page` == `this.nextPage`
- 加载更多时，返回的 `items` 会**自动追加**到已有 `items`（不是覆盖）
- **只有判断"没有更多"时返回 `nextPage: null`**，否则会无限翻页

## 3. items[] 支持的字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `string` | 标识符 |
| `title` | `string` | **标题（必填）** |
| `style` | `string` | 条目样式，默认 `simple` |
| `spanCount` | `number` | 占 12 栅格中的几格 |
| `summary` | `string` | 简述 |
| `label` | `string` | 角标/分类文字（vod、live 常用） |
| `viewerCount` | `number\|string` | 观看数（live） |
| `commentCount` | `number` | 评论数 |
| `voteCount` | `number` | 评分数量 |
| `time` | `string\|number` | 时间（时间戳或日期字符串） |
| `image` | `Url` | 图片（旧字段 `thumb` 已废弃但兼容） |
| `author` | `Author` | `{ name, avatar, route }` |
| `onClick` | `function` | 点击回调，**优先级高于 route** |
| `onLongClick` | `function` | 长按回调 |
| `route` | `Route` | 点击跳转的目标 |

> 所有字段几乎都可选，但**尽可能多赋值**，Dora.js 会尽量展示；为 `null` 的字段 UI 自动隐藏。

## 4. 全部条目样式一览

| style | 默认 spanCount | 适用场景 | 关键字段 |
|---|---|---|---|
| `simple` | 12 | 通用单行列表 | title, summary, image |
| `icon` | 4 | 图标九宫格（入口） | title, image($icon) |
| `category` | 12 | **分组标题**（不发请求，只是标题行） | title |
| `vod` | 6 | 影视海报墙（2 列） | image, title, label, summary |
| `live` | 6 | 直播/短视频卡片 | image, title, label, viewerCount, author |
| `gallery` | 12 | 大图/瀑布流 | image, title, summary, author |
| `article` | 12 | 新闻条目（左图右文） | title, image, summary, time, author |
| `book` | 6 | 图书封面 | image, title |
| `richMedia` | 12 | 富媒体大卡（带 rating/tags/actions） | image, title, subtitle, summary, rating, tags |
| `dashboard` | 6 | 数据卡片 | title, summary, image, color, textColor |
| `richContent` | 12 | 列表里内嵌正文/网页 | `content: { markdown \| html \| url }` |
| `label` | 4 | 小标签按钮，**必须配 `onClick`** | title, onClick |
| `chips` | 12 | 胶囊+多个 action 按钮 | title, actions[] |

### 典型写法

```js
// 影视海报墙
{
  title: '冰雪奇缘2',
  style: 'vod',
  image: 'https://...jpg',
  label: '喜剧,动画,冒险',
  summary: '剧情简介……',
  route: $route('detail', { id: '123' })
}

// 直播/短视频卡片
{
  title: '标题',
  style: 'live',
  image: 'https://...jpg',
  label: '英雄联盟',
  viewerCount: '1.1k',
  author: { name: 'UP主', avatar: 'https://...png' },
  route: $route('detail', { id })
}

// 分组标题
{ title: '样式：gallery', style: 'category' }

// 按钮标签（做筛选/切换用）
{ style: 'label', title: '切换线路', onClick() { this.refresh() } }

// 列表里直接嵌一段 markdown
{ style: 'richContent', title: 'README.md', content: { markdown: '# hi' } }
```

### 用 actions 做"分类切换"（社区插件最常见的技巧）

```js
let cid = 6
module.exports = {
  type: 'list',
  title: '分类',
  actions: [
    { title: '电影', onClick() { cid = 6;  this.title = '电影'; this.refresh() } },
    { title: '电视剧', onClick() { cid = 8; this.title = '电视剧'; this.refresh() } }
  ],
  async fetch({ page }) {
    const resp = await $http.get(`${endpoint}/vod/${cid}-${page || 1}.html`)
    ...
  }
}
```
> ⚠️ 用 `this.refresh()` 后列表会重新从第一页加载，因此**分类 id 要存在模块级变量**里。
> 注意模块级变量在同一 Node 实例内是**共享**的（多个同组件实例会互相影响），必要时用 `this.xxx` 存。

## 5. spanCount 栅格

横向空间被划成 **12 份**：

| spanCount | 效果 |
|---|---|
| 12 | 整行 |
| 6 | 一行 2 个 |
| 4 | 一行 3 个 |
| 3 | 一行 4 个 |

```js
{ title: 'x', style: 'live', spanCount: 12, image: '...' }
```

## 6. 搜索按钮

设置 `searchRoute` 后，页面右上角会出现搜索按钮，用户输入的关键词以 `args.keyword` 传给目标路由：

```js
// components/index.js
searchRoute: $route('search'),

// components/search.js
module.exports = {
  type: 'list',
  async fetch({ args, page }) {
    const keyword = args.keyword
    const resp = await $http.get(`${endpoint}/search?wd=${encodeURIComponent(keyword)}&page=${page || 1}`)
    return { index: 0, items: [...], nextPage: (page || 1) + 1 }
  }
}
```

若要让**全局搜索**（App 首页搜索框）找到本扩展，还需在 `package.json` 里声明：

```json
"contributes": { "search": "search" }
```
值为 `components/` 下的路径（不带 `.js`）。

## 7. 错误处理与空数据

```js
async fetch({ page }) {
  try {
    const resp = await $http.get(url, { timeout: 15000 })
    const items = parse(resp.data)
    if (!items.length) {
      return { items: [{ style: 'simple', title: '没有更多内容了' }], nextPage: null }
    }
    return { items, nextPage: (page || 1) + 1 }
  } catch (e) {
    this.error = '加载失败：' + e.message    // 页面显示错误态
    return { items: [] }
  }
}
```

## 8. 内置的一个小陷阱

`fetch` 中返回的 `items` 里若使用 `this.xxx`（如 `this.convert(v)`），
必须是 `fetch: async function () {}` 或对象方法简写形式；用**箭头函数**会导致 `this` 指向错误。

```js
// ❌
fetch: async ({args}) => { return { items: [this.convert()] } }
// ✅
async fetch({args}) { return { items: [this.convert()] } }
```