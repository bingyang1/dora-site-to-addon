# 我的站点

Dora.js 扩展：将 `https://www.example.com` 的内容接入 Dora.js。

> ⚠️ 本项目仅供学习与研究使用，请勿用于商业用途。所有内容版权归原站点所有。

## 功能

- 首页分类浏览（电影 / 连续剧 / 综艺 / 动漫）
- 列表分页加载
- 详情页解析播放地址
- 内置视频播放器
- 关键词搜索（支持 App 全局搜索）

## 安装

1. 将本目录打包为 `xxx.dora`：
   ```bash
   tar -czf my-site-v1.0.0.dora package
   ```
   > 目录结构是 `xxx.dora → package/*`，注意 `package` 这一层必须在压缩包根部。

2. 传到手机，用 Dora.js 打开该文件即可安装。

## 开发

- 入口：`main.js`（全局常量、请求头、公共函数）
- 页面：`components/*.js`（一个文件 = 一个页面）
- 配置：`assets/prefs.json`（在 Dora.js 的设置页修改）
- 站点地址在 `main.js` 的 `global.base` 中修改

## 目录

```
package/
├── package.json
├── main.js
├── README.md
├── assets/
│   ├── icon.png
│   └── prefs.json
└── components/
    ├── index.js     # 首页
    ├── list.js      # 分类列表
    ├── detail.js    # 详情
    ├── play.js      # 播放
    └── search.js    # 搜索
```
