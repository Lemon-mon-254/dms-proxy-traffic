#!/bin/bash
# setup-nftables.sh — 配置 nftables 代理流量统计规则
#
# 用法:
#   sudo ./setup-nftables.sh create        # 创建统计规则
#   sudo ./setup-nftables.sh delete        # 删除统计规则
#   sudo ./setup-nftables.sh show          # 显示当前规则
#   sudo ./setup-nftables.sh sudoers       # 授权无密码读取 nftables
#
# 代理端口通过环境变量 PROXY_PORT 指定, 默认 7890 (常见: Clash 7890 · v2ray 10808 · sing-box 1080):
#   PROXY_PORT=2547 sudo ./setup-nftables.sh create

PROXY_PORT="${PROXY_PORT:-7890}"

create_rules() {
    echo "创建 nftables 规则 (代理端口: $PROXY_PORT)..."

    if sudo nft list table inet proxy_stat 2>/dev/null | grep -q "table inet proxy_stat"; then
        echo "表 inet proxy_stat 已存在, 先删除旧规则"
        sudo nft delete table inet proxy_stat
    fi

    local conf="/tmp/proxy-traffic-nftables.conf"
    cat > "$conf" << EOF
table inet proxy_stat {
    chain input {
        type filter hook input priority 0; policy accept;

        # 上传: 发往本地代理端口的数据 (dport = 代理端口)
        tcp dport $PROXY_PORT counter comment "proxy-up"
        udp dport $PROXY_PORT counter comment "proxy-up"
    }

    chain output {
        type filter hook output priority 0; policy accept;

        # 下载: 来自本地代理端口的数据 (sport = 代理端口)
        tcp sport $PROXY_PORT counter comment "proxy-down"
        udp sport $PROXY_PORT counter comment "proxy-down"
    }
}
EOF

    sudo nft -f "$conf"
    if [ $? -eq 0 ]; then
        echo "nftables 规则创建成功:"
        sudo nft list table inet proxy_stat
    else
        echo "nftables 规则创建失败"
        return 1
    fi
}

delete_rules() {
    echo "删除 nftables 规则..."
    sudo nft delete table inet proxy_stat 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "nftables 规则删除成功"
    else
        echo "nftables 规则删除失败或不存在"
    fi
}

show_rules() {
    echo "当前 nftables 规则:"
    sudo nft list table inet proxy_stat 2>/dev/null || echo "表 inet proxy_stat 不存在(请先运行 create)"
}

setup_sudoers() {
    local user="${SUDO_USER:-$(whoami)}"
    echo "为 $user 配置无密码读取 nftables 权限..."
    echo "$user ALL=(root) NOPASSWD: /usr/bin/nft" | sudo tee /etc/sudoers.d/proxy-nft >/dev/null
    sudo chmod 440 /etc/sudoers.d/proxy-nft
    echo "已写入 /etc/sudoers.d/proxy-nft"
}

case "$1" in
    create)  create_rules ;;
    delete)  delete_rules ;;
    show)    show_rules ;;
    sudoers) setup_sudoers ;;
    *)
        echo "用法: sudo $0 {create|delete|show|sudoers}"
        echo "  create   - 创建(重建) nftables 统计规则"
        echo "  delete   - 删除 nftables 统计规则"
        echo "  show     - 显示当前规则"
        echo "  sudoers  - 授权当前用户无密码读取 nftables"
        ;;
esac
