# WORKFLOW · 「给我一个站点 → 输出 Dora 项目」执行手册

> 这是给 AI 用的操作剧本。**按顺序执行，每步都要有可验证的产出。**
> 触发语：*「把 xxx 站做成 Dora 扩展」「写个 dora 插件采集这个站」「https://xxx 封装一下」*

---

## 输入契约

| 输入 | 必需 | 说明 |
|---|---|---|
| 站点 URL | ✅ | 首页或任一分类页 |
| 想要的功能 | ✖ | 默认：浏览 + 分页 + 详情 + 搜索 |
| 显示名称 | ✖ | 默认取站点标题 |
| 分类页/搜索页 URL | ✖ | 若能提供，直接跳过侦察 |

**缺口处理**：只给了域名 → 先抓首页，自己推出分类页与搜索页格式（见 Step 2）。

---

## Step 0 · 环境检查（10 秒）

```bash
SKILL=/sdcard/Download/dora/dora-site-to-addon
ls "$SKILL/scripts"          # 确认脚手架存在
command -v python3 node curl # 需要哪个装哪个
```

---

## Step 1 · 站点侦察——判定"配方"

```bash
sh $SKILL/scripts/probe_site.sh https://目标站点
```

同时用 `visit_web` / `http_request` 抓首页与一个分类页，记录下面 6 项：

| # | 采集项 | 例子 |
|---|---|---|
| 1 | 站点类型 | maccms / JSON-API / 图站 / 文章站 / SPA |
| 2 | 列表容器选择器 | `div.stui-vodlist__box` |
| 3 | 标题选择器 | `h4 a` |
| 4 | 封面选择器 | `a.stui-vodlist__thumb` 的 `style:url(...)` 或 `img[data-original]` |
| 5 | 详情链接格式 | `/detail/1234.html` |
| 6 | 分页/搜索 URL 格式 | `/vod/6-{page}.html`，`/vodsearch/----------{page}---.html?wd={kw}` |

### 判定表

| 命中特征 | 判定 | 走哪个配方 |
|---|---|---|
| `stui-vodlist` / `mac-vodlist` / `player_aaaa` | 苹果CMS VOD | `reference/08-site-recipes.md` 配方 A |
| JSON 响应 / `/api/` / `__NUXT__` / `__NEXT_DATA__` | 接口站 | 配方 B（**优先**） |
| 大量 `<img>` 瀑布流 | 图片站 | 配方 C |
| `<article>` / 正文容器 | 文章站 | 配方 D |
| 需要 token/cookie | 登录站 | 配方 E |
| 全 JS 渲染 + 有加密签名 | 硬骨头 | 配方 F（最后手段） |

> ⚠️ **能拿 JSON 就绝不解析 HTML。** 接口站的稳定性是 HTML 解析的 10 倍。

---

## Step 2 · 找出全部入口 URL（关键，决定工程骨架）

至少要确定 4 个 URL 模板：

```
列表：  {base}/vod/{cid}-{page}.html          ← page 从 1 开始
详情：  {base}/detail/{id}.html              ← 或完整 href
播放：  详情页里的 m3u8 / player_aaaa.url
搜索：  {base}/vodsearch/----------{page}---.html?wd={kw}&submit=
```

**找不到搜索** → 就跳过 search 组件，把 `contributes.search` 删掉。
**找不到分类 id** → 从首页导航的 `<a href="/vod/6---.html">` 里正则批量提取。

产出物：一张表

```
| 页面 | URL 模板 | 路由 | 组件文件 |
| 首页/分类 | /vod/{cid}-{page}.html | list | components/list.js |
| 详情 | 由列表 href 来 | detail | components/detail.js |
| 播放 | 详情解析 | play | components/play.js |
| 搜索 | /vodsearch/... | search | components/search.js |
```

---

## Step 3 · 生成骨架

```bash
sh $SKILL/scripts/new_addon.sh /sdcard/Download/dora/<slug> "显示名称" "作者"
```

生成后立刻做三件事：
1. `package/main.js` → 把 `global.base` 改成目标站点；补 `Referer`
2. `package/package.json` → 改 `categories`、按需保留 `contributes.search`
3. `package/assets/icon.png` → 放图标（没图标可先留模板的）

### Step 3.5 · （推荐）先抄一份同类插件的作业

