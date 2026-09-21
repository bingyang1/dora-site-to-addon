# 13 · Dora.js 内部机制（安装 / 数据库 / 调试服务）

> 这一篇全是**实测逆向**出来的：Dora.js 1.8.1 / Android 15（ColorOS，Magisk root）。
> 用途：当「App 安装失败」「Live Sync 推不进去」「想无界面自动化」时，照着这篇定位。

---

## 1. 扩展在磁盘上的布局

```
/data/data/com.linroid.dora/
├── app_home/
│   ├── package.json                 # yarn 工作区根（@dora.js/home）
│   ├── .pnp.js  .yarn/  .yarnrc.yml  # Yarn PnP（依赖解析用）
│   └── addons/
│       └── <uuid>/
│           ├── src/                 # ★ 扩展源码（main.js / components/ / assets/ …）
│           │   └── .pnp.js          # 该扩展的 PnP 入口（装过依赖才有）
│           ├── data/                # 扩展运行时数据（$storage 等）
│           └── .yarnrc.yml
├── databases/dorajs.db              # ★ Room(SQLite)：扩展清单在这里
└── cache/temp/<sha256>/             # ★ push 上传的包先解到这里
```

判断扩展"装没装"看两处：**`app_home/addons/<uuid>/src/`** 和 **`dorajs.db` 的 `addons` 表**。
只放文件不写库 → 列表里不出现；只写库不放文件 → 列表里有、点开报错。

---

## 2. App 装一个扩展的 4 个步骤（实测）

```
① 建目录  app_home/addons/<uuid>/{data}
② 跑 yarn 装依赖（Node 15.5.0 + Yarn PnP）→ 生成 src/.pnp.js、.yarnrc.yml
③ 写入源码 src/（来自 .dora 里的 package/）
④ 写数据库 addons 表 → 这一步之后才会出现在扩展列表里
```

**典型失败**：卡在 ②③ 之间报错 → 目录建了、`src/` 空、数据库无记录 → 用户看到「能安装但报错」，列表里也没有。

> ⚠️ **Node 版本坑（最常见的安装失败原因）**
> Dora 运行时是 **Node 15.5.0**。`"cheerio": "^1.0.0-rc.12"` 现在会解析到 **1.2.0（要求 Node ≥ 20）**，
> 装依赖阶段直接失败。
> 对策二选一：
> - **写零依赖插件**（纯正则解析 HTML，本站点结构规整，实测完全够用）← 最稳
> - 或把依赖**锁死到 Node 15 能跑的版本**：`"cheerio": "1.0.0-rc.12"`（不要用 `^`）

---

## 3. `dorajs.db` —— 扩展清单是数据库行为，不是文件扫描

```sqlite
-- addons 表（19 列，除 search/installUrl 外全部 NOT NULL）
id, uuid, author, label, description, name, version, icon, prefs, main,
editing, sort, categories, from_npm, search, updatedAt, createdAt, colors, pinned, installUrl
```

| 列 | 说明 |
|---|---|
| `uuid` | 主键级标识；push/pull 都按它认领 |
| `label` | 手机列表里显示的名字（= displayName） |
| `editing` | **1 = 该扩展处于「编辑模式」**（长按图标进入编辑模式就是把这一列置 1） |
| `search` | 有全局搜索就填组件名，如 `search`（= contributes.search） |
| `colors` | JSON 字符串：`{"primary":"#ff2e7d32","titleText":"#ffffffff","bodyText":"#ffffffff"}` |
| `from_npm` | 本地安装填 0 |
| `icon`/`prefs`/`main` | 相对 `src/` 的路径，如 `assets/icon.png` |

相关表：`documents`（编辑器打开的文件）、`addon_usage`（启动统计：`addon_id, last_launch, launch_count`）。

**重要**：`/addon` 接口返回的列表来自**启动时读取 DB 构建的内存对象**，所以
**改完 DB 必须重启 App** 才会生效（单纯放文件不会自动扫描）。

---

## 4. 数据库安装法（不开 App 界面也能"装"扩展）

> ✅ 实测成立：装完 `/addon` 能列出、能进编辑模式、会被启动。

```bash
# 0) 备份（务必）
cp /data/data/com.linroid.dora/databases/dorajs.db* /sdcard/Download/_doradb/backup/

# 1) 停 App（释放数据库）
am force-stop com.linroid.dora

# 2) 拷出 DB → 在能跑 python3 的环境里改 → 拷回
#    （Android shell 没有 python3/sqlite3；Linux(proot) 有 python3 但默认看不到 /data/data）
cp /data/data/com.linroid.dora/databases/dorajs.db      /sdcard/Download/_doradb/
cp /data/data/com.linroid.dora/databases/dorajs.db-wal  /sdcard/Download/_doradb/ 2>/dev/null
cp /data/data/com.linroid.dora/databases/dorajs.db-shm  /sdcard/Download/_doradb/ 2>/dev/null
```

