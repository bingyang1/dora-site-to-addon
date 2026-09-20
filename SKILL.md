---
name: dora-site-to-addon
description: 把任意网站（视频站/图片站/文章站/漫画站/API）封装成 Dora.js 扩展（.dora 包）。当用户说「把这个网站做成 Dora 插件」「写个 dora 扩展」「采集这个站点」「给这个链接做个 addon」时使用。内含 Dora.js 官方文档全量镜像、可复制组件模板、真实可跑示例与一键打包脚本。
---

# Dora.js 站点转扩展（Site → Addon）

## 这个技能解决什么

输入：**一个站点 URL（可选：分类页/详情页/搜索页）**
输出：**一个能在 Dora.js 里安装运行的 `.dora` 扩展包 + 源码工程目录**

Dora.js 的核心哲学：**用简单的 JavaScript 为原生界面提供数据**。
👉 你**不需要写界面**。你只需要告诉它 `type: 'list'` 并返回 `items` 数组，它就渲染成列表；
返回 `{ url: 'xx.m3u8' }` 就是播放器；返回 `{ content: { markdown } }` 就是阅读器。

所以「写一个 Dora 项目」= **把网页数据映射成 Dora 的数据结构**。

---

## 0. 30 秒速览

```
my-addon/
├── package.json        # 元信息 + 依赖（cheerio / axios 等）
├── main.js             # 入口，全局 require、初始化（只跑一次）
├── assets/
│   ├── icon.png        # 图标
│   └── prefs.json      # 配置界面（账号/画质/源地址…）
├── components/         # 每个文件 = 一个原生页面
│   ├── index.js        # 必填！点击图标进入的第一个页面
│   ├── list.js         # 列表页
│   ├── detail.js       # 详情页（可嵌套 video/article/image）
│   └── search.js       # 全局搜索入口
└── scripts/            # 注入 WebView 的 JS
```

打包：`tar -czf xxx.dora package/` —— **`.dora` 本质就是 tar.gz**。

---

## 1. 五条铁律（违反必错）

1. **入口文件名固定**：点击扩展图标永远先执行 `components/index.js`（其 `path` 为 `index`）。
2. **组件只用 `module.exports = { ... }`** 导出普通对象，不是 class，不能 `new`。
3. **数据靠 `fetch()` 返回**：返回对象 → 属性自动赋给 `this`；返回数组 → 直接当 `items`。
4. **列表分页靠 `nextPage`**：`fetch({ page })` 里 `page` 就是上一次返回的 `nextPage`，返回 `null` 表示没有更多。
5. **路由靠 `$route('组件路径', args)`**：路径**相对 `components/` 目录且不带 `.js`**。
   `components/xj/detail.js` → `$route('xj/detail', {...})`。

补充：
- 内置组件可以直接用 `@` 前缀调用：`$route('@video', {url})`、`$route('@image', {url})`、`$route('@article', ...)`。**自己不用写视频播放器/看图器。**
- **`@` 对布局组件同样有效，可以"凭空嵌套"而不建文件**：
  `$route('@bottomTab', { items: [ {title:'A', route: $route('a')} ] })`（官方 api-demo 的 nested.js 示范）
- `scripts/` 目录**不只是 WebView 注入脚本**，它是**公共模块目录**：`require('../scripts/const')` 是常见用法。
- 全局 API 都以 `$` 开头，无需 require：`$http`/`$axios`、`$ui`、`$input`、`$route`、`$router`、`$prefs`、`$storage`、`$icon`、`$assets`。
  文档外还有 `$clipboard`、`$ui.showCode()`、`$ui.viewFile()`、`$prefs.open()`（见 `reference/11-api-reality-check.md`）。

---

## 2. 工作流（严格按顺序执行）

### Step 1 — 站点侦察
用 `visit_web` / `http_request` 抓首页 HTML，判断站点"配方"：

| 特征 | 站点类型 | 组件方案 |
|---|---|---|
| HTML 里有 `div.stui-vodlist__box` / `mac-vodlist` | 苹果CMS(maccms) VOD 站 | list + detail(video) + search |
| 有 `/vodsearch/----wq---.html` 或 `/index.php/vod/search.html` | 同上，有搜索 | 加 `contributes.search` |
| 纯 `<script>window.__DATA__=` JSON | SPA/接口站 | 直接抓 API，`$http.get` 拿 JSON |
| 分页是 `?page=2` / `/{id}-{page}.html` | 常规分页 | `nextPage` |
| 瀑布流图片 | 图片站 | `style:'gallery'` + `$route('@image')` |
| 正文长文 | 文章站 | `type:'article'` |
| 反爬（需 cookie/签名/token） | 加密站 | 先看有没有免签接口；有 WebView 才用 `type:'webview'` |

**关键动作**：按 F12 / 用 `http_request` 打开详情页，**优先找 XHR/api 接口**（返回 JSON 比写 cheerio 选择器稳定 10 倍）。找不到才降级为 HTML + cheerio 解析。

