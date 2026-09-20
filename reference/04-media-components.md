# 04 · 媒体组件：video / audio / image / article / webview

这 5 个组件是"零界面"的关键 —— **不需要写播放器/阅读器 UI，只需要把 URL 交出来。**

---

## 1. video 组件

```js
module.exports = {
  type: 'video',
  async fetch({ args }) {
    const resp = await $http.get(`https://api.example.com/detail/${args.id}`)
    return {
      title: resp.data.title,
      image: resp.data.cover,          // 封面
      url: resp.data.playUrl,          // 播放地址（mp4 / m3u8）
      headers: {                       // 可选：请求头
        'User-Agent': 'Mozilla/5.0 ...',
        'Referer': 'https://example.com/'
      }
    }
  }
}
```

### 额外属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `url` | `Url` | 视频地址 |
| `headers` | `object` | 播放请求的 HTTP 头 |
| `selectors` | `object[]` | 线路/清晰度选择器 |
| `startDanmaku()` | `function` | 用户开启弹幕时调用，在这里启动拉取任务 |
| `stopDanmaku()` | `function` | 关闭弹幕时调用，释放任务 |
| `sendDanmaku(content)` | `function` | 用户发弹幕的回调 |

### 额外接口

- `this.addDanmaku({ content, color, author })` —— 添加一条弹幕

```js
this.addDanmaku({
  content: 'Hello World!',
  color: '#000000',
  author: { name: 'linroid' }
})
```

> 弹幕目前**仅支持直播弹幕**（官方说明）。

### selectors —— 多线路/多清晰度

```js
module.exports = {
  async fetch() {
    const resp = await $http.get('...')
    return {
      url: resp.data.url,
      isLive: true,                       // 直播时用（隐藏进度条）
      selectors: [
        {
          title: '清晰度',                  // 选择器名称（部分版本用 name）
          select: 0,                        // 默认选中 options[0]
          onSelect: this.onSelectQuality,   // 用户选中后的回调，参数是选中的 option 对象
          options: [
            { title: '高清', value: { baseUrl: 'http://a.com', qs: 1 } },
            { title: '标准', value: { baseUrl: 'http://a.com', qs: 2 } }
          ]
        },
        {
          title: '线路',
          select: 0,
          onSelect: this.onSelectSource,
          options: [
            { title: '线路1', value: 'https://cdn1.com/v.m3u8' },
            { title: '线路2', value: 'https://cdn2.com/v.m3u8' }
          ]
        }
      ]
    }
  },
  onSelectQuality(option) {
    this.url = `${option.value.baseUrl}?qs=${option.value.qs}`
  },
  onSelectSource(option) {
    this.url = option.value
  }
}
```

### 实战：从详情页 HTML 里挖 m3u8（maccms 常见）

```js
const $ = cheerio.load(html)
let playUrl = ''
// 1) 常见的 player_aaaa 变量
const m = html.match(/player_aaaa\s*=\s*(\{[\s\S]*?\})/)
if (m) { try { playUrl = JSON.parse(m[1]).url } catch (e) {} }
// 2) 兜底：正则直接抓 m3u8/mp4
if (!playUrl) {
  const m2 = html.match(/https?:\\?\/\\?\/[^"'\s]+?\.(m3u8|mp4)[^"'\s]*/i)
  if (m2) playUrl = m2[0].replace(/\\/g, '')
}
// 3) m3u8 里的相对路径要拼接
if (playUrl && !/^https?:/.test(playUrl)) playUrl = baseUrl + playUrl
```

> 加密站点（`urls` 被 Base64/自定义编码）时：先看能不能用 `$http` 直接请求解析接口，
> 否则退回 `type: 'webview'` + `runScript` + `$dora.sendEvent` 在网页里抓真实地址。

---

## 2. audio 组件

```js
module.exports = {
  type: 'audio',
  async fetch({ args }) {
    return {
      title: '歌名',
      image: 'https://...jpg',
      url: 'https://...mp3',
      headers: { Referer: 'https://example.com/' },
      hasPrevious: true,
      hasNext: true
    }
  },
  onPrevious() { this.url = '上一个节目地址'; this.title = '上一个' },
  onNext()     { this.url = '下一个节目地址'; this.title = '下一个' }
}
```

额外属性：`url`、`headers`、`hasPrevious`、`onPrevious()`、`hasNext`、`onNext()`。

---

## 3. image 组件

```js
module.exports = { type: 'image', fetch({ args }) { return { url: args.url, title: args.title } } }
```

额外属性只有 `url: Url`。支持保存、设壁纸、分享。

**最快的用法（连组件文件都不用写）：**

```js
route: $route('@image', { url: item.pic, title: item.title })
```

---

## 4. article 组件

```js
module.exports = {
  type: 'article',
  async fetch({ args }) {
    const resp = await $http.get(`https://api.example.com/post/${args.id}`)
    return {
      title: resp.data.title,
      image: resp.data.cover,
      time: resp.data.publishedAt,        // 时间字符串或时间戳
      author: { name: resp.data.author },
      content: {
        url: `https://example.com/post/${args.id}`,  // ★ 用于解析正文里的相对资源
        markdown: resp.data.contentMarkdown,
        // html: '<p>...</p>',
        // text: '纯文本',
        charset: 'utf-8'
      }
    }
  }
}
```

`content` 支持的字段（**选其一**，同时给则优先级按实现）：

| 字段 | 说明 |
|---|---|
| `url` | 文章地址。**只给 url 会以内嵌 WebView 形式打开**；同时给了 html/markdown/text 时它用于解析相对路径资源 |
| `html` | HTML 内容 |
| `markdown` | Markdown 内容 |
| `text` | 纯文本内容 |
| `charset` | 编码，默认 UTF-8 |

去广告/去导航的常见做法：用 cheerio 取正文容器再 `$.html(container)`：

```js
const $ = cheerio.load(html)
$('script,style,.ad,.comment,.nav,.footer').remove()
const content = $('.article-content').html()
return { content: { url: pageUrl, html: content } }
```

---

## 5. webview 组件

```js
module.exports = {
  type: 'webview',
  uiOptions: { statusBar: true, toolBar: true, navigationBar: true },
  script: 'dom.js',                       // scripts/ 下的注入脚本
  async fetch() { return { url: 'https://www.example.com/' } },
  created() {
    this.actions = [
      { title: '取 Cookie', onClick: () => $ui.toast(JSON.stringify(this.cookies)) },
      { title: '执行脚本', onClick: () => this.runScript('document.title') }
    ]
  },
  onPageStarted(url) { console.log('start', url) },
  onPageFinished(url) { console.log('finished', url) },
  onLoadingUrl(url) { /* 每个资源加载 */ },
  onEvent(name, data) { $ui.toast(`${name} ${JSON.stringify(data)}`) }
}
```

### 额外属性 / 接口

| 名称 | 说明 |
|---|---|
| `url` | 打开的网页 |
| `script` | 注入的 JS（可以是 `scripts/` 下的文件名，也可以是 JS 代码） |
| `onPageStarted(url)` / `onPageFinished(url)` / `onLoadingUrl(url)` | 页面生命周期 |
| `onEvent(name, data)` | 接收网页发来的事件 |
| `uiOptions` | `{ statusBar, toolBar, navigationBar }` 布尔 |
| `this.runScript(script)` | 在网页中执行 JS / 加载 `scripts/` 下的 js 文件 |
| `this.redirect(url)` | 跳转 |
| `this.cookies` | 读写 Cookie（读=全部；写=与已有合并） |

### 双向通信

- **网页 → 组件**：页面里调 `$dora.sendEvent(name, data)`，组件里 `onEvent(name, data)` 接收
- **组件 → 网页**：`this.runScript('...')`

### 实战：WebView 抓真实播放地址

```js
// scripts/dom.js （注入页面）
(function () {
  setInterval(() => {
    const v = document.querySelector('video')
    if (v && v.src) {
      $dora.sendEvent('video_url', { url: v.src })
    }
  }, 2000)
})()

// components/sniff.js
module.exports = {
  type: 'webview',
  script: 'dom.js',
  async fetch({ args }) { return { url: args.pageUrl } },
  onEvent(name, data) {
    if (name === 'video_url') {
      $storage.put('last_url', data.url)
      $router.to($route('@video', { url: data.url }))
    }
  }
}
```

---

## 6. 组合套路（这才是站点封装的常态）

```
detail.js (type: 'list')        ← 详情页：简介 + 线路按钮
   ├─ 点击"播放" → $route('play', { id, line }) → play.js (type: 'video')
   └─ 内嵌节点：$route('@video', { url })
```

`list` 里也能直接塞一个 `richContent` 条目内嵌详细正文：

```js
{
  title: '简介',
  style: 'richContent',
  content: { url: pageUrl, html: introHtml }
}
```