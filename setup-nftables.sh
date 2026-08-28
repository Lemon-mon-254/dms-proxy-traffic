#!/bin/bash
# setup-nftables.sh — 配置并持久化 nftables 代理流量统计规则
#
# 用法（全部需要 root）:
#   sudo ./setup-nftables.sh install     # 一键安装: 依赖 + 规则 + 持久化 + 免密读取
#   sudo ./setup-nftables.sh create      # 仅创建(应用)当前统计规则
#   sudo ./setup-nftables.sh uninstall   # 移除: 规则 + 持久化服务 + 选项是否还原 sudoers
#   sudo ./setup-nftables.sh delete      # 仅删除当前统计规则
#   sudo ./setup-nftables.sh show        # 显示当前规则与状态
#   sudo ./setup-nftables.sh sudoers     # 仅授权无密码读取 nftables(可单独执行)
#
# 代理端口通过环境变量 PROXY_PORT 指定, 默认 7890 (常见: Clash 7890 · v2ray 10808 · sing-box 1080):
#   PROXY_PORT=2547 sudo ./setup-nftables.sh install

set -e

PROXY_PORT="${PROXY_PORT:-7890}"
RULES_FILE="/etc/nftables.d/proxy-traffic.nft"
SERVICE_NAME="nft-proxy-traffic.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

setup_sudoers() {
    local user="${SUDO_USER:-$(whoami)}"
    echo "为 $user 配置无密码读取 nftables 权限..."
    echo "$user ALL=(root) NOPASSWD: /usr/bin/nft" > /etc/sudoers.d/proxy-nft
    chmod 440 /etc/sudoers.d/proxy-nft
    echo "已写入 /etc/sudoers.d/proxy-nft"
}

remove_sudoers() {
    rm -f /etc/sudoers.d/proxy-nft
    echo "已删除 /etc/sudoers.d/proxy-nft"
}

ensure_nft() {
    if ! command -v nft >/dev/null 2>&1; then
        echo "未检测到 nft, 尝试安装 nftables..."
        if command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm nftables
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y nftables
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y nftables
        else
            echo "无法自动安装 nftables, 请手动安装后重试" >&2
            exit 1
        fi
        echo "nftables 已安装"
    fi
    command -v nft >/dev/null 2>&1 || { echo "nft 仍不可用" >&2; exit 1; }
}

write_rules_file() {
    mkdir -p /etc/nftables.d
    cat > "$RULES_FILE" << EOF
# 由 ProxyTraffic 插件生成 — 代理端口 $PROXY_PORT
# 上传: 发往本地代理端口的数据 (dport); 下载: 来自本地代理端口的数据 (sport)
table inet proxy_stat {
    chain input {
        type filter hook input priority 0; policy accept;
        tcp dport $PROXY_PORT counter comment "proxy-up"
        udp dport $PROXY_PORT counter comment "proxy-up"
    }
    chain output {
        type filter hook output priority 0; policy accept;
        tcp sport $PROXY_PORT counter comment "proxy-down"
        udp sport $PROXY_PORT counter comment "proxy-down"
    }
}
EOF
    echo "规则文件已写入: $RULES_FILE"
}

apply_rules() {
    # 移除旧表避免重复定义, 再加载
    nft delete table inet proxy_stat 2>/dev/null || true
    nft -f "$RULES_FILE"
    echo "nftables 规则已应用:"
    nft list table inet proxy_stat
}

create_rules() {
    ensure_nft
    write_rules_file
    apply_rules
}

create_service() {
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=ProxyTraffic nftables counters
After=network-pre.target
Wants=network-pre.target
Before=network-pre.target nftables.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/nft -f $RULES_FILE

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    echo "持久化服务已启用: $SERVICE_NAME (开机自动加载统计规则)"
}

install_all() {
    ensure_nft
    write_rules_file
    apply_rules
    setup_sudoers
    create_service
    echo ""
    echo "======================================================"
    echo "安装完成 ✅"
    echo "  代理端口: $PROXY_PORT"
    echo "  规则文件: $RULES_FILE (持久化, 重启不丢)"
    echo "  服务:     $SERVICE_NAME (开机自动加载)"
    echo "  免密读取: /etc/sudoers.d/proxy-nft"
    echo ""
    echo "插件内请将 \"代理端口\" 设置为 $PROXY_PORT 以匹配本次规则。"
    echo "======================================================"
}

uninstall_all() {
    nft delete table inet proxy_stat 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"
    rm -f "$RULES_FILE"
    systemctl daemon-reload
    echo "已删除 nftables 统计规则与持久化服务配置。"
    read -r -p "是否同时移除免密读取(sudoers)? [y/N] " ans
    case "$ans" in
        y|Y) remove_sudoers ;;
        *) echo "已保留 /etc/sudoers.d/proxy-nft" ;;
    esac
}

show_status() {
    echo "=== 运行时规则 ==="
    nft list table inet proxy_stat 2>/dev/null || echo "表 inet proxy_stat 不存在(尚未应用)"
    echo ""
    echo "=== 持久化服务 ==="
    systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "未启用"
    systemctl is-active "$SERVICE_NAME" 2>/dev/null || true
    echo ""
    echo "=== 插件依赖 ==="
    command -v nft >/dev/null 2>&1 && echo "nft: OK" || echo "nft: 缺失"
}

case "$1" in
    install)    install_all ;;
    create)     create_rules ;;
    delete)     nft delete table inet proxy_stat 2>/dev/null || true; echo "已删除统计规则";;
    show)       show_status ;;
    sudoers)    setup_sudoers ;;
    uninstall)  uninstall_all ;;
    *)
        echo "用法: sudo $0 {install|create|delete|show|sudoers|uninstall}"
        echo "  install   - 一键安装 (依赖 + 规则 + 持久化 + 免密读取)"
        echo "  create    - 仅创建(应用)统计规则"
        echo "  delete    - 仅删除统计规则"
        echo "  show      - 显示规则与状态"
        echo "  sudoers   - 仅配置无密码读取 nftables"
        echo "  uninstall - 移除规则 + 持久化 + (可选)免密"
        ;;
esac
