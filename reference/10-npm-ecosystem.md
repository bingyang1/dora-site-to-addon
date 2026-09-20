# 10 · npm 生态调研（137 个真实插件）

> 数据来源：npm registry 搜索 `dora.js`，共 **137 个已发布插件**（2026-09 快照）。
> 结论先行：**Dora.js 社区留下了大量可读的真实代码，是最好的教材。**

---

## 1. 怎么搜、怎么下、怎么看

```bash
# ① 搜索（registry 搜索 API，无需 key）
curl -s "https://registry.npmjs.org/-/v1/search?text=dora.js&size=250" | python3 -m json.tool | less

# 只搜官方/特定 scope
curl -s "https://registry.npmjs.org/-/v1/search?text=scope:dora.js&size=100"

# ② 看某个包的元信息（含依赖、main、版本）
curl -s "https://registry.npmjs.org/dorajs-twitch/latest"

# ③ 下载并拆包（npm tarball 内层就是 package/，与 .dora 完全同构）
curl -sL -o pkg.tgz "https://registry.npmjs.org/dorajs-twitch/-/dorajs-twitch-1.4.6.tgz"
mkdir pkg && tar -xzf pkg.tgz -C pkg && find pkg -type f
```

**关键点**：npm 上的包解压后就是 `package/` 目录 —— **和 `.dora` 压缩包内容一模一样**。
所以「学别人怎么写」和「自己打包」用的是同一套结构。

> 国内可换镜像：`https://registry.npmmirror.com/`（对应 `-v1/search` 不一定可用，
> 元信息接口 `registry.npmmirror.com/<pkg>/latest` 可用）

---

## 2. 生态全景（137 个包的分类）

| 类别 | 约数 | 代表包 |
|---|---|---|
| 影视聚合站（第三方站点采集） | ~35 | `dorajs-zi-yuan-cai-ji`、`dorajs-die-ying-shi-jie`、`dorajs-du-bo-ku` |
| 直播平台 | ~14 | `dorajs-twitch`、`dorajs-huya`、`dorajs-douyu`、`dorajs-bililive`、`dorajs-livetv` |
| 工具 / 管理 | ~13 | `dorajs-index`、`jsfun-index`、`dorajs-backup`、`dorajs-check`、`dorajs-listhelper` |
| 图片 / 写真 / 壁纸 | ~10 | `dorajs-mzitu`、`dorajs-huaban`、`dorajs-polayoutu`、`dorajs-pixiv`、`@dora.js/bing-wallpaper` |
| 音频 / 音乐 | ~8 | `dorajs-ximalaya`、`dorajs-wang-yi-yunmusic`、`dorajs-li-zhi`、`dorajs-mao-erfm` |
| 网盘 / 下载 | ~8 | `dorajs-onedrive`、`dorajs-ariang`、`dorajs-zhong-zi-sou-suo`、`dorajs-coolapk` |
| 资讯 / RSS | ~7 | `dorajs-rss`、`dorajs-ithome-rss`、`dorajs-wlor-rssreader`、`dorajs-hubonews` |
| 阅读 / 书籍 | ~6 | `dorajs-99csw`、`dorajs-epub-reader`、`dorajs-ban-yue-shu-wu`、`dorajs-search-book` |
| 漫画 | ~5 | `dorajs-bainianmh`、`dorajs-one-man-hua`、`dorajs-man-hua-bei`、`dorajs-zhi-yin-man-ke` |
| 签到 / 自动化 | ~4 | `dorajs-jing-dongck`、`getjdck`、`dorajs-kao-qin-bu` |
| 官方包 | ~6 | `@dora.js/api-demo`、`@dora.js/types`、`@dora.js/unsplash`、`@dora.js/readhub`、`@dora.js/bing-wallpaper` |

**时间线**：绝大多数发布于 **2020-03 ~ 2021-05**（Dora.js 1.7/1.8 时代）。
最晚仍在维护的是 `dorajs-mzitu@1.4.0`（**2025-02**，备注"时隔多年再次修复一下"）。
**推论**：写扩展时不要依赖任何"最近才可能修好"的第三方接口；站点随时会挂，把源地址做成可配置更稳。

---

## 3. 精选案例：6 个包教会了你什么

> 以下**只记录技法**（代码为本文重写，非原包源码）。原包许可证多为 UNLICENSED，请勿直接再分发其代码。

### 案例 1 · `@dora.js/api-demo@1.8.1` —— 官方示例扩展（**最该读的包**）

