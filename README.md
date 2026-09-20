# dora-site-to-addon

<p align="center">
  <b>给一个网址，还一个 Dora.js 扩展</b><br>
  <sub>把任意网站（视频 / 图片 / 文章 / 漫画 / API）封装成可安装的 <code>.dora</code> 插件</sub>
</p>

<p align="center">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue.svg">
  <img alt="platform" src="https://img.shields.io/badge/platform-Android-3DDC84.svg">
  <img alt="dora" src="https://img.shields.io/badge/Dora.js-%3E%3D1.8.0-ff69b4.svg">
  <img alt="npm packages studied" src="https://img.shields.io/badge/npm%20addons-137-orange.svg">
  <img alt="files" src="https://img.shields.io/badge/files-125-lightgrey.svg">
</p>

---

这是一个 **AI 技能包（Skill）**：把「把某个网站做成 Dora.js 扩展」这件事，
拆解成一套可复用的**知识库 + 模板 + 脚本 + 工作流**。

> **Dora.js** 是 Android 上的内容型编程平台 —— 你用 JavaScript 提供数据，它用原生 UI 渲染。
> 所以「写一个 Dora 扩展」= **把网页数据映射成 Dora 的数据结构**，不需要写界面。

## 它解决什么问题

```
输入： https://example.com
输出： my-site/                  ← 源码工程
       my-site-v1.0.0.dora       ← 可直接安装的插件包
```

按 `WORKFLOW.md` 走 7 步：侦察站点 → 判定配方 → 生成骨架 → 写解析 → 自检 → 打包 → 交付。

## 快速开始

```bash
git clone https://github.com/bingyang1/dora-site-to-addon.git
cd dora-site-to-addon
SKILL=$PWD

# 1) 侦察站点（指纹识别 + 选择器线索）
sh $SKILL/scripts/probe_site.sh https://example.com

# 2) 生成工程骨架（自动生成 uuid、替换包名作者）
sh $SKILL/scripts/new_addon.sh ~/my-site "我的站点" "你的名字"

# 3) 改 main.js 的 global.base → 目标站点
#    写 components/*.js 的解析逻辑（照抄 reference/08-site-recipes.md 的配方）

# 4) 自检（结构 / 路由 / 语法 / 相对 require）
python3 $SKILL/scripts/check_addon.py ~/my-site

# 5) 打包
sh $SKILL/scripts/build_dora.sh ~/my-site
```

把生成的 `.dora` 传到手机，用 Dora.js 打开即可安装。

## 能做什么 / 怎么做

| 站点类型 | 识别特征 | 组件方案 |
|---|---|---|
| 苹果CMS(maccms) VOD 站 | `stui-vodlist` / `player_aaaa` | `topTab` + `list(vod)` + `video` |
| JSON 接口站 | 响应是 JSON / `__NUXT__` / `/api/` | 直接映射，**首选** |
| 图片 / 壁纸站 | 瀑布流 `<img>` | `list(gallery)` + `@image` |
| 文章 / 资讯站 | 长文正文 | `list(article)` + `article` |
| 直播站 | `.m3u8` + 多清晰度 | `video` + `selectors` + 弹幕 |
| 需登录的站 | token / cookie | `prefs.json` + `webview` 取 cookie |

## 目录结构

