import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "proxyTraffic"

    property string currentLang: String(root.loadValue("language", "zh"))
    readonly property bool isZh: root.currentLang !== "en"
    function tr(zh, en) { return root.isZh ? zh : en }

    function orderLabel(id) {
        if (id === "speed") return root.tr("速度", "Speed")
        if (id === "cumulative") return root.tr("累计流量", "Cumulative")
        if (id === "today") return root.tr("历史流量", "History")
        if (id === "destinations") return root.tr("流量去向", "Destinations")
        if (id === "redirect") return root.tr("分流统计", "Redirect")
        return id
    }

    onPluginServiceChanged: {
        if (pluginService) {
            root.currentLang = String(root.loadValue("language", "zh"));
        }
    }

    onSettingChanged: {
        root.currentLang = String(root.loadValue("language", "zh"));
    }

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

    ToggleSetting {
        settingKey: "showRedirect"
        label: root.tr("分流统计", "Redirect")
        description: root.tr("弹出面板显示 xray 出站的代理/直连流量\n(仅 xray/v2rayN)", "Show proxy vs direct traffic breakdown\n(xray/v2rayN only)")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "useXrayCumul"
        label: root.tr("累计流量改用 xray", "Use xray for cumulative")
        description: root.tr("累计流量/胶囊改用 xray 分流统计来源 (proxy+direct)\n(仅 xray/v2rayN 适用; 更准确, 且跨重启不丢失)", "Cumulative & pill use xray outbound stats (proxy+direct)\n(xray/v2rayN only; more accurate, survives restarts)")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "barCumulOnly"
        label: root.tr("栏上累计仅显示代理流量", "Bar cumulative proxy-only")
        description: root.tr("栏上胶囊的累计流量只显示代理(proxy)出站, 不含直连\n(需配合\"累计流量改用 xray\"开启)", "Bar pill cumulative shows only proxy outbound, excluding direct\n(requires \"Use xray for cumulative\" enabled)")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showSpeed"
        label: root.tr("速度卡片", "Speed card")
        description: root.tr("弹出面板显示实时下载/上传速率卡片", "Show real-time download/upload rate cards")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showCumulCard"
        label: root.tr("累计流量卡片", "Cumulative card")
        description: root.tr("弹出面板显示累计上下行流量", "Show cumulative up/down traffic")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showToday"
        label: root.tr("历史流量卡片", "History card")
        description: root.tr("弹出面板显示最近 N 天上下行流量及折线图", "Show recent up/down traffic and its line chart")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "chartDays"
        label: root.tr("折线图天数", "Chart days")
        description: root.tr("折线图显示最近多少天的历史", "How many days of history the chart shows")
        options: [
            { label: "3", value: "3" },
            { label: "7", value: "7" },
            { label: "14", value: "14" },
            { label: "30", value: "30" },
            { label: "90", value: "90" }
        ]
        defaultValue: "7"
    }

    // ── Card order (自定义顺序) ──
    StyledText {
        width: parent.width
        text: root.tr("顺序", "Order")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    property var order: ["speed", "cumulative", "today", "destinations", "redirect"]

    function loadOrder() {
        var stored = root.loadValue("cardOrder", null)
        if (Array.isArray(stored) && stored.length > 0) {
            var valid = []
            for (var i = 0; i < stored.length; i++) {
                if (root.orderLabel(stored[i]) !== stored[i]) valid.push(stored[i])
            }
            if (valid.length > 0) root.order = valid
        }
    }

    function moveCardUp(index) {
        if (index <= 0) return
        var arr = root.order.slice()
        var t = arr[index - 1]
        arr[index - 1] = arr[index]
        arr[index] = t
        root.order = arr
        root.saveValue("cardOrder", arr)
    }

    function moveCardDown(index) {
        if (index >= root.order.length - 1) return
        var arr = root.order.slice()
        var t = arr[index + 1]
        arr[index + 1] = arr[index]
        arr[index] = t
        root.order = arr
        root.saveValue("cardOrder", arr)
    }

    Component.onCompleted: root.loadOrder()

    StyledRect {
        width: parent.width
        height: 210
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerLow, Theme.popupTransparency)
        border.color: Theme.surfaceContainerHighest
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.topMargin: Theme.spacingXS
            anchors.bottomMargin: Theme.spacingXS
            spacing: Theme.spacingXS

            Repeater {
                model: root.order

                StyledRect {
                    required property string modelData
                    required property int index

                    width: parent ? parent.width : 0
                    height: 36
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    border.color: Theme.withAlpha(Theme.surfaceText, 0.08)
                    border.width: 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.orderLabel(modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        MouseArea {
                            width: 28; height: 24
                            id: upBtn
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: index > 0
                            opacity: enabled ? 1 : 0.3
                            onClicked: root.moveCardUp(index)
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: upBtn.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u25B2"
                                    font.pixelSize: 10
                                    color: Theme.surfaceText
                                }
                            }
                        }

                        MouseArea {
                            width: 28; height: 24
                            id: downBtn
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: index < root.order.length - 1
                            opacity: enabled ? 1 : 0.3
                            onClicked: root.moveCardDown(index)
                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: downBtn.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u25BC"
                                    font.pixelSize: 10
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    StringSetting {
        settingKey: "xrayApiPort"
        label: root.tr("xray API 端口", "xray API port")
        description: root.tr("xray 的 API inbound 端口,用于读取分流统计", "xray API inbound port, used to read redirect stats")
        placeholder: "2551"
        defaultValue: "2551"
    }

    StringSetting {
        settingKey: "xrayAccessLog"
        label: root.tr("代理访问日志路径", "Proxy access log path")
        description: root.tr("xray 的 access 日志文件,用于解析目标域名", "xray access log file, used to resolve target domains")
        placeholder: "/home/lemonmon/.local/share/v2rayN/binConfigs/access.log"
        defaultValue: "/home/lemonmon/.local/share/v2rayN/binConfigs/access.log"
    }
}