| 学到 | 位置 |
|---|---|
| `bottomTab` 可以用**静态 `items`**（不写 fetch） | `components/index.js` |
| **`$route('@bottomTab', { items: [...] })` 可以凭空嵌套布局组件**，不用建文件 | `components/types/nested.js` |
| `$permission.request('sdcard')` 可以放在 **`async beforeCreate()`** 里 | `components/file.js` |
| `$ui.viewFile(path)` 用系统应用打开文件 | `components/file.js` |
| `fs.readdirSync` + `path.resolve` + `fs.statSync` 做文件浏览器 | `components/file.js` |
| `$ui.showCode(JSON.stringify(obj, null, '  '))` 用来展示对象 | `components/api.js` |
| `$prefs.open()` 打开配置页 | `components/api.js` |
| `article` 最简写法只要 `content: { text: 'Hello world!' }` | `components/empty.js` |
| 空文件（0 字节）在 `components/` 里不会报错，只是不会被调用 | `components/storage.js` |

> `nested.js` 那段是"零文件嵌套布局"的官方示范：
> ```js
> module.exports = {
>   type: 'drawer',
>   items: [{
>     title: '-> bottomTab > topTab',
>     route: $route('@bottomTab', {
>       items: [
>         { title: 'topTab', route: $route('types/topTab'), image: $icon('favorite_border') },
>         { title: 'Tab 2',  route: $route('empty'),       image: $icon('feedback') }
>       ]
>     })
>   }]
> }
> ```

### 案例 2 · `dorajs-twitch@1.4.6` —— 直播站（复杂度最高）

这个包把"直播"这件难事拆得很干净，值得整包通读：

| 技法 | 说明 |
|---|---|
| **i18n 国际化** | `require('i18n')` + `directory: __dirname + '/i18n'`，`i18n.__('key')` |
| **`__dirname` 可用** | 说明扩展内是标准 CommonJS 环境 |
| **`selectors` 真实用法** | option 上直接挂业务字段（`option.url`），`onSelect: o => { this.url = o.url }` |
| **画质记忆** | `$storage.put('quaility_channel', option.title)`，下次 `getSelect()` 里还原 |
| **弹幕 = WebSocket** | `startDanmaku()` 里连 `ws://` IRC，`stopDanmaku()` 里 close + clearInterval |
| **`validateStatus`** | 让 axios 不因 403/404 抛异常，自己根据 `resp.status` 提示"未开播/无权限" |
| **历史记录 LRU** | `new LRU(n)` + `lru.load($storage.get(k))` / `lru.dump()` |
| **共享配置对象** | `main.js` 的 `module.exports = { config, history, i18n, ... }`，组件里**直接用 `config`、`history`** |

关键示意（重写版）：

```js
// main.js
const i18n = require('i18n')
i18n.configure({ defaultLocale: 'en-US', directory: __dirname + '/i18n' })
i18n.setLocale($prefs.get('Accept-Language') || 'en-US')

const config = { headers: { 'Client-Id': $prefs.get('Client-Id') } }

module.exports = { config, i18n }     // → 组件里可直接用 config / i18n
```

```js
// components/video.js
module.exports = {
  type: 'video',
  async fetch({ args }) {
    const resp = await $http.get(m3u8Url, {
      validateStatus: s => (s >= 200 && s < 300) || s === 403 || s === 404
    })
    if (resp.status === 403) { $ui.toast(i18n.__('noPermission')); return }
    const options = this.getOptions(resp.data)       // 解析 m3u8 里的 #EXT-X-MEDIA
    const select = this.getSelect(options, 'q_ch')
    return {
      url: options[select].url,
      isLive: true,
      selectors: [{
        title: i18n.__('quaility'),
        select: select,
        onSelect: option => { this.url = option.url; $storage.put('q_ch', option.title) },
        options: options
      }]
    }
  },
  startDanmaku() { this.ws = new (require('ws'))('wss://...') /* ... */ },
  stopDanmaku() { this.ws && this.ws.close(); clearInterval(this.pingId) }
}
```

### 案例 3 · `dorajs-rss@1.0.8` —— 工程化架构（最该学的分层）

目录本身就是教材：

```
package/
├── data/       Site.js  Article.js          # 纯数据模型（构造 + 默认值）
├── dao/        Dao.js  SiteDao.js  ArticleDao.js   # 持久化层，内部用 $storage
├── service/    feed.js                      # 网络层，输入 URL 输出 {site, articles}
├── util/       index.js                     # 工具类（全部 static 方法）
└── components/ index.js  site.js  article.js
```

| 技法 | 说明 |
|---|---|
| **分层解耦** | 组件只负责"渲染 + 交互"，取数据调 `service`，存数据调 `dao` |
| **`$http` 流式** | `$http({ url, responseType: 'stream' }).then(r => r.data.pipe(parser))` |
| **`multiple: true` 的返回值是数组** | `for (const option of selected) { ... }` |
| **相对 require 跨目录** | `require('../dao/SiteDao')`（基于 `/src` 解析） |
| **`$storage` key 编码** | `$storage.put(encodeURIComponent(key), value)` |
| **`contributes.search: null`** | 显式声明"本扩展不提供搜索" |
| **`$dora.mixin({ pageSize: 20 })`** | 给所有组件注入共享属性/方法 |
| **`$input.select` 选项用 `{title, value}`** | `options.push({ title: v.siteName, value: v.feedUrl })` |

