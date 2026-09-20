# examples · 示例扩展

全部为**完整工程**（`<示例>/package/...`），可直接打包或拆开抄代码。

```bash
# 打包任意示例
sh ../scripts/build_dora.sh demo-bing-wallpaper
```

| 示例 | 类型 | 演示的技术点 | 依赖 |
|---|---|---|---|
| `demo-bing-wallpaper` | 接口站 / 图片 | **自写、完整可跑**：分页、`gallery` 样式、`$route('@image')` 零代码看图页、`prefs.json` 配置、`actions` 切换参数、`$input.select` | 无 |
| `readhub` | 接口站 / 资讯 | `topTab` 布局、`list` + `article` 样式、`@article` 内置页、`$dora.mixin` 注入共享属性 | 无 |
| `unsplash` | 图片站 | npm 依赖注入（`unsplash-js`+`node-fetch`）、`module.exports` 挂 global、`$assets()` 图标、`$route('@image')` | unsplash-js, node-fetch |
| `bing_wallpaper` | 图片站 | 直接 `require()` 第三方 npm 包、`translucent` 沉浸式标题栏、`gallery` 瀑布流 | wonderful-bing-wallpaper |
| `api_demo` | 全 API 演示 | **强烈建议通读**：全部 11 种组件类型、全部 list 条目样式、`$storage`/`$permission`/`$ui.showCode`/`webview` 通信/`tasks` 后台任务/`$route('@bottomTab')` 零文件嵌套 | axios, cheerio, lru-cache |

> `api_demo` 为 **npm 1.8.1** 与 GitHub master 的合并版（取更新的组件代码 + GitHub 独有的 `tasks/` 演示）。

## 建议阅读顺序

1. **`demo-bing-wallpaper`** —— 最短路径看懂"一个 Dora 扩展长什么样"（1 个组件 + 1 个 main.js）
2. **`readhub`** —— 看懂多页面结构与布局组件（topTab → list → article）
3. **`api_demo/components/api.js`** —— 全部全局 API 的可点击演示（含文档未记载的 `$prefs.open()`、`$ui.showCode()`）
4. **`api_demo/components/types/nested.js`** —— `$route('@bottomTab', {items:[...]})` 零文件嵌套布局
5. **`api_demo/components/types/list.js`** —— 一次性看完全部 13 种列表条目样式的写法
6. **`api_demo/components/file.js`** —— 权限申请 + Node `fs` 文件浏览器

## 快速对照：我要做 X，该看哪个文件？

| 我想… | 看 |
|---|---|
| 写一个最简单的列表页 | `demo-bing-wallpaper/package/components/index.js` |
| 做多分类 tab 首页 | `readhub/package/components/index.js` |
| 列表 → 详情 两跳 | `readhub/` 全套 |
| 用内置图片查看器 | `unsplash/package/components/index.js` 里的 `$route('@image', {...})` |
| 用内置文章阅读器 | `readhub/package/components/news.js` 里的 `$route('@article', {...})` |
| 用内置视频播放器 | `api_demo/components/types/video.js` |
| 写配置界面 (prefs) | `demo-bing-wallpaper/package/assets/prefs.json` |
| WebView 抓数据 | `api_demo/components/types/webview.js` + `api_demo/scripts/dom.js` |
| 后台任务 | `api_demo/tasks/get_ip.js` |

> 这些示例来自 Dora.js 官方示例仓库（MIT）：https://github.com/Dorajs/samples
> `demo-bing-wallpaper` 为本地新增示例，数据源为必应公开接口。