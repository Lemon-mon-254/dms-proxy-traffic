# Proxy Traffic — DMS Plugin

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar widget that monitors real-time throughput and cumulative traffic of your local proxy via **nftables** counters.

## Features

- **Bar pill** — live proxy download/upload speed (`↓1.2 MB/s ↑45 KB/s`)
- **Popout panel** — click the pill for detailed rates and cumulative traffic (down/up)
- **Proxy-only** — only counts traffic flowing through the local proxy port
- **Configurable display**: toggle download rate / upload rate / cumulative traffic / port on the bar
- Adjustable refresh interval (1–5 s)
- Works with horizontal and vertical bars

## Installation

Clone (or copy) this directory into the DMS plugins folder:

```bash
git clone https://github.com/Lemon-mon-254/dms-proxy-traffic.git ~/.config/DankMaterialShell/plugins/ProxyTraffic
```

Then in DMS: **Settings → Plugins → Scan for Plugins**, enable **Proxy Traffic**, add it to your DankBar layout and restart the shell:

```bash
dms restart
```

## Quick start

The plugin reads proxy traffic from nftables counters. Two steps are required:

**1. Create the nftables counters (proxy port default `7890`)**

```bash
cd ~/.config/DankMaterialShell/plugins/ProxyTraffic
sudo ./setup-nftables.sh create
```

You can override the port used by the rules:

```bash
PROXY_PORT=2547 sudo ./setup-nftables.sh create
```

Common proxy ports: **Clash 7890** · v2ray/xray 10808 · sing-box 1080.

**2. Grant passwordless read access to nftables** (so the bar widget can read counters without prompting)

```bash
sudo ./setup-nftables.sh sudoers
```

This writes `/etc/sudoers.d/proxy-nft` with a NOPASSWD entry for `/usr/bin/nft`.

## Configuration

| Setting | Default | Description |
|---|---|---|
| Proxy port | `7890` | Local proxy listen port (must match the port used to create nftables rules; common: Clash `7890` · v2ray/xray `10808` · sing-box `1080`) |
| Refresh interval | `2s` | Sampling frequency |
| Show download rate | on | `↓ speed` on the bar |
| Show upload rate | on | `↑ speed` on the bar |
| Show cumulative | off | Shows total proxy traffic on the bar |
| Show port | off | Appends `:port` |

> **Important:** the *Proxy port* in settings should match the port used when running `setup-nftables.sh create`, otherwise counters will not match.

## Managing rules

```bash
sudo ./setup-nftables.sh show      # inspect current counters
sudo ./setup-nftables.sh delete    # remove counters (cumulative reset)
sudo ./setup-nftables.sh create    # re-create counters (also resets totals)
```

The counters are **persistent** (maintained in the kernel until reboot or table deletion), so the plugin shows historical cumulative traffic since the table was created.

## How it works

The bundled `proxy-traffic-split` script reads the nftables counters and emits one JSON line:

```json
{"up": 118045, "down": 454352, "persistent": true}
```

- `up` — bytes sent to the local proxy port (application → proxy)
- `down` — bytes received from the local proxy port (proxy → application)

The QML widget diffs consecutive samples to derive live rates, matching the difference between samples over the elapsed time.

## Requirements

- DankMaterialShell >= 1.4.0
- `nft` (nftables), `sudo`
- A local proxy listening on the configured port (e.g. v2ray/xray/sing-box/clash)

## License

MIT
