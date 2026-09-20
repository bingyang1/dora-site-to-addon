# 11 · API 实测对照表（文档之外的真实情况）

> 来源三处交叉验证：
> ① 官方文档（`reference/raw/`）
> ② **`@dora.js/types@1.0.4`** 的 `globals.d.ts`（官方发布的运行时类型定义）
> ③ 真实发布的插件源码（`@dora.js/api-demo@1.8.1`、`dorajs-twitch@1.4.6`、`dorajs-rss@1.0.8`、`dorajs-mzitu@1.4.0`）
>
> **冲突时以「实测可用」为准**，下文均标注了证据来源。

---

## 一、文档里没有、但真实可用的 API ⭐

| API | 签名 | 用途 | 来源 |
|---|---|---|---|
| `$prefs.open()` | `open(): void` | **直接打开本扩展的配置页** | types + api-demo |
| `$ui.showCode(code)` | `showCode(code: string)` | 用代码块样式展示长文本/JSON（比 toast 好用得多） | types + api-demo |
| `$ui.viewFile(path)` | `viewFile(path)` | 调用系统应用打开文件 | types + api-demo |
| `$clipboard` | `get/set .text` | **读写剪贴板** | types（`ClipboardModule`） |
| `$downloader` | `download(params \| string): number` | 下载文件（**实验性**） | types；api-demo 里被注释掉 |
| `$storage.dir` | `dir: string` | 本扩展数据目录路径（`/data`） | types |
| `$dora.packageName` | `string` | 当前扩展包名 | types |
| `$dora.locale` | `string` | 系统语言（i18n 可用它定默认语言） | types |
| `__dirname` | Node 全局 | 在扩展内可用，`__dirname + '/i18n'` 是标准写法 | twitch |
| `fs` / `path` / `crypto` / `URL` | Node 内置 | 直接用（沙箱内 `/src` 只读、`/data` 可写） | api-demo(file.js) / rss |

用法示例：

```js
$prefs.open()                                  // 打开设置页
$ui.showCode(JSON.stringify(addons, null, '  '))  // 展示对象
$ui.viewFile('/data/xxx.json')                 // 用系统应用打开
$clipboard.text = '要复制的内容'                // 写剪贴板
console.log($clipboard.text)                   // 读剪贴板
console.log($storage.dir, $dora.packageName, $dora.locale)
```

> ⚠️ `$downloader` 在官方示例里**被注释掉**，且 types 里叫 `download()`、api-demo 注释里叫 `add()`，
> 参数名一个写 `fileName` 一个写 `filename` —— **说明该 API 未定型，别用。**

---

## 二、文档说法 vs 真实情况（差异清单）

| 项 | 文档说法 | 真实情况 | 证据 |
|---|---|---|---|
| `$http` 别名 | `$http` 是 axios 别名 | 同时存在 `$axios`，两者等价；**官方 1.8.1 示例已统一改用 `$http`** | api-demo 1.8.0 用 `$axios` → 1.8.1 改成 `$http` |
| `Action` 图标字段 | `icon: Url` | types 里写的是 **`image`**；但真实代码（rss）用 `icon: $icon('add')` **也能生效** | types vs rss |
| `Route.type` | 文档列为字段之一 | types 里 `Route` **只有 `args` + `path`**（`type` 是组件自己的常量） | types |
| `fetch` 的 context | 有 `from`/`route`/`args`/`page` | types 里 `FetchContext` **只有 `args`/`route`/`page`**（`from` 仍可用但不保证） | types |
| `$input.select` 返回值 | 返回"选项对象" | 单选返回 **option 对象本身**；**`multiple: true` 时返回数组** | rss（`for (const option of selected)`） |
| `$input.select` 选项字段 | 文档示例用 `{id, title}` | 实际是**任意对象**，只有 `title` 用于显示；值可以叫 `value`/`url`/`uuid` 随你 | api-demo 用 `id`，rss 用 `value`，twitch 用 `uuid` |
| `$input.prompt` | 已废弃，用 `text()` | 真实代码里 **`prompt` 仍大量使用**（rss / api-demo），功能正常 | rss、api-demo |
| `ListItem.thumb` | 已被 `image` 取代 | types 里 **`thumb` 仍在 `Item` 定义中**（兼容层仍在） | types |
| `head`/`headers` | `headers` | 一致；注意别写成大写 `Headers` | — |
| `video.selectors[].name` | 部分文章写 `name` | **类型定义里只有 `title`**，用 `title` | types（`Selector`） |
| 空组件文件 | 未提及 | `components/` 下 0 字节文件**不会报错**，只是不会被调用 | api-demo 的 `storage.js` |
| `main.js` 的 exports | "属性会放到 global" | 实测：`module.exports = { i18n, config }` 后，组件里**可直接写 `i18n.__()`**（无需 `global.` 前缀） | twitch |
| `components/` 之外 | 文档只提到 `scripts/` 存注入脚本 | **`scripts/` 实际是公共模块目录**，`require('../scripts/const')` 是常见用法 | mzitu |
| `contributes.search` | 填组件路径 | 也接受 **`null`**（显式表示不提供搜索） | rss、mzitu |

