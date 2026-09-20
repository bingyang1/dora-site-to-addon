# 06 · 全局 API 全量签名

> 所有全局 API 都以 `$` 开头，**无需 `require`**，可直接使用。

---

## $dora —— 应用信息 & 实例配置

| 成员 | 签名 | 说明 |
|---|---|---|
| `mixin` | `mixin(object)` | 为**所有组件**继承一个对象（公共逻辑） |
| `addons` | `addons(): Promise<Addon[]>` | 获取所有已安装插件列表 |
| `install` | `install(url: string): Promise<Addon\|null>` | 安装扩展，url 形如 `npm://@dora.js/unsplash` |
| `uninstall` | `uninstall(uuid: string): boolean` | 卸载扩展 |
| `isInstalled` | `isInstalled(uuid: string): boolean` | 是否已安装 |
| `subscribe` | `subscribe(userid: string): Promise<boolean>` | 订阅开发者 |
| `isSubscribed` | `isSubscribed(userid: string): boolean` | 是否已订阅 |
| `versionCode` | `number` | 如 `10` |
| `versionName` | `string` | 如 `1.0.0` |
| `sendEvent` | `sendEvent(name, data)` | **在 WebView 页面中**使用，向组件发事件 |

```js
$dora.mixin({
  created() { console.log('component created') }
})
console.log($dora.versionName)
```

---

## $http —— 网络请求

