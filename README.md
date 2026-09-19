# Navidrome for TOS 7

把 [Navidrome](https://github.com/navidrome/navidrome)（自托管音乐服务器/串流）
打包成 TerraMaster TOS 7 应用中心规范的 deb 包。

## 模式

- **WebUI External Open（新标签页）**：桌面图标点击后经 `http://<NAS的IP>:8181/navidrome/`
  在新标签页打开（`open_path: true`，无 `type` 字段）
- **全回环**：后端仅监听 `127.0.0.1:8453`，不对外开端口，流量全部经平台 nginx 路由
- **保留前缀转发**（metube 同款）：`proxy_pass http://127.0.0.1:8453/navidrome/` +
  二进制 `--baseurl /navidrome` 原生子路径运行，SPA/Subsonic API/分享链接全自洽
- **双落盘**：`init.d/`、`nginx/` 满足平台注册；同时以 dpkg 实体文件放
  `/etc/systemd/system/`、`/etc/nginx/conf.d/`，systemd/nginx 直接加载
- 二进制取自官方 Release（sha256 校验），Go 静态编译零运行时依赖

## 使用

```bash
./build.sh            # fetch → stage → verify → deb 一条龙
make check            # 语法与资产静态自检
./build.sh info       # 查看当前配置
```

产物（`out/`）：

- `navidrome_<版本>_<arch>.deb` — 本地安装/测试用
- `navidrome_<platform>.deb` + `.sha256` — 上架 Release 资产（Release tag = `v<完整版本>`）

改配置：编辑 `config.env`（上游版本/迭代号/架构/维护者），重新 `./build.sh`。

## 升级上游版本

1. `config.env` 里改 `NAVIDROME_VERSION`
2. `./build.sh distclean && ./build.sh`
3. `.lang` 与 `changelog` 中的版本号文案同步更新
4. `PKG_RELEASE` 视情况从 `-1` 重新计数

## 目录

```
config.env   打包配置（版本/架构/维护者）
build.sh     四阶段构建（fetch/stage/verify/deb）
makedeb.sh   无 dpkg 依赖的极简 deb 打包器（ar + Python tarfile）
scripts/     资产静态自检
assets/      config.ini / control / lang / 图标 / nginx / systemd / 生命周期脚本 / webui 占位页
```

## 真机验证

见 `~/Documents/projects/TOS-DEB-PACKAGING-GUIDE.md` 第五节清单
（TOS web 端口 8181；测试机 `ssh tnas-57`）。
