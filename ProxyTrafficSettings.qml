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
        text: "监控经过本地代理端口的实时网速与累计流量。通过 nftables 统计代理流量。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "proxyPort"
        label: "代理端口"
        description: "本地代理监听端口"
        placeholder: "2547"
        defaultValue: "2547"
    }

    SelectionSetting {
        settingKey: "refreshInterval"
        label: "刷新间隔"
        description: "采样频率"
        options: [
            { label: "1 秒", value: "1" },
            { label: "2 秒", value: "2" },
            { label: "3 秒", value: "3" },
            { label: "5 秒", value: "5" }
        ]
        defaultValue: "2"
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
        settingKey: "showCumulative"
        label: "累计流量"
        description: "栏上显示代理累计上下行流量"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPort"
        label: "端口号"
        description: "栏上显示 :端口"
        defaultValue: false
    }
}
