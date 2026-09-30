import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "../../services/DisplayScale.js" as DisplayScale

Item {
    id: root

    readonly property var activeMonitors: Hypr.monitors.values.filter(monitor => monitor.lastIpcObject && !monitor.lastIpcObject.disabled)
    readonly property var monitorReadings: activeMonitors.map(monitor => monitor.lastIpcObject)

    // Helpers — derive everything from lastIpcObject so cable swaps don't break.
    function fmtHz(hz): string {
        if (!hz)
            return "—";
        const rounded = Math.round(hz);
        if (Math.abs(hz - rounded) < 0.01)
            return `${rounded}`;
        return hz.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
    }

    // Apply runtime monitor changes via the mon-set helper, which edits the
    // matching monitorv2 block in generated monitor-layout.conf and reloads.
    // Disabled outputs must not also have matching monitorv2 blocks, so the
    // old hyprland.conf editor broke after monitor layout generation moved to
    // monitor-layout.conf. Only changed key(s) get sent; unrelated fields stay.
    function monApply(monitor, opts): void {
        if (!monitor?.lastIpcObject)
            return;
        const args = ["mon-set", monitor.name];
        if (opts?.mode?.value)
            args.push(`mode=${opts.mode.value}`);
        if (opts?.vrr !== undefined)
            args.push(`vrr=${opts.vrr ? 1 : 0}`);
        if (opts?.cm !== undefined)
            args.push(`cm=${opts.cm}`);
        if (args.length > 2)
            Quickshell.execDetached(args);
    }
    function monAvailableModes(monitor): var {
        const obj = monitor?.lastIpcObject;
        if (!obj)
            return [];

        const seen = new Set();
        const modes = [];
        for (const raw of obj.availableModes ?? []) {
            const match = raw.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            if (!match)
                continue;
            const mode = {
                width: Number(match[1]),
                height: Number(match[2]),
                rate: Number(match[3]),
                value: raw.replace(/Hz$/, "")
            };
            if (mode.rate < 59)
                continue;
            const key = `${mode.width}x${mode.height}@${mode.rate.toFixed(2)}`;
            if (seen.has(key))
                continue;
            seen.add(key);
            modes.push(mode);
        }

        return modes.filter(mode => {
            const rounded = Math.round(mode.rate);
            const hasExactPeer = modes.some(peer => peer.width === mode.width && peer.height === mode.height && Math.abs(peer.rate - rounded) < 0.01 && Math.abs(peer.rate - mode.rate) < 0.2);
            return Math.abs(mode.rate - rounded) < 0.01 || !hasExactPeer;
        });
    }
    function monAvailableResolutions(monitor): var {
        const preferredAwModes = ["3840x2160", "2560x1440", "1920x1080"];
        const seen = new Set();
        return monAvailableModes(monitor).filter(mode => {
            const key = `${mode.width}x${mode.height}`;
            if (monIsAwOled(monitor) && !preferredAwModes.includes(key))
                return false;
            if (seen.has(key))
                return false;
            seen.add(key);
            return true;
        }).sort((a, b) => (b.width * b.height) - (a.width * a.height));
    }
    function monIsAwOled(monitor): bool {
        return (monitor?.lastIpcObject?.description ?? "").includes("AW3225QF");
    }
    function monModeForResolution(monitor, width: int, height: int): var {
        const currentRate = monitor?.lastIpcObject?.refreshRate ?? 60;
        const modes = monAvailableModes(monitor).filter(mode => mode.width === width && mode.height === height);
        if (!modes.length)
            return null;
        return modes.reduce((best, mode) => Math.abs(mode.rate - currentRate) < Math.abs(best.rate - currentRate) ? mode : best);
    }
    function monModesForCurrentResolution(monitor): var {
        const obj = monitor?.lastIpcObject;
        if (!obj)
            return [];
        return monAvailableModes(monitor).filter(mode => mode.width === obj.width && mode.height === obj.height).sort((a, b) => a.rate - b.rate);
    }

    // Heuristic: panel currently running 10-bit (XRGB2101010) is HDR-capable.
    // 8-bit panels can't drive HDR meaningfully. Caveat: a 10-bit panel that
    // hasn't been forced into 10-bit mode in the user's conf will look like
    // an 8-bit panel here — set bitdepth=10 in monitorv2 to expose the toggle.
    function monSupportsHdr(monitor): bool {
        const fmt = monitor?.lastIpcObject?.currentFormat ?? "";
        return fmt.includes("2101010");
    }

    // Hyprland/DRM do not expose a usable vrr_capable flag through Quickshell.
    // Keep this allowlist explicit: high fixed refresh (e.g. Dell P2425HE 100 Hz)
    // is not the same thing as Adaptive-Sync/VRR support.
    function monSupportsVrr(monitor): bool {
        const desc = monitor?.lastIpcObject?.description ?? "";
        return desc.includes("DELL S3221QS") || monIsAwOled(monitor);
    }

    implicitHeight: layout.implicitHeight

    // Also reflects scale changes made with the existing keyboard shortcuts.
    Timer {
        interval: 2000
        repeat: true
        running: SysControl.polling
        triggeredOnStart: true

        onTriggered: Hypr.refreshMonitors()
    }
    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                font: Tokens.font.title.medium
                text: qsTr("Display controls")
            }
            IconTextButton {
                checked: SysControl.autoHdr
                icon: "auto_awesome"
                text: SysControl.autoHdr ? qsTr("Auto HDR on") : qsTr("Auto HDR off")
                type: checked ? IconTextButton.Filled : IconTextButton.Tonal

                onClicked: SysControl.setAutoHdr(!SysControl.autoHdr)
            }
        }
        // ── Monitor layout ────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                text: qsTr("Monitor layout")
            }
            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        {
                            id: "desk",
                            icon: "dashboard_customize",
                            label: qsTr("Both monitors")
                        },
                        {
                            id: "gaming",
                            icon: "desktop_windows",
                            label: qsTr("OLED only")
                        },
                    ]

                    delegate: IconTextButton {
                        required property var modelData

                        checked: (SysControl.monitorMode === "cool-s" ? "desk" : SysControl.monitorMode) === modelData.id
                        enabled: !checked
                        horizontalPadding: Tokens.padding.medium
                        icon: modelData.icon
                        text: modelData.label
                        type: checked ? IconTextButton.Filled : IconTextButton.Tonal

                        onClicked: SysControl.setMonitorMode(modelData.id)
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                text: qsTr("Layout changes refresh the desktop shell. Save open work first.")
                wrapMode: Text.WordWrap
            }
        }
        StyledRect {
            Layout.fillWidth: true
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: scaleControls.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.medium

            GridLayout {
                id: scaleControls

                anchors.left: parent.left
                anchors.margins: Tokens.padding.small
                anchors.right: parent.right
                anchors.top: parent.top
                columnSpacing: Tokens.spacing.medium
                columns: root.width >= 580 ? 2 : 1
                rowSpacing: Tokens.spacing.small

                StyledText {
                    font: Tokens.font.body.medium
                    text: qsTr("Desktop scale")
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: DisplayScale.steps

                        delegate: IconTextButton {
                            required property var modelData

                            checked: DisplayScale.selected(root.monitorReadings, modelData.value)
                            disabled: SysControl.scaleBusy || !DisplayScale.available(root.monitorReadings, modelData.value) || checked
                            disabledColour: checked ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer
                            disabledOnColour: checked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            horizontalPadding: Tokens.padding.medium
                            text: modelData.label
                            type: checked ? IconTextButton.Filled : IconTextButton.Tonal
                            verticalPadding: Tokens.padding.small

                            onClicked: SysControl.setScale(modelData.argument)
                        }
                    }
                }
                StyledText {
                    Layout.columnSpan: scaleControls.columns
                    Layout.fillWidth: true
                    color: SysControl.scaleError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    text: SysControl.scaleError || (SysControl.scaleBusy ? qsTr("Applying scale…") : qsTr("All displays · saved across restarts and sign-ins."))
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ── Connected monitors ────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                text: qsTr("Connected monitors")
            }
            GridLayout {
                Layout.fillWidth: true
                columnSpacing: Tokens.spacing.small
                columns: root.width >= 680 ? 2 : 1
                rowSpacing: Tokens.spacing.small

                Repeater {
                    model: ScriptModel {
                        values: root.activeMonitors
                    }

                    delegate: StyledRect {
                        id: tile

                        readonly property bool brightnessAvailable: brightnessMonitor !== null && brightnessMonitor !== undefined
                        readonly property var brightnessMonitor: Brightness.getMonitor(modelData?.name ?? "")
                        readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
                        readonly property bool hdrCapable: root.monSupportsHdr(modelData)
                        readonly property bool hdrOn: (modelData?.lastIpcObject?.colorManagementPreset ?? "srgb") !== "srgb"
                        readonly property real hz: modelData?.lastIpcObject?.refreshRate ?? 0
                        readonly property bool isAwOled: root.monIsAwOled(modelData)
                        readonly property int modeHeight: modelData?.lastIpcObject?.height ?? 0
                        readonly property int modeWidth: modelData?.lastIpcObject?.width ?? 0
                        required property var modelData
                        readonly property var rates: root.monModesForCurrentResolution(modelData)
                        readonly property var resolutions: root.monAvailableResolutions(modelData)
                        readonly property bool vrrCapable: root.monSupportsVrr(modelData)
                        // VRR state from conf, NOT from lastIpcObject.vrr.
                        // lastIpcObject.vrr reports engagement (bool); for
                        // vrr=2 (fullscreen-only) it stays false at idle.
                        readonly property bool vrrOn: {
                            const v = SysControl.monitorConf[modelData?.name]?.vrr;
                            return v !== undefined && v !== "0";
                        }

                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.preferredHeight: monCol.implicitHeight + Tokens.padding.medium * 2
                        color: Colours.tPalette.m3surfaceContainer
                        radius: Tokens.rounding.medium

                        ColumnLayout {
                            id: monCol

                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.top: parent.top
                            anchors.topMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.small

                            // ── Header: icon + name + current Hz ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                    text: "monitor"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true

                                        StyledText {
                                            Layout.fillWidth: true
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                            font: Tokens.font.body.small
                                            text: tile.isAwOled ? "Alienware OLED" : (tile.modelData?.lastIpcObject?.model ?? tile.modelData?.name ?? "Display")
                                        }
                                        StyledText {
                                            color: Colours.palette.m3onSurfaceVariant
                                            font: Tokens.font.body.small
                                            text: DisplayScale.label(tile.modelData?.lastIpcObject?.scale)
                                        }
                                    }
                                    StyledText {
                                        color: Colours.palette.m3primary
                                        font: Tokens.font.body.medium
                                        text: `${tile.modeWidth}×${tile.modeHeight} · ${root.fmtHz(tile.hz)} Hz`
                                    }
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            // ── Display brightness ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small
                                visible: tile.brightnessAvailable

                                MaterialIcon {
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                    text: `brightness_${Math.max(1, Math.min(7, Math.round(tile.brightnessValue * 6) + 1))}`
                                }
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: Tokens.padding.medium * 3

                                    StyledSlider {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        bgColour: Colours.palette.m3outlineVariant
                                        value: tile.brightnessValue

                                        onInteraction: value => tile.brightnessMonitor?.setBrightness(value)
                                    }
                                }
                                StyledText {
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                    text: `${Math.round(tile.brightnessValue * 100)}%`
                                }
                            }

                            // ── Dell AW OLED resolution buttons ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall
                                visible: tile.isAwOled && tile.resolutions.length > 1

                                Repeater {
                                    model: tile.resolutions

                                    delegate: IconTextButton {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        checked: tile.modeWidth === modelData.width && tile.modeHeight === modelData.height
                                        font: Tokens.font.body.small
                                        text: modelData.width === 3840 ? "4K" : modelData.height === 1440 ? "1440p" : modelData.height === 1080 ? "1080p" : `${modelData.width}×${modelData.height}`
                                        type: IconTextButton.Tonal
                                        verticalPadding: Tokens.padding.small

                                        onClicked: root.monApply(tile.modelData, {
                                            mode: root.monModeForResolution(tile.modelData, modelData.width, modelData.height)
                                        })
                                    }
                                }
                            }

                            // ── Refresh rate buttons (only if multiple rates) ──
                            Flow {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall
                                visible: tile.rates.length > 1

                                Repeater {
                                    model: tile.rates

                                    delegate: IconTextButton {
                                        required property var modelData

                                        checked: Math.abs(tile.hz - modelData.rate) < 0.05
                                        font: Tokens.font.body.small
                                        text: root.fmtHz(modelData.rate) + " Hz"
                                        type: IconTextButton.Tonal
                                        verticalPadding: Tokens.padding.small

                                        onClicked: root.monApply(tile.modelData, {
                                            mode: modelData
                                        })
                                    }
                                }
                            }

                            // ── VRR + HDR toggles (only if heuristic detects support) ──
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall
                                visible: tile.vrrCapable || tile.hdrCapable

                                IconTextButton {
                                    Layout.fillWidth: true
                                    checked: tile.vrrOn
                                    font: Tokens.font.body.small
                                    icon: "tv_gen"
                                    text: tile.vrrOn ? qsTr("VRR on") : qsTr("VRR off")
                                    type: IconTextButton.Tonal
                                    verticalPadding: Tokens.padding.small
                                    visible: tile.vrrCapable

                                    onClicked: root.monApply(tile.modelData, {
                                        vrr: !tile.vrrOn
                                    })
                                }
                                IconTextButton {
                                    Layout.fillWidth: true
                                    checked: tile.hdrOn
                                    font: Tokens.font.body.small
                                    icon: "hdr_on"
                                    text: tile.hdrOn ? qsTr("HDR on") : qsTr("HDR off")
                                    type: IconTextButton.Tonal
                                    verticalPadding: Tokens.padding.small
                                    visible: tile.hdrCapable

                                    onClicked: root.monApply(tile.modelData, {
                                        cm: tile.hdrOn ? "srgb" : "hdredid"
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
