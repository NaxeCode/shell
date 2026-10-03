pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState
    property real maximumHeight: 900
    property string statePath: `${Quickshell.env("HOME")}/.local/state/ai-usage/usage.json`
    property bool refreshEnabled: true
    property var snapshot: ({ providers: [] })
    property string loadError: ""
    property double nowMs: Date.now()
    property bool showDetails: false
    readonly property double ageMinutes: snapshot.fetchedAt ? Math.max(0, (nowMs - Date.parse(snapshot.fetchedAt)) / 60000) : Infinity
    readonly property bool stale: !isFinite(ageMinutes) || ageMinutes >= 20 || loadError !== ""

    implicitWidth: 560
    implicitHeight: Math.min(maximumHeight, cards.implicitHeight + header.implicitHeight + footer.implicitHeight + Tokens.padding.large * 2 + Tokens.spacing.medium * 2)

    function remaining(used: var): real {
        return typeof used === "number" && isFinite(used) && used >= 0 ? Math.max(0, 100 - used) : -1;
    }

    function duration(seconds: real): string {
        const minutes = Math.max(1, Math.round(seconds / 60));
        if (minutes >= 1440)
            return `${Math.floor(minutes / 1440)}d ${Math.floor((minutes % 1440) / 60)}h`;
        if (minutes >= 60)
            return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
        return `${minutes}m`;
    }

    function boundary(window: var): string {
        const seconds = (Date.parse(window.resetsAt || "") - nowMs) / 1000;
        if (!isFinite(seconds))
            return qsTr("Reset not reported");
        if (seconds <= 0)
            return qsTr("Awaiting reset update");
        return (window.closes ? qsTr("Window ends in ") : qsTr("Resets in ")) + duration(seconds);
    }

    function rateLabel(value: var): string {
        return typeof value === "number" && isFinite(value) ? `${value.toFixed(value < 10 ? 1 : 0)} pp/h` : "—";
    }

    function etaLabel(epoch: var): string {
        if (typeof epoch !== "number" || !isFinite(epoch))
            return "—";
        return epoch * 1000 <= nowMs ? qsTr("now") : duration(epoch - nowMs / 1000);
    }

    function forecastLabel(window: var, forecast: var): string {
        if (stale)
            return qsTr("Reading is stale · forecast paused");
        if (Date.parse(window.resetsAt || "") <= nowMs || forecast.state === "reset_due")
            return qsTr("Waiting for the next quota window");
        if (forecast.state === "exhausted")
            return qsTr("Limit reached");
        if (!forecast.state || forecast.state === "learning")
            return qsTr("Learning your pace · at least 30 min needed");
        if (forecast.state === "unavailable")
            return forecast.reason || qsTr("Forecast unavailable");
        if (forecast.etaAt != null)
            return qsTr("Estimated limit in %1%2").arg(etaLabel(forecast.etaAt)).arg(forecast.confidence === "low" ? qsTr(" · low evidence") : "");
        if (forecast.risk === "watch" && forecast.etaLowAt != null)
            return qsTr("Could run out before this window ends");
        if (forecast.risk === "within")
            return qsTr("On pace to last · about %1% left at reset").arg(Math.round(forecast.projectedRemaining));
        return qsTr("Early estimate · about %1% left at window end").arg(Math.round(forecast.projectedRemaining));
    }

    function trendLabel(forecast: var): string {
        if (stale || forecast.state !== "tracking")
            return qsTr("Learning");
        const labels = { rising: qsTr("Rising"), falling: qsTr("Easing"), steady: qsTr("Steady"), idle: qsTr("Quiet") };
        return labels[forecast.trend] || qsTr("Learning");
    }

    function applyText(text: string): void {
        try {
            const parsed = JSON.parse(text);
            if (!Array.isArray(parsed.providers))
                throw new Error("Invalid snapshot");
            snapshot = parsed;
            nowMs = Date.now();
            loadError = "";
        } catch (error) {
            loadError = qsTr("Usage file is unreadable");
        }
    }

    Timer {
        interval: 30000
        running: root.screenState.usage
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    FileView {
        id: usageFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyText(text())
        onFileChanged: reload()
    }

    Process {
        id: refresh
        command: [`${Quickshell.env("HOME")}/.local/bin/ai-usage`]
        stdout: StdioCollector { onStreamFinished: usageFile.reload() }
    }

    Connections {
        target: root.screenState
        function onUsageChanged(): void {
            if (root.screenState.usage && root.refreshEnabled && !refresh.running)
                refresh.running = true;
        }
    }

    Component.onCompleted: {
        if (screenState.usage && refreshEnabled)
            refresh.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "monitoring"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText { text: qsTr("AI capacity"); font: Tokens.font.title.medium }
                StyledText {
                    text: root.loadError || (refresh.running ? qsTr("Refreshing…") : !isFinite(root.ageMinutes) ? qsTr("Waiting for a reading") : root.ageMinutes < 1 ? qsTr("Updated just now") : qsTr("Updated %1m ago").arg(Math.floor(root.ageMinutes)))
                    color: root.stale ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }
            }
            IconButton {
                icon: root.showDetails ? "unfold_less" : "query_stats"
                type: IconButton.Text
                onClicked: root.showDetails = !root.showDetails
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: qsTr("Forecast details and model evidence")
                Accessible.name: qsTr("Toggle forecast details")
            }
            IconButton {
                icon: "refresh"
                type: IconButton.Text
                disabled: refresh.running || !root.refreshEnabled
                onClicked: refresh.running = true
                QQC.ToolTip.visible: hovered
                QQC.ToolTip.text: qsTr("Refresh usage")
                Accessible.name: qsTr("Refresh usage")
            }
        }

        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: cards.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true
            QQC.ScrollBar.vertical: StyledScrollBar { flickable: scroll }

            ColumnLayout {
                id: cards
                width: scroll.width
                spacing: Tokens.spacing.small

                StyledText {
                    visible: !root.snapshot.providers.length
                    text: root.loadError || qsTr("Checking your usage…")
                }
                Repeater {
                    model: root.snapshot.providers
                    LimitCard {
                        required property var modelData
                        Layout.fillWidth: true
                        provider: modelData
                    }
                }
            }
        }

        StyledText {
            id: footer
            Layout.fillWidth: true
            text: root.showDetails ? qsTr("White tick: projected remaining · sparkline: usage this window\nLocal estimates, not guarantees · pp = percentage points") : qsTr("Local estimates, not guarantees · pp = percentage points")
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }
    }
    component Sparkline: Canvas {
        id: sparkline
        required property var points
        required property color ink
        implicitWidth: 78
        implicitHeight: 24
        onPointsChanged: requestPaint()
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!points || points.length < 2)
                return;
            const low = Math.min(...points.map(p => p.y));
            const high = Math.max(...points.map(p => p.y));
            const spread = Math.max(2, high - low);
            ctx.strokeStyle = ink;
            ctx.lineWidth = 1.8;
            ctx.lineJoin = "round";
            ctx.beginPath();
            for (let i = 0; i < points.length; ++i) {
                const x = 2 + points[i].x * (width - 4);
                const y = height - 3 - (points[i].y - low) / spread * (height - 6);
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }

    component UsageMeter: ColumnLayout {
        id: meter
        required property var window
        readonly property var forecast: window.forecast || ({})
        readonly property real leftValue: root.remaining(window.percent)
        readonly property bool tracking: !root.stale && forecast.state === "tracking" && Date.parse(window.resetsAt || "") > root.nowMs
        readonly property color accent: root.stale ? Colours.palette.m3outline : forecast.risk === "likely" || forecast.risk === "exhausted" ? Colours.palette.m3error : forecast.risk === "watch" ? Colours.palette.m3primary : Colours.palette.m3tertiary
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: meter.window.label
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }
            StyledText {
                text: meter.leftValue < 0 ? "—" : `${Math.round(meter.leftValue)}%`
                font: Tokens.font.title.medium
                color: meter.accent
            }
            StyledText { text: qsTr("left"); color: Colours.palette.m3onSurfaceVariant }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 7
            radius: 3.5
            color: Colours.palette.m3surfaceContainerHighest
            clip: true
            Rectangle {
                width: parent.width * Math.max(0, meter.leftValue) / 100
                height: parent.height
                radius: parent.radius
                color: meter.accent
                opacity: root.stale ? 0.45 : 1
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                visible: meter.tracking && typeof meter.forecast.projectedRemaining === "number"
                x: Math.max(0, Math.min(parent.width - width, parent.width * (meter.forecast.projectedRemaining || 0) / 100))
                width: 2
                height: parent.height
                color: Colours.palette.m3onSurface
            }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.boundary(meter.window)
                color: Colours.palette.m3onSurfaceVariant
            }
            MaterialIcon {
                text: !meter.tracking ? "hourglass_empty" : meter.forecast.trend === "rising" ? "trending_up" : meter.forecast.trend === "falling" ? "trending_down" : "trending_flat"
                color: meter.accent
                fontStyle: Tokens.font.icon.small
            }
            StyledText {
                text: meter.tracking ? `${root.trendLabel(meter.forecast)} · ${root.rateLabel(meter.forecast.recentRate)}` : root.stale ? qsTr("Stale") : meter.forecast.state === "exhausted" ? qsTr("At limit") : meter.forecast.state === "reset_due" ? qsTr("Reset due") : meter.forecast.state === "unavailable" ? qsTr("No estimate") : qsTr("Learning")
                color: meter.accent
            }
            Sparkline {
                visible: (meter.forecast.spark || []).length > 1
                points: meter.forecast.spark || []
                ink: meter.accent
                opacity: root.stale ? 0.45 : 1
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.forecastLabel(meter.window, meter.forecast)
            color: meter.tracking ? meter.accent : Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            visible: root.showDetails
            Layout.fillWidth: true
            spacing: 4
            StyledText {
                Layout.fillWidth: true
                visible: meter.tracking
                text: qsTr("To last: ≤ %1 · blended pace: %2").arg(root.rateLabel(meter.forecast.sustainableRate)).arg(root.rateLabel(meter.forecast.rate))
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                visible: meter.tracking
                text: meter.forecast.etaLowAt != null
                    ? qsTr("Scenario range: %1 to %2").arg(root.etaLabel(meter.forecast.etaLowAt)).arg(meter.forecast.etaHighAt != null ? root.etaLabel(meter.forecast.etaHighAt) : qsTr("beyond reset"))
                    : qsTr("At window end: %1–%2% remaining").arg(Math.floor(meter.forecast.remainingLow || 0)).arg(Math.ceil(meter.forecast.remainingHigh || 0))
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                text: qsTr("%1 evidence · %2h observed · %3 samples").arg(meter.forecast.confidence || "low").arg((meter.forecast.observedHours || 0).toFixed(1)).arg(meter.forecast.sampleCount || 0)
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                text: meter.forecast.reason || qsTr("Collecting readings every five minutes. No history is invented.")
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
            }
        }
    }

    component LimitCard: Rectangle {
        id: card
        required property var provider
        readonly property bool live: provider.status === "ok"
        readonly property var windows: live ? (provider.windows || []) : []
        color: Colours.palette.m3surfaceContainerHigh
        radius: Tokens.rounding.large
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.22)
        implicitHeight: column.implicitHeight + Tokens.padding.medium * 2

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 10
                    color: Colours.palette.m3surfaceContainerHighest
                    StyledText {
                        anchors.centerIn: parent
                        text: (card.provider.name || "?").slice(0, 1)
                        font: Tokens.font.title.small
                        color: Colours.palette.m3primary
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText { text: card.provider.name || ""; font: Tokens.font.title.small }
                    StyledText {
                        Layout.fillWidth: true
                        text: card.provider.plan || ""
                        visible: text !== ""
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }
                MaterialIcon {
                    visible: !card.live
                    text: "cloud_off"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: !card.live || !card.windows.length
                text: card.provider.detail || qsTr("No quota windows reported")
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: card.windows
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Qt.alpha(Colours.palette.m3outline, 0.2)
                    }
                    UsageMeter { Layout.fillWidth: true; window: modelData }
                }
            }
        }
    }
}
