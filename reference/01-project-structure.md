# 01 · 工程结构 / package.json / prefs.json / main.js

## 1. 扩展包结构

Dora.js 扩展包后缀为 `.dora`，**本质就是一个 `tar.gz`**，内部固定有一层 `package/` 根目录：

```
package/
├── assets/
│   ├── icon.png        # 图标，支持 .png .jpg .webp .svg
│   └── prefs.json      # 配置界面定义（可选）
├── components/
│   └── index.js        # 组件（每个文件 = 一个原生页面）
├── scripts/            # 注入 WebView 的 js（可选）
├── main.js             # 入口文件
├── README.md
└── package.json
```

- `assets/` 存放资源（图片、数据文件）
- `components/` 每个组件对应一个原生页面，**可能被执行多次**（每次进页面都创建实例）
- `scripts/` 存放注入 WebView 的脚本
- `main.js` 扩展启动时首先执行，**每个实例生命周期内只执行一次**

### 虚拟文件系统（重要）

扩展运行在沙箱里，**看不到真实路径**。实例运行前会挂载：

| 路径 | 权限 | 说明 |
|---|---|---|
| `/src` | 只读 | 扩展源码目录（安装后代码解压到这里）。`./README.md` 这类相对路径指向它 |
| `/data` | 读写 | 扩展数据目录（配置、存储、缓存） |
| `/shared` | 读写 | 扩展间共享目录（❌ 官方标注未完善） |
| `/sdcard` | 需授权 | 映射手机外置存储（❌ 官方标注未完善），用 `$permission.request('sdcard')` 申请 |

所以 `require('./xxx')`、`fs.readFileSync('./README.md')` 是相对 `/src` 的。

## 2. package.json

真实可用模板（字段说明见注释）：

```json
{
  "name": "dorajs-my-site",             // npm 包名，全小写连字符
  "displayName": "我的站点",             // 应用里显示的名字
  "version": "1.0.0",
  "uuid": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",  // ★ 必填且必须唯一，v4 随机生成
  "description": "把这个站点写成了 Dora 扩展",
  "updates": "首个版本",                 // 更新说明，订阅用户可见
  "icon": "assets/icon.png",            // 也可以是 assets/icon.svg
  "prefs": "assets/prefs.json",         // 有配置文件才写
  "main": "main.js",
  "license": "MIT",
  "author": {
    "name": "yourname",
    "fullname": "Your Name",
    "email": "you@example.com"
  },
  "homepage": "",
  "repository": { "type": "git", "url": "" },
  "engines": { "dora": ">=1.8.0" },      // 也有插件写成 "Dora.js": ">=1.8.1"
  "engineStrick": true,
  "keywords": ["Dora.js"],
  "categories": ["video"],               // video/image/article/music/book...
  "dependencies": {                      // ★ 会被 Dora.js 自动 npm install
    "cheerio": "^1.0.0-rc.12",
    "axios": "^0.21.1"
  },
  "contributes": {
    "search": "search",                  // ★ 全局搜索入口，值为 components 下的路径（不带 .js）
    "tasks": {                           // 可选：后台任务
      "get_ip": { "icon": "assets/ip.svg", "label": "获取外网 IP" }
    }
  }
}
```

**生成 uuid：**
```bash
python3 -c "import uuid;print(uuid.uuid4())"
```

**注意**：`dependencies` 里的包由 Dora.js 在安装时下载安装，**不要把 node_modules 打进 .dora**。

## 3. prefs.json — 自动生成配置界面

放一个 json 就能得到一个原生设置页，用户在「扩展设置」里修改，代码里用 `$prefs.get('key')` 读取。

```json
{
  "endpoint": {
    "type": "string",
    "default": "https://www.example.com",
    "title": "站点地址"
  },
  "token": {
    "type": "password",
    "default": null,
    "title": "登录 Token"
  },
  "quality": {
    "type": "string",
    "default": "1080p",
    "title": "画质",
    "options": [
      { "value": "1080p", "title": "高清 1080P" },
      { "value": "720p",  "title": "标清 720P" }
    ]
  },
  "enableDanmaku": {
    "type": "boolean",
    "default": true,
    "title": "开启弹幕"
  },
  "pageSize": {
    "type": "number",
    "default": 20,
    "title": "每页数量"
  }
}
```

字段规格：

| 属性 | 必填 | 说明 |
|---|---|---|
| `title: string` | ✅ | 配置项标题 |
| `type: string` | ✅ | `boolean` / `number` / `string` / `password` |
| `default: any` | ✅ | 默认值，类型须与 `type` 一致 |
| `options: []` | ✖ | 有则点击弹出列表选择；元素 `{value, title}` |

> ⚠️ `password` 类型**是明文存储**，不要当加密用。

## 4. main.js — 入口文件

`main.js` 里 `module.exports` 返回的对象属性**会挂到全局 `global` 上**，所以适合放：

- 校验运行环境
- `require` 公共依赖并挂 global
- 全局常量（如 API 域名）
- `$dora.mixin({...})` 全局混入生命周期

标准模板：

```js
if (typeof $dora == 'undefined') {
  console.error('This project runs only in Dora.js.')
  console.error('Please visit https://dorajs.com/ for more information.')
  process.exit(-1)
}

// —— 公共依赖挂到 global，供所有组件直接使用 ——
global.cheerio = require('cheerio')
// global.axios = require('axios');   // 一般不需要，$http/$axios 已内置

$dora.mixin({
  created() {
    // 所有组件创建后都会执行
  }
})

module.exports = {
  endpoint: 'https://www.example.com',
  UA: 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36'
}

console.info('扩展启动成功')
```

## 5. README.md

扩展详情页会展示，建议包含：站点来源、功能列表、免责声明。

## 6. 运行时注意事项

- 每个扩展跑在**独立 Node.js 实例**里（集成了 Node.js v14.x / v15.5.0），扩展的不同组件共享同一个实例
- 所有扩展实例运行在**同一个进程**；`process.exit()` 只会结束当前扩展实例，不会杀掉 App
- 一个扩展的所有页面都关闭后，其实例自动结束
- 支持大部分 ES6+ 语法、支持 npm 包、支持 `require('fs')` 等 Node 内置模块

## 7. 从零创建扩展的三种方式

1. **手机端**：Dora.js → 右下角「开发中」→「创建扩展」→ 填显示名称/作者 → 自动打开编辑器
2. **VSCode 插件**（推荐）：长按扩展图标 → 右上角菜单「连接 VSCode」，VSCode 装 `Dora.js` 插件（`linroid.dora`），连接同 WiFi 下手机 IP，选扩展 + 本地目录，编辑后点纸飞机推送
3. **AI 生成**：本项目（写工程目录 → `build_dora.sh` 打包 → 手机端安装 .dora）