```python
# 在 Linux 环境里跑：checkpoint 把 WAL 合并进 .db，再插记录
import sqlite3, time
con = sqlite3.connect('/sdcard/Download/_doradb/dorajs.db')
con.execute('pragma wal_checkpoint(TRUNCATE)')
now = int(time.time() * 1000)
con.execute('delete from addons where uuid=?', (UUID,))
con.execute(
    'insert into addons (uuid,author,label,description,name,version,icon,prefs,main,'
    'editing,sort,categories,from_npm,search,updatedAt,createdAt,colors,pinned,installUrl) '
    'values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    (UUID, 'author', '显示名', '描述', '包名', '1.0.0',
     'assets/icon.png', 'assets/prefs.json', 'main.js',
     0, 1, '', 0, 'search', now, now,
     '{"primary":"#ff2e7d32","titleText":"#ffffffff","bodyText":"#ffffffff"}', 0, None))
con.commit()
con.execute('pragma wal_checkpoint(TRUNCATE)')   # 保证数据都在 .db 里
con.close()
```

```bash
# 3) 写回并修正属主（否则 App 写不进去）
cp /sdcard/Download/_doradb/dorajs.db /data/data/com.linroid.dora/databases/dorajs.db
rm -f /data/data/com.linroid.dora/databases/dorajs.db-wal \
      /data/data/com.linroid.dora/databases/dorajs.db-shm
chown 10379:10379 /data/data/com.linroid.dora/databases/dorajs.db   # 10379 = com.linroid.dora 的 uid
chmod 660        /data/data/com.linroid.dora/databases/dorajs.db

# 4) 放源码（属主也要对）
U=<uuid>; A=/data/data/com.linroid.dora/app_home/addons/$U
mkdir -p $A/src $A/data
cp -r <工程>/package/. $A/src/
chown -R 10379:10379 $A

# 5) 启动 → 验证
am start -n com.linroid.dora/.ui.DoraActivity
curl -s http://127.0.0.1:4000/addon     # 能看到就说明注册成功
```

验证要点：`/addon` 出现该 uuid；`addon_usage` 里出现它的启动记录；用户界面上能看到并进编辑模式。

> ✅ 这种"数据库安装"的扩展**能列表、能编辑、能运行，而且 Live Sync 一样能推得进去**
> （曾被误判为"推不进去"，已证伪 —— 真正的坑是 zip 的目录条目，见 §5）。

---

## 5. ⚠️ Live Sync 的 push 到底做了什么（实测）

### 5.1 成功时的完整日志链

push 本质上是**在手机上完整跑了一遍安装流程**（解包 → yarn install → 覆盖 `addons/<uuid>/src` → 写 DB），
只是目标 uuid 由 zip 里 `package.json` 的 `uuid` 字段决定。这些只有 `logcat` 看得到：

```
D Httpd: POST route=/addon, path=/addon, query=null
V File    : unzip /data/data/com.linroid.dora/cache/NanoHTTPD-1011688769963837911
                    -> /data/data/com.linroid.dora/cache/temp/<sha256>
I AddonManager: install from directory: /data/user/0/com.linroid.dora/cache/temp/<sha256>
I AddonManager: yarn install: src=/data/user/0/com.linroid.dora/cache/temp/<sha256>
I NodeShell[yarn]: exec: yarn install --disable-pnp --cache-folder .../app_home/.yarn \
      --link-folder .../app_home/.bin --prefix .../app_home --cwd <temp> \
      --ignore-scripts --emoji true --no-lockfile --registry https://registry.npmmirror.com
I AddonManager: yarn install finished
I AddonManager: updating existing addon: Addon(id=6, uuid=03535c54-..., editing=true, ...)
I Httpd: install success: addon=Addon(id=6, uuid=03535c54-..., ...)
```

> 注意里面那行 `--registry https://registry.npmmirror.com` —— App 现在用的是 npmmirror（淘宝源已废弃）。
> 另外整个 `yarn install` 在零依赖工程上是**零耗时**的（`yarn install v1.23.0` 后立刻 `finished`），
> 所以**把插件写成零依赖是最省事、最不容易翻车的做法**（见 `10-npm-ecosystem.md`）。

### 5.2 失败时的日志，以及**真正的根因**

```
D Httpd: POST route=/addon, path=/addon, query=null
E Httpd: Failed to install addon
E Httpd: java.io.IOException: No such file or directory
E Httpd:   at java.io.File.createNewFile(File.java:1022)
E Httpd:   at ...FilePackageProvider.kt:1
E Httpd:   at ...PackageProvider.kt:8
E Httpd:   at ...service.vscode...Httpd.kt:9
I Httpd: install success: addon=kotlin.Unit      ← 失败也打 "success"，也回 {"code":0}
```

**根因：zip 里没有「目录条目」。**