### `Item` 完整字段（来自 types，含文档未列出的）

```ts
{
  id?, title?, style?, spanCount?, subtitle?, summary?,
  thumb?, image?,                 // thumb 为兼容字段
  route?, author?, viewerCount?, time?, label?,
  color?, aspect?,                // 图片主色 / 宽高比（gallery 用）
  action?, actions?, tags?, rating?,
  onClick?, onLongClick?
}
```
- `rating: { score?, total?, text }`
- `tags: Action[]`（richMedia 样式用）
- `aspect = width / height`（gallery 瀑布流防抖动，unsplash 示例有示范）

### `Selector` 完整结构（types）

```ts
{
  title: string,
  select?: number,
  options: [{ title: string, ...任意字段 }],
  onSelect: (option) => void
}
```

---

## 三、`Component` 内部结构（types 里的实现细节）

```ts
class Component {
  readonly type: string
  readonly route: Route
  readonly hooks: object
  readonly bridge: any
  readonly args: object
  readonly fields: Set<string>
  readonly properties: any
  constructor(route: Route, bridge: any)
  refresh(): void
  fetch(context: FetchContext): Promise<object | []>
  _doFetch(context: FetchContext): Promise<void>
  _callHook(name: string): void
  _attach(mixin: object): void
}
```

解读（对写代码有用的部分）：
- `fields: Set<string>` —— **只有声明过的字段才会被同步到原生 UI**。
  意思是 `fetch()` 返回的属性名如果是官方字段（`title`/`items`/`url`…）才会生效；
  **自己乱造的字段不会被渲染**，但会挂在 `this` 上可供你代码内部使用。
- `_doFetch` 是内部方法，说明 `fetch()` 的返回值由框架接管后写回 `this`，所以：
  **`fetch` 返回什么，`this` 上就有什么。**
- `_attach(mixin)` 对应 `$dora.mixin()`。
- `refresh()` 就是重新走一遍 `beforeCreate → fetch → created`。

---

## 四、`Route` / `Addon` 等实体结构（types）

```ts
Route  { args: object, path: string }
Addon  { id: number, uuid: string, label: string, main: string }
Author { name, avatar?, route?, onClick? }
Action { title, route?, image?, onClick? }
Danmaku{ content, author?, color? }
SystemUiOptions { statusBar, toolbar?, navigationBar? }
```

> `$dora.addons()` 返回的每个 Addon 里，实际还能取到 `displayName`（api-demo 的卸载列表演示里用了
> `addon.displayName` 和 `addon.uuid`）。

---

## 五、写代码时的"以谁为准"决策树

```
有冲突时：
  ├─ 是"某个字段名/结构"的疑问？
  │     → 以 @dora.js/types 为准（它是运行时类型定义，直接对应实现）
  ├─ 是"某 API 存不存在、怎么调"的疑问？
  │     → 先搜 reference/raw/ 文档；没有 → 查 types；还没有 → 下载一个真实插件 grep 一下
  └─ 是"行为/时序"的疑问（生命周期、分页、嵌套）？
        → 以 @dora.js/api-demo@1.8.1 的可运行示例为准
```

**实操建议**：
1. 只用**文档 + types 双重确认过**的 API 写核心功能
2. 文档外 API（`$clipboard`/`$ui.showCode` 等）可以用于**增强体验**，但要写 `try/catch` 兜底：
   ```js
   try { $ui.showCode(text) } catch (e) { $ui.alert(text) }
   ```
3. **绝对不要用** `$downloader`（未定型）

## 六、附：类型定义原文位置

下载后可直接查看（内容短小，5 分钟能读完，强烈建议读一遍）：

```bash
curl -sL "https://registry.npmjs.org/@dora.js/types/-/types-1.0.4.tgz" | tar -xz -C /tmp/t
cat /tmp/t/package/globals.d.ts      # ← 全部全局 API 的类型定义
cat /tmp/t/package/index.d.ts
```

本技能已将其要点整理为上文，原文可随时重新下载。