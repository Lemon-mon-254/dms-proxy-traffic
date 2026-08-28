import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string proxyPort: (pluginData.proxyPort !== undefined && pluginData.proxyPort !== "") ? pluginData.proxyPort : "7890"
    readonly property string scriptPath: {
        var url = Qt.resolvedUrl("proxy-traffic-split").toString()
        return url.indexOf("file://") === 0 ? url.substring(7) : url
    }
    readonly property string destScriptPath: {
        var url = Qt.resolvedUrl("proxy-destination").toString()
        return url.indexOf("file://") === 0 ? url.substring(7) : url
    }
    property int refreshSec: (pluginData.refreshInterval !== undefined && pluginData.refreshInterval !== "") ? parseInt(pluginData.refreshInterval) : 2
    property bool showDownRate: pluginData.showDownRate !== false
    property bool showUpRate: pluginData.showUpRate !== false
    property bool showCumulative: pluginData.showCumulative === true
    property bool showPort: pluginData.showPort === true
    property bool showDestinations: pluginData.showDestinations === true
    property string xrayAccessLog: (pluginData.xrayAccessLog !== undefined && pluginData.xrayAccessLog !== "") ? pluginData.xrayAccessLog : ""
    property bool isZh: pluginData.language !== "en"

    property real rateUp: 0
    property real rateDown: 0
    property real totalUp: 0
    property real totalDown: 0
    property bool persistent: false
    property bool sampleOk: false
    property real lastUp: -1
    property real lastDown: -1
    property double lastTs: 0

    property var destinations: []
    property var processes: []

    function fmtSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + " GB"
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB"
        if (b >= 1024) return (b / 1024).toFixed(1) + " KB"
        return Math.round(b) + " B"
    }

    function tr(zh, en) { return root.isZh ? zh : en }

    function applySample(text) {
        let s = null
        try { s = JSON.parse(text.trim()) } catch (e) { root.sampleOk = false; return }
        if (!s || typeof s.up !== "number") { root.sampleOk = false; return }
        if (s.persistent !== true) {
            // 规则未就绪（nft 缺失 / 表不存在 / 无权限）
            root.sampleOk = false
            root.persistent = false
            root.rateUp = 0
            root.rateDown = 0
            root.totalUp = 0
            root.totalDown = 0
            root.lastTs = 0
            root.lastUp = -1
            root.lastDown = -1
            return
        }
        const now = Date.now() / 1000
        if (root.lastTs > 0 && now > root.lastTs && root.lastUp >= 0 && root.persistent === (s.persistent === true)) {
            const dt = now - root.lastTs
            const du = s.up - root.lastUp
            const dd = s.down - root.lastDown
            root.rateUp = du > 0 ? du / dt : 0
            root.rateDown = dd > 0 ? dd / dt : 0
        }
        root.lastUp = s.up
        root.lastDown = s.down
        root.lastTs = now
        root.totalUp = s.up
        root.totalDown = s.down
        root.persistent = s.persistent === true
        root.sampleOk = true
    }

    function applyDest(text) {
        if (!root.showDestinations) return
        let s = null
        try { s = JSON.parse(text.trim()) } catch (e) { return }
        if (!s || !Array.isArray(s.destinations)) return
        root.destinations = s.destinations
        root.processes = Array.isArray(s.processes) ? s.processes : []
    }

    Process {
        id: sampler
        command: ["sh", "-c", "exec '" + root.scriptPath + "'"]
        stdout: StdioCollector {
            id: outCollector
            onStreamFinished: root.applySample(outCollector.text)
        }
    }

    Process {
        id: destSampler
        command: [
            "sh", "-c",
            "XRAY_ACCESS='" + root.xrayAccessLog + "' " +
            "PROXY_PORT='" + root.proxyPort + "' exec '" + root.destScriptPath + "'"
        ]
        stdout: StdioCollector {
            id: destCollector
            onStreamFinished: root.applyDest(destCollector.text)
        }
    }

    Timer {
        interval: Math.max(1, root.refreshSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            sampler.running = true
            if (root.showDestinations) destSampler.running = true
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "swap_vert"
                size: Theme.iconSize - 4
                color: root.sampleOk ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showDownRate
                text: "↓" + root.fmtSpeed(root.rateDown)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showUpRate
                text: "↑" + root.fmtSpeed(root.rateUp)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showCumulative
                text: root.fmtBytes(root.totalDown + root.totalUp)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showPort
                text: ":" + root.proxyPort
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "swap_vert"
                size: Theme.iconSize - 4
                color: root.sampleOk ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.showDownRate
                text: "↓" + root.fmtSpeed(root.rateDown)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.showUpRate
                text: "↑" + root.fmtSpeed(root.rateUp)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.showCumulative
                text: root.fmtBytes(root.totalDown + root.totalUp)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutRoot
            headerText: root.tr("代理流量监控", "Proxy Traffic")
            detailsText: "127.0.0.1:" + root.proxyPort + (root.persistent ? root.tr(" · 持久统计", " · persistent") : root.tr(" · 会话统计", " · session"))
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: contentCol.implicitHeight

                Column {
                    id: contentCol
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    // Setup hint (shown while nftables rules are not ready)
                    StyledRect {
                        id: setupHint
                        width: parent.width
                        visible: !root.sampleOk
                        implicitHeight: setupHintCol.implicitHeight + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                        border.color: Theme.warning
                        border.width: 1

                        Column {
                            id: setupHintCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingL
                            spacing: Theme.spacingS

                            StyledText {
                                text: root.tr("需要先完成一次性安装", "One-time setup required")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.warning
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            StyledText {
                                text: root.tr("请在终端运行并设置正确的代理端口：", "Run in a terminal (set your actual proxy port):")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                            StyledRect {
                                width: parent.width
                                radius: Theme.cornerRadius - 2
                                color: Theme.surfaceContainerHigh
                                implicitHeight: cmdText.implicitHeight + Theme.spacingM * 2

                                StyledText {
                                    id: cmdText
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    text: "sudo PROXY_PORT=" + root.proxyPort + " ./setup-nftables.sh install"
                                    font.family: "monospace"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // Speed cards - side by side
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        // Download card
                        StyledRect {
                            width: (parent.width - Theme.spacingS) / 2
                            height: 80
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                DankIcon {
                                    name: "arrow_downward"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.fmtSpeed(root.rateDown)
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.tr("下载", "Download")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Upload card
                        StyledRect {
                            width: (parent.width - Theme.spacingS) / 2
                            height: 80
                            radius: Theme.cornerRadius
                            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)

                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                DankIcon {
                                    name: "arrow_upward"
                                    size: Theme.iconSize
                                    color: Theme.error
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.fmtSpeed(root.rateUp)
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.error
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.tr("上传", "Upload")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    // Cumulative traffic
                    StyledRect {
                        width: parent.width
                        implicitHeight: totalRow.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Row {
                            id: totalRow
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: root.tr("累计下行", "Total down")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    text: root.fmtBytes(root.totalDown)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }

                            Item { width: 1; height: 1; anchors.verticalCenter: parent.verticalCenter }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: root.tr("累计上行", "Total up")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    text: root.fmtBytes(root.totalUp)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                }
                            }
                        }
                    }

                    // Traffic destinations (流量去向)
                    StyledRect {
                        visible: root.showDestinations
                        width: parent.width
                        implicitHeight: destCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: destCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: root.tr("流量去向", "Destinations")
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: root.tr("目标域名", "Domains")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Column {
                                spacing: 2
                                Repeater {
                                    model: root.destinations
                                    StyledText {
                                        required property string domain
                                        required property int count
                                        text: "• " + domain + "  (" + count + ")"
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        color: Theme.surfaceText
                                    }
                                }
                            }

                            StyledText {
                                text: root.tr("访问进程", "Processes")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Column {
                                spacing: 2
                                Repeater {
                                    model: root.processes
                                    StyledText {
                                        required property string name
                                        required property int count
                                        text: "• " + name + "  (" + count + ")"
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        color: Theme.surfaceText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: root.showDestinations ? 560 : 280
}
