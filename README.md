# Proxy Traffic — DMS Plugin

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget that monitors real-time throughput and cumulative traffic through a local proxy port (default `127.0.0.1:7890`).

## Features

- **Bar pill** — live download/upload speed (`↓1.2 MB/s ↑45 KB/s`)
- **Popout panel** — click the pill for detailed rates, cumulative traffic and active connection count
- **Session & persistent modes**
  - *Session* (default): reads kernel TCP counters via `ss`, no root required
  - *Persistent*: automatically switches to nftables counters if available (historical totals since counter creation)
- **Configurable display**: toggle download rate / upload rate / total traffic / port number on the bar
- Adjustable refresh interval (1–5 s)

## Installation

Copy (or symlink) this directory into the DMS plugins folder:

```bash
git clone https://github.com/<you>/dms-proxy-traffic.git ~/.config/DankMaterialShell/plugins/ProxyTraffic
```

Then in DMS: **Settings → Plugins → Scan for Plugins**, enable **Proxy Traffic**, add it to your DankBar layout and restart the shell (`dms restart`).

## Configuration

| Setting | Default | Description |
|---|---|---|
| Proxy port | `7890` | Local proxy listen port |
| Refresh interval | `2s` | Sampling frequency |
| Show download rate | on | `↓ speed` on the bar |
| Show upload rate | on | `↑ speed` on the bar |
| Show total traffic | off | Appends combined total |
| Show port | off | Appends `:port` |

## Persistent counting (optional)

The widget falls back to nftables counters when they are readable without a password. To enable:

```bash
# allow passwordless read of the counter table
echo "$USER ALL=(root) NOPASSWD: /usr/bin/nft" | sudo tee /etc/sudoers.d/proxy-nft

# create the counter table (re-run after each reboot)
sudo nft add table inet proxy_stat
sudo nft add chain inet proxy_stat input '{ type filter hook input priority -100; }'
sudo nft add chain inet proxy_stat output '{ type filter hook output priority -100; }'
sudo nft add rule inet proxy_stat input tcp dport 7890 counter comment '"proxy-up"'
sudo nft add rule inet proxy_stat output tcp sport 7890 counter comment '"proxy-down"'
```

Without this step everything still works — you just get session-level totals instead.

## How it works

The bundled `proxy-traffic` script samples kernel TCP byte counters for all connections whose destination is the configured port (`ss -tinH "dport = :PORT"`), sums them, and emits one JSON line:

```json
{"up":118045,"down":454352,"persistent":false,"conns":6}
```

If `sudo -n nft -j list table inet proxy_stat` succeeds, it reports persistent nftables counters instead. The QML widget diffs consecutive samples to derive rates.

## Requirements

- DankMaterialShell >= 1.4.0
- `ss` (iproute2), `jq` (only needed for persistent mode)

## License

MIT
