import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "proxyTraffic"

    StyledText {
        width: parent.width
        text: "Proxy Traffic"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "监控经过本地代理端口的实时网速与流量。内置 proxy-traffic 脚本通过 ss 读取内核 TCP 计数器(会话统计);若配置了 nftables 持久计数器并授予免密 sudo,则自动切换为历史累计模式。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "proxyPort"
        label: "代理端口"
        description: "本地代理监听端口(Clash 默认 7890,v2rayN 默认 10808 或自定义)"
        placeholder: "7890"
        defaultValue: "7890"
    }

    SelectionSetting {
        settingKey: "refreshInterval"
        label: "刷新间隔"
        description: "采样频率,越小越实时,CPU 开销略增"
        options: [
            { label: "1 秒", value: "1" },
            { label: "2 秒", value: "2" },
            { label: "3 秒", value: "3" },
            { label: "5 秒", value: "5" }
        ]
        defaultValue: "2"
    }

    StyledText {
        width: parent.width
        text: "栏上显示内容"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "showDownRate"
        label: "下载速率"
        description: "栏上显示 ↓ 下载速度"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showUpRate"
        label: "上传速率"
        description: "栏上显示 ↑ 上传速度"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showTotal"
        label: "累计流量"
        description: "栏上追加显示上下行总流量"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPort"
        label: "端口号"
        description: "栏上追加显示 :端口"
        defaultValue: false
    }
}