> ❌ 此前记的"对**手工塞数据库装出来的扩展**会推失败"是**错误结论，已被证伪** ——
> 实测同一台机器、同一个**数据库安装的**扩展（uuid `03535c54-...`），把 zip 补上目录条目后
> push **完整生效**（`src/` 整棵树被替换，md5 与工作区逐字节一致）。

机理（详见 `12-live-sync.md` §2.4）：解包器只对**目录条目**执行 `mkdirs()`，
对**文件条目**直接 `File(root, "assets/icon.png").createNewFile()`。于是：

1. `main.js` / `package.json` / `README.md` 这些**根文件能解出来** →
   所以 `cache/temp/<sha256>/` 里**只有这 3 个文件**（`assets/`、`components/` 整个消失，这是最直接的判据）；
2. 一碰到第一个子目录条目（`assets/icon.png`）→ 父目录不存在 → ENOENT → **整个安装中止**；
3. 最终 `addons/<uuid>/src` **一个字节都没改**，而 HTTP 返回 `{"code":0}`。

⇒ **`code:0` 完全不可信，必须验证文件是否真的变了。**

### 5.3 怎么判断 push 到底成没成

```bash
# 1) 看 App 自己的日志（唯一能看到真相的地方）
logcat -d --pid $(pidof com.linroid.dora) | grep -E 'Httpd|AddonManager'
#    成功的标志：出现 "updating existing addon: Addon(" 且 addon 不是 kotlin.Unit

# 2) 看文件有没有真的变（推一个含"标记字符串"的版本，再 grep）
grep -c 'MY-MARKER' /data/data/com.linroid.dora/app_home/addons/<uuid>/src/main.js

# 3) 看解包目录里有没有子目录（最快的判据：只有 3 个根文件 = 必失败）
ls -R /data/data/com.linroid.dora/cache/temp/$(ls -t /data/data/com.linroid.dora/cache/temp | head -1)

# 4) 看 mtime
ls -l /data/data/com.linroid.dora/app_home/addons/<uuid>/src/main.js
```

> ❌ 不要用「push 返回 code:0」当作成功依据。
> ❌ 也不要用「推一份刚从手机 pull 下来的原样内容」来验证 —— 文件内容本来就一样，看不出效果。
> ✅ 最稳的验证：**给自己加一行唯一标记**（如 `// SYNC-TEST-<时间戳>`）再推，然后 md5 + grep 双查。

### 5.4 想用 push 的正确姿势

- 目标扩展的 uuid 必须**已经在手机上**（装 `.dora` 包 / 手机端「创建扩展」/ **数据库安装法**，三者都行）；
- 打包出的 zip **必须带目录条目**（`scripts/dora-sync.sh push` 已内置，并会在缺条目时直接报错退出）；
- 推送时 App 需在**前台**（否则连不上，见 `12-live-sync.md` §4）；
- 推完**用 §5.3 的方法确认落地** —— 永远不要看返回码。

---

## 6. 无界面自动化小抄（root/Shizuku）

```bash
# 拉起调试服务（等价于 App 里点「连接 VSCode」）
# 只解决"端口有没有"，解决不了"push 推给谁"
am startservice -n com.linroid.dora/.service.vscode.VSCodeService
curl -s http://127.0.0.1:4000/ping          # → pong

# 重启 App 后服务会掉（force-stop 会清掉），按需重新拉起
am force-stop com.linroid.dora
am start -n com.linroid.dora/.ui.DoraActivity

# 让 App 前台（否则 4000 端口连不上 —— 后台冻结，见 12-live-sync.md §4）
# 组件入口只有 DoraActivity 一个：
#   com.linroid.dora/.ui.DoraActivity
# .dora 文件投递到安装界面（系统默认会被 alook/MT/WPS 抢单，必须 -n 指定）
am start -a android.intent.action.VIEW -c android.intent.category.DEFAULT -t '*/*' \
  -d "file:///sdcard/Download/xxx.dora" -n com.linroid.dora/.ui.DoraActivity
# → logcat 会看到：DoraActivity: Navigated to com.linroid.dora:id/installerFragment

# 查端口属主：0FA0 = 4000（hex），行尾的 uid 就是属主
grep -i ':0FA0' /proc/net/tcp6

# 拷出数据库（读清单/排错用）；Android shell 没有 python3/sqlite3，
# 要读内容就拷到 /sdcard 再用 Linux 环境的 python3
cp /data/data/com.linroid.dora/databases/dorajs.db* /sdcard/Download/_doradb/
```

---

## 7. 安全 / 风险提示

- 手工改 `dorajs.db` 属于**改 App 私有数据**：动手前**先备份**（`databases/` 三个文件一起拷）。
- `chown/chmod` 别忘：DB 必须属于 App 的 uid（本例 `10379`），否则 App 写入失败甚至更糟。
- 改完 DB 一定要 `pragma wal_checkpoint(TRUNCATE)`，并把 `-wal/-shm` 删掉，
  避免 App 读到过期 WAL。
- 本文所有操作都在**自己的设备**上做逆向调试，不要用于绕过付费/授权。
