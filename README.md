# Alpine Linux VLESS Reality 一键交互安装

基于 [甬哥 Argosbx](https://github.com/yonggekkk/argosbx) 的 Alpine Linux 交互式安装封装脚本，支持自定义 VLESS Reality 端口、伪装域名（SNI）、节点名称前缀及 UUID。

> **注意**：本项目调用第三方 `argosbx.sh`，并非独立实现 Xray。上游脚本可能包含其他协议或组件的部署逻辑；本项目不能保证只运行 Xray、不会安装 Sing-box/Cloudflared，也不保证在 64 MiB 内存限制下稳定运行。运行前请审查脚本及上游源码。

## 功能

- 检查 Alpine 版本、CPU 架构、cgroup 内存及根目录磁盘使用情况。
- 交互设置 Reality 监听端口、SNI、节点名称前缀、UUID。
- 可选逐项安装并核验 `bash`、`busybox-extras`、`gcompat`、`libc6-compat`、`iptables`、`openssl`。
- 创建 `/root/sbx_update` 标记，下载上游 Argosbx 并记录 SHA256。
- 二次确认后调用上游脚本，安装结束时尝试显示节点信息。
- **不自动重启**，不配置开机续装，也不执行重启后验收。

## 运行环境

- Alpine Linux，`x86_64` 或 `aarch64` 架构。
- `root` 权限、正常的网络连接及 GitHub Raw 访问能力。
- 系统需要有 `apk`、`wget`、`sh` 等基础命令。
- 需确保 Reality 端口未被占用，并在服务商防火墙及系统防火墙中按需放行 TCP 端口。

## 一键安装

以 **root** 身份执行：

```sh
apk add --no-cache wget && wget -qO /tmp/install.sh https://raw.githubusercontent.com/amuer2011/vless-for-alphine/main/install.sh && sh /tmp/install.sh
```

> 请先将仓库中的 `install.sh` 上传至 `main` 分支根目录。上述命令将从 GitHub 下载并执行代码，请确认仓库内容可信。

也可以先下载、审查，再运行：

```sh
wget -O /tmp/install.sh https://raw.githubusercontent.com/amuer2011/vless-for-alphine/main/install.sh
cat /tmp/install.sh
sh /tmp/install.sh
```

## 交互配置

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| Reality 监听端口 | `21374` | 范围为 1–65535 |
| Reality 伪装域名（SNI） | `developer.nvidia.com` | 需填写域名，不包含 `https://` |
| 节点名称前缀 | `Alpine-Reality` | 不是 Linux 系统用户名 |
| UUID | `auto` | `auto` 表示交由上游生成，也可输入标准 UUID |
| 安装/检查依赖 | `y` | 选择 `n` 时仍会检查依赖是否齐全 |

脚本在执行安装前会显示配置摘要并要求确认；下载上游脚本后还会再次确认是否执行。两次确认均默认 **否**，需要明确输入 `y`。

配置通过上游脚本环境变量 `vlpt`、`reym`、`name`、`uuid` 传递；最终生效情况取决于实际下载的 Argosbx 版本。

## 安装过程

1. 检查系统、架构、cgroup 内存与磁盘。
2. 交互输入参数并确认。
3. 逐项安装（或核验）依赖。
4. 创建 `/root/sbx_update`。
5. 下载 `/root/argosbx.sh`，生成 `/root/argosbx.sha256`。
6. 用户确认后运行 Argosbx。
7. 尝试执行 `agsbx list` 并读取 `/root/agsbx/jhsub.txt`。

## 安装后查看

```sh
# 上游节点列表（若已提供 agsbx 命令）
agsbx list

# 节点订阅/分享信息（如存在）
cat /root/agsbx/jhsub.txt

# 下载的上游脚本及其 SHA256
sha256sum /root/argosbx.sh
cat /root/argosbx.sha256
```

可按需手动检查运行状态（不是安装脚本自动执行的验收步骤）：

```sh
rc-service xray status
ss -lntp | grep 21374
ps | grep '[x]ray'
cat /sys/fs/cgroup/memory.current
cat /sys/fs/cgroup/memory.events
```

其中 `21374` 请替换成实际填写的端口。服务名、进程及命令是否存在，取决于上游安装结果。**不要将 `oom=0`、`oom_kill=0` 或内存低于 64 MiB 视为脚本保证。**

## 常见问题

**下载失败**：检查 DNS、网络连接及能否访问 `raw.githubusercontent.com`。

**依赖安装失败**：检查 Alpine 软件源和剩余磁盘空间；脚本会在失败时退出。

**没有显示节点信息**：查看上游安装过程输出，并确认 `/root/agsbx/jhsub.txt` 是否存在。

**端口无法连接**：检查服务是否启动、监听端口是否正确、云平台安全组及系统防火墙是否放行。

**内存不足 / OOM**：64 MiB 环境非常紧张；可以增加可用内存或 Swap，再排查上游实际启动的进程。

## 安全提示

- 脚本会以 `root` 身份执行从第三方仓库下载的代码；使用前请审查并确认信任。
- `argosbx.sha256` 仅用于记录本次下载文件的哈希值，**不等于来源真实性验证**。
- 节点分享链接及配置可能包含敏感凭证，请勿公开粘贴到 Issue 或日志中。
- 建议固定经过审查的上游提交版本，避免上游 `main` 分支变化导致行为改变。

## 项目地址与致谢

- 本项目：<https://github.com/amuer2011/vless-for-alphine>
- 上游项目：<https://github.com/yonggekkk/argosbx>

本项目是面向 Alpine Linux 的安装流程封装，相关协议实现及上游安装逻辑归原项目维护者所有。
