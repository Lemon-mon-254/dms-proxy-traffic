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
    readonly property string redirectScriptPath: {
        var url = Qt.resolvedUrl("proxy-redirect-stats").toString()
        return url.indexOf("file://") === 0 ? url.substring(7) : url
    }
    property int refreshSec: (pluginData.refreshInterval !== undefined && pluginData.refreshInterval !== "") ? parseInt(pluginData.refreshInterval) : 2
    property bool showDownRate: pluginData.showDownRate !== false
    property bool showUpRate: pluginData.showUpRate !== false
    property bool showCumulative: pluginData.showCumulative === true
    property bool showPort: pluginData.showPort === true
    property bool showDestinations: pluginData.showDestinations === true
    property bool showRedirect: pluginData.showRedirect === true
    property bool showSpeed: pluginData.showSpeed !== false
    property bool showCumulCard: pluginData.showCumulCard !== false
    property bool showToday: pluginData.showToday !== false
    property int chartDays: (pluginData.chartDays !== undefined && pluginData.chartDays !== "") ? parseInt(pluginData.chartDays) : 7
    readonly property var cardOrder: {
        var order = pluginData.cardOrder
        if (Array.isArray(order) && order.length > 0) return order
        return ["speed", "cumulative", "today", "destinations", "redirect"]
    }
    property string xrayAccessLog: (pluginData.xrayAccessLog !== undefined && pluginData.xrayAccessLog !== "") ? pluginData.xrayAccessLog : ""
    property string xrayApiPort: (pluginData.xrayApiPort !== undefined && pluginData.xrayApiPort !== "") ? pluginData.xrayApiPort : "2551"
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

    property bool redirectReady: false
    property real redirectProxyDown: 0
    property real redirectProxyUp: 0
    property real redirectDirectDown: 0
    property real redirectDirectUp: 0

    // ── Daily usage (今日统计) ──
    property string todayKey: ""
    property real todayUp: 0
    property real todayDown: 0
    property var dailyHistory: ({})
    property bool dailyLoaded: false

    function todayDateKey() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd")
    }

    function loadDaily() {
        if (!root.pluginService || root.dailyLoaded) return
        try {
            var days = root.pluginService.loadPluginState(root.pluginId, "daily", {})
            root.dailyHistory = (days && typeof days === "object") ? days : {}
        } catch (e) { root.dailyHistory = {} }
        root.todayKey = root.todayDateKey()
        if (root.dailyHistory[root.todayKey]) {
            root.todayDown = Number(root.dailyHistory[root.todayKey].down) || 0
            root.todayUp = Number(root.dailyHistory[root.todayKey].up) || 0
        } else {
            root.todayDown = 0
            root.todayUp = 0
        }
        root.dailyLoaded = true
    }

    function persistDaily() {
        if (!root.pluginService || !root.dailyLoaded) return
        root.rolloverDaily()
        root.dailyHistory[root.todayKey] = { down: root.todayDown, up: root.todayUp }
        try {
            root.pluginService.savePluginState(root.pluginId, "daily", root.dailyHistory)
        } catch (e) {}
    }

    function rolloverDaily() {
        var k = root.todayDateKey()
        if (k !== root.todayKey) {
            // 归档前一天的记录
            if (root.todayKey) {
                root.dailyHistory[root.todayKey] = { down: root.todayDown, up: root.todayUp }
            }
            root.todayKey = k
            root.todayDown = 0
            root.todayUp = 0
        }
    }

    function accumulateDaily(dUp, dDown) {
        if (!root.dailyLoaded) return
        root.rolloverDaily()
        if (dUp > 0) root.todayUp += dUp
        if (dDown > 0) root.todayDown += dDown
        root.dailyHistory[root.todayKey] = { down: root.todayDown, up: root.todayUp }
    }

    // Sorted recent daily series (chronological), up to chartDays entries
    readonly property var chartSeries: (function() {
        var keys = Object.keys(root.dailyHistory)
        keys.sort()
        var n = Math.max(1, root.chartDays)
        var slice = keys.slice(-n)
        var series = []
        for (var i = 0; i < slice.length; i++) {
            var k = slice[i]
            var d = root.dailyHistory[k] || {}
            series.push({ key: k, down: Number(d.down) || 0, up: Number(d.up) || 0 })
        }
        return series
    })()

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

    function shortDate(key) {
        var p = String(key).split("-")
        if (p.length >= 3) return parseInt(p[1]) + "/" + parseInt(p[2])
        return key
    }

    function tr(zh, en) { return root.isZh ? zh : en }

    function cardVisible(id) {
        if (id === "speed") return root.showSpeed
        if (id === "cumulative") return root.showCumulCard
        if (id === "today") return root.showToday
        if (id === "chart") return false
        if (id === "destinations") return root.showDestinations
        if (id === "redirect") return root.showRedirect
        return false
    }

    readonly property var cardModel: {
        var list = []
        for (var i = 0; i < root.cardOrder.length; i++) {
            var id = root.cardOrder[i]
            if (root.cardVisible(id)) list.push(id)
        }
        return list
    }

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
        // ── Daily accumulation (independent of rate calc) ──
        if (root.lastUp >= 0) {
            const dUp = s.up - root.lastUp
            const dDown = s.down - root.lastDown
            if (dUp > 0 || dDown > 0) root.accumulateDaily(dUp, dDown)
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

    function applyRedirect(text) {
        if (!root.showRedirect) return
        let s = null
        try { s = JSON.parse(text.trim()) } catch (e) { return }
        if (!s || typeof s.ready !== "boolean") return
        if (!s.ready || !s.proxy || !s.direct) {
            root.redirectReady = false
            return
        }
        root.redirectProxyDown = Number(s.proxy.down) || 0
        root.redirectProxyUp = Number(s.proxy.up) || 0
        root.redirectDirectDown = Number(s.direct.down) || 0
        root.redirectDirectUp = Number(s.direct.up) || 0
        root.redirectReady = true
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

    Process {
        id: redirectSampler
        command: [
            "sh", "-c",
            "XRAY_API_PORT='" + root.xrayApiPort + "' exec '" + root.redirectScriptPath + "'"
        ]
        stdout: StdioCollector {
            id: redirectCollector
            onStreamFinished: root.applyRedirect(redirectCollector.text)
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
            if (root.showRedirect) redirectSampler.running = true
        }
    }

    // ── Delay init until pluginService is injected by DMS ──
    Timer {
        id: initTimer
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (root.pluginService) {
                root.loadDaily()
                if (root.dailyLoaded) initTimer.running = false
            }
        }
    }

    // ── Persist daily usage periodically (every 60s) and on component destroy ──
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.persistDaily()
    }

    Component.onDestruction: root.persistDaily()

    function cardComponent(id) {
        if (id === "speed") return speedCardCmp
        if (id === "cumulative") return cumulativeCardCmp
        if (id === "today") return todayCardCmp
        if (id === "destinations") return destCardCmp
        if (id === "redirect") return redirectCardCmp
        return null
    }

    // ── Card Components (rendered by Repeater in content order) ──

    Component {
        id: speedCardCmp
        Row {
            width: parent ? parent.width : 0
            spacing: Theme.spacingS

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
    }

    Component {
        id: cumulativeCardCmp
        StyledRect {
            width: parent ? parent.width : 0
            implicitHeight: cumulRow.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                id: cumulRow
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
    }

    Component {
        id: todayCardCmp
        StyledRect {
            width: parent ? parent.width : 0
            implicitHeight: todayCol2.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: todayCol2
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: root.tr("今日流量", "Today") + "  ↓" + root.fmtBytes(root.todayDown) + "  ↑" + root.fmtBytes(root.todayUp)
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                // ── History line chart (merged into History card) ──
                StyledText {
                    visible: root.chartSeries.length === 0
                    text: root.tr("暂无历史数据", "No history yet")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                Canvas {
                    id: todayChartCanvas
                    visible: root.chartSeries.length > 0
                    width: parent.width
                    height: root.chartSeries.length > 0 ? 90 : 0
                    antialiasing: true
                    property bool drawn: false

                    onPaint: {
                        var ctx = getContext("2d")
                        var s = root.chartSeries
                        var w = width
                        var h = height
                        ctx.reset()
                        ctx.clearRect(0, 0, w, h)
                        if (s.length === 0) return

                        var padL = 26, padR = 6, padB = 14, padT = 8
                        var plotW = w - padL - padR
                        var plotH = h - padT - padB

                        var maxV = 1
                        for (var i = 0; i < s.length; i++) {
                            if (s[i].down > maxV) maxV = s[i].down
                            if (s[i].up > maxV) maxV = s[i].up
                        }
                        maxV = maxV * 1.1

                        function x(i) { return s.length === 1 ? padL + plotW / 2 : padL + plotW * (i / (s.length - 1)) }
                        function y(v) { return padT + plotH * (1 - v / maxV) }

                        ctx.fillStyle = Theme.surfaceVariantText
                        ctx.font = "8px sans-serif"
                        ctx.textAlign = "left"
                        ctx.fillText(root.fmtBytes(maxV), 2, padT + 3)
                        ctx.strokeStyle = Theme.withAlpha(Theme.surfaceText, 0.12)
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(padL, padT + 0.5)
                        ctx.lineTo(w - padR, padT + 0.5)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.moveTo(padL, padT + plotH + 0.5)
                        ctx.lineTo(w - padR, padT + plotH + 0.5)
                        ctx.stroke()

                        ctx.fillStyle = Theme.surfaceVariantText
                        ctx.font = "8px sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText(root.shortDate(s[0].key), x(0), padT + plotH + 10)
                        if (s.length > 2) {
                            ctx.fillText(root.shortDate(s[Math.floor(s.length / 2)].key), x(Math.floor(s.length / 2)), padT + plotH + 10)
                        }
                        ctx.fillText(root.shortDate(s[s.length - 1].key), x(s.length - 1), padT + plotH + 10)

                        ctx.strokeStyle = Theme.primary
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        for (var d = 0; d < s.length; d++) {
                            var px = x(d), py = y(s[d].down)
                            if (d === 0) ctx.moveTo(px, py)
                            else ctx.lineTo(px, py)
                        }
                        ctx.stroke()

                        ctx.strokeStyle = Theme.error
                        ctx.beginPath()
                        for (var u = 0; u < s.length; u++) {
                            var ux = x(u), uy = y(s[u].up)
                            if (u === 0) ctx.moveTo(ux, uy)
                            else ctx.lineTo(ux, uy)
                        }
                        ctx.stroke()

                        for (var p = 0; p < s.length; p++) {
                            ctx.fillStyle = Theme.primary
                            ctx.beginPath()
                            ctx.arc(x(p), y(s[p].down), 2, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.fillStyle = Theme.error
                            ctx.beginPath()
                            ctx.arc(x(p), y(s[p].up), 2, 0, Math.PI * 2)
                            ctx.fill()
                        }

                        todayChartCanvas.drawn = true
                    }

                    Connections {
                        target: root
                        function onDailyHistoryChanged() { todayChartCanvas.requestPaint() }
                        function onTodayUpChanged() { todayChartCanvas.requestPaint() }
                        function onTodayDownChanged() { todayChartCanvas.requestPaint() }
                    }
                }
            }
        }
    }

    Component {
        id: destCardCmp
        StyledRect {
            width: parent ? parent.width : 0
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

    Component {
        id: redirectCardCmp
        StyledRect {
            width: parent ? parent.width : 0
            implicitHeight: redirectCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: redirectCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: root.tr("分流统计", "Redirect")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    visible: !root.redirectReady
                    text: root.tr("xray 统计不可用\n请确认 API 端口正确 (默认 2551) 且 xray 已开启 outbound 流量统计",
                                  "xray stats unavailable\nCheck API port (default 2551) and that xray outbound stats are enabled")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Column {
                    id: redirectTable
                    visible: root.redirectReady
                    width: parent.width
                    spacing: Theme.spacingXXS
                    property int nameW: width * 0.34
                    property int numW: width * 0.33

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXXS
                        StyledText {
                            width: redirectTable.nameW
                            text: root.tr("代理", "Proxy")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                        }
                        StyledText {
                            width: redirectTable.numW
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtBytes(root.redirectProxyDown)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                        StyledText {
                            width: redirectTable.numW
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtBytes(root.redirectProxyUp)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXXS
                        StyledText {
                            width: redirectTable.nameW
                            text: root.tr("直连", "Direct")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.error
                        }
                        StyledText {
                            width: redirectTable.numW
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtBytes(root.redirectDirectDown)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                        StyledText {
                            width: redirectTable.numW
                            horizontalAlignment: Text.AlignRight
                            text: root.fmtBytes(root.redirectDirectUp)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }
                    }
                }
            }
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

                    // Cards in user-defined order & visibility
                    Repeater {
                        model: root.cardModel
                        delegate: Loader {
                            width: contentCol.width
                            sourceComponent: root.cardComponent(modelData)
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: root.popoutContentH

    readonly property real popoutContentH: {
        var h = 0
        for (var i = 0; i < root.cardModel.length; i++) {
            var id = root.cardModel[i]
            if (id === "speed") h += 80 + Theme.spacingM
            else if (id === "cumulative") h += 78 + Theme.spacingM
            else if (id === "today") h += 170 + Theme.spacingM
            else if (id === "destinations") h += 260 + Theme.spacingM
            else if (id === "redirect") h += 140 + Theme.spacingM
        }
        if (!root.sampleOk) h += 150 + Theme.spacingM
        return Math.max(200, h + 90)
    }
}