### 案例 4 · `dorajs-mzitu@1.4.0` —— 2025 年仍在更新

| 学到 | 说明 |
|---|---|
| **`scripts/` 是公共模块目录** | `require('../scripts/const')`、`require('../scripts/spider')`，不只是 WebView 注入 |
| **`axios` 可直接 require** | `const { default: axios } = require('axios')`，与 `$http` 并存 |
| **首启引导** | `main.js` 里 `if (!$prefs.get('user_id')) { $input.confirm({...}); $prefs.set(...) }` |
| **图标可用 `.ico` 和绝对路径** | `"icon": "/assets/favicon.ico"` |
| ⚠️ 反面教材 | 作者把 `bottomTab` 代码**同时**写在 `main.js` 和 `components/index.js`，冗余（`main.js` 的 exports 只需放全局共享物） |
| ⚠️ 反面教材 | `keywords: ["dorajs, ikmn, Dora.js"]` —— 一个字符串塞了三个词，`keywords` 应为字符串数组 |

### 案例 5 · `dorajs-index` / `jsfun-index` —— 目录型插件

「浏览 npm 上所有扩展」的插件。技法：
- `contributes.search` 用 `null` 或省略
- 直接请求 `registry.npmjs.org/-/v1/search?text=keywords:dora.js`
- **说明生态存在分支平台 `JSFun`**：包名从 `dorajs-*` 也出现了 `jsfun-*`，
  `jsfun-index` 的描述是"可以查看 npm 仓库中所有的 Dora.js / JSFun 扩展"。
  写 `engines` 时，部分包用 `"dora": ">=1.8.1"`，个别包用 `"Dora.js": ">=1.8.1"`，两者都被接受。

### 案例 6 · `dorajs-backup` / `dorajs-check` —— 工具型插件

- 备份扩展列表到 GitHub Gist / GitLab Snippet → 用 `$http` + token
- `dorajs-check`（49KB）是发布辅助工具，可用于理解包校验
- 技法：把 token/账号放 `prefs.json`，用 `$input.password` 输入

---

## 4. 社区约定汇总（真实包里高频出现、文档没写的）

| 约定 | 出现频率 | 说明 |
|---|---|---|
| `package.json` 加 `"engineStrick": true` | 极高 | 强制引擎校验 |
| `"categories": ["video"]` | 高 | 分类：video / image / article / music / news / book |
| `"donates": {}` | 中 | 捐赠配置 |
| `"updates": "..."` | 中 | 更新日志，订阅者可见 |
| `icon` 用 `.svg` | 高 | 矢量图标更小更清晰 |
| `main.js` 首行判空 `$dora` | 极高 | 标准防御写法 |
| `$dora.mixin({...})` 注入 `pageSize` 等 | 中 | 共享属性 |
| `prefs.json` 里的 key 用中划线（`Maximum-History-Entries`） | 中 | 也可用驼峰，注意代码里 key 要一致 |
| 用 `$storage` 做缓存/历史/登录态 | 极高 | 而不是自己写文件 |
| README 写明数据来源与免责声明 | 中 | 建议都写 |

---

## 5. 怎么把别人的包用在自己的项目里

```bash
# 1. 找同类站点 → 下载最像的那个包
curl -sL "https://registry.npmjs.org/dorajs-xxx/-/dorajs-xxx-1.0.0.tgz" | tar -xz -C /tmp/study

# 2. 先看 package.json（依赖 + engines + categories）
# 3. 再看 main.js（全局初始化套路）
# 4. 再看 components/index.js（首页结构）
# 5. 最后看具体解析组件（选择器／接口）
```

**注意**：
- 大多第三方包是 `UNLICENSED`，**参考思路可以，整段复制要谨慎**（尤其别把别人的作者名、token 一起抄过去）
- 抄 `package.json` 时**必须换掉 `uuid`**，否则会和原包冲突
- 抄 `prefs.json` 字段时，代码里的 `$prefs.get(key)` 要同步改

## 6. 生态现状与选型建议

- **Dora.js 本体（1.8.x）已停更**，npm 上的包多停留在 2020–2021
- 存在衍生平台 **JSFun**（包名 `jsfun-*`），兼容 Dora.js 扩展格式
- 因此生成扩展时：
  - `engines` 写 `">=1.8.0"` 兼容性最好
  - 不要依赖某个具体站点的"当前可用性"，**把 base URL 放进 `prefs.json` 的 `options`**
  - 优先选**接口稳定、有公开 API** 的数据源（如 bing 壁纸、RSS、公开 REST API），
    这类扩展不会因为站点改版而失效