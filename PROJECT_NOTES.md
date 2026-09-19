# Navidrome for TOS 7 — 项目笔记

## 基本信息

| 项 | 值 |
|---|---|
| app_id / 包名 | `navidrome` |
| 上游 | https://github.com/navidrome/navidrome |
| 打包版本 | 0.64.0-3（Release tag: `v0.64.0-3`） |
| 模式 | WebUI External Open（新标签页）+ 全回环（127.0.0.1:8453） |
| 类目 | `Audio_Video_Entertainment`（官方 10 类之一） |
| 维护者 | Moechz <moechz@users.noreply.github.com> |

## 架构决策

1. **保留前缀转发**（metube 同款，非 beszel 的剥离模式）：
   `proxy_pass http://127.0.0.1:8453/navidrome/` + 二进制 `--baseurl /navidrome`。
   Navidrome 官方支持子路径（`ND_BASEURL`），SPA/Subsonic API/分享链接全自洽。
2. **ExecStart 写死安全参数**：`--address 127.0.0.1 --port 8453 --baseurl /navidrome
   --musicfolder/--datafolder/--cachefolder`。Navidrome 优先级为
   **环境变量 > 命令行参数 > 配置文件**（官方文档明确），因此：
   - env 文件被误删 → 仍仅回环监听（flag 兜底）
   - 用户要改端口/目录 → 在 `navidrome.env` 写 `ND_PORT`/`ND_MUSICFOLDER` 即可覆盖
   - flag 名来自上游 `cmd/root.go`：`--address/-a --port/-p --baseurl --musicfolder --datafolder --cachefolder`
3. **目录布局**：DB `/var/lib/navidrome/data`，缓存 `/var/lib/navidrome/cache`，
   音乐 `/var/lib/navidrome/music`（env 可指向共享文件夹）。
   ⚠️ 上游官方 deb 的 DB 在 `/var/lib/navidrome/` 根目录——同名包升级时旧库
   不会自动接管，postinst 检测到会打印 ND_DATAFOLDER 提示（不搬数据）。
4. **与上游 deb 的关系（坑 10）**：上游 goreleaser 的包名也是 `navidrome` →
   同名包，dpkg 视为升级，天然无文件互踩；**不能也不需要 Conflicts 自身**。
   上游 Depends: ffmpeg（硬依赖）；我们用 **Recommends: ffmpeg**（TOS 用
   Ubuntu jammy 源，apt 装包实测会自动带装 ffmpeg；商店路径忽略时 postinst
   有提示兜底，直连播放不依赖 ffmpeg）。
5. **图标**：官方 logo SVG 在 website 仓库 `assets/icons/logo.svg`
   （viewBox 恰为 0 0 512 512、透明背景），直接采用。
6. **语言文件**：14 种全部人工翻译（含 hu/tr/pt 等）。

## 真机踩坑记录（tnas-57, TOS x86_64）

| 现象 | 根因 | 修复 |
|---|---|---|
| `location = /navidrome` 的 301 Location 为 `http://127.0.0.1/navidrome/`（丢 8181 端口，浏览器会被踢到 80） | TOS nginx 对 `return` 构造绝对 URL 时未带端口（`$host` 不含端口） | location 内加 `absolute_redirect off;` → 输出相对 Location `/navidrome/` |
| Subsonic API 返回的 `artistImageUrl` 等绝对链接丢端口 | nginx 传 `Host $host`（不含端口），Navidrome 按 Host 生成绝对 URL | 改传 `Host $http_host`（带端口） |
| HEAD 请求 405 | Navidrome 只支持 GET（官方行为，非故障） | 验证脚本用 GET |

## 真机验证结论（2026-09-16, tnas-57）

- ✅ 安装：干净，postinst 输出引导信息；ffmpeg 经 Recommends 自动安装
- ✅ 服务 active + enabled（reinstall 升级路径后依然 enabled，坑 3 防住）
- ✅ 回环直连 `127.0.0.1:8453/navidrome/` → 302 → `/navidrome/app/` 200（title: Navidrome）
- ✅ 平台路由 `127.0.0.1:8181/navidrome/` → 同上 200
- ✅ 无尾斜杠 `/navidrome` → 301 相对 Location → 200
- ✅ 端口封闭：`ss` 仅 127.0.0.1:8453 监听；外部地址连接拒绝
- ✅ nginx -t 通过；conf.d 双落盘生效（beszel 共存无冲突）
- ✅ E2E：ffmpeg 造测试 MP3 → Watcher 自动扫描入库 → 创建管理员（首访）→
  Subsonic `getArtists`/`search3` 列出 → `stream.view` 经路由下载完整有效 MP3
- ✅ remove：服务停、数据/用户保留；重装后管理员与歌曲无缝恢复
- ✅ purge：数据/用户/unit/nginx conf 全清（index.html 占位页残留在 postrm 补清）

## 上游版本升级流程

1. `config.env` 改 `NAVIDROME_VERSION`（tarball 资产名带版本号：
   `navidrome_<ver>_linux_<arch>.tar.gz`，checksums 文件名固定 `navidrome_checksums.txt`）
2. `.lang` 与 changelog 中的版本号文案同步
3. `./build.sh` → 真机按 README 清单回归
4. arm64 机型：`TARGET_ARCH=arm64` 出包（上游有 linux_arm64 资产）

## 待办 / 边界

- [ ] TOS 桌面图标点开行为（需人工在桌面确认；apt 安装按 beszel 经验会出现图标）
- [ ] 上游 deb → 本包的真实迁移路径仅做了提示未做数据搬迁（少见场景）
- [ ] Insights 匿名统计保持上游默认开启；用户可在 env 关（已写注释）

## 2026-09-16 真机验证记录（tnas-57）

- 0.64.0-1 完整 E2E 通过：安装/服务/路由 8181→8453/建号/扫描/流媒体/卸载保留数据/purge
- **应用中心安装卡 59% 事件**：dpkg 完成后 TOS 注册环节静默挂起（oexe 不生成）。
  `restart application` + 刷新页面后注册自动补完，应用用户出现在共享文件夹权限列表。
  已写入打包指南坑 11（含定位方法：link/unlink 是背景噪音）
- **-2 变更**：显示名改 "Navidrome Music Server"（.lang 14 语言 + webui title），
  避开商店 NavidromeDocker 同名（坑 12）。sha256 42dabc01…

## 2026-09-16 按最新指南合规审计（-3）

- 逐条对照指南 14 坑 + §一/§二全部硬性项审计：主体合规
  （双落盘、init.d 单单元、无 conffile、ExecStart 无 $、prerm 条件 disable、
  nginx 前缀保留 + absolute_redirect off + Host $http_host、COPYFILE_DISABLE、
  webui 含 html、14 语言、图标 viewBox 实测合规、Docker 字样零残留）
- 补 3 处：postinst 提示文案同步显示名；构建期新增「版本三处一致」断言
  （.lang version 渲染值 + control.in 占位符行）与图标 viewBox 断言（check_assets）
- 清理 assets 残留 .DS_Store；-3 产物 sha256 93bd3f4e…（NAS: /tmp/navidrome-3.deb）
