# Proxy Traffic — DMS 插件

一个针对 [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) 的 DankBar 组件，通过 **nftables** 计数器实时监控本地代理的网速与累计流量。

## 特性

- **栏上胶囊** — 实时代理下载/上传速度（`↓1.2 MB/s ↑45 KB/s`）
- **弹出面板** — 点击胶囊查看详细的速率与累计流量（下行/上行）
- **仅统计代理** — 只统计经过本地代理端口的流量
- **可配置显示**：在栏上切换 下载速率 / 上传速率 / 累计流量 / 端口号
- 可调刷新间隔（1–5 秒）
- 同时支持横向和纵向工具栏

## 安装

将本目录克隆（或复制）到 DMS 插件目录：

```bash
git clone https://github.com/Lemon-mon-254/dms-proxy-traffic.git ~/.config/DankMaterialShell/plugins/ProxyTraffic
```

然后在 DMS 中：**设置 → 插件 → 扫描插件**，启用 **Proxy Traffic**，将其添加到 DankBar 布局并重启：

```bash
dms restart
```

## 快速开始

插件从 nftables 计数器读取代理流量，需要两步：

**1. 创建 nftables 计数器（代理端口默认 `7890`）**

```bash
cd ~/.config/DankMaterialShell/plugins/ProxyTraffic
sudo ./setup-nftables.sh create
```

可以通过环境变量覆盖规则所用的端口：

```bash
PROXY_PORT=2547 sudo ./setup-nftables.sh create
```

常见代理端口：**Clash 7890** · v2ray/xray 10808 · sing-box 1080。

**2. 授予无密码读取 nftables 的权限**（这样栏上组件读取计数器时不会弹出密码提示）

```bash
sudo ./setup-nftables.sh sudoers
```

该命令会向 `/etc/sudoers.d/proxy-nft` 写入一条针对 `/usr/bin/nft` 的 NOPASSWD 配置。

## 配置项

| 设置 | 默认值 | 说明 |
|---|---|---|
| 代理端口 | `7890` | 本地代理监听端口（须与创建 nftables 规则所用的端口一致；常见：Clash `7890` · v2ray/xray `10808` · sing-box `1080`） |
| 刷新间隔 | `2s` | 采样频率 |
| 下载速率 | 开 | 栏上显示 `↓ 速度` |
| 上传速率 | 开 | 栏上显示 `↑ 速度` |
| 累计流量 | 关 | 栏上显示代理累计上下行流量 |
| 端口号 | 关 | 追加显示 `:端口` |

> **重要：** 设置中的"代理端口"应与运行 `setup-nftables.sh create` 时的端口一致，否则计数器将不匹配。

## 规则管理

```bash
sudo ./setup-nftables.sh show      # 查看当前计数器
sudo ./setup-nftables.sh delete    # 删除计数器（累计清零）
sudo ./setup-nftables.sh create    # 重新创建计数器（同样会清零累计）
```

计数器是**持久**的（在内核中保持，直到重启或删除表），因此插件会显示自创建以来累计的历史流量。

## 运行原理

随附的 `proxy-traffic-split` 脚本读取 nftables 计数器并输出一行 JSON：

```json
{"up": 118045, "down": 454352, "persistent": true}
```

- `up` — 发送到本地代理端口的字节数（应用 → 代理）
- `down` — 从本地代理端口接收的字节数（代理 → 应用）

QML 组件对连续采样做差分运算，从而得到实时速率。

## 屏幕截图

（待补充截图）

## 环境要求

- DankMaterialShell >= 1.4.0
- `nft`（nftables）、`sudo`
- 一个监听在已配置端口上的本地代理（例如 v2ray/xray/sing-box/clash）

## 许可证

MIT