判定出站点类型后，从 npm 找**同品类**的真实插件读一遍，比自己从零想结构快得多：

```bash
# 做直播站 → 看 dorajs-twitch；做 RSS/资讯 → 看 dorajs-rss；做视频站 → 看 dorajs-zi-yuan-cai-ji
curl -sL "https://registry.npmjs.org/dorajs-twitch/-/dorajs-twitch-1.4.6.tgz" | tar -xz -C /tmp/study
find /tmp/study -type f
```
读的顺序：`package.json` → `main.js` → `components/index.js` → 具体解析组件。
清单与案例拆解见 `reference/10-npm-ecosystem.md`。
⚠️ 第三方包多为 UNLICENSED：**抄结构、抄思路，不要整段复制**；抄了 `package.json` 必须换 `uuid`。

---

## Step 4 · 写解析逻辑（最容易翻车的一步）

### 铁律
1. **先打印再写选择器**：
   ```js
   const $ = cheerio.load(html)
   console.log('matched:', $('你的选择器').length)   // 必须是 >0
   console.log($('body').html().slice(0, 800))      // 看真实结构
   ```
2. 每个字段先 `console.log(title, image, href)`，确认没 `undefined` 再组装 items。
3. 相对地址一律 `absUrl()`；懒加载一律 `data-original || data-src || src || style:url()`。
4. 所有网络请求 `try/catch`，失败 `this.error = e.message`。
5. `nextPage` 只在**确实还有下一页**时给值，否则 `null`。

### 每个组件的检查点

| 组件 | 必须确认 |
|---|---|
| `index.js` | 分类 id 列表正确、`type` 与布局匹配 |
| `list.js` | 首屏有数据、翻第 2 页有数据、翻到底不报错 |
| `detail.js` | 能拿到播放地址（`player_aaaa` 或正则兜底） |
| `play.js` | `url` 是绝对地址、`headers.Referer` 已设 |
| `search.js` | 关键词 encodeURIComponent、空关键词有兜底 |

---

## Step 5 · 自检

```bash
python3 $SKILL/scripts/check_addon.py /sdcard/Download/dora/<slug>
# 再用 node 做一次真语法检查（比括号平衡更可靠）
for f in $(find /sdcard/Download/dora/<slug>/package -name '*.js'); do node --check "$f" || echo "FAIL $f"; done
```

必须 **0 error**。warning 逐条看，大多是"缺 README / 图标不存在"，补上即可。

---

## Step 6 · 打包

```bash
sh $SKILL/scripts/build_dora.sh /sdcard/Download/dora/<slug>
# 输出：/sdcard/Download/dora/<显示名称>-v<版本>.dora
tar -tzf <输出.dora> | head -5     # 必须 package/ 开头
```

---

## Step 6.5 · 真机联调（可选，但强烈推荐）

**能联调就别打包**——打包→传手机→安装→进页面→翻日志，一轮 2 分钟；
Live Sync 改完 2 秒就在手机上看到效果（就是官方 VSCode 插件的 `autoPush`，但不用电脑）。

```bash
SH=$SKILL/scripts/dora-sync.sh

sh $SH ping                       # 探活（连不上会自动尝试把 Dora 拉到前台）
sh $SH list                       # 列扩展，拿 uuid
sh $SH pull <uuid|名称> ./dev      # 拉真机源码到本地（平铺工程）
sh $SH push ./dev                 # 推回去 → 手机端提示「xxx 已更新」
sh $SH watch ./dev                # 盯目录，一改就推
```

**前置**：Dora.js → 长按扩展 → 右上角菜单 → 「连接 VSCode」（服务监听 `127.0.0.1:4000`）。

**两条铁律**（违反必卡死）：

| # | 铁律 | 踩了会怎样 | 解法 |
|---|---|---|---|
| ① | 同步期间 **Dora 必须在前台** | 它进后台被系统冻结，TCP **超时**（`HTTP=000`，不是 404/拒绝） | `am start -n com.linroid.dora/.ui.DoraActivity`（Shizuku 即可，无需 root），或分屏保持可见 |
| ② | 联调 zip 必须**平铺**（根目录就是 `package.json`） | 套了一层 `package/`，扩展直接废掉 | 用 `dora-sync.sh push`，它按官方规则打包并排除 `node_modules` |

