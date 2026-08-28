import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "proxyTraffic"

    property bool isZh: pluginData.language !== "en"
    function tr(zh, en) { return root.isZh ? zh : en }

    StyledText {
        width: parent.width
        text: "Proxy Traffic"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: root.tr("监控经过本地代理端口的实时网速与累计流量。通过 nftables 统计代理流量。", "Monitors real-time throughput and cumulative traffic of your local proxy via nftables counters.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "language"
        label: root.tr("界面语言", "Language")
        description: root.tr("简体中文 / English", "Simplified Chinese / English")
        options: [
            { label: "简体中文", value: "zh" },
            { label: "English", value: "en" }
        ]
        defaultValue: "zh"
    }

    StringSetting {
        settingKey: "proxyPort"
        label: root.tr("代理端口", "Proxy port")
        description: root.tr("本地代理监听端口\n常见: Clash 7890 · v2ray/xray 10808 · sing-box 1080", "Local proxy listen port\nCommon: Clash 7890 · v2ray/xray 10808 · sing-box 1080")
        placeholder: "7890"
        defaultValue: "7890"
    }

    SelectionSetting {
        settingKey: "refreshInterval"
        label: root.tr("刷新间隔", "Refresh interval")
        description: root.tr("采样频率", "Sampling frequency")
        options: [
            { label: root.tr("1 秒", "1 s"), value: "1" },
            { label: root.tr("2 秒", "2 s"), value: "2" },
            { label: root.tr("3 秒", "3 s"), value: "3" },
            { label: root.tr("5 秒", "5 s"), value: "5" }
        ]
        defaultValue: "2"
    }

    ToggleSetting {
        settingKey: "showDownRate"
        label: root.tr("下载速率", "Download rate")
        description: root.tr("栏上显示 ↓ 下载速度", "Show ↓ download speed on the bar")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showUpRate"
        label: root.tr("上传速率", "Upload rate")
        description: root.tr("栏上显示 ↑ 上传速度", "Show ↑ upload speed on the bar")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showCumulative"
        label: root.tr("累计流量", "Cumulative traffic")
        description: root.tr("栏上显示代理累计上下行流量", "Show cumulative proxy traffic on the bar")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPort"
        label: root.tr("端口号", "Port number")
        description: root.tr("栏上显示 :端口", "Show :port on the bar")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showDestinations"
        label: root.tr("流量去向", "Destinations")
        description: root.tr("弹出面板显示目标域名与访问进程\n(需代理开启 access 日志)", "Show target domains & processes in popout\n(proxy access log required)")
        defaultValue: false
    }

    StringSetting {
        settingKey: "xrayAccessLog"
        label: root.tr("代理访问日志路径", "Proxy access log path")
        description: root.tr("xray 的 access 日志文件,用于解析目标域名", "xray access log file, used to resolve target domains")
        placeholder: "/home/lemonmon/.local/share/v2rayN/binConfigs/access.log"
        defaultValue: "/home/lemonmon/.local/share/v2rayN/binConfigs/access.log"
    }
}
