# Codex Deepin 任务栏插件

适用于 Deepin 23.1 的 `dde-shell` 原生任务栏 Applet。把 Codex 任务繁忙度、额度剩余百分比、CPU、内存、根分区磁盘占用和上下行网速显示在任务栏左侧。插件与任务栏同层渲染，不创建悬浮窗口。

## 指示灯

| 颜色 | 含义 |
| --- | --- |
| 绿色 | 0 个本地 Codex 任务运行中 |
| 黄色 | 1 个本地 Codex 任务运行中 |
| 红色 | 2 个及以上本地 Codex 任务运行中 |
| 灰色 | 无法读取本地任务状态 |

Codex 后面的百分比始终表示账号额度剩余，与指示灯颜色无关。鼠标悬停可看运行任务数和网络接口。各项指标占用固定宽度，数值右对齐；网速超过栏宽时会省略末尾字符；单元格宽度可在 `package/main.qml` 中调整。

任务数每 3 秒更新，读取当前用户 `~/.codex/state_5.sqlite` 中最近更新的线程，并根据相应 JSONL 会话记录中的 `task_started`、`task_complete`、`turn_aborted` 事件判断。为避免异常退出后长期显示繁忙，超过 10 分钟未更新的记录不计入。它统计本机 Codex CLI、桌面端及编辑器写入同一 `CODEX_HOME` 的任务；远端云任务或未写入本机记录的任务不在统计范围内。

额度剩余通过 `codex app-server` 的 `account/rateLimits/read` 每 60 秒刷新。网络接口取系统默认路由。网速中的 `K/s`、`M/s`、`G/s` 分别为 KiB/s、MiB/s、GiB/s 的紧凑写法。

## 安装

压缩包内附有针对 Deepin 23.1、`dde-shell 1.0.10` 的预编译模块。解压后在项目目录运行：

```bash
./install.sh
```

安装到当前用户的 `~/.local` 目录，写入 `dde-shell@DDE.service` 的用户级插件路径配置并重启任务栏。

其他 `dde-shell` 版本请先安装开发依赖并重新编译：

```bash
sudo apt install g++ pkg-config libdde-shell-dev libdtk6core-dev qt6-base-dev qt6-base-dev-tools
./build.sh
```

预编译模块仅对 `dde-shell 1.0.10` 做了兼容性验证。

## 卸载

```bash
./uninstall.sh
```

## 项目文件

- `src/codexdock.cpp`：Qt6/DDE Applet，读取系统资源并启动状态采集进程。
- `package/main.qml`、`package/metadata.json`：任务栏条状界面及插件元数据。
- `scripts/codex-activity.py`：本地运行任务计数。
- `scripts/codex-rate-status.py`：Codex 额度剩余百分比。
- `dist/org.deepin.ds.dock.codexstats.so`：已验证的预编译模块。
- `build.sh`、`install.sh`、`uninstall.sh`：构建、安装与卸载。
- `tests/test_activity.py`：任务计数逻辑验证。
