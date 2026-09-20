# 02 · 组件基础与生命周期

## 1. 组件是什么

- 一个组件文件 = **一个原生页面**。打开新页面 → 创建新组件实例；页面销毁 → 实例销毁。
- 组件文件通过 `module.exports` 导出一个**普通对象**（不是 class，不能 `new`）。
- 点击扩展图标时，Dora.js 首先启动 **`components/index.js`**（path = `index`）。

最小可用组件：

```js
module.exports = {
  type: 'list',
  async fetch({ page }) {
    let resp = await $http.get('https://api.example.com/list?page=' + (page || 1))
    return {
      nextPage: (page || 1) + 1,
      items: resp.data.data.map(v => ({ title: v.title, style: 'simple' }))
    }
  }
}
```

## 2. 所有组件都支持的属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `type` | `string` | **常量**，组件类型，决定加载哪套 API |
| `id` | `string` | 资源唯一标识（仅限当前组件内），用于收藏/进度恢复。默认 `this.route.args.toString()` |
| `title` | `string` | 页面标题 |
| `subtitle` | `string\|null` | 页面子标题 |
| `actions` | `Action[]` | 顶部菜单项（右上角），见 `07-struct-and-route.md` |
| `author` | `Author` | 作者信息 |
| `summary` | `string` | 概要描述 |
| `image` | `Url\|null` | 缩略图/图标 |
| `error` | `string\|null` | 当前错误消息；`refresh()` 会把它置回 `null` |
| `searchRoute` | `Route\|null` | 不为 null 时页面显示搜索按钮 |
| `fetch(context)` | `function` | 获取数据（核心） |

其他常见但文档未列全的属性（社区插件与官方示例中大量使用）：
`translucent: true`（半透明沉浸式标题栏）、`allowBookmark: true`（允许收藏）、
`style`（列表整体样式）、`headers`（video/audio 的请求头）。

## 3. 支持的类型

| type | 用途 | 文档状态 |
|---|---|---|
| `list` | 目录/列表 | ✅ |
| `video` | 视频播放器 | ✅ |
| `audio` | 音频播放器 | ✅ |
| `article` | 文章阅读器 | ✅ |
| `image` | 图片查看器（可保存/设壁纸/分享） | ✅ |
| `webview` | 内置浏览器 | ✅ |
| `topTab` | 顶部 tab 布局 | ✅ |
| `bottomTab` | 底部 tab 布局 | ✅ |
| `drawer` | 抽屉菜单布局 | ✅ |
| `book` | 图书 | ❌ 未完善 |
| `cartoon` | 漫画 | ❌ 未完善 |
| `compose` | 编辑器 | ❌ 未完善 |

> 💡 内置实现可用 `@` 前缀直接路由：`$route('@image', { url, title })`、
> `$route('@video', { url })`、`$route('@article', { content })`。
> 其内置 `fetch({ args }) { return args }` —— 也就是说**传进去的 args 就是它的 fetch 返回值**。
> 这是"零代码页面"的秘密武器。

## 4. 组件实例通用接口

| 成员 | 说明 |
|---|---|
| `this.route` | 当前组件路由（`Route` 对象） |
| `this.args` | `route.args` 的别名 |
| `this.from` | 来源路由；首页时为 `null` |
| `this.refresh()` | 刷新当前页面（重新 fetch） |
| `this.finish()` | 结束当前组件页面 |

## 5. fetch(context)

`context` 的属性：

| 属性 | 说明 |
|---|---|
| `route` | 当前路由 |
| `from` | 来源路由 |
| `args` | `route.args` 别名（常用） |
| `page` | 分页参数（**只有 list 有**），等于 `this.nextPage`，为 `null`/`undefined` 表示首次加载或刷新 |

三种返回方式：

```js
// 1) 直接返回对象（推荐）—— 属性会被赋给 this
async fetch({ args }) {
  return { title: '标题', items: [...], nextPage: 2 }
}

// 2) 返回 Promise
fetch() {
  return $http.get(url).then(res => ({ items: res.data }))
}

// 3) list 组件可以只返回数组（等价于设置 items）
fetch() {
  return [{ title: 'A' }, { title: 'B' }]
}
```

推荐用解构 + async/await：

```js
async fetch({ args, page }) { ... }
```

## 6. 生命周期钩子

| 钩子 | 时机 |
|---|---|
| `beforeCreate()` | 获取数据前（`fetch()` 之前）。常用于先设置 `this.title` |
| `created()` | 数据获取完成（`fetch()` 之后） |
| `activated()` | 页面可见（前台） |
| `inactivated()` | 页面不可见（退后台或打开新页面） |
| `beforeDestroy()` | 销毁前 |
| `destroyed()` | 已销毁 |

```js
module.exports = {
  beforeCreate() { this.title = 'Hello World' },
  async fetch() { /* ... */ },
  created() { console.log('loaded', this.items && this.items.length) },
  destroyed() { clearInterval(this.timer) }   // 清理定时器/任务
}
```

> ⚠️ 在 `created()` 里 `this.items` 才是最终数据；在 `beforeCreate()` 里拿不到。

## 7. 全局混入（给所有组件加公共逻辑）

```js
// main.js
$dora.mixin({
  beforeCreate() {
    this.headers = { 'User-Agent': 'Mozilla/5.0 ...', Referer: endpoint + '/' }
  },
  created() {
    console.log('component created')
  }
})
```

## 8. 添加一个新组件

`components/` 下新建 `.js` 文件即可，路由路径 = 相对 `components/` 的路径去掉 `.js`：

| 文件 | 路由写法 |
|---|---|
| `components/index.js` | `$route('index')`（图标入口，默认启动） |
| `components/list.js` | `$route('list')` |
| `components/xj/detail.js` | `$route('xj/detail', { id })` |

手机端操作：面包屑图标 → 打开抽屉 → `components` 文件夹 → `+` → 添加文件 → 输入文件名。