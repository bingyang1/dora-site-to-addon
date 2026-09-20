# 07 · 通用数据结构与路由

## Url

描述资源地址，可以是：

1. 网络地址：`'https://example.com/icon.png'`
2. Dora.js 内置资源：`$icon(name[, color])`
3. 扩展 assets 资源：`$assets(path)`

三者**在使用处可以混用**（`image`、`avatar`、`icon` 等字段都接受 `Url`）。

## Route

| 字段 | 类型 | 说明 |
|---|---|---|
| `type` | `string` | 组件类型 |
| `path` | `string` | 组件路径，**相对 `components/`**，不带 `.js`。如 `components/user/profile.js` → `user/profile` |
| `args` | `object` | 传入的参数 |

构建方式：始终用 `$route(path, args)`，**不要手写字面量对象**。

```js
$route('user/profile', { uid: 1 })
$route('@video', { url: 'https://x.com/a.m3u8' })
$route('https://example.com')
```

## Author

| 字段 | 类型 | 说明 |
|---|---|---|
| `name` | `string` | 作者姓名 |
| `avatar` | `string\|null` | 头像 URL |
| `route` | `string\|null` | 点击头像/姓名跳转的路由 |

```js
author: {
  name: 'UP主名',
  avatar: 'https://...png',
  route: $route('https://space.bilibili.com/xxx')
}
```

## Action

支持点击操作的菜单项/按钮。用于组件的 `actions`，以及 `richMedia` / `chips` 条目内的 `actions`、`tags`。

| 字段 | 类型 | 说明 |
|---|---|---|
| `title` | `string` | 标题 |
| `onClick` | `function\|null` | 点击回调 |
| `route` | `string\|null` | 跳转路由（`onClick` 优先） |
| `icon` | `Url\|null` | 图标 |

```js
actions: [
  { title: '刷新', onClick() { this.refresh() } },
  { title: '官网', route: $route('https://example.com') },
  { title: '设置', icon: $icon('settings'), onClick: async () => { /* ... */ } }
]
```

> `actions` 里的回调注意 `this`：用 `onClick() {}`（方法简写）时 `this` 是组件实例；
> 用箭头函数时 `this` 是定义处的 `this`（模块级即为 `undefined`/global）。

## fetch 上下文 (context)

| 字段 | 类型 | 说明 |
|---|---|---|
| `from` | `Route` | 来源路由 |
| `route` | `Route` | 当前路由 |
| `args` | `object` | `route.args` 别名 |
| `page` | `any?` | 分页参数（仅 list） |

## 进度 / 收藏 相关

- `id: string` —— 资源唯一标识，默认 `this.route.args.toString()`，底层用 `route.path + id` 作唯一键
- `allowBookmark: true` —— 允许收藏（list 组件常用）

```js
module.exports = {
  type: 'list',
  allowBookmark: true,
  id: this && this.args && this.args.id    // 通常无需手写
}
```

## 搜索门面（package.json）

```json
"contributes": {
  "search": "search"
}
```
对应 `components/search.js`，实现方式与普通 list 相同，通过 `args.keyword` 取关键词：

```js
module.exports = {
  async fetch({ page, args }) {
    console.log(args.keyword)
  }
}
```

## 后台任务（package.json，进阶）

```json
"contributes": {
  "tasks": {
    "get_ip": { "icon": "assets/ip.svg", "label": "Sample: 获取外网 IP" }
  }
}
```
对应 `tasks/get_ip.js`：

```js
module.exports = {
  async run() {
    const resp = await $http.get('https://api.ipify.org?format=json')
    $ui.toast(`IP: ${resp.data.ip}`)
  }
}
```
> 文档中任务接口不完整，慎用；不确定时不要写。