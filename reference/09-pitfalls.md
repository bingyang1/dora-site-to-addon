# 09 · 常见坑与排错手册

## A. 语法 / 结构类

| 现象 | 原因 | 修法 |
|---|---|---|
| 点图标白屏/无反应 | 没有 `components/index.js` | 必须有，且 `module.exports` 里有 `type` |
| `xxx is not defined` | 用了 `import` / `export` | Dora.js 用 CommonJS：`require()` + `module.exports` |
| `Cannot read property 'x' of undefined` | `fetch` 用箭头函数导致 `this` 丢失 | 改 `async fetch() {}` 方法简写 |
| 页面一直转圈 | `fetch` 里没 `return`，或返回了 Promise 却没 await | `return await ...` 或 `return $http.get().then(...)` |
| 只显示第一页 | `nextPage` 没返回或恒为同值 | 返回 `page + 1`，到末页返回 `null` |
| 点击条目没反应 | `route` 路径写错 / 带了 `.js` | 路径相对 `components/`，**不带 `.js`** |
| 请求头设置不生效 | 在对象里写了 `Headers`（大写） | `headers` 小写 |

## B. 网络类

| 现象 | 原因 | 修法 |
|---|---|---|
| 403 / 返回挑战页 | 缺 UA 或 Referer | `$http.defaults.headers.common['User-Agent']='Mozilla/5.0 ...'`，并加 `Referer: 站点首页` |
| 返回乱码 | GBK 站点 | 换 UTF-8 镜像/接口；或 `require('iconv-lite')` 转码 |
| `ERR_CLEARTEXT_NOT_PERMITTED` | http 明文站 | 用 https；不行则换站 |
| 请求超时 | 站点慢/被墙 | 加 `timeout: 15000` 并 `try/catch`；考虑镜像域名 |
| JSON 里是 HTML 实体 | 服务端转义 | 手动 `replace(/"/g,'"')` 后再 `JSON.parse` |

## C. 数据映射类

| 现象 | 原因 | 修法 |
|---|---|---|
| 图片全是破图 | 相对路径/img 懒加载属性 | 用 `data-original`/`data-src`/`background-image` 并补全域名 |
| 图片显示 `<img>` 但空白 | 站点有防盗链 | 图片本身免不了，尽量取 CDN 直链 |
| 视频能播放但无画面/黑屏 | 缺 Referer | video 组件的 `headers.Referer` |
| 播放地址是相对路径 | m3u8 相对 | `url = base + url` |
| 列表标题带一堆空白/换行 | 没 trim | `.text().replace(/\s+/g,' ').trim()` |
| 时间显示成乱码 | 传了非法格式 | 转成时间戳（ms）或标准日期字符串 |

## D. 生命周期 / 状态类

| 现象 | 原因 | 修法 |
|---|---|---|
| 切换分类后列表是旧数据 | 用了模块级变量且没清空 | 在 `fetch` 开头重建数组，或 `this.refresh()` 前先 `this.items = []` |
| 多个页面互相干扰 | 模块级变量在实例间共享 | 数据放 `this.xxx`，只把"配置"放模块级 |
| 定时器泄漏、退出后还在跑 | 没清理 | `beforeDestroy()/destroyed()` 里 `clearInterval` |
| `created()` 里 `this.items` 为空 | `fetch` 还没赋值 | 在 `created()` 里访问 `this.items` 是安全的；`beforeCreate()` 里不是 |
| 页面标题不刷新 | 设置了模块级 title | 用 `this.title = xxx`（`beforeCreate` 里设最稳） |

## E. 打包 / 安装类

| 现象 | 原因 | 修法 |
|---|---|---|
| 安装后闪退/无法启动 | 压缩包根目录不是 `package/` | `.dora` 内必须是 `package/package.json` 这一层 |
| 安装时提示解析失败 | `package.json` 语法错误（多了逗号） | `python3 -m json.tool package.json` 校验 |
| 扩展装不上 / 覆盖不了旧版 | `uuid` 重复或未更新 | 每次都用新的 uuid v4；升级时**保留 uuid、升 version** |
| 装上直接报缺模块 | `dependencies` 里漏了 cheerio 等 | 补齐 `dependencies` 后重装 |
| 打出来的包特别大 | 打进了 node_modules | 打包前排除 `node_modules`、`.git`、`.DS_Store` |

**校验脚本**：
```bash
python3 scripts/check_addon.py <工程目录>     # 结构+语法+路由一致性检查
tar -tzf xxx.dora | head -20                 # 确认是 package/ 开头
python3 -m json.tool package/package.json > /dev/null && echo "json ok"
```

## F. 调试技巧

```js
// 1) 一切靠 console.log（在 Dora.js 的「开发中 → 日志」里看）
console.log('resp', JSON.stringify(resp.data).slice(0, 500))

// 2) 结构不确定时，先打印 HTML 片段
const $ = cheerio.load(html)
console.log($('body').html().slice(0, 1000))

// 3) 选择器不确定时，数一下命中数量
console.log('matched:', $('.stui-vodlist__box').length)

// 4) 在页面里回显调试信息（比翻日志快）
this.error = JSON.stringify(someVar).slice(0, 200)

// 5) 观察请求（不改代码）
$http.interceptors.response.use(r => { console.log(r.config.url, r.status); return r })
```

## G. 合规红线（务必告知用户）

- 只封装**公开、无需登录**的内容；不要绕过付费墙 / DRM / 会员鉴权
- 不要在扩展里硬编码他人的账号、Cookie、密钥
- 不要内置盗版/成人内容站点的"资源聚合"，或绕过平台审核
- 生成的项目建议在 README 标注"仅供学习研究，请勿用于商业用途"
- 若用户要求封装明显侵权的站点，应说明风险并建议改为合法数据源

## H. 版本差异提示

- 文档说 Node.js 为 v15.5.0；FAQ 里写 v14.1.0 —— **以实际 `process.versions` 为准**
- `$http`（文档）与 `$axios`（社区代码）是**同一个 axios 实例的别名**，两者混用没问题
- `thumb` 字段自 V1.5.1 起被 `image` 取代，但**仍兼容**
- `$input.prompt()` 已被 `$input.text()` 取代
- `1.8.x` 及以前的 Dora.js 已停更；若目标设备是 `JSFun` 等衍生版，注意 `engines` 字段写法（有插件写成 `"Dora.js": ">=1.8.1"`）