**排查一条命令**：

```bash
PID=$(pidof com.linroid.dora); cat /proc/$PID/cgroup | head -3
# cpuset:/background → 就是这个坑；cpuset:/foreground → 正常
```

完整协议 / 实测记录 / 环境差异 / 安全须知：**`reference/12-live-sync.md`**。
装扩展 4 步、`dorajs.db` 表结构、数据库安装法、push 为何返回 `code:0` 却没落地：**`reference/13-app-internals.md`**。

> ⚠️ 联调只适合「开发中反复改」；**最终交付仍要走 Step 6 打包 `.dora`**，两者目录结构不同。

---

## Step 7 · 交付（必须给用户这些）

```
✅ 源码目录：/sdcard/Download/dora/<slug>/
✅ 安装包：  /sdcard/Download/dora/名称-v1.0.0.dora
✅ 用法：    传到手机 → 用 Dora.js 打开该文件 → 安装 → 点图标进入
✅ 功能清单：首页分类 / 分页 / 详情 / 播放 / 搜索
✅ 站点适配点：main.js 里的 global.base（换站点只改这一行）
✅ 免责声明：仅供学习研究，内容版权归原站所有
```

如果某个功能没做出来（比如搜索页格式找不到），**必须明确说明并写进 README 的"已知问题"**，不要假装完成。

---

## 常见分支处理

### 分支 1：站点是 SPA，HTML 里没数据
1. 找 `__NUXT__` / `__NEXT_DATA__` / `__INITIAL_STATE__`，里面往往直接是 JSON
2. 用 `http_request` 试 `/api/...` 常见路径
3. 试移动端：加 UA 为手机 → 很多站点会返回简化版 HTML 或独立 H5 接口
4. 都不行 → 配方 F（WebView 嗅探），并在 README 注明

### 分支 2：详情页是"选集"结构（剧集）
```js
// 从详情页提取播放列表
const eps = []
$('.stui-content__playlist a').each((i, el) => {
  eps.push({
    title: $(el).text().trim(),
    url: absUrl($(el).attr('href'))     // 每一集的集数页
  })
})
// items 里每集一条，点击 → play 组件
```
剧集多时用 `selectors` 或分页处理。

### 分支 3：一个站点有多个域名/源，容易挂
把可切换的源放到 `prefs.json` 的 `options` 里，让用户自己切：
```json
"endpoint": { "type": "string", "default": "https://a.com", "title": "站点线路",
  "options": [{ "value": "https://a.com", "title": "线路1" }, { "value": "https://b.com", "title": "线路2" }] }
```
代码里 `$http` 用 `$prefs.get('endpoint')` 而不是常量。

### 分支 4：要用户输入关键词 / 选线路
用 `$input.text()` / `$input.select()`，不要写死。见 `reference/06-global-api.md`。

---

## 验收清单（发给用户前逐条打勾）

- [ ] `components/index.js` 存在且有 `type`
- [ ] `global.base` 是**目标站点**，不是 `example.com`
- [ ] 分类 id / URL 模板与真实站点一致（不是照抄模板里的 6/8/10/12）
- [ ] 所有 `$route` 目标文件都存在（`check_addon.py` 0 error）
- [ ] `node --check` 全部通过
- [ ] 图片地址是绝对 URL 且能打开
- [ ] 播放地址能打开（至少手动验证过一个）
- [ ] `nextPage` 到底会变 `null`
- [ ] 打包后 `tar -tzf` 是 `package/` 开头
- [ ] README 写了站点、功能、已知问题、免责声明
- [ ] 明确告知用户"仅供学习研究"

---

## 反模式（不要做）

| ❌ | ✅ |
|---|---|
| 照抄模板的选择器不改 | 先 `console.log` 确认真实选择器 |
| 把 `items.push` 到模块级变量后忘了 return | 每次 `fetch` 里新建数组并 return |
| `nextPage: page + 1` 但永远不停 | 末页返回 `null` |
| 在 `fetch` 里 `await` 放进返回对象的字段 | 先 await 完，再组装对象 |
| 写死账号/token | 放 `prefs.json` |
| 打包时带上 node_modules | 用 `build_dora.sh` |
| 声称"能用"但没验证 | 逐条跑验收清单，如实说明限制 |