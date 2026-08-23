import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string proxyPort: (pluginData.proxyPort !== undefined && pluginData.proxyPort !== "") ? pluginData.proxyPort : "7890"
    readonly property string scriptPath: {
        var url = Qt.resolvedUrl("proxy-traffic").toString()
        return url.indexOf("file://") === 0 ? url.substring(7) : url
    }
    property int refreshSec: (pluginData.refreshInterval !== undefined && pluginData.refreshInterval !== "") ? parseInt(pluginData.refreshInterval) : 2
    property bool showDownRate: pluginData.showDownRate !== false
    property bool showUpRate: pluginData.showUpRate !== false
    property bool showTotal: pluginData.showTotal === true
    property bool showPort: pluginData.showPort === true

    property real rateUp: 0
    property real rateDown: 0
    property real totalUp: 0
    property real totalDown: 0
    property bool persistent: false
    property int connCount: 0
    property bool sampleOk: false
    property real lastUp: -1
    property real lastDown: -1
    property double lastTs: 0

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

    function applySample(text) {
        let s = null
        try { s = JSON.parse(text.trim()) } catch (e) { root.sampleOk = false; return }
        if (!s || typeof s.up !== "number") { root.sampleOk = false; return }
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
        root.connCount = s.conns || 0
        root.sampleOk = true
    }

    Process {
        id: sampler
        command: ["sh", "-c", "PROXY_PORT=" + root.proxyPort + " exec '" + root.scriptPath + "'"]
        stdout: StdioCollector {
            id: outCollector
            onStreamFinished: root.applySample(outCollector.text)
        }
    }

    Timer {
        interval: Math.max(1, root.refreshSec) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }

    horizontalBarPill: Component {
        Row {
            id: hRow
            spacing: Theme.spacingXS

            DankIcon {
                name: "swap_vert"
                size: Theme.iconSize - 6
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
                visible: root.showTotal
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
            id: vCol
            spacing: Theme.spacingXS

            DankIcon {
                name: "swap_vert"
                size: Theme.iconSize - 6
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
                visible: root.showTotal
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
            headerText: "代理流量监控"
            detailsText: "127.0.0.1:" + root.proxyPort + (root.persistent ? " · 持久统计" : " · 会话统计")
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutRoot.headerHeight - popoutRoot.detailsHeight - Theme.spacingXL

                Column {
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    StyledRect {
                        width: parent.width
                        height: 84
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 4
                                DankIcon { name: "arrow_downward"; size: 14; color: Theme.primary }
                                StyledText { text: "下载速率"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }
                            StyledText {
                                text: root.fmtSpeed(root.rateDown)
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 4
                                DankIcon { name: "arrow_upward"; size: 14; color: Theme.primary }
                                StyledText { text: "上传速率"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }
                            StyledText {
                                text: root.fmtSpeed(root.rateUp)
                                font.pixelSize: Theme.fontSizeXLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        implicitHeight: rowsCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: rowsCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            Item {
                                width: parent.width
                                height: Math.max(tl.implicitHeight, tv.implicitHeight)
                                StyledText { id: tl; anchors.left: parent.left; text: "累计下行"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                StyledText { id: tv; anchors.right: parent.right; text: root.fmtBytes(root.totalDown); font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            }
                            Item {
                                width: parent.width
                                height: Math.max(tl2.implicitHeight, tv2.implicitHeight)
                                StyledText { id: tl2; anchors.left: parent.left; text: "累计上行"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                StyledText { id: tv2; anchors.right: parent.right; text: root.fmtBytes(root.totalUp); font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            }
                            Rectangle { width: parent.width; height: 1; color: Theme.surfaceContainerHighest }
                            Item {
                                width: parent.width
                                height: Math.max(cl.implicitHeight, cv.implicitHeight)
                                StyledText { id: cl; anchors.left: parent.left; text: "活跃连接"; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceVariantText }
                                StyledText { id: cv; anchors.right: parent.right; text: root.connCount + " 条"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: root.persistent
                              ? "nftables 持久统计已开启,数值为开机以来的历史累计"
                              : "当前为会话统计(仅活跃连接),运行 proxy_stat_on 可开启 nftables 持久统计"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 400
}
