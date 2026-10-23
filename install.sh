#!/bin/sh
set -eu

BASE=/root
UPSTREAM="$BASE/argosbx.sh"
URL=https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh

info() { printf '\n===== %s =====\n' "$1"; }
die() { printf '错误：%s\n' "$1" >&2; exit 1; }
ask() {
  printf '%s [%s]: ' "$1" "$2" >&2
  IFS= read -r answer || answer=''
  printf '%s' "${answer:-$2}"
}

[ "$(id -u)" -eq 0 ] || die '请以 root 身份运行'
[ -f /etc/alpine-release ] || die '此脚本仅适用于 Alpine Linux'
cd "$BASE"

info '系统环境'
printf 'Alpine: '; cat /etc/alpine-release
printf '架构: '; uname -m
case "$(uname -m)" in x86_64|aarch64) ;; *) die '仅支持 x86_64/aarch64' ;; esac
for f in memory.max memory.current memory.swap.max memory.events; do
  p="/sys/fs/cgroup/$f"
  if [ -r "$p" ]; then printf '\n%s:\n' "$f"; cat "$p"; fi
done
df -h /

info '交互配置'
PORT=$(ask 'Reality 监听端口' '21374')
case "$PORT" in ''|*[!0-9]*) die '端口必须为数字' ;; esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die '端口必须在 1-65535 之间'
SNI=$(ask 'Reality 伪装域名（SNI）' 'developer.nvidia.com')
case "$SNI" in ''|*[!A-Za-z0-9.-]*|.*|*.) die '域名格式不正确' ;; esac
printf '%s' "$SNI" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$' || die '域名格式不正确'
NAME=$(ask '节点名称前缀' 'Alpine-Reality')
case "$NAME" in ''|*[!A-Za-z0-9_.-]*) die '节点名称只允许字母、数字、下划线、点和连字符' ;; esac
UUID=$(ask 'UUID（auto 自动生成）' 'auto')
if [ "$UUID" != auto ]; then
  printf '%s\n' "$UUID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' || die 'UUID 格式不正确'
fi
INSTALL_DEPS=$(ask '安装/检查六项依赖？y/n' 'y')
case "$INSTALL_DEPS" in y|Y|n|N) ;; *) die '请输入 y 或 n' ;; esac

info '确认配置'
printf '端口: %s\n伪装域名: %s\n节点名称: %s\nUUID: %s\n安装依赖: %s\n自动重启: 否\n' "$PORT" "$SNI" "$NAME" "$UUID" "$INSTALL_DEPS"
CONFIRM=$(ask '确认继续？y/n' 'n')
case "$CONFIRM" in y|Y) ;; *) echo '已取消'; exit 0 ;; esac

if [ "$INSTALL_DEPS" = y ] || [ "$INSTALL_DEPS" = Y ]; then
  info '逐项安装依赖'
  for pkg in bash busybox-extras gcompat libc6-compat iptables openssl; do
    echo "安装 $pkg ..."
    apk add --no-cache "$pkg" || die "安装 $pkg 失败"
  done
fi
for cmd in bash wget openssl; do command -v "$cmd" >/dev/null 2>&1 || die "缺少命令 $cmd"; done
for pkg in bash busybox-extras gcompat libc6-compat iptables openssl; do apk info -e "$pkg" >/dev/null 2>&1 || die "依赖未安装: $pkg"; done
# 上游检查的是当前工作目录下的 sbx_update
: > "$BASE/sbx_update"

info '下载上游 Argosbx'
TMP="$UPSTREAM.tmp.$$"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
wget -qO "$TMP" "$URL" || die '下载失败'
[ -s "$TMP" ] || die '下载内容为空'
head -n 1 "$TMP" | grep -q '^#!/bin/bash' || die '下载内容不是预期的 Bash 脚本'
mv "$TMP" "$UPSTREAM"
chmod 700 "$UPSTREAM"
grep '当前版本' "$UPSTREAM" | head -n 1 || true
sha256sum "$UPSTREAM" | tee "$BASE/argosbx.sha256"
echo '提示：SHA256 仅记录本次下载的内容，不代表已验证上游安全性。'
CONFIRM=$(ask '已审查并信任上游脚本，继续执行？y/n' 'n')
case "$CONFIRM" in y|Y) ;; *) echo '已取消'; exit 0 ;; esac

info '安装 VLESS Reality'
if [ "$UUID" = auto ]; then
  vlpt="$PORT" reym="$SNI" name="$NAME" bash "$UPSTREAM"
else
  vlpt="$PORT" reym="$SNI" name="$NAME" uuid="$UUID" bash "$UPSTREAM"
fi

info '节点信息'
if command -v agsbx >/dev/null 2>&1; then agsbx list || true; fi
if [ -f "$BASE/agsbx/jhsub.txt" ]; then
  cat "$BASE/agsbx/jhsub.txt"
else
  echo '未发现节点文件，请检查上游安装输出。'
fi
printf '\n安装流程已结束，未自动重启。\n'
