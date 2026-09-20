# NOTICE · 第三方内容归属

> **LICENSE 覆盖范围**：仓库中的 `LICENSE`（MIT）**仅覆盖作者原创内容** ——
> `SKILL.md`、`WORKFLOW.md`、`reference/01~11-*.md`、`templates/`、`scripts/`、
> `examples/demo-bing-wallpaper/`。
> 其余第三方内容另有归属，见下文。

本仓库是一个「技能包」，为了方便离线查阅，收录了部分第三方内容。
**这些内容的版权归各自作者所有，本仓库仅作技术学习与归档用途。**

---

## 1. `reference/raw/` —— Dora.js 官方文档镜像

- **来源**：https://github.com/Dorajs/docs （原作者 linroid / Dora.js 项目）
- **内容**：37 篇 markdown 文档原文
- **状态**：原仓库未附 LICENSE，此处以「技术文档归档 + 明确署名」的方式收录
- **说明**：
  - 只镜像了 `.md` 文本，**未包含 `_media/` 下的图片**，因此原文中的图片链接会失效
  - 如原作者认为不妥，请提 Issue，会立即移除

## 2. `reference/types/` —— 官方运行时类型定义

- **来源**：npm 包 `@dora.js/types@1.0.4`（作者 linroid，`license: ISC`）
- **内容**：`globals.d.ts` / `index.d.ts` 原文
- **用途**：作为字段级的权威 API 参考

## 3. `examples/api_demo/`、`examples/readhub/`、`examples/unsplash/`、`examples/bing_wallpaper/`

- **来源**：https://github.com/Dorajs/samples （**LICENSE: MIT**，作者 linroid）
- **内容**：官方示例扩展源码
- **处理**：`api_demo` 为 npm 1.8.1 与 GitHub master 的合并版
- **许可**：遵循原仓库 MIT 许可

## 4. `reference/10-npm-ecosystem.md` 中提及的第三方插件

调研过程中拆解了以下 npm 包（**均为 UNLICENSED**）：

| 包名 | 版本 | 作者 |
|---|---|---|
| `dorajs-twitch` | 1.4.6 | cinhoo |
| `dorajs-rss` | 1.0.8 | Youth．霖 |
| `dorajs-mzitu` | 1.4.0 | matrixzw |
| `jsfun-index` | 1.3.1 | — |

**本仓库只记录了「技术技法」的总结，示例代码均为重新编写，未复制其源码。**
请勿将其用于再分发。

---

## 5. 免责声明

本技能的用途是**把公开可访问的网站数据接入 Dora.js**，仅供学习与研究。

- 请勿用于绕过付费墙、DRM、会员鉴权等
- 请勿用于聚合盗版内容
- 由使用者自行承担使用本技能产生的全部责任
- 所有被封装站点的内容版权归原站点所有

特别注意：GitHub 上流传的部分 Dora.js 插件涉及成人内容或盗版影视聚合，
**本仓库不包含、也不推荐此类用法**，README 中的合规红线章节即为明确边界。