**`$http` 就是 [axios](https://github.com/axios/axios) 实例**（部分版本别名 `$axios`，两者等价）。
官方文档原文：「将官方文档中的 `axios` 替换为 `$http` 即可」。

```js
// GET
const resp = await $http.get('https://api.example.com/posts', {
  params: { page: 1 },                       // → ?page=1
  headers: { 'User-Agent': 'Mozilla/5.0', Referer: 'https://example.com/' },
  timeout: 15000
})
console.log(resp.data, resp.status, resp.headers)

// POST JSON
const r2 = await $http.post('https://api.example.com/login', {
  username: 'a', password: 'b'
})

// POST 表单
const r3 = await $http.post('/user', new URLSearchParams({ a: 1 }), {
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
})

// 自定义 UA / 全局默认头
$http.defaults.headers.common['User-Agent'] = 'Mozilla/5.0 (Linux; Android 11) ...'
$http.defaults.headers.common['Referer'] = 'https://example.com/'

// 并发
const [a, b] = await Promise.all([$http.get(u1), $http.get(u2)])
```

**响应对象**：`{ data, status, statusText, headers, config, request }`

**常见坑**：
- 站点需要 `Referer` / `User-Agent` 才返回正常内容 → 全局设 `$http.defaults`
- 返回的是字符串而不是对象 → 服务端返回了 HTML，用 cheerio 解析，或加 `responseType: 'text'`
- 编码是 GBK 的老站 → 优先换成 GB2312 备用域名，或用 `iconv-lite`

---

## $ui —— 简单交互

| 方法 | 说明 |
|---|---|
| `$ui.alert(message: string)` | 弹窗（**不阻塞**） |
| `$ui.toast(message: string)` | toast（**不阻塞**） |
| `$ui.viewUser(userid: string)` | 查看 npm 用户 |
| `$ui.browser(url: string)` | 打开外部浏览器 |

```js
$ui.toast('已复制')
$ui.alert('出错了')
$ui.browser('https://dorajs.com')
```

---

## $input —— 用户输入（都返回 Promise）

| 方法 | 返回 | 参数 |
|---|---|---|
| `$input.confirm({title, message, okBtn})` | `Promise<boolean>` | 确认框 |
| `$input.text({title, hint, value, okBtn})` | `Promise<string\|null>` | 文本输入；null = 取消 |
| `$input.number({title, hint, value, okBtn})` | `Promise<number\|null>` | 数字输入（数字键盘） |
| `$input.password({title, hint, value, okBtn})` | `Promise<string\|null>` | 密码输入 |
| `$input.select({title, multiple, options, okBtn})` | `Promise<object\|null>` | 单选/多选；`options[].title` 用于显示 |
| `$input.prompt(...)` | 同 text | ⚠️ 已废弃，用 `text()` 代替 |

```js
// 确认
const ok = await $input.confirm({ title: '确认', message: '确定要删除吗？', okBtn: '删除' })
if (ok) { /* ... */ }

// 文本
const kw = await $input.text({ title: '输入关键词', hint: '如：斗罗大陆', value: '' })
if (kw) { $router.to($route('search', { keyword: kw })) }

// 单选
const opt = await $input.select({
  title: '选择线路',
  options: [{ title: '线路一', value: 'l1' }, { title: '线路二', value: 'l2' }]
})
if (opt) $ui.toast(opt.value)

// 多选
const opts = await $input.select({ title: '选择分类', multiple: true, options: [...] })
```

> ⚠️ **常见坑**：`$input.select` 的选项字段是 `title` + `value`（示例里返回值对象可能是整个 option）。
> `$input.select` 返回的**是 option 对象本身**，取 `.value` 或 `.title` 取决于你的写法。

---

## $prefs —— 配置项（对应 assets/prefs.json）

| 方法 | 说明 |
|---|---|
| `$prefs.get(key): any` | 读一个配置 |
| `$prefs.set(key, value)` | 写一个配置 |
| `$prefs.all(): object` | 取全部 |

```js
const quality = $prefs.get('quality') || '1080p'
$prefs.set('lastSource', 'line2')
```

---

## $storage —— 本地 KV 存储

| 方法 | 说明 |
|---|---|
| `$storage.put(key, value)` | 存入/覆盖 |
| `$storage.get(key): any` | 读取 |
| `$storage.all(): object` | 取全部（key-value） |
| `$storage.has(key): boolean` | 是否存在 |
| `$storage.remove(key)` | 删除 |

```js
$storage.put('history', [{ id: 1, t: 'name' }])
const h = $storage.get('history') || []
```

> 适合存登录态、播放历史、缓存过的分类数据。数据落在 `/data` 目录。

---

## $router —— 路由跳转

| 方法 | 说明 |
|---|---|
| `$router.to(route: Route)` | 跳转到新路由 |

```js
$router.to($route('detail', { id: 1 }))
$router.to($route('@image', { url: 'https://...jpg' }))
```

> ⚠️ `$route` 是**构建路由对象**的函数；`$router` 是**执行跳转**的。两者容易混淆。

---

## $route / $icon / $assets —— 资源与路由

### `$route(path: string|Url, args: object): Route`
```js
$route('posts/index')                        // 组件（相对 components/，不带 .js）
$route('detail', { id: 123 })                // 带参数
$route('@image', { url: 'https://...jpg' })  // 内置组件
$route('https://dorajs.com')                 // 外部 URL（会打开浏览器）
$route('market://details?id=com.linroid.dora') // 任意 schema
```

### `$icon(name: string, color: string|null): Url`
Material Design 图标。名字形如 `ic_settings` 或直接用 `movie`、`tv`、`face`、`search`、`person`、`more_vert` 等。
完整图标集见 https://github.com/google/material-design-icons

```js
$icon('ic_settings')
$icon('ic_settings', 'black')      // 语义化颜色
$icon('ic_settings', '#66ccff')    // 十六进制
```
预置颜色：`black, darkgray, gray, lightgray, white, red, green, blue, yellow, cyan, magenta, aqua, fuchsia, darkgrey, grey, lightgrey, lime, maroon, navy, olive, purple, silver, teal`

### `$assets(path: string): Url`
```js
$assets('cities.json')   // → assets/cities.json 的 URL
$assets('icon.svg')
```

---

## $permission —— 权限

| 方法 | 说明 |
|---|---|
| `$permission.request('sdcard')` | 申请权限（V1.8.1 起，目前只支持 `'sdcard'`） |

---

## 其他可用能力（运行时是完整 Node.js）

```js
const fs = require('fs')
fs.readFileSync('./README.md', { encoding: 'utf8' })     // ./ = /src（只读）
fs.writeFileSync('/data/cache.json', JSON.stringify(x))  // /data 可写

const crypto = require('crypto')
const { URL } = require('url')

console.log(process.versions)   // Node / V8 版本
```

npm 依赖：在 `package.json` 的 `dependencies` 中声明，Dora.js 安装扩展时自动安装，
在 `main.js` 里 `global.cheerio = require('cheerio')` 挂到全局供组件使用。