```
dora-site-to-addon/
├── SKILL.md                       技能入口：铁律 + 工作流 + 数据映射表 + 自检清单
├── WORKFLOW.md                    ★「站点 → 项目」7 步执行手册 + 分支处理 + 验收清单
│
├── reference/                     知识库（12 篇精编 + 官方原文）
│   ├── 01-project-structure.md    工程结构 / package.json / prefs.json / main.js
│   ├── 02-components-core.md      组件基础、生命周期、fetch 返回值
│   ├── 03-list-component.md       list 组件、分页、13 种条目样式
│   ├── 04-media-components.md     video / audio / image / article / webview
│   ├── 05-layout-components.md    topTab / bottomTab / drawer
│   ├── 06-global-api.md           $dora $http $ui $input $prefs $storage $router
│   ├── 07-struct-and-route.md     Author / Action / Url / Route
│   ├── 08-site-recipes.md         ★ 6 大站点类型实战配方
│   ├── 09-pitfalls.md             坑与排错手册
│   ├── 10-npm-ecosystem.md        ★ 137 个真实插件调研 + 6 个案例拆解
│   ├── 11-api-reality-check.md    ★ 文档外 API 实测表 + 差异清单
│   ├── types/                     官方运行时类型定义 globals.d.ts（字段级权威）
│   └── raw/                       Dora.js 官方文档原文镜像（37 篇 md）
│
├── templates/addon/               可直接复制的工程骨架（含详细注释）
│   ├── package.json  main.js  README.md
│   ├── assets/prefs.json
│   ├── components/  index / list / detail / play / search
│   └── scripts/dom.js             WebView 嗅探注入脚本
│
├── examples/                      5 个完整可跑示例
│   ├── demo-bing-wallpaper/       自写，最小完整扩展（接口站范本）
│   ├── api_demo/                  ★ 官方示例 1.8.1（全部组件类型 + 全部 API）
│   ├── readhub/                   topTab + list + article
│   ├── unsplash/                  npm 依赖 + gallery + @image
│   └── bing_wallpaper/            npm 依赖 + translucent
│
├── scripts/
│   ├── new_addon.sh               脚手架（生成 uuid、替换包名）
│   ├── build_dora.sh              打包成 .dora（保证 package/ 根目录）
│   ├── check_addon.py             自检：结构/路由/语法/相对 require
│   └── probe_site.sh              站点侦察（指纹识别 + 选择器线索）
│
├── LICENSE                        MIT（仅覆盖原创部分）
└── NOTICE.md                      第三方内容归属与免责声明
```

## 核心概念速记

| 概念 | 一句话 |
|---|---|
| 组件 | 一个 js 文件 = 一个原生页面，`module.exports` 导出**普通对象** |
| 入口 | 永远先跑 `components/index.js` |
| 数据 | `fetch()` 返回什么，`this` 上就有什么；list 返回 `items` |
| 分页 | `nextPage` 就是下次 `fetch({page})` 的 `page`；`null` = 没有更多 |
| 路由 | `$route('相对 components 的路径', args)`，**不带 `.js`** |
| 内置页面 | `$route('@image'\|'@video'\|'@article', args)` —— args 直接成为它的数据 |
| 零文件嵌套 | `$route('@bottomTab', { items: [...] })` 可以凭空嵌布局 |
| 打包 | `.dora` = tar.gz，根目录必须是 `package/` |

## 亮点：文档里没有的东西

全部来自三处交叉验证（官方文档 ↔ `@dora.js/types` ↔ 真实插件源码）：

- **文档外 API**：`$prefs.open()`、`$ui.showCode()`、`$ui.viewFile()`、`$clipboard`、`$storage.dir`、`$dora.locale`
- **差异纠正**：`Action` 图标字段文档写 `icon`、types 写 `image`（两个都能用）；
  `$input.select` 的 `multiple:true` **返回数组**；`script/` 其实是**公共模块目录**
- **真实技法**：直播弹幕用 WebSocket、`selectors` 挂业务字段、`validateStatus` 防 403 抛异常、
  用 `i18n` 包做国际化、`data/dao/service/util` 四层工程化

详见 [`reference/10-npm-ecosystem.md`](reference/10-npm-ecosystem.md) 与 [`reference/11-api-reality-check.md`](reference/11-api-reality-check.md)。

## 参考来源

- 官方文档：<https://github.com/Dorajs/docs>
- 官方示例：<https://github.com/Dorajs/samples>
- 官方类型：npm `@dora.js/types`
- npm 生态：`https://registry.npmjs.org/-/v1/search?text=dora.js`（137 个包）

## 免责声明

本技能用于**把公开可访问的网站数据接入 Dora.js**，仅供学习与研究。

- ❌ 不要用于绕过付费墙、DRM、会员鉴权
- ❌ 不要用于聚合盗版内容
- ⚠️ 所有被封装站点的内容版权归原站点所有
- ⚠️ 使用本技能产生的全部责任由使用者自行承担

第三方内容的授权情况见 [NOTICE.md](NOTICE.md)。

## License

[MIT](LICENSE) © 2026 bingyang1