### Step 2 — 定义数据流
画出「页面 → 组件」映射，例如：

```
index.js (bottomTab)  ─┬─→ list.js  (分类列表, 分页)
                       ├─→ search.js (搜索)
                       └─→ detail.js (详情, type:video)
```
每个节点写上：路由参数有哪些、数据从哪个 URL 来、字段怎么映射。

### Step 3 — 生成工程
优先直接用脚手架：
```bash
sh scripts/new_addon.sh <输出目录> "<显示名称>" "<uuid>"
```
生成后按下表填空。

### Step 4 — 写代码
从 `templates/addon/` 复制对应文件，或参考 `reference/08-site-recipes.md` 的现成配方。
**必须遵守的映射规范见第 3 节。**

### Step 5 — 自检
```bash
python3 scripts/check_addon.py <工程目录>
node scripts/lint_js.js <工程目录>     # 语法检查（可选）
```
逐条对照 SKILL.md 第 5 节清单。

### Step 6 — 打包交付
```bash
sh scripts/build_dora.sh <工程目录>    # 输出 /sdcard/Download/dora/xxx-v1.0.0.dora
```
不要用 zip 打前缀 `package/` 之外的东西，也不要包含 `node_modules`。

---

## 3. 数据映射对照表（最核心的一页）

### list 组件的 item
```js
{
  title: '标题',            // 必须有
  style: 'simple',          // simple|live|vod|icon|gallery|article|book|richMedia|category|dashboard|richContent|label|chips
  image: 'https://...jpg',  // 缩略图
  summary: '简介',
  label: '喜剧,动画',        // vod/live 的角标
  viewerCount: '1.1k',      // live 的播放量
  time: '2024-01-01',       // article 的时间
  spanCount: 6,             // 12 栅格，占多少（vod 默认 6）
  author: { name:'xx', avatar:'https://...' },
  route: $route('detail', { id: '1' }),   // 点击跳转
  onClick() { ... }                        // 优先级高于 route
}
```
### 站点数据 → Dora 字段的常见换算
| 网页里 | 映射为 |
|---|---|
| `<img src>` / `<img data-original>` / style 里的 `url(...)` | `image` |
| `<a href="/detail/1.html">` | `route: $route('detail', { id:'1' })` |
| 播放量 "1.2万播放" | `viewerCount` 或 `label` |
| 分类名 | `label` |
| 简介段落 | `summary` |
| 详情页 html 正文 | `type:'article'` 的 `content.html` 或 `content.markdown` |
| `.m3u8` / `.mp4` | `type:'video'` 的 `url` |

### 路由参数
`$route('detail', { id })` → 目标组件里 `fetch({ args })` 拿到 `args.id`。

---

## 4. 常用 API 速查

| API | 用途 |
|---|---|
| `$http` / `$axios` | axios 实例，`await $http.get(url, {headers})`，返回 `{data, status, headers}` |
| `$route(path, args)` | 创建路由对象；支持 URL：`$route('https://a.com')`（外部浏览器）、`$route('market://...')` |
| `$router.to(route)` | 主动跳转 |
| `$ui.toast(msg)` / `$ui.alert(msg)` / `$ui.browser(url)` | 提示/弹窗/外链 |
| `$input.text/confirm/number/password/select` | 都是 `await` 返回 Promise |
| `$prefs.get(k)` / `.set(k,v)` / `.all()` | 读 `assets/prefs.json` 定义的配置 |
| `$storage.put/get/all/has/remove` | 本地 KV 存储（登录态、缓存） |
| `$icon('face', 'red')` | Material 图标 URL，用于 `image` |
| `$assets('x.json')` | `assets/` 目录资源 URL |
| `$prefs.open()` | **直接打开本扩展配置页**（文档未记载） |
| `$ui.showCode(str)` | 以代码块展示长文本/JSON，调试神器（文档未记载） |
| `$clipboard.text` | 读写剪贴板（文档未记载） |
| `this.refresh()` / `this.finish()` / `this.title = x` | 刷新 / 关闭 / 改标题 |
| `this.append(items)` | 向列表追加数据（配合手动分页） |
| `this.error = 'xxx'` | 显示错误态 |

> `$input.select` 单选返回 option 对象；**`multiple: true` 时返回数组**。
> option 只要求有 `title`（用于显示），其余字段随你定义（`{value}`/`{url}`/`{uuid}` 都可以）。

---

## 5. 交付前自检清单

