# 12 · 真机联调（Live Sync）

> 改一行代码 → 手机上立刻生效。**不需要 VSCode，不需要电脑，不需要 WiFi。**
>
> 本文协议逆向自官方 VSCode 插件 [`DoraKit/vscode-extension`](https://github.com/DoraKit/vscode-extension)
> （`src/connector.ts` / `src/extension.ts`），并在 **Android 15 + Dora.js 1.8.1** 上全部实测通过。

---

## 0. 一句话原理

Dora.js 内置了一个 **HTTP 服务，监听 `4000` 端口**。
官方 VSCode 插件只是个 **http 客户端**：拉列表 → 拉源码 → 推源码。

所以只要你能发 HTTP 请求，你就是那个插件 ——
而 AI 工具跑在**同一台手机上**，直接打 `127.0.0.1:4000` 就行。

```
VSCode 插件  ──HTTP──▶ 手机:4000  ──▶  Dora.js 扩展文件
我/curl      ──HTTP──▶ 127.0.0.1:4000 ──┘   （同一台机器，连 WiFi 都不用）
```

---

## 1. 协议全貌（4 个接口，实测结果）

| 方法 | 路径 | 作用 | 实测 |
|---|---|---|---|
| `GET` | `/ping` | 探活，返回**裸文本** `pong`（不是 JSON） | ✅ HTTP 200 / `pong` |
| `GET` | `/addon` | 列出全部扩展（JSON 数组） | ✅ 返回 3 条完整元数据 |
| `GET` | `/addon/<uuid>?pull` | 拉取该扩展源码，返回 **zip 二进制** | ✅ 13295 字节 / 14 个文件 |
| `POST` | `/addon` | 推送源码，`multipart/form-data`，**字段名必须是 `file`** | ✅ `{"code":0,"message":""}` |

`/addon` 单条记录的字段：

```json
{
  "id": 4,
  "uuid": "20c2a41b-0272-4b42-9c03-0e08bd700541",
  "author": "pal",
  "displayName": "demo",
  "description": "没有描述",
  "name": "dorajs-demo",
  "version": "1.0.0",
  "icon": "assets/icon.png",
  "main": "main.js",
  "categories": [],
  "r": { "primary": "#387002", "titleText": "#000000", "bodyText": "#000000" }
}
```

> `uuid` 是**推送/拉取的唯一标识**。`displayName` 是手机上显示的名字。
> 「推送成功」的判据是响应里的 `code == 0`（成功后手机端会提示「xxx 已更新」）。

---

## 2. ⚠️ 必须知道的格式与行为约定（4 条）

### 2.1 联调 zip 是「平铺」的，**不要有 `package/` 前缀**

| | 目录结构 | 用途 |
|---|---|---|
| `.dora` 安装包 | **必须** `package/package.json` 开头 | 安装到 Dora.js |
| 联调 zip（pull/push） | **平铺**：根目录直接是 `main.js`、`components/`、`package.json` | 改代码热更新 |

官方插件打包代码是 `archiver.glob('**/*', { cwd: srcFolder, ignore: ['node_modules/**'] })` ——
**没有前缀，且排除 `node_modules`**。你给它一个带 `package/` 前缀的包，扩展目录会被套一层 `package/`，直接废掉。

> 📌 顺带记清楚两种容器的**文件格式也不同**（用 `head -c 8 | od -An -tx1` 一眼可辨）：
>
> | 产物 | 真实格式 | 构造方式 |
> |---|---|---|
> | `.dora` 安装包 | **`tar.gz`**（magic `1f 8b 08 00`） | `tar -czf out.dora -C <dir> package` |
> | 联调 push 的包 | **`zip`**（magic `50 4b 03 04`） | 见 §2.4（**必须带目录条目**） |
>
> 所以 `.dora` **不是 zip**，别用 `unzip`/`zipfile` 去读它（会报 `BadZipFile`），要用 `tar tzf`。
> `tar` 天然会写入目录条目，这也是 `.dora` 手动安装从来没踩过 §2.4 那个坑的原因。

### 2.2 联调工程根目录 = 一个带 `uuid` 的平铺工程

`pull` 出来的目录就是工程根，`package.json` 里必须有 `uuid`（推送时靠它认领目标扩展）。
升级版本号要**手动改** `version`，服务端不会自动加。

### 2.3 ⚠️ push 只能「更新」已存在的扩展（实测踩坑）

用**全新的 uuid** push，服务端会老老实实返回 `{"code":0,"message":""}`，
但 `/addon` 列表里**不会出现**这个扩展 —— 它被静默忽略了。**成功码 ≠ 真的生效。**

所以流程必须是「**先装包，再联调**」：

```bash
sh scripts/build_dora.sh <工程目录>      # 产出 xxx-v1.0.0.dora
# → 在手机上用 Dora.js 打开该文件安装（或手机端「创建扩展」）
sh scripts/dora-sync.sh list             # 能看到自己的 uuid 之后，push 才有意义
sh scripts/dora-sync.sh push <工程目录>   # 之后就是秒级热更新
```

`dora-sync.sh push` 现在会自动检查 uuid 是否存在并给出警告。

### 2.4 ★★★ 头号大坑：zip 里必须带「目录条目」

**这是本项目最贵的一个坑** —— 曾经让我把原因误判成"数据库安装的扩展不能热推"，
白白绕了半天。真正的原因是 zip 的构造方式。

Dora 的解包器（`FilePackageProvider`）处理 zip 条目时分两种：

| zip 条目类型 | App 的行为 |
|---|---|
| **目录条目**（名字以 `/` 结尾，如 `assets/`） | `mkdirs()` ✅ |
| **文件条目**（如 `assets/icon.png`） | 直接 `File(rootDir, "assets/icon.png").createNewFile()` ❌ 父目录不存在就抛 ENOENT |

⇒ 只要 zip 里有子目录文件、却没有对应的**目录条目**，App 就会在第一个子目录文件处抛
`java.io.IOException: No such file or directory`，**整个安装中止** —— 而 HTTP 照样返回 `{"code":0}`。

实测对比（同一份工程，只改 zip 里有没有目录条目）：

| zip 怎么打的 | 解包到 `cache/temp/<sha256>/` | 扩展目录 |
|---|---|---|
| Python `zipfile.write()`（**无**目录条目） | 只有 `main.js` / `README.md` / `package.json` 三个根文件；`assets/`、`components/` **整个消失** | 纹丝不动 ❌ |
| 带目录条目（`assets/`、`components/` 排在最前） | 全部条目正确解出 | `src/` 被**整棵树替换**，md5 与工作区逐字节一致 ✅ |

⚠️ **Python 的 `zipfile.write()` 不会自动生成目录条目**；
而 `zip -r`、`tar`、Node 的 `archiver`（官方 VSCode 插件用的就是它）都会自动生成。
自己写打包脚本时最容易踩这里 —— 而且踩了完全看不出来（返回码是 0）。

```python
# ✅ 正确：先写目录条目，再写文件
import os, stat, zipfile
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in {"node_modules", ".git"})
        for d in dirs:                                    # ① 目录条目
            rel = os.path.relpath(os.path.join(root, d), src) + "/"
            zi = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            zi.create_system = 3
            zi.external_attr = (stat.S_IFDIR | 0o755) << 16
            zi.compress_type = zipfile.ZIP_STORED
            z.writestr(zi, b"")
        for f in sorted(files):                           # ② 文件条目
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))
```

`scripts/dora-sync.sh push` 已内置该逻辑，并在打包后**自检**（缺目录条目直接报错退出，
不让你在"假成功"上浪费时间）：

```
· 打包（平铺 zip + 目录条目，排除 node_modules/.git/.vscode）…
  zip: 10 文件 + 2 目录条目
✓ 推送成功（手机端应提示「xxx 已更新」）
```

> 补充结论：**手工塞数据库装出来的扩展，热推一样能推**（见 `13-app-internals.md` §4）。
> 之前"数据库安装的扩展推不动"的判断已被证伪，真正原因就是本节这条。

### 2.5 ⚠️ 失败也返回 `code:0`（成功码不可信）

解包中止、`yarn install` 报错、uuid 不存在 —— 任何一种失败，App 都**只把错误打进 logcat**，
**HTTP 依然返回 `{"code":0,"message":""}`**，甚至日志里还会写一句
`install success: addon=kotlin.Unit`（`kotlin.Unit` 就是"空对象"，是失败的特征）。

⇒ **验证 push 必须看文件，不能看返回码**：

```bash
# 唯一能看到真相的入口（务必按 pid 过滤，否则会被别的日志淹）
logcat -d --pid $(pidof com.linroid.dora) | grep Httpd

# 推一个带「标记字符串」的版本，再 grep 目标文件
grep -c 'MY-MARKER' /data/data/com.linroid.dora/app_home/addons/<uuid>/src/main.js
```

> ❌ 反面教材：拿一份**刚从手机 pull 下来的原样内容**去 push，然后看 `code:0` 就以为成功 ——
> 文件内容本来就一样，这种"验证"毫无意义（我第一次就是这么被骗的）。

磁盘布局 / DB 表结构 / 装扩展的 4 步 / **数据库安装法**：见 **`13-app-internals.md`**。

---

## 3. 怎么把服务开起来

1. Dora.js → **长按扩展图标** → 右上角菜单 → **「连接 VSCode」**
2. 服务启动，监听 `[::]:4000`（双栈，IPv4/IPv6 都能连）
3. 关闭该模式 → 端口消失

检测（Android shell / Shizuku 均可）：

```bash
netstat -tln | grep 4000
# 或直接看十六进制：0FA0 = 4000，最后一位是属主 uid
grep -i ':0FA0' /proc/net/tcp6
# → 10379 对应 u0_a379，即 com.linroid.dora
```

---

## 4. ⚠️ 最大的坑：Dora 一进后台，TCP 直接超时

**现象**：端口明明在 LISTEN，`curl` 却得到 `HTTP=000` / `Connection timed out`
（不是 404，不是 connection refused，而是**超时**）。

**原因**：Dora 被切到后台，进程被系统冻结/限制，socket 挂在 backlog 里没人 `accept()`。

**判据**：

```bash
PID=$(pidof com.linroid.dora); cat /proc/$PID/cgroup | head -3
#   cpuset:/background   ← 就是这个坑
#   cpuset:/foreground   ← 正常，秒回 pong
# 有时 ps 里还会看到 STAT 列写着 do_freezer_trap
```

**解法（任选，实测都有效）**：

```bash
# A. 一行命令拉回前台（Shizuku / adb shell 即可，不需要 root）
am start -n com.linroid.dora/.ui.DoraActivity
#   → 之后立刻 pong [HTTP=200]，同一个 socket、同一个 IP
```

- B. 把 Dora 和你的编辑器**分屏/小窗**，让它保持可见
- C. 用 PC 上的 VSCode 插件也一样：**每次 push 前先确保 Dora 在前台**，否则推送静默超时

> 这就是为什么脚本里要把「先 `am start` 再 `curl`」串成一条命令 ——
> 你去 Operit/别处看消息的瞬间，Dora 就被冻住了。

---

## 5. 三条连接路线（全部实测连通）

| 路线 | 地址 | 需要 WiFi | 适合 |
|---|---|---|---|
| 本机 loopback | `http://127.0.0.1:4000` | ❌ | 手机上的 AI / 脚本（**推荐**） |
| IPv6 loopback | `http://[::1]:4000` | ❌ | 同上（服务监听 `[::]`） |
| 局域网 | `http://192.168.x.x:4000` | ✅ | PC 上的 VSCode 插件 |

> 只影响**连接地址**，不影响「必须前台」这条要求。

---

## 6. 零依赖上手（纯 curl）

```bash
# 0) 探活 → 期望裸文本 pong
curl -s -m 3 http://127.0.0.1:4000/ping

# 1) 列扩展，拿 uuid
curl -s http://127.0.0.1:4000/addon

# 2) 拉源码（uuid 从上面拿）
UUID=20c2a41b-0272-4b42-9c03-0e08bd700541
curl -s -o demo.zip "http://127.0.0.1:4000/addon/$UUID?pull"
mkdir -p demo && unzip -o demo.zip -d demo     # 平铺解压，demo/ 就是工程根

# 3) 改代码，然后推回去（字段名必须是 file）
cd demo && zip -qr ../demo.zip . -x 'node_modules/*'
curl -s -F "file=@../demo.zip" http://127.0.0.1:4000/addon
#   → {"code":0,"message":""}
```

---

## 7. 用脚本（推荐）

```bash
SKILL=/sdcard/Download/Operit/skills/dora-site-to-addon
SH="$SKILL/scripts/dora-sync.sh"

sh "$SH" ping                       # 探活（连不上会自动尝试把 Dora 拉前台）
sh "$SH" list                       # 列扩展（名称 / 版本 / 作者 / 包名 / uuid）
sh "$SH" pull demo                  # 拉 demo 扩展到 ./demo（也可直接给 uuid）
sh "$SH" push ./demo                # 打包（平铺 zip）并推送
sh "$SH" watch ./demo               # 盯着目录，一改就推（≈ 官方 autoPush）
```

配套环境变量：`DORA_HOST`（默认 `127.0.0.1`）、`DORA_PORT`（默认 `4000`）、`DORA_FG`（默认 `1`，`0` = 不自动前台化）。

### 7.1 ⚠️ 两个执行环境的差异（脚本会自动降级）

| 环境 | 有 | 没有 | 能干什么 |
|---|---|---|---|
| **Android shell**（Shizuku/Root） | `am` `curl` `unzip` `tar` `md5sum` | `zip` `python3` | `ping` / `list` / `pull` / **`foreground`**；`push` 需外部打好 zip |
| **Linux 终端**（proot Ubuntu） | `curl` `unzip` `python3`（含 `zipfile`） | 看不到 `/system/bin` → **没有 `am`** | `pull` / `push` / `watch`；**无法自动前台化** |

**组合拳（最稳）**：

```bash
# 1) Android shell 侧：把 Dora 拉前台
am start -n com.linroid.dora/.ui.DoraActivity

# 2) Linux 终端侧：拉/推/自动推
sh "$SKILL/scripts/dora-sync.sh" watch ./my-addon
```

`sh dora-sync.sh ping` 在 Linux 环境里失败时，会打印上面这行 `am start` 提示。

---

## 8. 和 PC 上的 VSCode 插件并存

- 插件名：Marketplace 搜 `Dora.js`（`linroid.dora`）
- 配置：`dorajs.host` = 手机 IP（如 `192.168.5.49`，端口写死 4000）；`dorajs.autoPush` 建议设成 `workspace`，只在扩展工程里自动推
- 用法：左侧 Dora.js 图标 → `Connect Dora.js` → 选扩展 + 本地目录 → 改完点纸飞机
- 流程和本文完全一致（它 pull 出来也是**平铺**目录、push 也是**平铺 zip**）

> ⚠️ **不要两边同时推同一个扩展**，会互相覆盖。
> ⚠️ VSCode 那边同样受「Dora 必须在前台」约束。

---

## 9. 安全须知（务必转达用户）

- 4000 端口**无鉴权、明文 HTTP**：同一局域网内任何人可以读你所有扩展源码、往手机推任意代码
- 公共 WiFi / 公司网络**不要**开「连接 VSCode」；用完即关
- 本机 `127.0.0.1` 相对安全，但仍是明文
- 不要把这个服务通过端口转发（`adb forward` / 内网穿透）暴露到公网

---

## 10. 实测记录（供复核）

| 项目 | 结果 |
|---|---|
| 端口属主 | `/proc/net/tcp6` 中 `:0FA0` → uid `10379` = `u0_a379` = `com.linroid.dora` ✅ |
| `GET /ping` | `pong`，HTTP 200 ✅ |
| `GET /addon` | 3 条扩展（demo / 扩展检索 / 示例扩展）✅ |
| `GET /addon/<uuid>?pull` | 13295 字节 zip，14 个文件（`main.js` `components/` `assets/` …）✅ |
| `POST /addon` | `{"code":0,"message":""}` ✅ |
| 后台冻结复现 | Dora 在 `cpuset:/background` 时 `127.0.0.1` / `::1` / 局域网**三个地址全部超时**；`am start` 后**三个地址全部 200** ✅ |
| 脚本自测 | `ping` / `list` / `pull`（按名称解析 uuid）/ `push`（平铺 zip + 目录条目）全部通过 ✅ |
| **未知 uuid 的 push** | 返回 `{"code":0,"message":""}` 但 `/addon` 列表**不变** —— 静默忽略，**成功码 ≠ 生效** ✅（见 §2.3） |
| **zip 不带目录条目**（Python `zipfile.write()`） | 解包目录里**只剩 3 个根文件**（`main.js` `README.md` `package.json`），`assets/`、`components/` 整个消失；扩展目录**纹丝不动**；HTTP 仍 `code:0`，日志 `Failed to install addon` + `java.io.IOException: No such file or directory` ❌（见 §2.4） |
| **zip 带目录条目**（同一份工程） | 13 个条目全部解出；`src/` **整棵树被替换**，`main.js` / `components/list.js` / `package.json` 的 md5 与工作区**逐字节一致**；新增文件 `src/assets/pushtest-marker.txt` 也正常落地；日志 `AddonManager: updating existing addon: Addon(id=6, …, editing=true)` 紧跟 `Httpd: install success: addon=Addon(...)` ✅ |
| **数据库安装的扩展照样能热推** | 目标扩展（uuid `03535c54…`）是**手工塞 `dorajs.db` 装出来的**，push 依然完整生效 ✅ —— **推翻**此前"数据库安装的扩展不支持热推"的错误结论 |
| `.dora` 容器格式 | **gzip tar**（magic `1f 8b 08 00`），`tar tzf` 可见 `package/` 前缀；**不是 zip** ✅ |
| **push 的完整日志链** | `Httpd POST route=/addon` → `File: unzip <cache/NanoHTTPD-xxx> -> cache/temp/<sha256>` → `AddonManager: install from directory` → `yarn install --disable-pnp … --registry https://registry.npmmirror.com` → `AddonManager: updating existing addon` → `Httpd: install success` ✅ |

---

## 11. 一页速查

```
地址        http://127.0.0.1:4000          （PC 上用 手机IP:4000）
探活        GET  /ping                      → pong
列表        GET  /addon                     → JSON 数组
拉源码      GET  /addon/<uuid>?pull         → zip（平铺）
推源码      POST /addon  (file=xxx.zip)     → {"code":0}
密钥        uuid（在 package.json 里）
开关        Dora.js 长按扩展 → 右上角「连接 VSCode」
铁律①      Dora 必须在**前台**，否则 TCP 超时 → am start -n com.linroid.dora/.ui.DoraActivity
铁律②      zip 必须**平铺**（不要 package/ 前缀），排除 node_modules
铁律③      zip 必须带**目录条目**（assets/ components/），否则子目录文件全丢 → ENOENT；★最易踩，见 §2.4
铁律④      push 只能更新**已存在**的扩展；首次务必先装 .dora，否则 code:0 也是假的
铁律⑤      code:0 不代表成功 —— 验证要看文件 md5 / 标记字符串 / logcat，不看返回码
脚本        scripts/dora-sync.sh  ping|list|pull|push|watch|foreground
```