- [ ] `components/index.js` 存在，且 `module.exports` 有 `type`
- [ ] `package.json` 有 `name / displayName / version / uuid / main / icon`，`uuid` 是新生成的 v4
- [ ] **所有网络请求都在 `fetch()` 里 await**，没有把 Promise 直接塞进返回对象
- [ ] 分页：`fetch({page})` 里 `page ?? 1`，返回 `nextPage = page + 1` 或 `null`
- [ ] `$route` 路径与 `components/` 下真实文件一一对应，**无 `.js` 后缀**
- [ ] 列表首屏用 `return { items }` 或 `return [...]`，不要 `items.push` 到模块级变量后忘记返回
- [ ] 图片/播放地址都是**绝对 URL**（相对地址要手动补域名）
- [ ] `try/catch` 包住解析逻辑，出错时 `this.error = e.message`
- [ ] 需要登录/密钥的站点，参数放 `prefs.json` 而不是硬编码
- [ ] 打包后 `tar -tzf xxx.dora | head` 能看到 `package/package.json`
- [ ] 无 `node_modules`、无 `.git`、无 `_work` 临时目录

---

## 6. 目录导览

| 路径 | 内容 |
|---|---|
| `reference/01-project-structure.md` | 工程结构 / package.json / prefs.json / main.js / 虚拟文件系统 |
| `reference/02-components-core.md` | 组件基础、生命周期、fetch 返回值、通用成员 |
| `reference/03-list-component.md` | list 组件、全部分页与条目样式（带截图说明） |
| `reference/04-media-components.md` | video / audio / image / article / webview 组件全参数 |
| `reference/05-layout-components.md` | topTab / bottomTab / drawer 布局组件 |
| `reference/06-global-api.md` | `$dora $http $ui $input $prefs $storage $router` 全量签名 |
| `reference/07-struct-and-route.md` | Author / Action / Url / Route 通用数据结构 |
| `reference/08-site-recipes.md` | **实战配方**：maccms视频站 / JSON接口站 / 图片站 / 文章站 / 需登录站 |
| `reference/09-pitfalls.md` | 常见坑与排错手册 |
| `reference/10-npm-ecosystem.md` | **npm 生态调研**：137 个真实插件、6 个精选案例（i18n/直播间/工程化分层） |
| `reference/11-api-reality-check.md` | **文档外 API 实测表**：`$clipboard`、`$prefs.open()` 等 + 文档与实现的差异清单 |
| `reference/types/globals.d.ts` | **官方运行时类型定义原文**（比文档更权威的字段级真相） |
| `reference/raw/` | Dora.js **官方文档原文镜像**（37 篇 markdown，离线可查） |
| `templates/addon/` | 可直接复制的工程骨架（含注释） |
| `examples/` | 真实可跑的完整示例（demo-bing-wallpaper / api_demo / readhub / unsplash / bing_wallpaper） |
| `scripts/` | `new_addon.sh` 脚手架、`build_dora.sh` 打包、`check_addon.py` 校验、`probe_site.sh` 侦察 |

## 6.5 遇到没见过的问题时，去 npm 抄作业

npm 上有 **137 个真实发布的 Dora.js 插件**，覆盖直播、影视、漫画、音频、RSS、网盘等全部品类——
这是比文档更实用的教材（`reference/10-npm-ecosystem.md` 有完整清单和案例拆解）：

```bash
# 搜同类插件
curl -s "https://registry.npmjs.org/-/v1/search?text=dora.js&size=250" | head -c 2000

# 下载并拆包（npm 包内层就是 package/，与 .dora 同构）
curl -sL "https://registry.npmjs.org/dorajs-twitch/-/dorajs-twitch-1.4.6.tgz" | tar -xz -C /tmp/study
```

- 想写**直播** → 看 `dorajs-twitch`（selectors / 弹幕 WebSocket / i18n）
- 想写**工程化分层** → 看 `dorajs-rss`（data / dao / service / util 四层）
- 想看**官方全 API** → 看 `@dora.js/api-demo@1.8.1`
- 注意：多为 `UNLICENSED`，**参考思路可以，别整段复制**；抄 `package.json` 必须换 `uuid`。

## 7. 遇到不确定的 API 时

**不要凭记忆编造**。按以下优先级查证：
1. `reference/types/globals.d.ts` —— **官方运行时类型定义**，字段级最权威
2. `reference/raw/` 里的官方原文（讲解最全）
3. `reference/11-api-reality-check.md` —— 文档与实现的冲突清单
4. `examples/` 里的真实代码
5. **npm 上 137 个真实插件**（`reference/10-npm-ecosystem.md`）：搜同类站点 → 下载 → 拆包 → 读
6. 本地社区插件：`/sdcard/Download/dora/*.dora`（拆包即可看源码）

```bash
# 拆开任意 .dora 看别人的实现
mkdir /tmp/x && tar -xzf /sdcard/Download/dora/视频模板-v1.0.0.dora -C /tmp/x && find /tmp/x -type f

# 从 npm 找一个同类插件来抄思路
curl -sL "https://registry.npmjs.org/dorajs-twitch/-/dorajs-twitch-1.4.6.tgz" | tar -xz -C /tmp/x
```